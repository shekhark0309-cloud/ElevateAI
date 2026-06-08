import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import {
  createServiceClient,
  successResponse,
  errorResponse,
  optionsResponse,
  createNotification,
} from "../_shared/utils.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

serve(async (req) => {
  if (req.method === "OPTIONS") return optionsResponse();

  try {
    const { team_event_id, action } = await req.json();

    if (!team_event_id || !action) {
      return errorResponse("team_event_id and action are required", 400);
    }

    const supabase = createServiceClient();

    // 1. Fetch Event
    const { data: event, error: eventError } = await supabase
      .from("team_events")
      .select("*")
      .eq("id", team_event_id)
      .single();

    if (eventError || !event) return errorResponse("Event not found", 404);

    // 2. Fetch Members
    const { data: members, error: membersError } = await supabase
      .from("team_members")
      .select("student_id")
      .eq("team_id", event.team_id)
      .eq("status", "active");

    if (membersError) throw membersError;

    if (action === "notify") {
      if (!members || members.length < 2) {
        return successResponse({ message: "Not enough members for debrief" });
      }

      for (const member of members) {
        await createNotification(
          supabase,
          member.student_id,
          "debrief_request",
          "⭐ Rate Your Teammates!",
          `How did your team do at ${event.event_name}? Rate ${members.length - 1} teammate(s) — takes 2 minutes.`,
          { team_event_id: event.id, team_id: event.team_id, debrief_deadline: event.debrief_deadline }
        );
      }
      return successResponse({ notified_count: members.length, debrief_deadline: event.debrief_deadline });

    } else if (action === "check_completion") {
      const completionStatus = [];
      let allCompleted = true;

      for (const member of members) {
        const { count, error: countError } = await supabase
          .from("peer_ratings")
          .select("*", { count: "exact", head: true })
          .eq("rater_id", member.student_id)
          .eq("context_type", "team")
          .eq("context_id", team_event_id);

        if (countError) throw countError;

        const hasCompleted = (count || 0) >= (members.length - 1);
        completionStatus.push({ student_id: member.student_id, completed: hasCompleted });
        if (!hasCompleted) allCompleted = false;
      }

      if (allCompleted && !event.debrief_completed) {
        await supabase
          .from("team_events")
          .update({ debrief_completed: true })
          .eq("id", team_event_id);

        const base = `${SUPABASE_URL}/functions/v1`;
        const headers = { Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`, "Content-Type": "application/json" };

        for (const member of members) {
          // Fire-and-forget trust score update
          fetch(`${base}/update-trust-score`, {
            method: "POST",
            headers,
            body: JSON.stringify({ student_id: member.student_id, reason: "post_hackathon_debrief" })
          }).catch(() => {});

          await createNotification(
            supabase,
            member.student_id,
            "debrief_complete",
            "Debrief Complete!",
            "All teammates rated. TrustScore updated."
          );
        }
      }

      return successResponse({
        completed: allCompleted,
        members_rated: completionStatus.filter(s => s.completed).length,
        total_members: members.length
      });
    }

    return errorResponse("Invalid action", 400);

  } catch (err) {
    return errorResponse(err.message, 500);
  }
});
