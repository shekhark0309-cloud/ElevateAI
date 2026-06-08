import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import {
  createServiceClient,
  successResponse,
  errorResponse,
  optionsResponse,
  callAI,
} from "../_shared/utils.ts";

serve(async (req) => {
  if (req.method === "OPTIONS") return optionsResponse();

  try {
    const { reason_key, delta, action, student_id } = await req.json();

    if (action === 'get_full_breakdown') {
      const supabase = createServiceClient();
      const { data: trust } = await supabase.from("trust_scores").select("*").eq("student_id", student_id).single();
      const { data: dna } = await supabase.from("student_dna").select("ai_summary").eq("student_id", student_id).single();

      const systemPrompt = `You are ElevateAI's TrustScore analyst.
Based on these dimensions, generate 1-sentence professional summaries for each category.
Be data-driven and warm. Reference "institutional data" or "peer feedback" where scores are high.

Dimensions: ${JSON.stringify(trust)}
AI DNA: ${dna?.ai_summary}

Categories to explain: reliability, collaboration, integrity, competency (skill_validation), credibility (community).
Return ONLY valid JSON with keys: reliability, collaboration, integrity, competency, credibility.`;

      const aiResponse = await callAI([{ role: "user", content: "Explain my TrustScore." }], systemPrompt, 500);
      const explanations = JSON.parse(aiResponse);

      return successResponse({ explanations });
    }

    const systemPrompt = "You are ElevateAI's TrustScore analyst. Convert technical trust events into warm, encouraging sentences for students.";
    const userMessage = `Convert this event: Key: ${reason_key}, Delta: ${delta}.`;

    const explanation = await callAI([{ role: "user", content: userMessage }], systemPrompt, 100);

    return successResponse({ explanation });
  } catch (err) {
    return errorResponse(err.message, 500);
  }
});
