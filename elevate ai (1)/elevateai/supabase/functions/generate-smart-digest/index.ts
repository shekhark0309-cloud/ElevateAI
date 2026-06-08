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

serve(async (req) => {
  if (req.method === "OPTIONS") return optionsResponse();

  try {
    const { student_id } = await req.json();

    if (!student_id) return errorResponse("student_id is required", 400);

    if (isRateLimited(`digest:${student_id}`, 3, 86400000)) {
      return errorResponse("Daily limit reached", 429);
    }

    const supabase = createServiceClient();

    // 1. Fetch unread, un-batched notifications (last 24h)
    const { data: notifs } = await supabase
      .from("notifications")
      .select("id, type, title, body, created_at")
      .eq("student_id", student_id)
      .eq("is_read", false)
      .eq("is_batched", false)
      .gte("created_at", new Date(Date.now() - 86400000).toISOString())
      .order("created_at", { ascending: false });

    if (!notifs || notifs.length === 0) {
      return successResponse({ message: "No pending notifications", digest_created: false });
    }

    // 2. Fetch Context
    const { data: dna } = await supabase
      .from("student_dna")
      .select("study_streak, focus_score, archetype, goals_short_term")
      .eq("student_id", student_id)
      .single();

    const { data: deadlines } = await supabase
      .from("opportunity_applications")
      .select("opportunities(title, apply_deadline)")
      .eq("student_id", student_id)
      .in("status", ["submitted", "under_review"]);

    const upcoming = deadlines
      ?.map((d: any) => d.opportunities)
      .filter((o: any) => {
        const d = new Date(o.apply_deadline);
        return d > new Date() && d < new Date(Date.now() + 7 * 86400000);
      });

    // 3. AI Classification
    const systemPrompt = "You are ElevateAI's notification intelligence layer. You help students stay focused on what matters by cutting through noise. Be brief, warm, and specific. RESPOND ONLY WITH VALID JSON.";

    const userMessage = `Classify these notifications for a student. Context: ${JSON.stringify({
      notifications: notifs,
      upcoming_deadlines: upcoming,
      student_context: {
        study_streak: dna?.study_streak,
        focus_score: dna?.focus_score,
        archetype: dna?.archetype,
        top_goal: dna?.goals_short_term?.[0],
      },
    })}

Return EXACTLY this JSON:
{
  "critical": [{ "id": "...", "title": "...", "body": "..." }],
  "important": [{ "id": "...", "title": "...", "body": "..." }],
  "low_notification_ids": ["id1", "id2"],
  "low_summary": "One sentence summarising the low-priority items",
  "nudge": "One warm, specific motivational line tailored to their archetype and current streak"
}

CRITICAL = deadline <24h, badge earned, team invite, scam alert
IMPORTANT = deadline 2-7 days, new opportunity match, TrustScore change
LOW = everything else`;

    let aiResult;
    try {
      const aiResponse = await callAI([{ role: "user", content: userMessage }], systemPrompt, 1000);
      aiResult = parseAIJson<any>(aiResponse);
    } catch (err) {
      console.error("AI Digest generation failed:", err);
      // Fallback simple digest
      aiResult = {
        critical: notifs.filter(n => ["team_invite", "scam_alert"].includes(n.type)),
        important: notifs.filter(n => !["team_invite", "scam_alert"].includes(n.type)).slice(0, 3),
        low_notification_ids: notifs.slice(3).map(n => n.id),
        low_summary: `You have ${Math.max(0, notifs.length - 3)} other updates.`,
        nudge: "Stay focused on your goals!",
      };
    }

    // 4. Mark low-priority as batched
    if (aiResult.low_notification_ids?.length > 0) {
      await supabase
        .from("notifications")
        .update({ is_batched: true })
        .in("id", aiResult.low_notification_ids);
    }

    // 5. Create Digest Notification
    await createNotification(
      supabase,
      student_id,
      "smart_digest",
      aiResult.critical.length > 0 ? `🔴 ${aiResult.critical.length} urgent item(s) today` : "📬 Daily Digest",
      aiResult.nudge,
      {
        critical_count: aiResult.critical.length,
        important_count: aiResult.important.length,
        low_summary: aiResult.low_summary,
        critical_items: aiResult.critical,
        important_items: aiResult.important,
      }
    );

    return successResponse({
      critical_count: aiResult.critical.length,
      important_count: aiResult.important.length,
      low_count: aiResult.low_notification_ids.length,
      nudge: aiResult.nudge,
    });

  } catch (err) {
    return errorResponse(err.message, 500);
  }
});
