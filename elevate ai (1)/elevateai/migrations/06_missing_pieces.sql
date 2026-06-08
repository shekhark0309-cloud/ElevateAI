-- =============================================================================
-- ElevateAI — Missing RPCs & Performance Layer
-- File: migrations/06_missing_pieces.sql
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. get_ranked_opportunities()
--    SQL-level ranking for opportunities.
--    Handles basic eligibility filtering and scoring before AI refinement.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION get_ranked_opportunities(p_student_id UUID)
RETURNS TABLE (
  opportunity_id     UUID,
  eligibility_match  BOOLEAN,
  match_score        NUMERIC,
  urgency_boost      NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_student RECORD;
  v_trust   NUMERIC;
BEGIN
  -- Load student profile
  SELECT * INTO v_student FROM public.student_profiles WHERE id = p_student_id;
  SELECT overall_score INTO v_trust FROM public.trust_scores WHERE student_id = p_student_id;

  RETURN QUERY
  SELECT
    o.id AS opportunity_id,
    -- Eligibility Logic
    (
      (ARRAY_LENGTH(o.eligible_states, 1) IS NULL OR v_student.state = ANY(o.eligible_states)) AND
      (ARRAY_LENGTH(o.eligible_categories, 1) IS NULL OR v_student.category = ANY(o.eligible_categories)) AND
      (o.min_cgpa IS NULL OR v_student.cgpa >= o.min_cgpa) AND
      (o.min_year IS NULL OR v_student.year_of_study >= o.min_year) AND
      (o.max_year IS NULL OR v_student.year_of_study <= o.max_year) AND
      (COALESCE(v_trust, 0) >= COALESCE(o.min_trust_score, 0))
    ) AS eligibility_match,
    -- Base Scoring
    (
      CASE WHEN o.is_featured THEN 20 ELSE 0 END +
      CASE WHEN o.is_verified THEN 15 ELSE 0 END +
      COALESCE(o.organizer_trust_score, 50) / 5.0 +
      -- Deadline proximity (closer = higher score, up to 10pts)
      GREATEST(0, 10 - EXTRACT(DAY FROM (o.apply_deadline - NOW())))
    ) AS match_score,
    -- Urgency
    CASE
      WHEN EXTRACT(DAY FROM (o.apply_deadline - NOW())) <= 2 THEN 10.0
      WHEN EXTRACT(DAY FROM (o.apply_deadline - NOW())) <= 7 THEN 5.0
      ELSE 0.0
    END AS urgency_boost
  FROM public.opportunities o
  WHERE o.status = 'active'
    AND o.apply_deadline > NOW()
    AND o.deleted_at IS NULL
    AND NOT EXISTS (
      SELECT 1 FROM public.opportunity_applications oa
      WHERE oa.opportunity_id = o.id AND oa.student_id = p_student_id
    );
END;
$$;


-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Enhanced get_student_dashboard()
--    Updated to include "Recent Activity" and better DNA summary.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION get_student_dashboard_v2(p_student_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_res JSONB;
BEGIN
  SELECT jsonb_build_object(
    'profile', (SELECT row_to_json(p) FROM (SELECT full_name, avatar_url, year_of_study FROM student_profiles WHERE id = p_student_id) p),
    'dna', (SELECT row_to_json(d) FROM (SELECT archetype, ai_summary, top_skills, study_streak FROM student_dna WHERE student_id = p_student_id) d),
    'trust', (SELECT row_to_json(t) FROM (SELECT overall_score, tier, reliability_score, collaboration_score FROM trust_scores WHERE student_id = p_student_id) t),
    'recent_activity', (
      SELECT COALESCE(jsonb_agg(a), '[]'::jsonb) FROM (
        SELECT 'trust_update' as type, reason, delta, recorded_at as ts FROM trust_score_history WHERE student_id = p_student_id
        UNION ALL
        SELECT 'badge_earned' as type, sb.name, 0, stb.earned_at FROM student_badges stb JOIN skill_badges sb ON sb.id = stb.badge_id WHERE stb.student_id = p_student_id AND stb.verify_status = 'verified'
        UNION ALL
        SELECT 'app_submitted' as type, o.title, 0, oa.submitted_at FROM opportunity_applications oa JOIN opportunities o ON o.id = oa.opportunity_id WHERE oa.student_id = p_student_id
        ORDER BY ts DESC LIMIT 10
      ) a
    ),
    'notifications_count', (SELECT COUNT(*) FROM notifications WHERE student_id = p_student_id AND is_read = FALSE)
  ) INTO v_res;

  RETURN v_res;
END;
$$;


-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Security Hardening: search_path
--    Ensure all functions are protected against search_path attacks.
-- ─────────────────────────────────────────────────────────────────────────────

ALTER FUNCTION submit_peer_rating SET search_path = public;
ALTER FUNCTION award_badge SET search_path = public;
ALTER FUNCTION create_team_with_members SET search_path = public;
ALTER FUNCTION apply_to_opportunity SET search_path = public;
ALTER FUNCTION get_student_dashboard SET search_path = public;
ALTER FUNCTION verify_badge_by_peer SET search_path = public;
ALTER FUNCTION accept_team_invite SET search_path = public;
