// supabase/functions/recalculate-dna/index.ts
// ═══════════════════════════════════════════════════════════════
// ElevateAI — Student DNA Engine: Full AI-Powered Profile Analysis
//
// Fetches complete student profile → sends to Claude for deep analysis
// → updates student_dna with AI narrative, archetype, strengths, etc.
// → creates notification → logs to history
//
// Called:
//   - On student profile completion
//   - After earning 3+ new badges
//   - After joining/completing a team event
//   - Weekly batch via cron
//   - Manual "Refresh my DNA" button in Flutter app
// ═══════════════════════════════════════════════════════════════

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import {
  createServiceClient,
  successResponse,
  errorResponse,
  optionsResponse,
  createNotification,
  callAI,
  parseAIJson,
  isRateLimited,
  StudentFullProfile,
} from "../_shared/utils.ts";

// ─── Types ────────────────────────────────────────────────────

interface DNAAnalysisResult {
  ai_summary: string;
  ai_strengths: string[];
  ai_growth_areas: string[];
  ai_team_role_hint: string;
  archetype: "Builder" | "Strategist" | "Creative" | "Executor";
  archetype_confidence: number;
  target_roles_suggestion: string[];
  preferred_industries_suggestion: string[];
}

// ─── Main Handler ─────────────────────────────────────────────

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return optionsResponse();
  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  let body: { student_id?: string; batch_all?: boolean };
  try {
    body = await req.json();
  } catch {
    return errorResponse("Invalid JSON body");
  }

  const supabase = createServiceClient();

  // ── Batch mode: recalculate all active students (cron only) ──
  if (body.batch_all) {
    const authHeader = req.headers.get("Authorization") ?? "";
    // Verify this is a service-role call (cron)
    if (!authHeader.includes(Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "")) {
      return errorResponse("Batch mode requires service role", 403);
    }

    const { data: students, error } = await supabase
      .from("student_profiles")
      .select("id")
      .eq("is_active", true)
      .is("deleted_at", null);

    if (error) return errorResponse(`Failed to list students: ${error.message}`, 500);

    // Process in serial to stay under free-tier AI rate limits
    const results: { id: string; success: boolean }[] = [];
    for (const s of students ?? []) {
      try {
        await processStudentDNA(supabase, s.id);
        results.push({ id: s.id, success: true });
      } catch (e) {
        console.error(`DNA batch failed for ${s.id}:`, e);
        results.push({ id: s.id, success: false });
      }
      // Small delay to avoid API rate limits on free tier
      await new Promise((r) => setTimeout(r, 500));
    }

    return successResponse({ batch: true, processed: results.length, results });
  }

  // ── Single student mode ──────────────────────────────────────
  const { student_id } = body;
  if (!student_id) return errorResponse("student_id is required");

  // Rate limit: 5 DNA recalcs per student per hour
  if (isRateLimited(`dna:${student_id}`, 5, 60 * 60 * 1000)) {
    return errorResponse("DNA recalculation rate limit exceeded. Try again later.", 429);
  }

  try {
    const result = await processStudentDNA(supabase, student_id);
    return successResponse(result);
  } catch (e) {
    console.error("DNA recalculation error:", e);
    return errorResponse(e instanceof Error ? e.message : "Unexpected error", 500);
  }
});

// ─── Core Logic ───────────────────────────────────────────────

async function processStudentDNA(
  supabase: ReturnType<typeof createServiceClient>,
  studentId: string
) {
  const startTime = Date.now();

  // ── 1. Fetch complete student profile ─────────────────────────
  const { data: profile, error: profileErr } = await supabase
    .from("student_profiles")
    .select(`
      id, full_name, college_id, course, branch, year_of_study,
      graduation_year, cgpa, state, category, family_income, gender,
      student_skills ( skill_name, proficiency, is_verified, source ),
      student_projects ( title, description, tech_stack, role, outcome, is_featured ),
      student_achievements ( title, achievement_type, issued_by, is_verified ),
      student_badges (
        verify_status, earned_at,
        skill_badges ( name, category, level, xp_value )
      )
    `)
    .eq("id", studentId)
    .eq("is_active", true)
    .single() as { data: StudentFullProfile | null; error: unknown };

  if (profileErr || !profile) {
    throw new Error(`Student not found: ${studentId}`);
  }

  // ── 2. Fetch existing DNA (for context) ───────────────────────
  const { data: existingDNA } = await supabase
    .from("student_dna")
    .select("archetype, goals_short_term, goals_long_term, version, study_streak, focus_score")
    .eq("student_id", studentId)
    .single();

  // ── 3. Fetch TrustScore for context ───────────────────────────
  const { data: trustScore } = await supabase
    .from("trust_scores")
    .select("overall_score, tier, reliability_score, collaboration_score")
    .eq("student_id", studentId)
    .single();

  // ── 4. Fetch recent peer ratings ─────────────────────────────
  const { data: recentRatings } = await supabase
    .from("peer_ratings")
    .select("overall, dimensions, context_type")
    .eq("ratee_id", studentId)
    .order("created_at", { ascending: false })
    .limit(10);

  // ── 5. Prepare AI context (compact, token-efficient) ──────────
  const verifiedSkills = profile.student_skills?.filter((s) => s.is_verified) ?? [];
  const allSkills = profile.student_skills ?? [];
  const verifiedBadges = profile.student_badges?.filter((b) => b.verify_status === "verified") ?? [];
  const featuredProjects = profile.student_projects?.filter((p) => p.is_featured) ?? profile.student_projects?.slice(0, 3) ?? [];

  const profileContext = {
    identity: {
      name: profile.full_name,
      course: profile.course,
      branch: profile.branch,
      year: profile.year_of_study,
      cgpa: profile.cgpa,
      state: profile.state,
      gender: profile.gender,
    },
    skills: {
      verified: verifiedSkills.map((s) => ({ name: s.skill_name, level: s.proficiency })),
      self_reported: allSkills
        .filter((s) => !s.is_verified)
        .map((s) => ({ name: s.skill_name, level: s.proficiency })),
      total_count: allSkills.length,
    },
    badges: verifiedBadges.map((b) => ({
      name: b.skill_badges?.name,
      category: b.skill_badges?.category,
      level: b.skill_badges?.level,
    })),
    projects: featuredProjects.map((p) => ({
      title: p.title,
      tech: p.tech_stack,
      role: p.role,
      outcome: p.outcome,
    })),
    achievements: profile.student_achievements?.map((a) => ({
      title: a.title,
      type: a.achievement_type,
      by: a.issued_by,
    })) ?? [],
    existing_goals: existingDNA
      ? {
          short_term: existingDNA.goals_short_term,
          long_term: existingDNA.goals_long_term,
        }
      : null,
    behavioral: existingDNA
      ? {
          study_streak: existingDNA.study_streak,
          focus_score: existingDNA.focus_score,
        }
      : null,
    trust: trustScore
      ? {
          score: trustScore.overall_score,
          tier: trustScore.tier,
          reliability: trustScore.reliability_score,
          collaboration: trustScore.collaboration_score,
        }
      : null,
    peer_feedback_avg:
      recentRatings && recentRatings.length > 0
        ? Number(
            (recentRatings.reduce((sum, r) => sum + (r.overall ?? 0), 0) / recentRatings.length).toFixed(2)
          )
        : null,
  };

  // ── 6. Call Claude API for deep analysis ─────────────────────
  const systemPrompt = `You are ElevateAI's Student DNA Analyzer. You deeply understand Indian students' academic and career journeys.

Analyze the student profile and produce a structured JSON response. Be specific, encouraging, and actionable.
Use Indian context (IITs, NITs, startups, GATE, CAT, internships, etc.) where relevant.

Archetypes:
- Builder: Loves building products, writing code, creating tangible things. Thrives with autonomy.  
- Strategist: Analytical, loves planning, data, business models. Natural leader/consultant.
- Creative: Design-forward, storytelling, marketing, ideation. Brings vision to teams.
- Executor: Gets things done, reliable, detail-oriented, project management, operations.

IMPORTANT: Respond ONLY with valid JSON — no explanation, no markdown, no preamble.`;

  const userPrompt = `Analyze this student profile and return a JSON with EXACTLY these fields:

{
  "ai_summary": "2-sentence professional bio in first person, specific to their skills and background",
  "ai_strengths": ["strength1", "strength2", "strength3"],
  "ai_growth_areas": ["area1", "area2"],
  "ai_team_role_hint": "one clear sentence about their ideal team role",
  "archetype": "Builder|Strategist|Creative|Executor",
  "archetype_confidence": 0.0-1.0,
  "target_roles_suggestion": ["role1", "role2", "role3"],
  "preferred_industries_suggestion": ["industry1", "industry2"]
}

Profile:
${JSON.stringify(profileContext, null, 2)}`;

  let aiResult: DNAAnalysisResult;
  try {
    const aiResponse = await callAI(
      [{ role: "user", content: userPrompt }],
      systemPrompt,
      800
    );
    aiResult = parseAIJson<DNAAnalysisResult>(aiResponse);
  } catch (aiError) {
    // ── Fallback: Generate rule-based DNA if AI fails ─────────
    console.warn("AI call failed, using rule-based fallback:", aiError);
    aiResult = generateRuleBasedDNA(profile, verifiedSkills, verifiedBadges);
  }

  // ── 7. Validate archetype is a valid enum value ───────────────
  const validArchetypes = ["Builder", "Strategist", "Creative", "Executor"];
  if (!validArchetypes.includes(aiResult.archetype)) {
    aiResult.archetype = "Builder"; // safe default
    aiResult.archetype_confidence = 0.3;
  }

  // ── 8. Upsert student_dna ─────────────────────────────────────
  const dnaPayload = {
    student_id: studentId,
    archetype: aiResult.archetype,
    archetype_confidence: Math.min(1, Math.max(0, aiResult.archetype_confidence)),
    ai_summary: aiResult.ai_summary,
    ai_strengths: aiResult.ai_strengths?.slice(0, 5) ?? [],
    ai_growth_areas: aiResult.ai_growth_areas?.slice(0, 3) ?? [],
    ai_team_role_hint: aiResult.ai_team_role_hint,
    // Suggest roles/industries if student hasn't set them yet
    ...((!existingDNA?.goals_short_term?.length) && {
      target_roles: aiResult.target_roles_suggestion?.slice(0, 5) ?? [],
      preferred_industries: aiResult.preferred_industries_suggestion?.slice(0, 3) ?? [],
    }),
    top_skills: verifiedSkills
      .sort((a, b) => b.proficiency - a.proficiency)
      .slice(0, 10)
      .map((s) => s.skill_name),
    last_ai_updated: new Date().toISOString(),
  };

  const { error: dnaError } = await supabase
    .from("student_dna")
    .upsert(dnaPayload, { onConflict: "student_id" });

  if (dnaError) throw new Error(`Failed to update DNA: ${dnaError.message}`);

  // ── 9. Create notification ────────────────────────────────────
  await createNotification(
    supabase,
    studentId,
    "dna_updated",
    "🧬 Your DNA Profile Updated!",
    `New insight: You're a ${aiResult.archetype} — ${aiResult.ai_team_role_hint}`,
    {
      archetype: aiResult.archetype,
      confidence: aiResult.archetype_confidence,
      strengths_count: aiResult.ai_strengths?.length ?? 0,
    }
  );

  // ── 10. Log DNA update event ──────────────────────────────────
  await supabase.from("trust_score_history").insert({
    student_id: studentId,
    overall_score: trustScore?.overall_score ?? 0,
    delta: 0,
    reason: "DNA profile refreshed via AI analysis",
    source: "dna_engine",
    snapshot: { archetype: aiResult.archetype, skills_count: allSkills.length },
  });

  const elapsed = Date.now() - startTime;
  console.log(`DNA recalculated for ${studentId} in ${elapsed}ms`);

  return {
    student_id: studentId,
    archetype: aiResult.archetype,
    archetype_confidence: aiResult.archetype_confidence,
    ai_summary: aiResult.ai_summary,
    ai_strengths: aiResult.ai_strengths,
    ai_growth_areas: aiResult.ai_growth_areas,
    ai_team_role_hint: aiResult.ai_team_role_hint,
    elapsed_ms: elapsed,
    dna_version: (existingDNA?.version ?? 0) + 1,
  };
}

// ─── Rule-Based Fallback DNA (no AI required) ─────────────────

function generateRuleBasedDNA(
  profile: StudentFullProfile,
  verifiedSkills: { skill_name: string; proficiency: number }[],
  verifiedBadges: { skill_badges?: { name: string; category: string } }[]
): DNAAnalysisResult {
  const techSkills = ["Python", "JavaScript", "React", "Flutter", "Machine Learning", "AI", "Blockchain", "Web Development"];
  const designSkills = ["UI/UX", "Figma", "Canva", "Graphic Design", "Photoshop"];
  const bizSkills = ["Finance", "Marketing", "Business Analysis", "Strategy", "Operations"];

  const skillNames = verifiedSkills.map((s) => s.skill_name);
  const hasTech = skillNames.some((s) => techSkills.some((t) => s.includes(t)));
  const hasDesign = skillNames.some((s) => designSkills.some((d) => s.includes(d)));
  const hasBiz = skillNames.some((s) => bizSkills.some((b) => s.includes(b)));

  let archetype: DNAAnalysisResult["archetype"] = "Builder";
  let confidence = 0.5;

  if (hasTech && !hasDesign && !hasBiz) { archetype = "Builder"; confidence = 0.7; }
  else if (hasBiz && !hasTech) { archetype = "Strategist"; confidence = 0.65; }
  else if (hasDesign) { archetype = "Creative"; confidence = 0.6; }
  else { archetype = "Executor"; confidence = 0.5; }

  const topSkillNames = verifiedSkills.slice(0, 3).map((s) => s.skill_name);
  const branch = profile.branch ?? "your field";

  return {
    ai_summary: `A ${profile.year_of_study}${getOrdinal(profile.year_of_study)}-year ${branch} student with expertise in ${topSkillNames.join(", ") || "multiple areas"} and a CGPA of ${profile.cgpa}. Passionate about building real-world solutions and continuously growing through hands-on projects.`,
    ai_strengths: [
      topSkillNames[0] ? `Strong ${topSkillNames[0]} proficiency` : "Technical aptitude",
      `Academic excellence with ${profile.cgpa} CGPA`,
      verifiedBadges.length > 0 ? `${verifiedBadges.length} verified badges demonstrating commitment` : "Consistent learner",
    ],
    ai_growth_areas: [
      "Deepen industry networking and professional presence",
      "Build cross-functional collaboration skills through team projects",
    ],
    ai_team_role_hint: `Best suited as the ${archetype === "Builder" ? "technical lead who turns ideas into working products" : archetype === "Strategist" ? "strategic thinker who aligns team efforts with clear goals" : archetype === "Creative" ? "design and innovation champion who shapes user experience" : "reliable executor who ensures deadlines are met and tasks completed"}`,
    archetype,
    archetype_confidence: confidence,
    target_roles_suggestion: hasTech ? ["Software Engineer", "Product Manager", "Startup Founder"] : ["Consultant", "Analyst", "Manager"],
    preferred_industries_suggestion: hasTech ? ["Technology", "Fintech", "Edtech"] : ["Consulting", "Finance", "FMCG"],
  };
}

function getOrdinal(n: number): string {
  return ["st", "nd", "rd"][((n % 100) - 11) % 10 <= 2 ? (n % 100) - 11 : (n % 10) - 1] || "th";
}
