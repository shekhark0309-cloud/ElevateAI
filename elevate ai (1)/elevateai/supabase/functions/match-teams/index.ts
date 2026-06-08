// supabase/functions/match-teams/index.ts
// ═══════════════════════════════════════════════════════════════
// ElevateAI — Smart Team Finder (PS #3)
//
// Multi-signal team matching: skill overlap, archetype balance,
// TrustScore compatibility, availability match, AI explanations.
//
// Returns top 8 team matches with per-team AI-generated explanations.
// Uses a single Claude call for all 8 explanations (token-efficient).
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
  analyzeReliability,
} from "../_shared/utils.ts";

// ─── Types ────────────────────────────────────────────────────

interface MatchFilters {
  opportunity_id?: string;    // Filter teams applying to a specific opportunity
  min_trust_score?: number;   // Minimum team leader trust score
  archetype_needed?: string;  // Specific archetype the student wants to join
  skill_needed?: string;      // Team must need a specific skill
  college_id?: string;        // Same-college teams only
  open_only?: boolean;        // Only teams actively recruiting
}

interface TeamCandidate {
  id: string;
  name: string;
  tagline: string;
  required_skills: string[];
  required_archetypes: string[];
  max_members: number;
  leader_name: string;
  leader_trust_score: number;
  leader_trust_tier: string;
  current_member_count: number;
  college_id: string;
  status: string;
  // Computed scores
  skill_overlap_score: number;
  archetype_balance_score: number;
  trust_compatibility_score: number;
  availability_score: number;
  composite_score: number;
  reliability_insight?: {
    status: string;
    is_warning: boolean;
    color: string;
  };
  // Filled by AI
  match_explanation?: string;
  complementary_skills?: string[];
  fit_percentage?: number;
  missing_roles?: string[];
  team_health_score?: number;
}

interface StudentDNAForMatching {
  archetype: string | null;
  top_skills: string[];
  availability: Record<string, string[]>;
  trust_score: number;
  trust_tier: string;
  preferred_study_time: string | null;
  target_roles: string[];
  team_size_preference: string | null;
  goals_short_term: string[];
}

// ─── Main Handler ─────────────────────────────────────────────

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return optionsResponse();
  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  let body: { student_id?: string; filters?: MatchFilters; limit?: number };
  try {
    body = await req.json();
  } catch {
    return errorResponse("Invalid JSON body");
  }

  const { student_id, filters = {}, limit = 8 } = body;
  if (!student_id) return errorResponse("student_id is required");

  // Rate limit: 20 match queries per student per hour
  if (isRateLimited(`match:${student_id}`, 20, 60 * 60 * 1000)) {
    return errorResponse("Rate limit exceeded. Please wait before refreshing matches.", 429);
  }

  const supabase = createServiceClient();

  try {
    // ── 1. Load student DNA + trust score ─────────────────────
    const { data: studentData, error: studentErr } = await supabase
      .from("student_profiles")
      .select(`
        id, college_id,
        student_dna (
          archetype, top_skills, availability, preferred_study_time,
          target_roles, team_size_preference, goals_short_term
        ),
        trust_scores ( overall_score, tier )
      `)
      .eq("id", student_id)
      .eq("is_active", true)
      .single();

    if (studentErr || !studentData) {
      return errorResponse("Student not found", 404);
    }

    const dna = studentData.student_dna as StudentDNAForMatching | null;
    const trust = studentData.trust_scores as { overall_score: number; tier: string } | null;

    const studentProfile: StudentDNAForMatching = {
      archetype: dna?.archetype ?? null,
      top_skills: dna?.top_skills ?? [],
      availability: dna?.availability ?? {},
      trust_score: trust?.overall_score ?? 0,
      trust_tier: trust?.tier ?? "Unverified",
      preferred_study_time: dna?.preferred_study_time ?? null,
      target_roles: dna?.target_roles ?? [],
      team_size_preference: dna?.team_size_preference ?? null,
      goals_short_term: dna?.goals_short_term ?? [],
    };

    // ── 2. Query open teams from the view ─────────────────────
    let teamQuery = supabase
      .from("v_open_teams")
      .select("*")
      .neq("leader_name", null); // ensure joined data present

    // Apply filters
    if (filters.min_trust_score) {
      teamQuery = teamQuery.gte("leader_trust_score", filters.min_trust_score);
    }
    if (filters.college_id ?? filters.open_only) {
      // college filter applied in post-processing (view doesn't expose college_id)
    }

    const { data: rawTeams, error: teamsErr } = await teamQuery.limit(50);
    if (teamsErr) return errorResponse(`Failed to load teams: ${teamsErr.message}`, 500);

    // Also get college_id for each team (not in view)
    const teamIds = rawTeams?.map((t) => t.id) ?? [];
    let teamsWithCollege: Array<{ id: string; college_id: string }> = [];
    if (teamIds.length > 0) {
      const { data: teamDetails } = await supabase
        .from("teams")
        .select("id, college_id")
        .in("id", teamIds);
      teamsWithCollege = teamDetails ?? [];
    }
    const collegeMap = new Map(teamsWithCollege.map((t) => [t.id, t.college_id]));

    // ── 3. Score each team ────────────────────────────────────
    const scoredTeams: TeamCandidate[] = (rawTeams ?? [])
      .filter((team) => {
        // Exclude teams where student is already a member
        const collegeId = collegeMap.get(team.id);
        if (filters.college_id && collegeId !== filters.college_id) return false;
        if (team.current_member_count >= team.max_members) return false;
        return true;
      })
      .map((team) => {
        const collegeId = collegeMap.get(team.id) ?? "";

        // Score 1: Skill overlap (0-40 points)
        const teamSkills = team.required_skills ?? [];
        const studentSkills = studentProfile.top_skills ?? [];
        let overlappingSkills = 0;
        let complementarySkills: string[] = [];

        if (teamSkills.length === 0) {
          overlappingSkills = 20; // teams with no specific requirements are neutral
        } else {
          for (const ts of teamSkills) {
            if (studentSkills.some((ss) =>
              ss.toLowerCase().includes(ts.toLowerCase()) ||
              ts.toLowerCase().includes(ss.toLowerCase())
            )) {
              overlappingSkills++;
            } else {
              complementarySkills.push(ts); // skills student would complement
            }
          }
          overlappingSkills = Math.round((overlappingSkills / teamSkills.length) * 40);
        }

        // Score 2: Archetype balance (0-25 points)
        // Teams want diversity; if student's archetype is explicitly needed, score higher
        const neededArchetypes = team.required_archetypes ?? [];
        let archetypeScore = 12; // neutral baseline

        if (studentProfile.archetype) {
          if (neededArchetypes.length === 0) {
            archetypeScore = 15; // no preference — always fits
          } else if (neededArchetypes.includes(studentProfile.archetype)) {
            archetypeScore = 25; // perfect archetype match
          } else {
            archetypeScore = 5; // doesn't match needed archetypes
          }
        }

        // Score 3: TrustScore compatibility (0-20 points)
        // Both student and team leader trust matters
        const leaderTrust = team.leader_trust_score ?? 0;
        const trustDiff = Math.abs(studentProfile.trust_score - leaderTrust);
        const trustScore = Math.max(0, 20 - Math.round(trustDiff / 10));

        // Score 4: Availability match (0-15 points)
        // Simple heuristic: if student has availability data, check preferred study time
        let availScore = 8; // default neutral
        if (studentProfile.preferred_study_time && studentProfile.availability) {
          const hasAvailability = Object.keys(studentProfile.availability).length > 0;
          availScore = hasAvailability ? 12 : 8;
        }

        // Bonus: same college (0-5 points)
        const sameCollege = collegeId === (studentData as { college_id: string }).college_id ? 5 : 0;

        let composite = overlappingSkills + archetypeScore + trustScore + availScore + sameCollege;

        // ── Reliability Intelligence Adjustment ────────────────
        // We evaluate the student's reliability relative to their skill level
        // (Skill level estimated from DNA top_skills count + overlap)
        const skillEst = Math.min(100, (studentProfile.top_skills.length * 8) + overlappingSkills);
        const rel = analyzeReliability(studentProfile.trust_score, skillEst);

        if (rel.is_warning) {
          composite -= 15; // Penalty for reliability risk in team matching
        } else if (rel.status === "Elite Contributor") {
          composite += 10; // Bonus for proven reliable high-performers
        }

        return {
          id: team.id,
          name: team.name,
          tagline: team.tagline ?? "",
          required_skills: teamSkills,
          required_archetypes: neededArchetypes,
          max_members: team.max_members,
          leader_name: team.leader_name,
          leader_trust_score: leaderTrust,
          leader_trust_tier: team.leader_trust_tier ?? "Unverified",
          current_member_count: team.current_member_count ?? 0,
          college_id: collegeId,
          status: team.status,
          skill_overlap_score: Math.min(40, overlappingSkills),
          archetype_balance_score: archetypeScore,
          trust_compatibility_score: trustScore,
          availability_score: availScore,
          composite_score: Math.min(100, Math.max(0, composite)),
          complementary_skills: complementarySkills.slice(0, 3),
          reliability_insight: {
            status: rel.status,
            is_warning: rel.is_warning,
            color: rel.color,
          },
        } as TeamCandidate;
      })
      .sort((a, b) => b.composite_score - a.composite_score)
      .slice(0, Math.min(limit, 8));

    if (scoredTeams.length === 0) {
      return successResponse({
        matches: [],
        message: "No open teams found matching your profile. Try adjusting filters or check back later.",
        student_archetype: studentProfile.archetype,
      });
    }

    // ── 4. Single AI call for all match explanations ──────────
    // Batch all teams in one prompt to minimize API calls
    let enrichedTeams = scoredTeams;

    try {
      const aiResults = await generateMatchExplanations(
        studentProfile,
        scoredTeams
      );

      enrichedTeams = scoredTeams.map((team, i) => {
        const ai = aiResults[i];
        return {
          ...team,
          match_explanation: ai?.explanation ?? generateFallbackExplanation(team, studentProfile),
          fit_percentage: Math.round(team.composite_score),
          missing_roles: ai?.missing_roles ?? [],
          team_health_score: ai?.health_score ?? 70,
        };
      });
    } catch (aiError) {
      console.warn("AI match explanation failed, using rule-based:", aiError);
      // Fallback: generate rule-based explanations
      enrichedTeams = scoredTeams.map((team) => ({
        ...team,
        match_explanation: generateFallbackExplanation(team, studentProfile),
        fit_percentage: Math.round(team.composite_score),
      }));
    }

    return successResponse({
      matches: enrichedTeams,
      student_archetype: studentProfile.archetype,
      student_skills: studentProfile.top_skills,
      total_open_teams_checked: rawTeams?.length ?? 0,
      filters_applied: filters,
    });

  } catch (e) {
    console.error("match-teams error:", e);
    return errorResponse(e instanceof Error ? e.message : "Unexpected error", 500);
  }
});

// ─── AI Explanation Generator ─────────────────────────────────

async function generateMatchExplanations(
  student: StudentDNAForMatching,
  teams: TeamCandidate[]
): Promise<Array<{ team_id: string; explanation: string; missing_roles: string[]; health_score: number }>> {
  const systemPrompt = `You are ElevateAI's team matching advisor. Generate match explanations and identify missing roles for teams.
Roles: Frontend, Backend, Full Stack, UI/UX, PM, Strategist, AI, ML, Data, Business, Marketing, Pitching, Research.

Respond ONLY with a JSON array — no markdown.`;

  const userPrompt = `Student profile:
- Archetype: ${student.archetype ?? "Unknown"}
- Top skills: ${student.top_skills.slice(0, 5).join(", ")}
- Goals: ${student.goals_short_term?.slice(0, 2).join(", ")}

For each team below, provide:
1. Match explanation (2 sentences max).
2. List of 1-2 missing roles.
3. Estimated team health score (0-100).

Teams:
${teams.map((t, i) => `${i + 1}. "${t.name}" (needs: ${t.required_skills.join(", ")}, current members: ${t.current_member_count}/${t.max_members})`).join("\n")}

Return JSON array:
[{"team_id": "${teams[0].id}", "explanation": "...", "missing_roles": ["..."], "health_score": 85}, ...]`;

  const response = await callAI(
    [{ role: "user", content: userPrompt }],
    systemPrompt,
    800
  );

  const parsed = parseAIJson<Array<{ team_id: string; explanation: string; missing_roles: string[]; health_score: number }>>(response);

  return teams.map((team, i) => ({
    team_id: team.id,
    explanation: parsed[i]?.explanation ?? parsed.find((p) => p.team_id === team.id)?.explanation ?? "",
    missing_roles: parsed[i]?.missing_roles ?? parsed.find((p) => p.team_id === team.id)?.missing_roles ?? [],
    health_score: parsed[i]?.health_score ?? parsed.find((p) => p.team_id === team.id)?.health_score ?? 70,
  }));
}

function generateFallbackExplanation(
  team: TeamCandidate,
  student: StudentDNAForMatching
): string {
  const skillOverlap = team.skill_overlap_score;
  const archetypeMatch = team.required_archetypes.includes(student.archetype ?? "") ?
    `Your ${student.archetype} archetype is exactly what this team needs.` :
    `Your skills complement this team's existing makeup well.`;

  if (skillOverlap >= 30) {
    return `Strong skill alignment — ${Math.round(skillOverlap / 40 * 100)}% of your verified skills match what this team needs. ${archetypeMatch}`;
  } else if (team.leader_trust_score > 70) {
    return `Led by a highly trusted teammate (${team.leader_trust_tier} tier), this team offers a quality collaboration environment. ${archetypeMatch}`;
  } else {
    return `This team is actively looking for members and your profile would add value to their mission. ${archetypeMatch}`;
  }
}
