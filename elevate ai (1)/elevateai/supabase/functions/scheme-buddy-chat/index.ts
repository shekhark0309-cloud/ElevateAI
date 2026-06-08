// scheme-buddy-chat/index.ts — Multilingual scheme eligibility chatbot
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createServiceClient, successResponse, errorResponse, optionsResponse, callAI } from "../_shared/utils.ts";

const LANGUAGE_INSTRUCTIONS: Record<string, string> = {
  hindi: 'Respond ONLY in simple Hindi. Use simple words a rural student understands. No jargon.',
  marathi: 'Respond ONLY in simple Marathi. Use words a rural Maharashtra student understands.',
  telugu: 'Respond ONLY in simple Telugu. Explain in a friendly and clear way.',
  english: 'Respond in simple English. Avoid jargon. Be friendly and direct.',
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return optionsResponse();
  const supabase = createServiceClient();

  try {
    const { student_id, message, language = 'english', conversation_history = [] } = await req.json();
    if (!student_id || !message) return errorResponse("student_id and message required");

    const langInstruction = LANGUAGE_INSTRUCTIONS[language] ?? LANGUAGE_INSTRUCTIONS.english;

    // Load student eligibility profile
    const { data: profile } = await supabase
      .from('student_profiles')
      .select('course, year_of_study, state, category, cgpa, family_income, gender')
      .eq('id', student_id)
      .single();

    const systemPrompt = `You are Scheme Buddy, a helpful government scheme advisor for Indian students.
${langInstruction}
Student profile: ${JSON.stringify(profile)}.
Your job: help students understand government scholarships, check eligibility, explain documents needed,
and guide them through applying. You know about NSP, PM scholarship, Pragati, Saksham, state scholarships,
SC/ST/OBC scholarships, and minority scholarships.
Keep responses under 100 words. Be warm and encouraging.`;

    const messages = [
      ...conversation_history,
      { role: 'user' as const, content: message }
    ];

    const reply = await callAI(messages, systemPrompt, 300);

    return successResponse({
      reply,
      language,
      timestamp: new Date().toISOString(),
    });
  } catch (e) {
    return errorResponse(e instanceof Error ? e.message : "Unexpected error", 500);
  }
});
