// scheme-buddy-chat/index.ts — Multilingual scheme eligibility chatbot
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createServiceClient, successResponse, errorResponse, optionsResponse, callAI } from "../_shared/utils.ts";

const LANGUAGE_INSTRUCTIONS: Record<string, string> = {
  hindi: 'Respond ONLY in simple Hindi. Use simple words a rural student understands.',
  marathi: 'Respond ONLY in simple Marathi. Use words a rural Maharashtra student understands.',
  telugu: 'Respond ONLY in simple Telugu. Use words a rural Andhra/Telangana student understands.',
  english: 'Respond in simple English. Avoid jargon.',
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return optionsResponse();
  const supabase = createServiceClient();

  try {
    const { student_id, message, language = 'auto', conversation_history = [] } = await req.json();
    if (!student_id || !message) return errorResponse("student_id and message required");

    // Load student eligibility profile
    const { data: profile } = await supabase
      .from('student_profiles')
      .select('course, year_of_study, state, category, cgpa, family_income, gender')
      .eq('id', student_id)
      .single();

    // Load student DNA signals for context
    const { data: dna } = await supabase
      .from('student_dna')
      .select('archetype, top_skills, goals_short_term')
      .eq('student_id', student_id)
      .single();

    const systemPrompt = `You are Scheme Buddy, a multilingual government scheme advisor for Indian students.
Current Language Mode: ${language}. If 'auto', detect the user's language and respond in the same (English, Hindi, Marathi, or Telugu).
Student profile: ${JSON.stringify(profile)}.
Student DNA: ${JSON.stringify(dna)}.

Your job:
1. Help students discover government schemes (NSP, state scholarships, etc.).
2. Explain eligibility based on THEIR profile.
3. List required documents (Income certificate, Caste certificate, Domicile, etc.).
4. Provide step-by-step application guidance.
5. Warn about deadlines and common mistakes.

Rules:
- Keep responses under 150 words.
- Be extremely warm and helpful.
- For Marathi: Use regional rural dialect nuances where appropriate.
- For Telugu: Use formal yet accessible language.
- If the user asks about a specific scheme, provide: Summary, Eligibility, Benefits, and Documents.`;

    const messages = [
      ...conversation_history,
      { role: 'user' as const, content: message }
    ];

    const reply = await callAI(messages, systemPrompt, 500);

    return successResponse({
      reply,
      detected_language: language === 'auto' ? 'detected' : language, // AI handles detection
      timestamp: new Date().toISOString(),
    });
  } catch (e) {
    return errorResponse(e instanceof Error ? e.message : "Unexpected error", 500);
  }
});

