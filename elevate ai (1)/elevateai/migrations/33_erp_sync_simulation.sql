-- =============================================================================
-- ElevateAI — ERP Sync Simulation (M18 Task 2-6)
-- File: migrations/33_erp_sync_simulation.sql
-- =============================================================================

-- 1. Add academic simulation fields to student_profiles
ALTER TABLE student_profiles
ADD COLUMN IF NOT EXISTS erp_synced BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS erp_credits_completed INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS erp_backlogs SMALLINT DEFAULT 0,
ADD COLUMN IF NOT EXISTS erp_course_progress NUMERIC(5,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS erp_semester_gpa NUMERIC[] DEFAULT '{}';

-- 2. Add academic trust dimensions to trust_scores
ALTER TABLE trust_scores
ADD COLUMN IF NOT EXISTS academic_reliability_score NUMERIC(4,1) DEFAULT 0,
ADD COLUMN IF NOT EXISTS academic_consistency_score NUMERIC(4,1) DEFAULT 0;

-- 3. Update get_student_os_dashboard to include academic snapshot
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
  v_project_count   INTEGER;
  v_skill_count     INTEGER;
  v_portfolio_score INTEGER;
  v_focus_goal      INTEGER;
  v_academic        JSONB;
BEGIN
  -- 1. Base Signal Fetching
  SELECT * INTO v_profile FROM student_profiles WHERE id = p_student_id;
  SELECT * INTO v_dna FROM student_dna WHERE student_id = p_student_id;
  SELECT * INTO v_trust FROM trust_scores WHERE student_id = p_student_id;

  -- 2. Focus Intelligence
  v_focus_intel := get_focus_intelligence(p_student_id);

  -- 3. REAL TREND ENGINE
  v_prev_trust := (SELECT overall_score FROM trust_score_history
                    WHERE student_id = p_student_id AND source != 'dna_engine'
                    ORDER BY recorded_at DESC LIMIT 1 OFFSET 1);
  v_overall_trend := CASE
    WHEN v_prev_trust IS NULL THEN 'Insufficient Data'
    WHEN v_trust.overall_score > v_prev_trust THEN 'up'
    WHEN v_trust.overall_score < v_prev_trust THEN 'down'
    ELSE 'stable'
  END;

  -- 4. Dynamic Focus Goal
  v_focus_goal := COALESCE(60 + (jsonb_array_length(v_dna.skill_gaps) * 30), 120);

  -- 5. Daily Summary
  v_summary := jsonb_build_object(
    'trust_score', COALESCE(v_trust.overall_score, 0),
    'career_readiness', COALESCE(v_dna.placement_score, 0),
    'focus_score', COALESCE(v_dna.focus_score, 0),
    'productivity_score', COALESCE(v_dna.productivity_score, 0),
    'streak', COALESCE(v_dna.study_streak, 0),
    'trend', v_overall_trend
  );

  -- 6. Academic Snapshot (M18 Task 7)
  v_academic := jsonb_build_object(
    'synced', v_profile.erp_synced,
    'attendance', COALESCE(v_trust.erp_attendance_pct, 0),
    'cgpa', COALESCE(v_profile.cgpa, 0),
    'progress', COALESCE(v_profile.erp_course_progress, 0),
    'credits', COALESCE(v_profile.erp_credits_completed, 0),
    'backlogs', COALESCE(v_profile.erp_backlogs, 0),
    'reliability', COALESCE(v_trust.academic_reliability_score, 0),
    'consistency', COALESCE(v_trust.academic_consistency_score, 0),
    'last_sync', v_trust.erp_synced_at
  );

  -- 7. TOP ACTION ENGINE
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

  IF v_top_action IS NULL AND v_dna.roadmap IS NOT NULL AND jsonb_array_length(v_dna.roadmap) > 0 THEN
    v_top_action := jsonb_build_object(
      'label', 'Next Milestone: ' || (v_dna.roadmap->0->>'step'),
      'action', '/career_predictor',
      'priority', 'medium'
    );
  END IF;

  -- 8. Real Portfolio Aggregation
  SELECT COUNT(*) INTO v_project_count FROM student_projects WHERE student_id = p_student_id;
  SELECT COUNT(*) INTO v_skill_count FROM student_skills WHERE student_id = p_student_id AND is_verified = TRUE;
  v_portfolio_score := LEAST(100, (v_project_count * 20) + (v_skill_count * 5));

  -- 9. Hub Data
  SELECT jsonb_build_object(
    'id', o.id,
    'title', o.title,
    'match', ROUND(ro.match_score + ro.urgency_boost),
    'reason', ro.match_reason
  )
  INTO v_opp FROM opportunities o
  JOIN get_ranked_opportunities(p_student_id) ro ON ro.opportunity_id = o.id
  WHERE ro.eligibility_match = TRUE
  ORDER BY ro.match_score + ro.urgency_boost DESC LIMIT 1;

  v_focus := jsonb_build_object(
    'today_minutes', COALESCE(v_dna.daily_focus_minutes, 0),
    'risk_level', v_focus_intel->>'risk_level',
    'intervention', v_focus_intel->>'intervention',
    'recommended_session', v_focus_intel->>'next_recommended_session',
    'goal_minutes', v_focus_goal
  );

  -- 10. Smart Nudges
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
    'career_center', jsonb_build_object(
       'score', COALESCE(v_dna.placement_score, 0),
       'top_gap', COALESCE(v_dna.skill_gaps->0->>'skill', 'None Identified'),
       'projection_90d', v_dna.readiness_projection_90d
    ),
    'network_hub', jsonb_build_object('invites', (SELECT COUNT(*) FROM team_members WHERE student_id = p_student_id AND status = 'invited')),
    'focus_center', v_focus,
    'scam_center', jsonb_build_object('count', (SELECT COUNT(*) FROM scam_reports WHERE created_at > NOW() - INTERVAL '7 days')),
    'portfolio_center', jsonb_build_object(
       'completion', v_portfolio_score,
       'project_count', v_project_count,
       'verified_skills', v_skill_count
    ),
    'nudges', COALESCE(v_nudges, '[]'::jsonb),
    'archetype', v_dna.archetype,
    'academic_snapshot', v_academic
  );
END;
$$;
