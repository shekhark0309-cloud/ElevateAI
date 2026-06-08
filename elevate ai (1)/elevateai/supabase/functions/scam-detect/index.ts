// supabase/functions/scam-detect/index.ts
// ═══════════════════════════════════════════════════════════════
// ElevateAI — ScamShield: AI-Powered Opportunity Fraud Detection
//
// Triggered via:
//   1. Supabase Webhook on opportunities INSERT
//   2. Manual scan request from admin/student
//
// Analyzes: title, description, URL, organizer, prize structure
// Returns: risk_score (0-100), risk_level, flags, explanation
// Auto-flags suspicious entries (risk_score > 60)
// ═══════════════════════════════════════════════════════════════

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import {
  createServiceClient,
  successResponse,
  errorResponse,
  optionsResponse,
  callAI,
  parseAIJson,
  createNotification,
  getAuthenticatedUser,
} from "../_shared/utils.ts";

// ─── Types ────────────────────────────────────────────────────

interface ScamAnalysisResult {
  risk_score: number;         // 0-100 (0 = safe, 100 = definite scam)
  risk_level: "safe" | "low" | "medium" | "high" | "critical";
  flags: string[];            // Specific red flags found
  explanation: string;        // Human-readable summary
  recommendation: string;     // What action to take
  confidence: number;         // AI confidence in assessment (0-1)
}

// Known legitimate Indian institutions/platforms (lower suspicion)
const TRUSTED_ORGANIZERS = [
  "iit", "nit", "bits", "mhrd", "ugc", "aicte", "nsf", "dst",
  "google", "microsoft", "amazon", "flipkart", "infosys", "wipro",
  "tata", "reliance", "devfolio", "hackerearth", "unstop", "internshala",
  "ministry", "government", "gov.in", "nic.in",
];

// Suspicious patterns
const SCAM_URL_PATTERNS = [
  "bit.ly", "tinyurl", "t.ly", "rb.gy", "shorturl",
  "telegram.me/", "whatsapp.com/",  // legitimate platforms misused for scams
];

const SCAM_KEYWORDS = [
  "pay to apply", "registration fee required", "deposit required",
  "wire transfer", "western union", "bitcoin payment",
  "guaranteed selection", "100% job placement", "no interview required",
  "work from home guaranteed", "earn per day", "earn per hour",
  "click here to claim", "limited time only", "act now",
  "provide your bank details", "share your aadhar",
];

// ─── Main Handler ─────────────────────────────────────────────

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return optionsResponse();
  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  const { user, error: authError } = await getAuthenticatedUser(req);
  if (authError || !user) return errorResponse("Unauthorized", 401);

  let body: {
    // From Supabase Webhook
    type?: string;
    record?: Record<string, unknown>;
    // From manual scan
    opportunity_id?: string;
    // Direct content scan (no DB lookup needed)
    title?: string;
    description?: string;
    url?: string;
    organizer?: string;
    prize_amount?: number;
  };

  try {
    body = await req.json();
  } catch {
    return errorResponse("Invalid JSON body");
  }

  const supabase = createServiceClient();

  // ── Resolve opportunity data ───────────────────────────────
  let oppData: {
    id?: string;
    title: string;
    description?: string;
    apply_url?: string;
    organizer_name?: string;
    prize_amount?: number;
    stipend_amount?: number;
    type?: string;
    posted_by?: string;
  };

  if (body.type === "INSERT" && body.record) {
    // From Supabase Webhook
    oppData = body.record as typeof oppData;
  } else if (body.opportunity_id) {
    // Manual scan by opportunity ID
    const { data, error } = await supabase
      .from("opportunities")
      .select("id, title, description, apply_url, organizer_name, prize_amount, stipend_amount, type, posted_by")
      .eq("id", body.opportunity_id)
      .single();

    if (error || !data) return errorResponse("Opportunity not found", 404);
    oppData = data;
  } else if (body.title) {
    // Direct content scan
    oppData = {
      title: body.title,
      description: body.description,
      apply_url: body.url,
      organizer_name: body.organizer,
      prize_amount: body.prize_amount,
    };
  } else {
    return errorResponse("Provide opportunity_id, title, or webhook record");
  }

  try {
    // ── 1. Rule-based pre-screening (fast, no AI) ─────────────
    const preScreenFlags: string[] = [];
    let preScreenScore = 0;

    // Check for suspicious keywords in title/description
    const contentToScan = `${oppData.title} ${oppData.description ?? ""}`.toLowerCase();
    for (const keyword of SCAM_KEYWORDS) {
      if (contentToScan.includes(keyword.toLowerCase())) {
        preScreenFlags.push(`Suspicious keyword: "${keyword}"`);
        preScreenScore += 15;
      }
    }

    // Check URL
    if (oppData.apply_url) {
      for (const pattern of SCAM_URL_PATTERNS) {
        if (oppData.apply_url.toLowerCase().includes(pattern)) {
          preScreenFlags.push(`Suspicious URL pattern: ${pattern}`);
          preScreenScore += 20;
        }
      }
      // No HTTPS
      if (oppData.apply_url.startsWith("http://")) {
        preScreenFlags.push("Apply URL uses unsecured HTTP (not HTTPS)");
        preScreenScore += 10;
      }
    }

    // Prize amount too good to be true
    if (oppData.prize_amount && oppData.prize_amount > 10000000) { // > 1 crore
      preScreenFlags.push(`Unusually high prize amount: ₹${(oppData.prize_amount / 100000).toFixed(1)}L`);
      preScreenScore += 15;
    }

    // Check if organizer is in trusted list
    const organizerLower = (oppData.organizer_name ?? "").toLowerCase();
    const isTrustedOrganizer = TRUSTED_ORGANIZERS.some((org) => organizerLower.includes(org));
    if (isTrustedOrganizer) preScreenScore -= 20; // bonus for trusted organizers
    if (!oppData.organizer_name) {
      preScreenFlags.push("No organizer name provided");
      preScreenScore += 10;
    }

    // ── 2. AI deep analysis (only if not obviously safe/scam) ──
    let aiResult: ScamAnalysisResult | null = null;

    const needsAIAnalysis = preScreenScore > 10 || preScreenScore < 0 || preScreenFlags.length > 0;

    if (needsAIAnalysis) {
      try {
        aiResult = await analyzeWithAI(oppData, preScreenFlags, preScreenScore);
      } catch (aiError) {
        console.warn("AI scam analysis failed, using rule-based only:", aiError);
      }
    }

    // ── 3. Combine scores ─────────────────────────────────────
    const finalScore = aiResult
      ? Math.round(aiResult.risk_score * 0.7 + Math.max(0, Math.min(100, preScreenScore)) * 0.3)
      : Math.max(0, Math.min(100, preScreenScore));

    const allFlags = [
      ...preScreenFlags,
      ...(aiResult?.flags ?? []),
    ].filter((f, i, arr) => arr.indexOf(f) === i); // deduplicate

    const riskLevel = getRiskLevel(finalScore);
    const finalResult: ScamAnalysisResult = {
      risk_score: finalScore,
      risk_level: riskLevel,
      flags: allFlags,
      explanation: aiResult?.explanation ?? generateRuleBasedExplanation(finalScore, allFlags, oppData),
      recommendation: generateRecommendation(riskLevel),
      confidence: aiResult?.confidence ?? (preScreenFlags.length > 0 ? 0.7 : 0.5),
    };

    // ── 4. Update opportunity if found in DB ──────────────────
    if (oppData.id) {
      if (finalScore >= 60) {
        // Auto-flag as unverified and notify admins
        await supabase
          .from("opportunities")
          .update({
            is_verified: false,
            meta: supabase.rpc("jsonb_merge", {
              // Append scam detection result to meta
              original: oppData,
              override: {
                scam_scan: {
                  risk_score: finalScore,
                  risk_level: riskLevel,
                  scanned_at: new Date().toISOString(),
                  flags: allFlags.slice(0, 5),
                },
              },
            }),
          })
          .eq("id", oppData.id);

        // Create scam report automatically for high-risk
        if (finalScore >= 75) {
          await supabase.from("scam_reports").upsert({
            reported_by: oppData.posted_by ?? "00000000-0000-0000-0000-000000000000",
            opportunity_id: oppData.id,
            category: "fake_opportunity",
            status: "investigating",
            title: `Auto-detected: ${oppData.title}`,
            description: finalResult.explanation,
            evidence_urls: oppData.apply_url ? [oppData.apply_url] : [],
          }, { onConflict: "opportunity_id,category" });
        }

        // Notify poster (if any) about the flag
        if (oppData.posted_by) {
          await createNotification(
            supabase,
            oppData.posted_by,
            "opportunity_flagged",
            "⚠️ Your opportunity listing was flagged",
            `"${oppData.title}" has been flagged for review (risk score: ${finalScore}/100). Please add more details or contact support.`,
            { opportunity_id: oppData.id, risk_score: finalScore, flags: allFlags.slice(0, 3) }
          );
        }
      } else if (finalScore < 20 && !isTrustedOrganizer) {
        // Auto-verify clean opportunities
        await supabase
          .from("opportunities")
          .update({ is_verified: true })
          .eq("id", oppData.id)
          .eq("is_verified", false);
      }
    }

    return successResponse({
      opportunity_id: oppData.id ?? null,
      title: oppData.title,
      ...finalResult,
      pre_screen_flags: preScreenFlags,
      auto_action: finalScore >= 75 ? "flagged_and_reported" : finalScore >= 60 ? "unverified" : finalScore < 20 ? "auto_verified" : "manual_review",
    });

  } catch (e) {
    console.error("scam-detect error:", e);
    return errorResponse(e instanceof Error ? e.message : "Unexpected error", 500);
  }
});

// ─── AI Analysis ──────────────────────────────────────────────

async function analyzeWithAI(
  opp: { title: string; description?: string; apply_url?: string; organizer_name?: string; prize_amount?: number; type?: string },
  preFlags: string[],
  preScore: number
): Promise<ScamAnalysisResult> {
  const systemPrompt = `You are ElevateAI's fraud detection AI, specialized in identifying fake/scam opportunities targeting Indian college students.

Common scams in India:
- Fake scholarship portals asking for registration fees
- Fake internship offers from impersonated companies
- Multi-level marketing disguised as "business development internships"
- Phishing opportunities collecting Aadhaar/bank details
- Too-good-to-be-true prize money competitions

Be thorough but not paranoid. Legitimate opportunities exist at all prize levels.
Respond ONLY with valid JSON.`;

  const userPrompt = `Analyze this opportunity for potential fraud:

Title: "${opp.title}"
Type: ${opp.type ?? "Unknown"}
Organizer: "${opp.organizer_name ?? "Not provided"}"
Apply URL: ${opp.apply_url ?? "None"}
Prize/Stipend: ${opp.prize_amount ? `₹${opp.prize_amount.toLocaleString("en-IN")}` : "Not specified"}
Description excerpt: "${(opp.description ?? "").substring(0, 500)}"

Pre-screen flags already found: ${preFlags.join("; ") || "None"}
Pre-screen score: ${preScore}/100

Return JSON:
{
  "risk_score": 0-100,
  "risk_level": "safe|low|medium|high|critical",
  "flags": ["specific flag 1", "specific flag 2"],
  "explanation": "2-sentence explanation of your assessment",
  "recommendation": "1 actionable sentence for students",
  "confidence": 0.0-1.0
}`;

  const response = await callAI(
    [{ role: "user", content: userPrompt }],
    systemPrompt,
    400
  );

  return parseAIJson<ScamAnalysisResult>(response);
}

// ─── Helpers ──────────────────────────────────────────────────

function getRiskLevel(score: number): ScamAnalysisResult["risk_level"] {
  if (score >= 75) return "critical";
  if (score >= 60) return "high";
  if (score >= 40) return "medium";
  if (score >= 20) return "low";
  return "safe";
}

function generateRuleBasedExplanation(
  score: number,
  flags: string[],
  opp: { title: string; organizer_name?: string }
): string {
  if (score >= 75) {
    return `"${opp.title}" shows multiple high-risk indicators: ${flags.slice(0, 2).join(", ")}. This opportunity has been automatically flagged for investigation.`;
  }
  if (score >= 40) {
    return `"${opp.title}" by ${opp.organizer_name ?? "unknown organizer"} has some characteristics requiring manual review: ${flags[0] ?? "unusual patterns detected"}.`;
  }
  return `"${opp.title}" appears to be a legitimate opportunity with ${flags.length === 0 ? "no significant" : "minor"} red flags.`;
}

function generateRecommendation(riskLevel: ScamAnalysisResult["risk_level"]): string {
  const map = {
    critical: "Do NOT apply. This has been flagged as highly suspicious. Report to your college's placement cell immediately.",
    high: "Proceed with extreme caution. Verify the organizer directly via official channels before sharing any personal information.",
    medium: "Verify the organizer's official website before applying. Never pay any registration or processing fee.",
    low: "Opportunity looks mostly legitimate but double-check the organizer's credentials before sharing sensitive documents.",
    safe: "This opportunity appears legitimate. Apply with confidence, but always protect your personal information.",
  };
  return map[riskLevel];
}
