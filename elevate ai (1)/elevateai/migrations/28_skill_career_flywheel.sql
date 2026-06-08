-- =============================================================================
-- ElevateAI — M6 + M7: Skill-Career Flywheel Integration
-- File: migrations/28_skill_career_flywheel.sql
-- =============================================================================

-- 1. Extend DNA with structured intelligence
ALTER TABLE student_dna
  ADD COLUMN IF NOT EXISTS skill_gaps JSONB DEFAULT '[]'::JSONB,
  ADD COLUMN IF NOT EXISTS roadmap    JSONB DEFAULT '[]'::JSONB;

-- 2. Update OSDashboard to use structured intelligence
CREATE OR REPLACE FUNCTION get_student_os_dashboard(p_student_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile      RECORD;
  v_dna          RECORD;
  v_trust        RECORD;
  v_top_action   JSONB;
  v_summary      JSONB;
  v_opp          JSONB;
  v_career       JSONB;
  v_network      JSONB;
  v_focus        JSONB;
  v_scam         JSONB;
  v_portfolio    JSONB;
  v_nudges       JSONB;
  v_prev_score   NUMERIC;
  v_trend        TEXT;
BEGIN
  -- Data fetching
  SELECT * INTO v_profile FROM student_profiles WHERE id = p_student_id;
  SELECT * INTO v_dna FROM student_dna WHERE student_id = p_student_id;
  SELECT * INTO v_trust FROM trust_scores WHERE student_id = p_student_id;

  -- Trend logic
  v_prev_score := (SELECT overall_score FROM trust_score_history WHERE student_id = p_student_id ORDER BY recorded_at DESC LIMIT 1 OFFSET 1);
  v_trend := CASE WHEN v_trust.overall_score > v_prev_score THEN 'up' WHEN v_trust.overall_score < v_prev_score THEN 'down' ELSE 'stable' END;

  -- Summary
  v_summary := jsonb_build_object(
    'trust_score', v_trust.overall_score,
    'career_readiness', v_dna.placement_score,
    'focus_score', v_dna.focus_score,
    'productivity_score', v_dna.productivity_score,
    'streak', v_dna.study_streak,
    'trend', v_trend
  );

  -- Career Command Center (Using AI Gaps + Roadmap)
  v_career := jsonb_build_object(
    'score', v_dna.placement_score,
    'top_gap', COALESCE(v_dna.skill_gaps->0->>'skill', 'None'),
    'next_milestone', COALESCE(v_dna.roadmap->0->>'step', 'Build profile'),
    'projection_90d', v_dna.readiness_projection_90d
  );

  -- Top Action (Now smarter)
  -- Priority: Notification > Top Gap Challenge > Expiring Opp
  v_top_action := (
    SELECT jsonb_build_object('label', title, 'action', COALESCE(data->>'route', '/notifications'), 'priority', 'high')
    FROM notifications WHERE student_id = p_student_id AND is_read = FALSE ORDER BY urgency DESC LIMIT 1
  );

  IF v_top_action IS NULL AND v_dna.skill_gaps IS NOT NULL AND jsonb_array_length(v_dna.skill_gaps) > 0 THEN
    v_top_action := jsonb_build_object(
      'label', 'Fill Gap: ' || (v_dna.skill_gaps->0->>'skill'),
      'action', '/skill_reality',
      'priority', 'medium'
    );
  END IF;

  -- Hubs (Simplified for demo)
  SELECT jsonb_build_object('title', title, 'match', match_score, 'id', opportunity_id) INTO v_opp FROM get_ranked_opportunities(p_student_id) ro JOIN opportunities o ON o.id = ro.opportunity_id WHERE eligibility_match = TRUE LIMIT 1;
  v_network := jsonb_build_object('invites', (SELECT COUNT(*) FROM team_members WHERE student_id = p_student_id AND status = 'invited'));
  v_focus := jsonb_build_object('risk', v_dna.career_risk_score);
  v_scam := jsonb_build_object('count', (SELECT COUNT(*) FROM scam_reports WHERE created_at > NOW() - INTERVAL '3 days'));
  v_portfolio := jsonb_build_object('completion', (SELECT COUNT(*) FROM student_projects WHERE student_id = p_student_id) * 20);

  RETURN jsonb_build_object(
    'summary', v_summary,
    'top_action', v_top_action,
    'opportunity_hub', v_opp,
    'career_center', v_career,
    'network_hub', v_network,
    'focus_center', v_focus,
    'scam_center', v_scam,
    'portfolio_center', v_portfolio,
    'archetype', v_dna.archetype,
    'nudges', '[]'::jsonb
  );
END;
$$;
