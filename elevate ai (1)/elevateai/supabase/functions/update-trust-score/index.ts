// supabase/functions/update-trust-score/index.ts
// ═══════════════════════════════════════════════════════════════
// ElevateAI — TrustScore Network: Full Weighted Recalculation
//
// Implements the complete TrustScore formula:
//   Overall = 30% Reliability + 25% Collaboration + 20% Integrity
//             + 15% SkillValidation + 10% Community
//
// Called after:
//   - ERP sync (attendance/assignment data)
//   - Peer rating submitted
//   - Badge verified
//   - Team event completed
//   - Application accepted/rejected
//   - Manual recalculation (admin)
//   - Batch nightly recalc
// ═══════════════════════════════════════════════════════════════

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import {
  createServiceClient,
  successResponse,
  errorResponse,
  optionsResponse,
  createNotification,
  computeOverallTrustScore,
  calculateTrustTier,
  isRateLimited,
} from "../_shared/utils.ts";

// ─── Types ────────────────────────────────────────────────────

interface TrustDimensions {
  reliability_score: number;
  collaboration_score: number;
  integrity_score: number;
  skill_validation_score: number;
  community_score: number;
}

interface TrustUpdateResult {
  student_id: string;
  previous_score: number;
  new_score: number;
  delta: number;
  new_tier: string;
  tier_changed: boolean;
  dimensions: TrustDimensions;
  reason: string;
}

// ─── Main Handler ─────────────────────────────────────────────

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return optionsResponse();
  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  let body: {
    student_id?: string;
    batch_all?: boolean;
    reason?: string;
    erp_data?: {
      attendance_pct: number;
      assignment_score: number;
      semester_gpa?: number[];
    };
  };
  try {
    body = await req.json();
  } catch {
    return errorResponse("Invalid JSON body");
  }

  const supabase = createServiceClient();

  // ── Batch mode ────────────────────────────────────────────
  if (body.batch_all) {
    const { data: students } = await supabase
      .from("student_profiles")
      .select("id")
      .eq("is_active", true)
      .is("deleted_at", null);

    const results: TrustUpdateResult[] = [];
    for (const s of students ?? []) {
      try {
        const result = await recalculateTrustScore(supabase, s.id, "Nightly batch recalculation");
        results.push(result);
      } catch (e) {
        console.error(`Trust batch failed for ${s.id}:`, e);
      }
      await new Promise((r) => setTimeout(r, 100));
    }
    return successResponse({ batch: true, processed: results.length, results });
  }

  // ── Single student mode ───────────────────────────────────
  const { student_id, reason = "Manual recalculation", erp_data } = body;
  if (!student_id) return errorResponse("student_id is required");

  // Rate limit: 10 trust updates per student per hour
  if (isRateLimited(`trust:${student_id}`, 10, 60 * 60 * 1000)) {
    return errorResponse("TrustScore update rate limit exceeded", 429);
  }

  try {
    const result = await recalculateTrustScore(supabase, student_id, reason, erp_data);
    return successResponse(result);
  } catch (e) {
    console.error("update-trust-score error:", e);
    return errorResponse(e instanceof Error ? e.message : "Unexpected error", 500);
  }
});

// ─── Core Recalculation Logic ─────────────────────────────────

async function recalculateTrustScore(
  supabase: ReturnType<typeof createServiceClient>,
  studentId: string,
  reason: string,
  erpData?: { attendance_pct: number; assignment_score: number; semester_gpa?: number[] }
): Promise<TrustUpdateResult> {

  // ── 1. Load All Base Context ──────────────────────────────
  const { data: current } = await supabase
    .from("trust_scores")
    .select("*")
    .eq("student_id", studentId)
    .single();

  if (!current) {
    await supabase.from("trust_scores").insert({ student_id: studentId });
    // Retry fetch...
  }

  const { data: dna } = await supabase.from("student_dna").select("*").eq("student_id", studentId).single();

  // ── 2. Compute Reliability Score (0-100) ──────────────────
  // Weights: ERP (40%), Focus Consistency (30%), Application Completion (30%)
  let reliabilityScore = 0;
  let academicReliability = current?.academic_reliability_score || 0;
  let academicConsistency = current?.academic_consistency_score || 0;

  // ERP Signal
  if (erpData) {
    academicReliability = 0.5 * erpData.attendance_pct + 0.5 * erpData.assignment_score;
    if (erpData.semester_gpa && erpData.semester_gpa.length > 1) {
      const avg = erpData.semester_gpa.reduce((a, b) => a + b, 0) / erpData.semester_gpa.length;
      const variance = erpData.semester_gpa.reduce((a, b) => a + Math.pow(b - avg, 2), 0) / erpData.semester_gpa.length;
      academicConsistency = Math.max(0, 100 - (variance * 100));
    }
  }

  // Focus Signal (M18 Task 4)
  const { data: focusSessions } = await supabase
    .from("focus_sessions")
    .select("status, duration_seconds")
    .eq("student_id", studentId)
    .gte("created_at", new Date(Date.now() - 7 * 86400000).toISOString());

  const totalFocus = focusSessions?.length || 0;
  const completedFocus = focusSessions?.filter(s => s.status === 'completed').length || 0;
  const focusReliability = totalFocus > 0 ? (completedFocus / totalFocus) * 100 : 70;

  // App Signal
  const { data: apps } = await supabase.from("opportunity_applications").select("status").eq("student_id", studentId);
  const appCompletion = (apps?.length || 0) > 0 ? (apps!.filter(a => a.status !== 'draft').length / apps!.length) * 100 : 80;

  reliabilityScore = 0.4 * academicReliability + 0.3 * focusReliability + 0.3 * appCompletion;

  // ── 3. Compute Collaboration Score (0-100) ────────────────
  // Weights: Peer Ratings (60%), Team Participation (40%)
  const { data: peerRatings } = await supabase.from("peer_ratings").select("overall").eq("ratee_id", studentId);
  const avgRating = (peerRatings?.length || 0) > 0
    ? (peerRatings!.reduce((s, r) => s + (r.overall || 3), 0) / peerRatings!.length) * 20
    : 75;

  const { data: teams } = await supabase.from("team_members").select("status").eq("student_id", studentId);
  const inviteAcceptRate = (teams?.length || 0) > 0
    ? (teams!.filter(t => t.status === 'active').length / teams!.length) * 100
    : 100;

  const collaborationScore = 0.6 * avgRating + 0.4 * inviteAcceptRate;

  // ── 4. Compute Integrity Score (0-100) ────────────────────
  // Profile completeness + Validated Reports - Scam Penalties
  const { data: profile } = await supabase.from("student_profiles").select("*").eq("id", studentId).single();
  const fields = ["full_name", "email", "phone", "course", "year_of_study", "cgpa"];
  const completeness = (fields.filter(f => profile?.[f as keyof typeof profile]).length / fields.length) * 100;

  const { data: myReports } = await supabase.from("scam_reports").select("status").eq("reported_by", studentId);
  const reportQuality = (myReports?.length || 0) > 0
    ? (myReports!.filter(r => r.status === 'confirmed').length / myReports!.length) * 100
    : 50;

  const { data: reportsAgainst } = await supabase.from("scam_reports").select("status").eq("opportunity_id", studentId); // Assuming id check for people too
  const penalty = (reportsAgainst?.filter(r => r.status === 'confirmed').length || 0) * 20;

  const integrityScore = Math.max(0, (0.7 * completeness + 0.3 * reportQuality) - penalty);

  // ── 5. Compute Skill Validation Score (0-100) ─────────────
  // Badges (50%), Verified Skills (30%), Innovation Hub Activity (20%)
  const { data: badges } = await supabase.from("student_badges").select("id").eq("student_id", studentId).eq("verify_status", "verified");
  const badgeScore = Math.min(50, (badges?.length || 0) * 10);

  const { data: vSkills } = await supabase.from("student_skills").select("proficiency").eq("student_id", studentId).eq("is_verified", true);
  const skillScore = Math.min(30, (vSkills?.length || 0) * 5);

  const { data: ideas } = await supabase.from("project_ideas").select("stage").eq("creator_id", studentId);
  const innovationScore = Math.min(20, (ideas?.length || 0) * 5 + ideas?.filter(i => i.stage !== 'idea').length * 5);

  const skillValidationScore = badgeScore + skillScore + innovationScore;

  // ── 6. Compute Community Score (0-100) ────────────────────
  // Ratings given + Leadership + Safety Participation
  const { data: ratingsGiven } = await supabase.from("peer_ratings").select("id").eq("rater_id", studentId);
  const { data: teamsLed } = await supabase.from("teams").select("id").eq("leader_id", studentId);

  const communityScore = Math.min(100,
    (ratingsGiven?.length || 0) * 5 +
    (teamsLed?.length || 0) * 15 +
    (myReports?.length || 0) * 10
  );

  // ── 7. Final Weighing ─────────────────────────────────────
  const dimensions: TrustDimensions = {
    reliability_score: Math.round(reliabilityScore * 10) / 10,
    collaboration_score: Math.round(collaborationScore * 10) / 10,
    integrity_score: Math.round(integrityScore * 10) / 10,
    skill_validation_score: Math.round(skillValidationScore * 10) / 10,
    community_score: Math.round(communityScore * 10) / 10,
  };

  const newOverallScore = computeOverallTrustScore(dimensions);
  const newTier = calculateTrustTier(newOverallScore);
  const previousScore = current?.overall_score ?? 0;
  const delta = Math.round((newOverallScore - previousScore) * 10) / 10;

  // ── 8. Updates ──────────────────────────────────────────
  await supabase.from("trust_scores").update({
    ...dimensions,
    overall_score: newOverallScore,
    tier: newTier,
    last_calculated: new Date().toISOString(),
    academic_reliability_score: academicReliability,
    academic_consistency_score: academicConsistency,
    erp_synced_at: erpData ? new Date().toISOString() : current?.erp_synced_at
  }).eq("student_id", studentId);

  if (Math.abs(delta) > 0.1) {
    await supabase.from("trust_score_history").insert({
      student_id: studentId,
      overall_score: newOverallScore,
      delta,
      reason,
      source: erpData ? "erp" : "system_intel",
    });
  }

  // Notify significant changes
  if (Math.abs(delta) >= 2 || newTier !== current?.tier) {
    await createNotification(
      supabase,
      studentId,
      "trust_update",
      delta > 0 ? "📈 TrustScore Improved!" : "📉 TrustScore Update",
      `Your score is now ${newOverallScore.toFixed(1)} (${newTier}). ${delta > 0 ? "Your recent activity shows high reliability." : "Focus on completing your sessions to improve."}`,
      { delta, tier: newTier }
    );
  }

  return {
    student_id: studentId,
    previous_score: previousScore,
    new_score: newOverallScore,
    delta,
    new_tier: newTier,
    tier_changed: newTier !== current?.tier,
    dimensions,
    reason,
  };
}
