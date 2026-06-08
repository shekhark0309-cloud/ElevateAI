// supabase/functions/recalculate-dna/index.ts
// ═══════════════════════════════════════════════════════════════
// ElevateAI — Student DNA & Career Flywheel Orchestrator
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
  getAuthenticatedUser,
} from "../_shared/utils.ts";

interface DNAAnalysisResult {
  ai_summary: string;
  ai_strengths: string[];
  ai_growth_areas: string[];
  ai_team_role_hint: string;
  archetype: "Builder" | "Strategist" | "Creative" | "Executor";
  archetype_confidence: number;
  target_roles_suggestion: string[];
  preferred_industries_suggestion: string[];
  skill_gaps: { skill: string; reason: string; priority: string }[];
  roadmap_steps: { step: string; status: string; impact: string }[];
  readiness_projection_90d: number;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return optionsResponse();

  const { user, error: authError } = await getAuthenticatedUser(req);
  if (authError || !user) return errorResponse("Unauthorized", 401);

  const { student_id } = await req.json();
  if (!student_id) return errorResponse("student_id is required");

  // Security: Only allow student to recalculate their own DNA
  if (student_id !== user.id) {
    return errorResponse("Forbidden: You can only recalculate your own DNA", 403);
  }

  if (isRateLimited(`dna:${student_id}`, 10, 3600000)) {
    return errorResponse("Rate limit exceeded", 429);
  }

  const supabase = createServiceClient();

  try {
    // 1. Fetch complete profile
    const { data: profile } = await supabase
      .from("student_profiles")
      .select(`
        *,
        student_skills ( skill_name, proficiency, is_verified ),
        student_projects ( title, description, tech_stack, is_featured ),
        student_badges ( skill_badges ( name, category, level ) )
      `)
      .eq("id", student_id)
      .single() as { data: StudentFullProfile };

    const { data: existingDNA } = await supabase
      .from("student_dna")
      .select("*")
      .eq("student_id", student_id)
      .single();

    // 2. AI Analysis for DNA + Career Flywheel
    const systemPrompt = "You are the ElevateAI Career & DNA Engine. Analyze the student and evolve their roadmap. Respond ONLY with valid JSON.";
    const userPrompt = `
      Analyze this student profile and evolve their career roadmap.
      Current Archetype: ${existingDNA?.archetype}
      Skills: ${JSON.stringify(profile.student_skills)}
      Projects: ${JSON.stringify(profile.student_projects)}

      Return JSON:
      {
        "ai_summary": "...",
        "ai_strengths": ["..."],
        "ai_growth_areas": ["..."],
        "ai_team_role_hint": "...",
        "archetype": "Builder|Strategist|Creative|Executor",
        "archetype_confidence": 0.9,
        "target_roles_suggestion": ["..."],
        "preferred_industries_suggestion": ["..."],
        "skill_gaps": [{"skill": "DSA", "reason": "Required for SDE", "priority": "high"}],
        "roadmap_steps": [{"step": "Complete React Challenge", "status": "active", "impact": "High"}],
        "readiness_projection_90d": 85
      }
    `;

    const aiResponse = await callAI([{ role: "user", content: userPrompt }], systemPrompt, 1000);
    const aiResult = parseAIJson<DNAAnalysisResult>(aiResponse);

    // 3. Update DNA Table (Orchestrating Flywheel)
    const { error: dnaUpdateError } = await supabase
      .from("student_dna")
      .upsert({
        student_id,
        archetype: aiResult.archetype,
        archetype_confidence: aiResult.archetype_confidence,
        ai_summary: aiResult.ai_summary,
        ai_strengths: aiResult.ai_strengths,
        ai_growth_areas: aiResult.ai_growth_areas,
        ai_team_role_hint: aiResult.ai_team_role_hint,
        skill_gaps: aiResult.skill_gaps,
        roadmap: aiResult.roadmap_steps,
        readiness_projection_90d: aiResult.readiness_projection_90d,
        last_ai_updated: new Date().toISOString()
      }, { onConflict: "student_id" });

    if (dnaUpdateError) throw dnaUpdateError;

    // 4. Update Career Score (RPC)
    await supabase.rpc("calculate_placement_score", { p_student_id: student_id });

    // 5. Check if score improved significantly for notification
    const { data: newDNA } = await supabase.from("student_dna").select("placement_score").eq("student_id", student_id).single();
    const oldScore = existingDNA?.placement_score || 0;
    const newScore = newDNA?.placement_score || 0;

    if (newScore > oldScore) {
      await createNotification(
        supabase,
        student_id,
        "career_readiness_increased",
        "📈 Career Readiness Increased!",
        `Your placement score jumped from ${oldScore.toFixed(0)} to ${newScore.toFixed(0)}! Keep it up.`,
        { delta: newScore - oldScore }
      );
    }

    return successResponse({
      student_id,
      archetype: aiResult.archetype,
      new_score: newScore,
      gaps_identified: aiResult.skill_gaps.length
    });

  } catch (e) {
    console.error(e);
    return errorResponse(e.message, 500);
  }
});
