import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import {
  createServiceClient,
  successResponse,
  errorResponse,
  optionsResponse,
  callAI,
  parseAIJson,
  isRateLimited,
  createNotification,
} from "../_shared/utils.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

serve(async (req) => {
  if (req.method === "OPTIONS") return optionsResponse();

  try {
    const { student_id, attempt_id } = await req.json();

    if (!student_id || !attempt_id) {
      return errorResponse("student_id and attempt_id are required", 400);
    }

    if (isRateLimited(`eval:${student_id}`, 10, 3600000)) {
      return errorResponse("Rate limit exceeded. Try again later.", 429);
    }

    const supabase = createServiceClient();

    // 1. Fetch attempt
    const { data: attempt, error: attemptError } = await supabase
      .from("challenge_attempts")
      .select("*, skill_challenges(*)")
      .eq("id", attempt_id)
      .eq("student_id", student_id)
      .single();

    if (attemptError || !attempt) {
      return errorResponse("Attempt not found", 404);
    }

    if (attempt.status !== "submitted") {
      return errorResponse(`Attempt is in status: ${attempt.status}`, 400);
    }

    // 2. Update status to in_progress
    await supabase
      .from("challenge_attempts")
      .update({ status: "in_progress" })
      .eq("id", attempt_id);

    const challenge = attempt.skill_challenges;

    // 3. Build AI Prompt
    const systemPrompt = "You are a strict but fair technical evaluator for student coding challenges at an Indian engineering college. Evaluate the submitted solution against the problem statement. Be specific and honest. Partial credit is allowed. RESPOND ONLY WITH VALID JSON — no markdown, no preamble.";

    const userMessage = `Problem: ${challenge.problem_statement}
Expected Output: ${challenge.expected_output}
Challenge Type: ${challenge.challenge_type}
Difficulty: ${challenge.difficulty}
Evaluation Criteria: ${JSON.stringify(challenge.evaluation_criteria)}

Student Submission:
${attempt.submitted_code || JSON.stringify(attempt.submitted_answer)}

Return EXACTLY this JSON:
{"score":0-100,"passed":boolean (true if score>=70),"breakdown":${JSON.stringify(challenge.evaluation_criteria)},"feedback":"2-4 sentence honest explanation of what was right and what to improve","improvement_tips":["tip1","tip2","tip3"]}`;

    let aiResult;
    try {
      const aiResponse = await callAI([{ role: "user", content: userMessage }], systemPrompt, 800);
      aiResult = parseAIJson<{
        score: number;
        passed: boolean;
        breakdown: Record<string, number>;
        feedback: string;
        improvement_tips: string[];
      }>(aiResponse);
    } catch (aiError) {
      console.error("AI Evaluation failed:", aiError);
      await supabase
        .from("challenge_attempts")
        .update({ status: "failed" })
        .eq("id", attempt_id);
      return errorResponse("Evaluation temporarily unavailable. Please retry.", 500);
    }

    const score = Math.min(100, Math.max(0, aiResult.score));
    const passed = score >= 70;

    let badgeId = null;

    // 4. Handle Pass
    if (passed) {
      // Find badge
      const { data: badge } = await supabase
        .from("skill_badges")
        .select("id, name")
        .or(`id.eq.${challenge.badge_id},name.ilike.%${challenge.skill_name || challenge.title}%`)
        .limit(1)
        .single();

      if (badge) {
        badgeId = badge.id;
        // Award Badge
        await supabase.from("student_badges").upsert({
          student_id,
          badge_id: badgeId,
          verify_status: "verified",
          evidence_meta: { challenge_id: challenge.id, score, attempt_id },
        });

        // Update Skill
        await supabase.from("student_skills").upsert({
          student_id,
          skill_name: badge.name,
          proficiency: Math.ceil(score / 20),
          is_verified: true,
          source: "challenge",
        }, { onConflict: "student_id,skill_name" });

        // Fire Flywheels
        const base = `${SUPABASE_URL}/functions/v1`;
        const headers = { Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`, "Content-Type": "application/json" };
        fetch(`${base}/recalculate-dna`, { method: "POST", headers, body: JSON.stringify({ student_id }) }).catch(() => {});
        fetch(`${base}/update-trust-score`, { method: "POST", headers, body: JSON.stringify({ student_id, reason: "badge_verified" }) }).catch(() => {});
      }
    }

    // 5. Update Attempt
    await supabase
      .from("challenge_attempts")
      .update({
        ai_score: score,
        ai_feedback: aiResult.feedback,
        ai_breakdown: aiResult.breakdown,
        passed,
        badge_awarded: badgeId,
        status: "evaluated",
        evaluated_at: new Date().toISOString(),
      })
      .eq("id", attempt_id);

    // 6. Notify
    await createNotification(
      supabase,
      student_id,
      passed ? "badge_earned" : "challenge_result",
      passed ? "🏅 Badge Earned!" : "Challenge result",
      passed
        ? `You passed the challenge with score ${score}/100!`
        : `You scored ${score}/100. ${aiResult.improvement_tips[0]}`,
      { attempt_id, score, passed }
    );

    return successResponse({
      attempt_id,
      score,
      passed,
      feedback: aiResult.feedback,
      improvement_tips: aiResult.improvement_tips,
      badge_awarded: badgeId,
      breakdown: aiResult.breakdown,
    });

  } catch (err) {
    return errorResponse(err.message, 500);
  }
});
