// supabase/functions/rank-schemes/index.ts
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

  try {
    const { student_id, limit = 10 } = await req.json();
    if (!student_id) return errorResponse("student_id is required");

    const supabase = createServiceClient();

    // 1. Fetch student profile
    const { data: student } = await supabase
      .from("student_profiles")
      .select("*, student_dna(*)")
      .eq("id", student_id)
      .single();

    if (!student) return errorResponse("Student not found", 404);

    // 2. Fetch active schemes
    const { data: schemes } = await supabase
      .from("schemes")
      .select("*")
      .eq("is_active", true);

    if (!schemes || schemes.length === 0) return successResponse([]);

    // 3. AI-based ranking (Rule-based pre-sort + AI justification)
    const scoredSchemes = schemes.map(scheme => {
      let score = 0;
      // Basic rule-based matching
      if (scheme.state === student.state) score += 40;
      if (scheme.category === student.category) score += 30;
      if (student.family_income <= (scheme.max_income || 800000)) score += 20;

      return { ...scheme, match_score: score };
    }).sort((a, b) => b.match_score - a.match_score).slice(0, limit);

    // 4. AI Justification
    const systemPrompt = "You are a scholarship advisor. For each scheme, provide a 1-sentence explanation of why it fits the student's profile. Return JSON.";
    const userPrompt = `Student: ${JSON.stringify(student)}\nSchemes: ${JSON.stringify(scoredSchemes)}`;

    try {
      const aiResponse = await callAI([{ role: "user", content: userPrompt }], systemPrompt, 500);
      const justifications = parseAIJson<any>(aiResponse);

      scoredSchemes.forEach((s, i) => {
        s.ai_reason = justifications[i]?.reason || justifications[s.id]?.reason || "Matches your profile.";
      });
    } catch (e) {
      console.warn("AI ranking justification failed:", e);
    }

    return successResponse(scoredSchemes);
  } catch (e) {
    return errorResponse(e.message, 500);
  }
});
