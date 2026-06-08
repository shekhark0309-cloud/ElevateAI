-- =============================================================================
-- ElevateAI — M7: Career Readiness Predictor Automation
-- File: migrations/25_career_predictor_automation.sql
-- =============================================================================

-- 1. Extend DNA with Forecast fields
ALTER TABLE student_dna
  ADD COLUMN IF NOT EXISTS readiness_projection_30d NUMERIC(5,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS readiness_projection_90d NUMERIC(5,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS career_risk_score       NUMERIC(5,2) DEFAULT 0;

-- 2. Enhanced RPC: calculate_placement_score
-- Includes more behavioral signals from M3, M5, M19
CREATE OR REPLACE FUNCTION calculate_placement_score(p_student_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_skill_count     INTEGER;
  v_badge_count     INTEGER;
  v_trust_score     NUMERIC;
  v_cgpa            NUMERIC;
  v_project_count   INTEGER;
  v_focus_score     NUMERIC;
  v_placement_score NUMERIC;
  v_salary_min      INTEGER;
  v_salary_max      INTEGER;
  v_risk_score      NUMERIC;
BEGIN
  -- Data fetching
  SELECT COUNT(*) INTO v_skill_count FROM student_skills WHERE student_id = p_student_id AND proficiency >= 3;
  SELECT COUNT(*) INTO v_badge_count FROM student_badges WHERE student_id = p_student_id AND verify_status = 'verified';
  SELECT overall_score INTO v_trust_score FROM trust_scores WHERE student_id = p_student_id;
  SELECT cgpa INTO v_cgpa FROM student_profiles WHERE id = p_student_id;
  SELECT COUNT(*) INTO v_project_count FROM student_projects WHERE student_id = p_student_id;
  SELECT COALESCE(focus_score, 0) INTO v_focus_score FROM student_dna WHERE student_id = p_student_id;

  -- Weighted formula
  v_placement_score := LEAST(100,
    (COALESCE(v_skill_count, 0) * 2.5) +   -- Max ~25
    (COALESCE(v_badge_count, 0) * 7) +     -- Max ~35
    (COALESCE(v_trust_score, 0) * 0.15) +  -- Max ~15
    (COALESCE(v_cgpa, 0) * 3) +            -- Max ~30
    (COALESCE(v_project_count, 0) * 5) +   -- Max ~25 (cap via LEAST)
    (COALESCE(v_focus_score, 0) * 0.1)     -- Max ~10
  );

  -- Risk Detection (Task 9)
  v_risk_score := (
    CASE WHEN v_project_count = 0 THEN 30 ELSE 0 END +
    CASE WHEN v_skill_count < 3 THEN 20 ELSE 0 END +
    CASE WHEN v_trust_score < 40 THEN 20 ELSE 0 END
  );

  -- Salary prediction
  v_salary_min := CASE
    WHEN v_placement_score >= 85 THEN 15
    WHEN v_placement_score >= 70 THEN 10
    WHEN v_placement_score >= 50 THEN 6
    ELSE 4
  END;
  v_salary_max := v_salary_min + 5;

  -- Update student_dna
  UPDATE student_dna SET
    placement_score = v_placement_score,
    salary_range_min = v_salary_min,
    salary_range_max = v_salary_max,
    career_risk_score = v_risk_score,
    readiness_projection_30d = LEAST(100, v_placement_score + 5), -- simplified projection
    readiness_projection_90d = LEAST(100, v_placement_score + 15),
    career_readiness_at = NOW()
  WHERE student_id = p_student_id;

  RETURN jsonb_build_object(
    'placement_score', ROUND(v_placement_score::NUMERIC, 1),
    'risk_score', v_risk_score,
    'salary_min', v_salary_min,
    'salary_max', v_salary_max,
    'projections', jsonb_build_object('30d', LEAST(100, v_placement_score + 5), '90d', LEAST(100, v_placement_score + 15))
  );
END;
$$;

-- 3. RPC: get_career_roadmap_intelligence
CREATE OR REPLACE FUNCTION get_career_roadmap_intelligence(p_student_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_dna RECORD;
  v_missing_skills TEXT[];
  v_next_actions JSONB := '[]'::JSONB;
BEGIN
  SELECT * INTO v_dna FROM student_dna WHERE student_id = p_student_id;

  -- 1. Identify Skill Gaps (Task 2)
  -- Logic: Required skills for target roles that student doesn't have at level 3+
  SELECT ARRAY_AGG(DISTINCT s) INTO v_missing_skills
  FROM UNNEST(v_dna.target_roles) r
  CROSS JOIN LATERAL (
    -- Mock requirement mapping (in real, we'd have a role_skills table)
    SELECT UNNEST(ARRAY['DSA', 'System Design', 'React']) WHERE r = 'Software Engineer'
    UNION ALL SELECT UNNEST(ARRAY['Figma', 'User Research']) WHERE r = 'UI/UX Designer'
  ) s
  WHERE NOT EXISTS (
    SELECT 1 FROM student_skills
    WHERE student_id = p_student_id AND skill_name = s AND proficiency >= 3
  );

  -- 2. Generate Action Center items (Task 10)
  IF ARRAY_LENGTH(v_missing_skills, 1) > 0 THEN
    v_next_actions := v_next_actions || jsonb_build_object(
      'priority', 'high',
      'label', 'Learn ' || v_missing_skills[1],
      'action', 'challenge',
      'impact', '+5 Readiness'
    );
  END IF;

  IF (SELECT COUNT(*) FROM student_projects WHERE student_id = p_student_id) < 2 THEN
    v_next_actions := v_next_actions || jsonb_build_object(
      'priority', 'medium',
      'label', 'Start a new Project',
      'action', 'hub',
      'impact', '+10 Readiness'
    );
  END IF;

  RETURN jsonb_build_object(
    'score', v_dna.placement_score,
    'risk_level', CASE WHEN v_dna.career_risk_score > 50 THEN 'High' WHEN v_dna.career_risk_score > 20 THEN 'Medium' ELSE 'Low' END,
    'gaps', COALESCE(v_missing_skills, '{}'),
    'next_actions', v_next_actions,
    'forecast', jsonb_build_object('current', v_dna.placement_score, '30d', v_dna.readiness_projection_30d, '90d', v_dna.readiness_projection_90d)
  );
END;
$$;

-- 4. Automatic Recalculation Triggers (Task 1)
CREATE OR REPLACE FUNCTION trigger_career_recalc()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM calculate_placement_score(COALESCE(NEW.student_id, NEW.id));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to relevant tables
CREATE OR REPLACE TRIGGER career_recalc_skills AFTER INSERT OR UPDATE ON student_skills FOR EACH ROW EXECUTE FUNCTION trigger_career_recalc();
CREATE OR REPLACE TRIGGER career_recalc_badges AFTER INSERT OR UPDATE ON student_badges FOR EACH ROW EXECUTE FUNCTION trigger_career_recalc();
CREATE OR REPLACE TRIGGER career_recalc_projects AFTER INSERT OR UPDATE ON student_projects FOR EACH ROW EXECUTE FUNCTION trigger_career_recalc();
CREATE OR REPLACE TRIGGER career_recalc_apps AFTER INSERT OR UPDATE ON opportunity_applications FOR EACH ROW EXECUTE FUNCTION trigger_career_recalc();

GRANT EXECUTE ON FUNCTION get_career_roadmap_intelligence TO authenticated;
