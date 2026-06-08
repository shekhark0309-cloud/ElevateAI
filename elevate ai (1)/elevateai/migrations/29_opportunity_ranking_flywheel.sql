-- =============================================================================
-- ElevateAI — Opportunity Ranking Flywheel
-- File: migrations/29_opportunity_ranking_flywheel.sql
-- =============================================================================

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
  v_skills  TEXT[];
BEGIN
  -- Load student profile
  SELECT * INTO v_student FROM public.student_profiles WHERE id = p_student_id;
  SELECT overall_score INTO v_trust FROM public.trust_scores WHERE student_id = p_student_id;
  SELECT ARRAY_AGG(skill_name) INTO v_skills FROM public.student_skills WHERE student_id = p_student_id AND proficiency >= 3;

  RETURN QUERY
  SELECT
    o.id AS opportunity_id,
    -- Eligibility Logic
    (
      (ARRAY_LENGTH(o.eligible_states, 1) IS NULL OR v_student.state = ANY(o.eligible_states)) AND
      (o.min_cgpa IS NULL OR v_student.cgpa >= o.min_cgpa) AND
      (COALESCE(v_trust, 0) >= COALESCE(o.min_trust_score, 0))
    ) AS eligibility_match,
    -- Base Scoring + Skill Matching (Task 6)
    (
      CASE WHEN o.is_featured THEN 20 ELSE 0 END +
      (SELECT COUNT(*) FROM UNNEST(o.required_skills) s WHERE s = ANY(v_skills)) * 10 + -- Skill alignment
      -- Deadline proximity
      GREATEST(0, 10 - EXTRACT(DAY FROM (o.apply_deadline - NOW())))
    ) AS match_score,
    -- Urgency
    CASE WHEN EXTRACT(DAY FROM (o.apply_deadline - NOW())) <= 2 THEN 10.0 ELSE 0.0 END AS urgency_boost
  FROM public.opportunities o
  WHERE o.status = 'active'
    AND o.apply_deadline > NOW()
    AND NOT EXISTS (
      SELECT 1 FROM public.opportunity_applications oa
      WHERE oa.opportunity_id = o.id AND oa.student_id = p_student_id
    );
END;
$$;
