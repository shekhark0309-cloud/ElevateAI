// supabase/functions/analyze-idea/index.ts
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import {
  successResponse,
  errorResponse,
  optionsResponse,
  callAI,
  parseAIJson,
} from "../_shared/utils.ts";

serve(async (req) => {
  if (req.method === "OPTIONS") return optionsResponse();

  try {
    const { title, description, problem_statement, solution } = await req.json();

    const systemPrompt = `You are ElevateAI Innovation Hub Validator.
Analyze the student's project idea and provide a structured validation.
Innovation Score (0-100), Feasibility Score (0-100).
Market Potential, Technical Complexity, Difficulty.
Suggested Improvements, Potential Risks, Suggested Team Roles, Hackathon Suitability.
Return ONLY valid JSON.`;

    const userPrompt = `
Idea Title: ${title}
Description: ${description}
Problem: ${problem_statement ?? "N/A"}
Solution: ${solution ?? "N/A"}

Validate this idea for a campus environment.`;

    const aiResponse = await callAI(
      [{ role: "user", content: userPrompt }],
      systemPrompt,
      800
    );

    const validation = parseAIJson(aiResponse);

    return successResponse(validation);
  } catch (error) {
    return errorResponse(error.message);
  }
});
