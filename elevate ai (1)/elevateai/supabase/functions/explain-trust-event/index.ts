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
      // In a real scenario, this would use the AI to generate personalized descriptions
      // based on the student's actual performance data.
      return successResponse({
        explanations: {
          credibility: "High accuracy in self-reported skills verified by 5 certificates.",
          reliability: "Consistent 95% attendance in core modules this month.",
          social: "Excellent feedback from 3 hackathon teammates.",
          competency: "Successfully delivered 2 high-impact open-source projects.",
          integrity: "Zero recorded violations and full compliance with academic policies."
        }
      });
    }

    const systemPrompt = "You are ElevateAI's TrustScore analyst. Convert technical trust events into warm, encouraging sentences for students.";
    const userMessage = `Convert this event: Key: ${reason_key}, Delta: ${delta}.`;

    const explanation = await callAI([{ role: "user", content: userMessage }], systemPrompt, 100);

    return successResponse({ explanation });
  } catch (err) {
    return errorResponse(err.message, 500);
  }
});
