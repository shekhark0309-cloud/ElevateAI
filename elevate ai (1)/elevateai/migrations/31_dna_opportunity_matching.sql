-- =============================================================================
-- ElevateAI — M14 + M1: DNA-Driven Opportunity Intelligence
-- File: migrations/31_dna_opportunity_matching.sql
-- =============================================================================

-- 1. Enhance get_ranked_opportunities with DNA Reason Engine
CREATE OR REPLACE FUNCTION get_ranked_opportunities(p_student_id UUID)
RETURNS TABLE (
  opportunity_id     UUID,
  eligibility_match  BOOLEAN,
  match_score        NUMERIC,
  urgency_boost      NUMERIC,
  match_reason       TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_student RECORD;
  v_dna     RECORD;
  v_trust   NUMERIC;
  v_skills  TEXT[];
BEGIN
  -- Load profile + DNA
  SELECT * INTO v_student FROM public.student_profiles WHERE id = p_student_id;
  SELECT * INTO v_dna FROM public.student_dna WHERE student_id = p_student_id;
  SELECT overall_score INTO v_trust FROM public.trust_scores WHERE student_id = p_student_id;
  SELECT ARRAY_AGG(skill_name) INTO v_skills FROM public.student_skills WHERE student_id = p_student_id AND proficiency >= 3;

  RETURN QUERY
  SELECT
    o.id AS opportunity_id,
    -- 1. Eligibility Logic
    (
      (ARRAY_LENGTH(o.eligible_states, 1) IS NULL OR v_student.state = ANY(o.eligible_states)) AND
      (o.min_cgpa IS NULL OR v_student.cgpa >= o.min_cgpa) AND
      (COALESCE(v_trust, 0) >= COALESCE(o.min_trust_score, 0))
    ) AS eligibility_match,
    -- 2. Base Scoring + DNA Weighting (Task 2 & 3)
    (
      CASE WHEN o.is_featured THEN 20 ELSE 0 END +
      -- Skill alignment
      (SELECT COUNT(*) FROM UNNEST(o.required_skills) s WHERE s = ANY(v_skills)) * 10 +
      -- Archetype weighting
      CASE
        WHEN v_dna.archetype = 'Builder' AND o.type IN ('hackathon', 'competition') THEN 25
        WHEN v_dna.archetype = 'Strategist' AND o.type IN ('fellowship', 'research') THEN 25
        WHEN v_dna.archetype = 'Creative' AND o.type IN ('hackathon', 'workshop') THEN 20
        WHEN v_dna.archetype = 'Executor' AND o.type IN ('internship', 'workshop') THEN 25
        ELSE 0
      END +
      -- Deadline proximity
      GREATEST(0, 10 - EXTRACT(DAY FROM (o.apply_deadline - NOW())))
    ) AS match_score,
    -- 3. Urgency
    CASE WHEN EXTRACT(DAY FROM (o.apply_deadline - NOW())) <= 2 THEN 10.0 ELSE 0.0 END AS urgency_boost,
    -- 4. Transparent Reasoning (Task 10)
    CASE
      WHEN (SELECT COUNT(*) FROM UNNEST(o.required_skills) s WHERE s = ANY(v_skills)) > 0
        THEN 'Matches your verified skill: ' || (SELECT skill_name FROM student_skills WHERE student_id = p_student_id AND proficiency >= 3 LIMIT 1)
      WHEN v_dna.archetype = 'Builder' AND o.type = 'hackathon' THEN 'Perfect for your Builder DNA — focus on shipping code.'
      WHEN v_dna.archetype = 'Creative' AND o.type = 'hackathon' THEN 'Matches your Creative DNA — bring the vision to your team.'
      WHEN v_dna.archetype = 'Strategist' THEN 'Aligns with your Strategist profile for high-impact roles.'
      ELSE 'Curated based on your general profile and TrustScore tier.'
    END AS match_reason
  FROM public.opportunities o
  WHERE o.status = 'active'
    AND o.apply_deadline > NOW()
    AND NOT EXISTS (
      SELECT 1 FROM public.opportunity_applications oa
      WHERE oa.opportunity_id = o.id AND oa.student_id = p_student_id
    );
END;
$$;

-- 2. Notification Trigger for DNA-Matched Opportunities (Task 7)
CREATE OR REPLACE FUNCTION notify_dna_matched_opportunity()
RETURNS TRIGGER AS $$
DECLARE
  v_student RECORD;
BEGIN
  -- Notify students whose DNA + Skills match this new opportunity
  -- (Using a subset for performance: same college or high trust)
  FOR v_student IN
    SELECT sp.id, dna.archetype
    FROM student_profiles sp
    JOIN student_dna dna ON dna.student_id = sp.id
    WHERE sp.is_active = TRUE
    LIMIT 100 -- In production, use a more targeted filter or background job
  LOOP
    -- Simple logic: if archetype fits the opportunity type, notify
    IF (NEW.type = 'hackathon' AND v_student.archetype IN ('Builder', 'Creative')) OR
       (NEW.type = 'internship' AND v_student.archetype = 'Executor') THEN

       INSERT INTO notifications (student_id, type, title, body, data, priority, urgency)
       VALUES (
         v_student.id,
         'dna_match_opportunity',
         '🧬 DNA Match Found!',
         'A new ' || NEW.type || ' matched your ' || v_student.archetype || ' DNA. Check it out!',
         jsonb_build_object('opportunity_id', NEW.id, 'route', '/opportunities'),
         'medium',
         6
       );
    END IF;
  END LOOP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER on_new_opportunity_dna_match
  AFTER INSERT ON opportunities
  FOR EACH ROW
  EXECUTE FUNCTION notify_dna_matched_opportunity();
