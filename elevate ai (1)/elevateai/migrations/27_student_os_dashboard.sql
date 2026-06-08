-- =============================================================================
-- ElevateAI — Student OS Command Center (Updated: Focus Flywheel Integration)
-- File: migrations/27_student_os_dashboard.sql
-- =============================================================================

CREATE OR REPLACE FUNCTION get_student_os_dashboard(p_student_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile         RECORD;
  v_dna             RECORD;
  v_trust           RECORD;
  v_top_action      JSONB;
  v_summary         JSONB;
  v_opp             JSONB;
  v_career          JSONB;
  v_network         JSONB;
  v_focus           JSONB;
  v_scam            JSONB;
  v_portfolio       JSONB;
  v_nudges          JSONB;
  v_focus_intel     JSONB;
  v_prev_trust      NUMERIC;
  v_overall_trend   TEXT;
BEGIN
  -- 1. Base Signal Fetching
  SELECT * INTO v_profile FROM student_profiles WHERE id = p_student_id;
  SELECT * INTO v_dna FROM student_dna WHERE student_id = p_student_id;
  SELECT * INTO v_trust FROM trust_scores WHERE student_id = p_student_id;

  -- 2. Focus Intelligence (M4/M5)
  v_focus_intel := get_focus_intelligence(p_student_id);

  -- 3. Trend Calculation
  v_prev_trust := (SELECT overall_score FROM trust_score_history
                    WHERE student_id = p_student_id AND source != 'dna_engine'
                    ORDER BY recorded_at DESC LIMIT 1 OFFSET 1);
  v_overall_trend := CASE
    WHEN v_trust.overall_score > v_prev_trust THEN 'up'
    WHEN v_trust.overall_score < v_prev_trust THEN 'down'
    ELSE 'stable'
  END;

  -- 4. Daily Summary (Section 1)
  v_summary := jsonb_build_object(
    'trust_score', COALESCE(v_trust.overall_score, 0),
    'career_readiness', COALESCE(v_dna.placement_score, 0),
    'focus_score', COALESCE(v_dna.focus_score, 0),
    'productivity_score', COALESCE(v_dna.productivity_score, 0),
    'streak', COALESCE(v_dna.study_streak, 0),
    'trend', v_overall_trend
  );

  -- 5. Top Action Engine (Section 2)
  v_top_action := (
    SELECT jsonb_build_object(
      'label', title,
      'action', COALESCE(data->>'route', action_url, '/notifications'),
      'priority', priority
    )
    FROM notifications
    WHERE student_id = p_student_id AND is_read = FALSE
    ORDER BY urgency DESC, created_at DESC LIMIT 1
  );

  -- 6. Hub Data
  -- Opportunity Hub
  SELECT jsonb_build_object('id', id, 'title', title, 'match', 85) INTO v_opp
  FROM v_active_opportunities LIMIT 1;

  -- Career Center
  v_career := jsonb_build_object(
    'score', COALESCE(v_dna.placement_score, 0),
    'top_gap', COALESCE(v_dna.skill_gaps->0->>'skill', 'None'),
    'projection_90d', v_dna.readiness_projection_90d
  );

  -- Focus & Productivity (Real Integration - Task 4)
  v_focus := jsonb_build_object(
    'today_minutes', COALESCE(v_dna.daily_focus_minutes, 0),
    'risk_level', v_focus_intel->>'risk_level',
    'intervention', v_focus_intel->>'intervention',
    'recommended_session', v_focus_intel->>'next_recommended_session',
    'goal_minutes', 120
  );

  -- 7. Smart Nudges
  SELECT jsonb_agg(n) INTO v_nudges FROM (
    SELECT title, body, priority as type, action_label, action_url as action
    FROM notifications
    WHERE student_id = p_student_id AND is_read = FALSE
    ORDER BY urgency DESC LIMIT 5
  ) n;

  RETURN jsonb_build_object(
    'summary', v_summary,
    'top_action', v_top_action,
    'opportunity_hub', v_opp,
    'career_center', v_career,
    'network_hub', jsonb_build_object('invites', (SELECT COUNT(*) FROM team_members WHERE student_id = p_student_id AND status = 'invited')),
    'focus_center', v_focus,
    'scam_center', jsonb_build_object('count', (SELECT COUNT(*) FROM scam_reports WHERE created_at > NOW() - INTERVAL '7 days')),
    'portfolio_center', jsonb_build_object('completion', 60),
    'nudges', COALESCE(v_nudges, '[]'::jsonb),
    'archetype', v_dna.archetype
  );
END;
$$;

GRANT EXECUTE ON FUNCTION get_student_os_dashboard TO authenticated;
