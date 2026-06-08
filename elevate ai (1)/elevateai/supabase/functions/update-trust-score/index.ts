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

  // ── 1. Get current trust score ────────────────────────────
  const { data: current, error: trustErr } = await supabase
    .from("trust_scores")
    .select("*")
    .eq("student_id", studentId)
    .single();

  if (trustErr || !current) {
    // Create initial trust score record if doesn't exist
    await supabase.from("trust_scores").insert({
      student_id: studentId,
      overall_score: 0,
      reliability_score: 0,
      collaboration_score: 0,
      integrity_score: 0,
      skill_validation_score: 0,
      community_score: 0,
      tier: "Unverified",
    });
    // Re-fetch
    const { data: fresh } = await supabase
      .from("trust_scores")
      .select("*")
      .eq("student_id", studentId)
      .single();
    if (!fresh) throw new Error(`Could not initialize trust score for ${studentId}`);
    Object.assign(current ?? {}, fresh);
  }

  if (current.is_frozen) {
    return {
      student_id: studentId,
      previous_score: current.overall_score,
      new_score: current.overall_score,
      delta: 0,
      new_tier: current.tier,
      tier_changed: false,
      dimensions: {
        reliability_score: current.reliability_score,
        collaboration_score: current.collaboration_score,
        integrity_score: current.integrity_score,
        skill_validation_score: current.skill_validation_score,
        community_score: current.community_score,
      },
      reason: "TrustScore is frozen for investigation — no changes applied",
    };
  }

  // ── 2. Compute Reliability Score (0-100) ──────────────────
  // Sources: ERP attendance (40%), ERP assignment scores (30%), application completion rate (30%)
  let reliabilityScore = current.reliability_score;
  let academicReliability = current.academic_reliability_score || 0;
  let academicConsistency = current.academic_consistency_score || 0;

  if (erpData) {
    // Direct ERP data provided
    const erpReliability = Math.min(100,
      0.5 * erpData.attendance_pct +
      0.5 * erpData.assignment_score
    );
    reliabilityScore = erpReliability;
    academicReliability = erpReliability; // In this simulation, they are tied

    // Academic Consistency: Low variance in semester GPA (M18 Task 4)
    if (erpData.semester_gpa && erpData.semester_gpa.length > 1) {
      const avg = erpData.semester_gpa.reduce((a, b) => a + b, 0) / erpData.semester_gpa.length;
      const variance = erpData.semester_gpa.reduce((a, b) => a + Math.pow(b - avg, 2), 0) / erpData.semester_gpa.length;
      academicConsistency = Math.max(0, 100 - (variance * 100)); // Lower variance = higher consistency
    } else {
      academicConsistency = 75; // Baseline for first sem
    }

    await supabase.from("trust_scores").update({
      erp_attendance_pct: erpData.attendance_pct,
      erp_assignment_score: erpData.assignment_score,
      erp_synced_at: new Date().toISOString(),
      academic_reliability_score: academicReliability,
      academic_consistency_score: academicConsistency
    }).eq("student_id", studentId);
  } else {
    // Compute from DB signals
    const { data: appStats } = await supabase
      .from("opportunity_applications")
      .select("status")
      .eq("student_id", studentId);

    const totalApps = appStats?.length ?? 0;
    const submittedApps = appStats?.filter((a) => a.status !== "draft").length ?? 0;
    const completionRate = totalApps > 0 ? (submittedApps / totalApps) * 100 : 50;

    // Blend with existing ERP data if available
    const erpWeight = current.erp_attendance_pct != null ? 0.6 : 0;
    const appWeight = 1 - erpWeight;

    const erpComponent = erpWeight > 0
      ? 0.6 * (current.erp_attendance_pct ?? 0) + 0.4 * (current.erp_assignment_score ?? 0)
      : 0;

    reliabilityScore = Math.min(100,
      erpWeight * erpComponent + appWeight * completionRate
    );
  }

  // ── 3. Compute Collaboration Score (0-100) ────────────────
  // Sources: Peer ratings average (70%), team participation (30%)
  const { data: peerRatings } = await supabase
    .from("peer_ratings")
    .select("overall, dimensions")
    .eq("ratee_id", studentId);

  let collaborationScore = current.collaboration_score;
  if (peerRatings && peerRatings.length > 0) {
    const avgRating = peerRatings.reduce((sum, r) => sum + (r.overall ?? 3), 0) / peerRatings.length;
    const ratingNormalized = (avgRating / 5) * 100; // 1-5 → 0-100

    // Extract communication & reliability from dimension scores
    const avgCommScore = peerRatings.reduce((sum, r) => {
      const dim = r.dimensions as Record<string, number> ?? {};
      return sum + (dim.communication ?? 3);
    }, 0) / peerRatings.length;
    const commNormalized = (avgCommScore / 5) * 100;

    // Rating count bonus (more ratings = higher confidence)
    const countBonus = Math.min(10, peerRatings.length);

    collaborationScore = Math.min(100,
      0.70 * ratingNormalized + 0.20 * commNormalized + countBonus
    );
  }

  // ── 4. Compute Integrity Score (0-100) ────────────────────
  // Sources: No scam reports (hard penalty), profile completeness (40%), ERP match (30%)
  const { data: scamReports } = await supabase
    .from("scam_reports")
    .select("status")
    .eq("reported_by", studentId); // reports ABOUT this student in context

  let integrityScore = current.integrity_score;
  const confirmedScams = scamReports?.filter((r) => r.status === "confirmed").length ?? 0;
  const pendingScams = scamReports?.filter((r) => r.status === "investigating").length ?? 0;

  if (confirmedScams > 0) {
    integrityScore = Math.max(0, integrityScore - 25 * confirmedScams);
  } else if (pendingScams > 0) {
    integrityScore = Math.max(0, integrityScore - 5 * pendingScams);
  } else {
    // Profile completeness check
    const { data: profile } = await supabase
      .from("student_profiles")
      .select("full_name, email, phone, avatar_url, cgpa, branch, course, year_of_study")
      .eq("id", studentId)
      .single();

    if (profile) {
      const fields = ["full_name", "email", "phone", "avatar_url", "cgpa", "branch", "course", "year_of_study"];
      const filledFields = fields.filter((f) => profile[f as keyof typeof profile] != null);
      const completeness = (filledFields.length / fields.length) * 100;
      // Blend completeness with existing integrity score
      integrityScore = Math.min(100,
        0.6 * Math.max(integrityScore, completeness) + 0.4 * completeness
      );
    }
  }

  // ── 5. Compute Skill Validation Score (0-100) ─────────────
  // Sources: Verified badges (50%), verified skills (30%), verified achievements (20%)
  const { data: verifiedBadges } = await supabase
    .from("student_badges")
    .select("skill_badges(xp_value, level)")
    .eq("student_id", studentId)
    .eq("verify_status", "verified");

  const { data: verifiedSkills } = await supabase
    .from("student_skills")
    .select("proficiency")
    .eq("student_id", studentId)
    .eq("is_verified", true);

  const { data: verifiedAchievements } = await supabase
    .from("student_achievements")
    .select("id")
    .eq("student_id", studentId)
    .eq("is_verified", true);

  // Badge XP sum (normalized to 100)
  type BadgeWithXP = { skill_badges: { xp_value: number; level: number } | null };
  const badgeXP = (verifiedBadges as BadgeWithXP[] ?? []).reduce((sum, b) => {
    return sum + (b.skill_badges?.xp_value ?? 0) * (b.skill_badges?.level ?? 1);
  }, 0);
  const badgeScore = Math.min(50, badgeXP / 20); // normalize

  // Verified skills score
  const skillScore = Math.min(30, (verifiedSkills?.length ?? 0) * 3);

  // Achievements score
  const achieveScore = Math.min(20, (verifiedAchievements?.length ?? 0) * 5);

  const skillValidationScore = Math.min(100, badgeScore + skillScore + achieveScore);

  // ── 6. Compute Community Score (0-100) ────────────────────
  // Sources: Ratings given (40%), team leadership (30%), opportunities applied (30%)
  const { data: ratingsGiven } = await supabase
    .from("peer_ratings")
    .select("id")
    .eq("rater_id", studentId);

  const { data: teamsLed } = await supabase
    .from("teams")
    .select("id")
    .eq("leader_id", studentId)
    .neq("status", "disbanded");

  const { data: appsCount } = await supabase
    .from("opportunity_applications")
    .select("id")
    .eq("student_id", studentId)
    .eq("status", "submitted");

  const ratingsScore = Math.min(40, (ratingsGiven?.length ?? 0) * 4);
  const leadershipScore = Math.min(30, (teamsLed?.length ?? 0) * 10);
  const engagementScore = Math.min(30, (appsCount?.length ?? 0) * 3);

  const communityScore = Math.min(100, ratingsScore + leadershipScore + engagementScore);

  // ── 7. Compute overall weighted score ─────────────────────
  const dimensions: TrustDimensions = {
    reliability_score: Math.round(reliabilityScore * 100) / 100,
    collaboration_score: Math.round(collaborationScore * 100) / 100,
    integrity_score: Math.round(integrityScore * 100) / 100,
    skill_validation_score: Math.round(skillValidationScore * 100) / 100,
    community_score: Math.round(communityScore * 100) / 100,
  };

  const newOverallScore = computeOverallTrustScore(dimensions);
  const newTier = calculateTrustTier(newOverallScore);
  const previousScore = current?.overall_score ?? 0;
  const delta = Math.round((newOverallScore - previousScore) * 100) / 100;

  // ── 8. Update trust_scores table ─────────────────────────
  const { error: updateErr } = await supabase
    .from("trust_scores")
    .update({
      ...dimensions,
      overall_score: newOverallScore,
      tier: newTier,
      last_calculated: new Date().toISOString(),
      academic_reliability_score: academicReliability,
      academic_consistency_score: academicConsistency
    })
    .eq("student_id", studentId);

  if (updateErr) throw new Error(`Failed to update trust score: ${updateErr.message}`);

  // ── 9. Log to history ─────────────────────────────────────
  await supabase.from("trust_score_history").insert({
    student_id: studentId,
    overall_score: newOverallScore,
    delta,
    reason,
    source: erpData ? "erp" : "batch_recalc",
    snapshot: {
      ...dimensions,
      overall_score: newOverallScore,
      tier: newTier,
      peer_ratings_count: peerRatings?.length ?? 0,
      verified_badges_count: verifiedBadges?.length ?? 0,
      verified_skills_count: verifiedSkills?.length ?? 0,
    },
  });

  // ── 10. Notify student if score changed significantly ─────
  const tierChanged = newTier !== (current?.tier ?? "Unverified");
  const significantChange = Math.abs(delta) >= 2;

  if (tierChanged) {
    await createNotification(
      supabase,
      studentId,
      "trust_tier_changed",
      `🏆 Trust Tier ${delta > 0 ? "Upgraded" : "Updated"}!`,
      `Congratulations! Your TrustScore is now ${newOverallScore.toFixed(1)} — you've reached ${newTier} tier!`,
      { previous_tier: current?.tier, new_tier: newTier, delta }
    );
  } else if (significantChange) {
    await createNotification(
      supabase,
      studentId,
      "trust_score_updated",
      `📊 TrustScore ${delta > 0 ? "Increased" : "Changed"}`,
      `Your TrustScore ${delta > 0 ? "went up" : "changed"} by ${Math.abs(delta).toFixed(1)} points to ${newOverallScore.toFixed(1)}.`,
      { delta, new_score: newOverallScore }
    );
  }

  return {
    student_id: studentId,
    previous_score: previousScore,
    new_score: newOverallScore,
    delta,
    new_tier: newTier,
    tier_changed: tierChanged,
    dimensions,
    reason,
  };
}
