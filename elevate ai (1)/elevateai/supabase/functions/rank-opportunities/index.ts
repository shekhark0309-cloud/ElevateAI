// supabase/functions/rank-opportunities/index.ts
// ═══════════════════════════════════════════════════════════════
// ElevateAI — AI Opportunity Engine (PS #9)
//
// Fetches all eligible opportunities for a student, applies:
//   1. Hard eligibility filtering (state, category, CGPA, income, etc.)
//   2. Multi-signal scoring (skills, deadline, prize, verification)
//   3. AI personalization layer (why THIS opportunity fits THIS student's DNA)
//   4. Serendipity injection (1-2 stretch opportunities to encourage growth)
//
// Returns a rich ranked list with per-opportunity explanations.
// ═══════════════════════════════════════════════════════════════

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import {
  createServiceClient,
  successResponse,
  errorResponse,
  optionsResponse,
  callAI,
  parseAIJson,
  isRateLimited,
} from "../_shared/utils.ts";

// ─── Types ────────────────────────────────────────────────────

interface StudentEligibilityProfile {
  id: string;
  state: string;
  category: string;
  course: string;
  year_of_study: number;
  cgpa: number;
  family_income: number;
  gender: string;
  trust_score: number;
  top_skills: string[];
  target_roles: string[];
  archetype: string | null;
  goals_short_term: string[];
  ai_summary: string | null;
  placement_score: number;
  previously_applied: string[];
}

interface RankedOpportunity {
  id: string;
  title: string;
  type: string;
  organizer_name: string;
  prize_amount: number | null;
  stipend_amount: number | null;
  apply_deadline: string;
  event_start: string | null;
  event_end: string | null;
  required_skills: string[];
  apply_url: string | null;
  banner_url: string | null;
  is_featured: boolean;
  is_verified: boolean;
  apply_count: number;
  organizer_trust_score: number | null;
  // Scoring
  eligibility_match: boolean;
  match_score: number;
  skill_overlap_count: number;
  days_until_deadline: number;
  urgency_level: "critical" | "high" | "medium" | "low";
  // AI personalization
  ai_reason: string;
  ai_tip: string;
  is_stretch_opportunity: boolean;
}

// ─── Main Handler ─────────────────────────────────────────────

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return optionsResponse();
  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  let body: {
    student_id?: string;
    type_filter?: string[];
    limit?: number;
    include_ineligible?: boolean;
  };
  try {
    body = await req.json();
  } catch {
    return errorResponse("Invalid JSON body");
  }

  const { student_id, type_filter, limit = 20, include_ineligible = false } = body;
  if (!student_id) return errorResponse("student_id is required");

  // Rate limit: 30 opportunity fetches per student per hour
  if (isRateLimited(`opps:${student_id}`, 30, 60 * 60 * 1000)) {
    return errorResponse("Rate limit exceeded. Please wait before refreshing.", 429);
  }

  const supabase = createServiceClient();

  try {
    // ── 1. Load student eligibility profile ───────────────────
    const { data: studentRaw, error: studentErr } = await supabase
      .from("student_profiles")
      .select(`
        id, state, category, course, year_of_study, cgpa,
        family_income, gender,
        student_dna ( top_skills, target_roles, archetype, goals_short_term, ai_summary, placement_score ),
        trust_scores ( overall_score, reliability_score, collaboration_score )
      `)
      .eq("id", student_id)
      .eq("is_active", true)
      .single();

    if (studentErr || !studentRaw) {
      return errorResponse("Student not found", 404);
    }

    // ... (rest of loading logic)

    const trustData = studentRaw.trust_scores as { overall_score?: number, reliability_score?: number } | null;
    const student: StudentEligibilityProfile = {
      id: student_id,
      state: studentRaw.state ?? "",
      category: studentRaw.category ?? "general",
      course: studentRaw.course ?? "",
      year_of_study: studentRaw.year_of_study ?? 1,
      cgpa: studentRaw.cgpa ?? 0,
      family_income: studentRaw.family_income ?? 0,
      gender: studentRaw.gender ?? "",
      trust_score: trustData?.overall_score ?? 0,
      top_skills: (dna?.top_skills as string[]) ?? [],
      target_roles: (dna?.target_roles as string[]) ?? [],
      archetype: (dna?.archetype as string) ?? null,
      goals_short_term: (dna?.goals_short_term as string[]) ?? [],
      ai_summary: (dna?.ai_summary as string) ?? null,
      placement_score: (dna?.placement_score as number) ?? 0,
      previously_applied: previouslyApplied,
    };

    const reliabilityScore = trustData?.reliability_score ?? 0;

    // ── 2. Use SQL function for base ranked list ───────────────
    const { data: sqlRanked, error: sqlErr } = await supabase
      .rpc("get_ranked_opportunities", { p_student_id: student_id });

    if (sqlErr) {
      console.error("SQL ranking failed:", sqlErr);
      // Fall through to manual ranking
    }

    // ── 3. Fetch full opportunity details for top candidates ───
    const topOpportunityIds = (sqlRanked ?? [])
      .filter((o: { eligibility_match: boolean }) => include_ineligible || o.eligibility_match)
      .slice(0, 40) // take top 40 for AI processing
      .map((o: { opportunity_id: string }) => o.opportunity_id);

    if (topOpportunityIds.length === 0) {
      return successResponse({
        opportunities: [],
        message: "No matching opportunities found right now. Check back soon!",
        student_profile_summary: {
          state: student.state,
          category: student.category,
          trust_score: student.trust_score,
          skills_count: student.top_skills.length,
        },
      });
    }

    let oppQuery = supabase
      .from("v_active_opportunities")
      .select("*")
      .in("id", topOpportunityIds);

    if (type_filter && type_filter.length > 0) {
      oppQuery = oppQuery.in("type", type_filter);
    }

    const { data: opportunities, error: oppErr } = await oppQuery;
    if (oppErr) return errorResponse(`Failed to load opportunities: ${oppErr.message}`, 500);

    // ── 4. Compute enhanced scores + eligibility ──────────────
    const now = new Date();
    const scored: RankedOpportunity[] = (opportunities ?? [])
      .filter((o) => !student.previously_applied.includes(o.id))
      .map((opp) => {
        const deadline = new Date(opp.apply_deadline);
        const daysUntil = Math.max(0, Math.ceil((deadline.getTime() - now.getTime()) / (1000 * 60 * 60 * 24)));

        // Hard eligibility check
        const eligible =
          (opp.eligible_states?.length === 0 || opp.eligible_states?.includes(student.state)) &&
          (opp.eligible_categories?.length === 0 || opp.eligible_categories?.includes(student.category)) &&
          (opp.eligible_courses?.length === 0 || opp.eligible_courses?.some((c: string) => student.course.includes(c) || c.includes(student.course))) &&
          (opp.min_year == null || student.year_of_study >= opp.min_year) &&
          (opp.max_year == null || student.year_of_study <= opp.max_year) &&
          (opp.min_cgpa == null || student.cgpa >= opp.min_cgpa) &&
          (opp.max_family_income == null || student.family_income <= opp.max_family_income) &&
          (student.trust_score >= (opp.min_trust_score ?? 0));

        // Skill overlap
        const requiredSkills = opp.required_skills ?? [];
        const overlappingSkills = requiredSkills.filter((rs: string) =>
          student.top_skills.some((ss) =>
            ss.toLowerCase().includes(rs.toLowerCase()) ||
            rs.toLowerCase().includes(ss.toLowerCase())
          )
        );

        // Scoring formula
        let score = 0;
        if (eligible) score += 30;
        if (opp.is_featured) score += 15;
        if (opp.is_verified) score += 10;

        // DNA & Work Style Weighting (M1 Task 1 & 4)
        const archetypeWeights: Record<string, Record<string, number>> = {
          'Builder': { 'hackathon': 15, 'project': 15, 'internship': 5 },
          'Strategist': { 'competition': 15, 'fellowship': 10, 'workshop': 5 },
          'Researcher': { 'research': 20, 'fellowship': 10 },
          'Creative': { 'hackathon': 10, 'competition': 10, 'workshop': 5 },
          'Executor': { 'internship': 15, 'workshop': 10 }
        };

        if (student.archetype && archetypeWeights[student.archetype]) {
          score += archetypeWeights[student.archetype][opp.type] ?? 0;
        }

        // TrustScore Bonus (M1 Task 3)
        if (student.trust_score > 80) score += 10;
        else if (student.trust_score > 60) score += 5;

        // Career Readiness Logic (M1 Task 2)
        if (student.placement_score > 70 && opp.type === 'internship') score += 15;
        if (student.placement_score < 40 && opp.type === 'workshop') score += 15; // Skill building

        // TrustScore Reliability Penalty (M18 Task 9)
        if (reliabilityScore < 50) score -= 20;
        if (reliabilityScore < 30) score -= 30;

        score += Math.min(20, overlappingSkills.length * 4);
        if (opp.prize_amount > 50000) score += 8;
        if (opp.prize_amount > 200000) score += 5;
        // Urgency boost
        if (daysUntil <= 2) score += 10;
        else if (daysUntil <= 7) score += 7;
        else if (daysUntil <= 14) score += 3;

        return {
          id: opp.id,
          title: opp.title,
          type: opp.type,
          organizer_name: opp.organizer_name,
          prize_amount: opp.prize_amount,
          stipend_amount: opp.stipend_amount,
          apply_deadline: opp.apply_deadline,
          event_start: opp.event_start,
          event_end: opp.event_end,
          required_skills: requiredSkills,
          apply_url: opp.apply_url,
          banner_url: opp.banner_url,
          is_featured: opp.is_featured,
          is_verified: opp.is_verified,
          apply_count: opp.apply_count,
          organizer_trust_score: opp.organizer_trust_score,
          eligibility_match: eligible,
          match_score: score,
          skill_overlap_count: overlappingSkills.length,
          days_until_deadline: daysUntil,
          urgency_level: daysUntil <= 2 ? "critical" : daysUntil <= 7 ? "high" : daysUntil <= 14 ? "medium" : "low",
          ai_reason: "", // filled by AI
          ai_tip: "",    // filled by AI
          is_stretch_opportunity: false,
        } as RankedOpportunity;
      })
      .sort((a, b) => {
        // Eligible first, then by score
        if (a.eligibility_match !== b.eligibility_match) {
          return a.eligibility_match ? -1 : 1;
        }
        return b.match_score - a.match_score;
      });

    // ── 5. Inject serendipity (stretch opportunities) ─────────
    // Add 1-2 opportunities slightly outside comfort zone
    const eligible = scored.filter((o) => o.eligibility_match);
    const ineligible = scored.filter((o) => !o.eligibility_match).slice(0, 2);
    const stretchOpps = ineligible.map((o) => ({ ...o, is_stretch_opportunity: true }));

    const finalList = [
      ...eligible.slice(0, limit - 2),
      ...stretchOpps,
    ].slice(0, limit);

    // ── 6. AI personalization layer ───────────────────────────
    let enrichedList = finalList;
    if (finalList.length > 0) {
      try {
        enrichedList = await addAIPersonalization(student, finalList);
      } catch (aiError) {
        console.warn("AI personalization failed, using rule-based:", aiError);
        enrichedList = finalList.map((opp) => ({
          ...opp,
          ai_reason: generateFallbackReason(opp, student),
          ai_tip: generateFallbackTip(opp, student),
        }));
      }
    }

    return successResponse({
      opportunities: enrichedList,
      total_eligible: eligible.length,
      total_stretch: stretchOpps.length,
      applied_count: previouslyApplied.length,
      student_summary: {
        top_skills: student.top_skills.slice(0, 5),
        archetype: student.archetype,
        trust_score: student.trust_score,
      },
    });

  } catch (e) {
    console.error("rank-opportunities error:", e);
    return errorResponse(e instanceof Error ? e.message : "Unexpected error", 500);
  }
});

// ─── AI Personalization ───────────────────────────────────────

async function addAIPersonalization(
  student: StudentEligibilityProfile,
  opportunities: RankedOpportunity[]
): Promise<RankedOpportunity[]> {
  // Only AI-personalize top 10 to stay within token limits
  const topN = opportunities.slice(0, 10);
  const rest = opportunities.slice(10);

  const systemPrompt = `You are ElevateAI's opportunity advisor for Indian students. 
Generate personalized 1-sentence "why this fits you" reasons and quick application tips.
Be specific, encouraging, and realistic. Reference the student's actual skills/goals.
Respond ONLY with valid JSON array.`;

  const userPrompt = `Student:
- Archetype: ${student.archetype ?? "Unknown"}
- Skills: ${student.top_skills.slice(0, 6).join(", ")}
- Goals: ${student.goals_short_term.slice(0, 2).join(", ")}
- State: ${student.state}, Category: ${student.category}
- Summary: ${student.ai_summary ?? "Active student"}

For each opportunity, provide a 1-sentence AI reason (why it fits their DNA) and a 1-sentence tip (how to stand out in application):

Opportunities:
${topN.map((o, i) => `${i + 1}. [${o.type}] "${o.title}" by ${o.organizer_name} — needs: ${o.required_skills.slice(0, 3).join(", ") || "any skills"} — ${o.days_until_deadline} days left`).join("\n")}

Return JSON array:
[{"id": "${topN[0].id}", "ai_reason": "...", "ai_tip": "..."}, ...]`;

  const response = await callAI(
    [{ role: "user", content: userPrompt }],
    systemPrompt,
    700
  );

  const aiData = parseAIJson<Array<{ id: string; ai_reason: string; ai_tip: string }>>(response);

  const enrichedTop = topN.map((opp, i) => ({
    ...opp,
    ai_reason: aiData[i]?.ai_reason ?? generateFallbackReason(opp, student),
    ai_tip: aiData[i]?.ai_tip ?? generateFallbackTip(opp, student),
  }));

  const enrichedRest = rest.map((opp) => ({
    ...opp,
    ai_reason: generateFallbackReason(opp, student),
    ai_tip: generateFallbackTip(opp, student),
  }));

  return [...enrichedTop, ...enrichedRest];
}

function generateFallbackReason(opp: RankedOpportunity, student: StudentEligibilityProfile): string {
  if (opp.skill_overlap_count > 0) {
    return `Your expertise in ${student.top_skills[0]} makes you a strong candidate for this ${opp.type}.`;
  }
  if (student.archetype === 'Builder' && (opp.type === 'hackathon' || opp.type === 'project')) {
    return `As a Builder, this practical project matches your DNA perfectly.`;
  }
  if (student.placement_score > 70 && opp.type === 'internship') {
    return `High career readiness detected. This internship is a great next step.`;
  }
  if (opp.is_featured) {
    return `This highly recommended opportunity is a great fit for a ${student.archetype ?? "motivated"} student like you.`;
  }
  return `This ${opp.type} by ${opp.organizer_name} is a valuable opportunity to build experience.`;
}

function generateFallbackTip(opp: RankedOpportunity, student: StudentEligibilityProfile): string {
  const typeMap: Record<string, string> = {
    hackathon: "Highlight your past projects and team collaboration experience in your submission.",
    scholarship: "Emphasize academic achievements and clearly articulate your long-term goals.",
    internship: "Tailor your resume to the company's tech stack and show impact from past projects.",
    fellowship: "Write a compelling personal statement connecting your background to the fellowship's mission.",
    research: "Mention any relevant coursework, papers, or projects that demonstrate research aptitude.",
    competition: "Practice mock submissions and review past winners to understand the evaluation criteria.",
    workshop: "Register early — workshops often have limited seats and fill up quickly.",
  };
  return typeMap[opp.type] ?? "Complete your ElevateAI profile fully to maximize your chances of selection.";
}
