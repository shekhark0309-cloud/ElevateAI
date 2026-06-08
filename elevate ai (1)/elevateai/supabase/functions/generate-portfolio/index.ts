// generate-portfolio/index.ts — Auto-generate resume from student DNA
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createServiceClient, successResponse, errorResponse,
  optionsResponse, callAI, parseAIJson, getAuthenticatedUser } from "../_shared/utils.ts";

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return optionsResponse();

  const supabase = createServiceClient();
  const { user, error: authError } = await getAuthenticatedUser(req);
  if (authError || !user) return errorResponse("Unauthorized", 401);

  let body;
  try {
    body = await req.json();
  } catch {
    body = {};
  }
  const { student_id = user.id, format = 'json' } = body;

  // Security: Only allow student to generate their own portfolio
  if (student_id !== user.id) {
    return errorResponse("Forbidden: You can only generate your own portfolio", 403);
  }

  // Fetch full profile
  const { data: profile, error: profileError } = await supabase
    .from('student_profiles')
    .select(`*, student_dna(*), student_skills(*), student_badges(*, skill_badges(*)), student_projects(*), student_achievements(*), trust_scores(*)`)
    .eq('id', student_id)
    .single();

  if (profileError || !profile) return errorResponse("Profile not found", 404);

  const prompt = `Generate a professional resume JSON for this student:
Name: ${profile.full_name}
Course: ${profile.course} | Branch: ${profile.branch} | Year: ${profile.year_of_study}
CGPA: ${profile.cgpa}
Archetype: ${profile.student_dna?.archetype} (Work Style DNA)
AI Summary: ${profile.student_dna?.ai_summary}
Top Strengths: ${profile.student_dna?.ai_strengths?.join(', ')}
TrustScore: ${profile.trust_scores?.overall_score} (Tier: ${profile.trust_scores?.tier})
Career Readiness Score: ${profile.student_dna?.placement_score}
Top Skills: ${profile.student_dna?.top_skills?.join(', ')}
Verified Badges: ${profile.student_badges?.map((b: any) => b.skill_badges.name).join(', ')}
Achievements: ${JSON.stringify(profile.student_achievements?.map((a: any) => ({ title: a.title, org: a.issued_by })))}
Projects: ${JSON.stringify(profile.student_projects?.map((p: any) => ({ title: p.title, description: p.description, tech: p.tech_stack })))}
Target Roles: ${profile.student_dna?.target_roles?.join(', ')}

Return ONLY valid JSON with keys: summary (2 sentences, incorporate DNA and Trust), skills (array), experience (array of {title, org, duration, bullets}), projects (array of {name, tech, impact}), achievements (array of {title, issued_by}), education ({degree, institution, cgpa, year}).`;

  try {
    const aiResponse = await callAI([{ role: 'user', content: prompt }], "Generate professional resume JSON", 1500);
    const resumeData = parseAIJson(aiResponse);

    return successResponse({ resume: resumeData, student_id, generated_at: new Date().toISOString() });
  } catch (e) {
    return errorResponse(e instanceof Error ? e.message : "AI generation failed", 500);
  }
});
