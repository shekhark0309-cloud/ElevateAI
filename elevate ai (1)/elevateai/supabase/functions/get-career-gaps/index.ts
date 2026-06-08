import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createServiceClient, successResponse, errorResponse, optionsResponse, getAuthenticatedUser, parseAIJson, callAI } from "../_shared/utils.ts";

serve(async (req) => {
  if (req.method === "OPTIONS") return optionsResponse();

  const supabase = createServiceClient();
  const { user, error } = await getAuthenticatedUser(req);
  if (error || !user) return errorResponse("Unauthorized", 401);

  let body;
  try {
    body = await req.json();
  } catch {
    body = {};
  }
  const { student_id = user.id } = body;

  // Fetch student DNA
  const { data: dna } = await supabase
    .from('student_dna')
    .select('top_skills, target_roles, archetype')
    .eq('student_id', student_id)
    .single();

  // Fetch verified badges
  const { data: badges } = await supabase
    .from('student_badges')
    .select('skill_badges(name, category)')
    .eq('student_id', student_id)
    .eq('verify_status', 'verified');

  const prompt = `
You are a career advisor for Indian college students.
Student archetype: ${dna?.archetype}
Current verified skills: ${JSON.stringify(dna?.top_skills)}
Target roles: ${JSON.stringify(dna?.target_roles)}
Earned badges: ${JSON.stringify(badges?.map((b: any) => b.skill_badges?.name))}

Return ONLY valid JSON:
{
  "skill_gaps": [{"skill": "...", "reason": "...", "priority": "high|medium|low"}],
  "roadmap_steps": [{"step": "...", "status": "done|active|pending", "impact": "..."}],
  "top_companies": ["...", "..."],
  "readiness_label": "Strong|Good|Developing"
}
`;

  try {
    const aiResponse = await callAI([{ role: 'user', content: prompt }], "Career gap analysis for student", 800);
    const result = parseAIJson(aiResponse);
    return successResponse(result);
  } catch (e) {
    return errorResponse(e instanceof Error ? e.message : "AI Analysis failed", 500);
  }
});
