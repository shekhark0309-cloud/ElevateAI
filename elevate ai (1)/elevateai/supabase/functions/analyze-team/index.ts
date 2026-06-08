// supabase/functions/analyze-team/index.ts
// ═══════════════════════════════════════════════════════════════
// ElevateAI — Team Health & Missing Role Analysis
//
// Analyzes team composition, calculates health scores across 5 dimensions,
// identifies missing roles, and suggests members.
// ═══════════════════════════════════════════════════════════════

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import {
  createServiceClient,
  successResponse,
  errorResponse,
  optionsResponse,
  callAI,
  parseAIJson,
} from "../_shared/utils.ts";

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return optionsResponse();
  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  let body: { team_id?: string };
  try {
    body = await req.json();
  } catch {
    return errorResponse("Invalid JSON body");
  }

  const { team_id } = body;
  if (!team_id) return errorResponse("team_id is required");

  const supabase = createServiceClient();

  try {
    // 1. Fetch team details
    const { data: team, error: teamErr } = await supabase
      .from("teams")
      .select("*")
      .eq("id", team_id)
      .single();

    if (teamErr || !team) return errorResponse("Team not found", 404);

    // 2. Fetch team members with DNA and TrustScores
    const { data: members, error: membersErr } = await supabase
      .from("team_members")
      .select(`
        student_id,
        role,
        student_profiles (
          full_name,
          student_dna ( archetype, top_skills, ai_team_role_hint, target_roles ),
          trust_scores ( overall_score, tier )
        )
      `)
      .eq("team_id", team_id)
      .eq("status", "active");

    if (membersErr || !members) return errorResponse("Failed to fetch team members");

    // 3. Prepare data for AI analysis
    const teamData = {
      name: team.name,
      tagline: team.tagline,
      required_skills: team.required_skills,
      members: members.map((m: any) => ({
        name: m.student_profiles.full_name,
        role: m.role || m.student_profiles.student_dna?.ai_team_role_hint || "Member",
        archetype: m.student_profiles.student_dna?.archetype,
        skills: m.student_profiles.student_dna?.top_skills || [],
        target_roles: m.student_profiles.student_dna?.target_roles || [],
        trust_score: m.student_profiles.trust_scores?.overall_score || 0,
        trust_tier: m.student_profiles.trust_scores?.tier || "Unverified",
      })),
    };

    // 4. AI Analysis
    const systemPrompt = `You are ElevateAI's Team Architect. Analyze the team's composition for balanced high-performance.
Support roles: Frontend Developer, Backend Developer, Full Stack Developer, UI/UX Designer, Product Manager, Product Strategist, AI Engineer, ML Engineer, Data Analyst, Business Analyst, Marketing Lead, Pitching Lead, Research Lead.

Return ONLY a JSON object:
{
  "health_score": number (0-100),
  "missing_roles": string[],
  "team_strength_summary": string,
  "risk_indicators": string[],
  "strengths": {
    "technical": number,
    "design": number,
    "business": number,
    "leadership": number,
    "execution": number
  },
  "compatibility_score": number,
  "reasoning": string
}`;

    const userPrompt = `Analyze this team:
Team Name: ${teamData.name}
Description: ${teamData.tagline}
Members:
${teamData.members.map(m => `- ${m.name}: ${m.role} (${m.archetype}), Skills: ${m.skills.join(", ")}, Trust: ${m.trust_score}`).join("\n")}

Identify missing roles from the supported list and evaluate 5 strength dimensions (0-100). Mention specific risks like "Strong Builders, Weak Design" or "High Skill, Low Reliability" (if any member has low TrustScore but high skills).`;

    const aiResponse = await callAI([{ role: "user", content: userPrompt }], systemPrompt, 1000);
    const analysis = parseAIJson(aiResponse);

    // 5. Suggest members for missing roles
    let suggestedMembers = [];
    if (analysis.missing_roles && analysis.missing_roles.length > 0) {
      // Find students who have target_roles or skills matching the missing roles
      const primaryMissing = analysis.missing_roles[0];
      const { data: candidates } = await supabase
        .from("v_student_dna_snapshot")
        .select("*")
        .not("id", "in", `(${members.map(m => m.student_id).join(",")})`)
        .order("trust_score", { ascending: false })
        .limit(3);

      suggestedMembers = candidates || [];
    }

    return successResponse({
      ...analysis,
      suggested_members: suggestedMembers,
    });

  } catch (error) {
    console.error("Analysis Error:", error);
    return errorResponse(error instanceof Error ? error.message : "Internal Server Error");
  }
});
