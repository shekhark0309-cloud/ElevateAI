-- =============================================================================
-- ElevateAI — Student OS Command Center (Updated: Removed Mocks)
-- File: migrations/27_student_os_dashboard.sql
-- =============================================================================

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
  v_urgent_opp   RECORD;
  v_next_badge   TEXT;
BEGIN
  -- 1. Base Signal Fetching
  SELECT * INTO v_profile FROM student_profiles WHERE id = p_student_id;
  SELECT * INTO v_dna FROM student_dna WHERE student_id = p_student_id;
  SELECT * INTO v_trust FROM trust_scores WHERE student_id = p_student_id;

  -- 2. Real Trend Calculation (Based on history)
  v_prev_score := (SELECT overall_score FROM trust_score_history
                   WHERE student_id = p_student_id
                   ORDER BY recorded_at DESC LIMIT 1 OFFSET 1);
  v_trend := CASE
    WHEN v_prev_score IS NULL THEN 'stable'
    WHEN v_trust.overall_score > v_prev_score THEN 'up'
    WHEN v_trust.overall_score < v_prev_score THEN 'down'
    ELSE 'stable'
  END;

  -- 3. Daily Summary (Section 1)
  v_summary := jsonb_build_object(
    'trust_score', COALESCE(v_trust.overall_score, 0),
    'career_readiness', COALESCE(v_dna.placement_score, 0),
    'focus_score', COALESCE(v_dna.focus_score, 0),
    'productivity_score', COALESCE(v_dna.productivity_score, 0),
    'streak', COALESCE(v_dna.study_streak, 0),
    'trend', v_trend,
    'scholarship_readiness', (SELECT COUNT(*) FILTER (WHERE eligibility_match = TRUE) * 10
                              FROM get_ranked_opportunities(p_student_id) ro
                              JOIN opportunities o ON o.id = ro.opportunity_id
                              WHERE o.type = 'scholarship'),
    'team_readiness', COALESCE(v_trust.collaboration_score, 0)
  );

  -- 4. Today's Most Important Action (Section 2)
  -- Priority logic: Notifications > Critical Deadlines > Profile Gaps
  v_top_action := (
    SELECT jsonb_build_object('label', title, 'action', COALESCE(data->>'route', '/notifications'), 'priority', priority)
    FROM notifications
    WHERE student_id = p_student_id AND is_read = FALSE
    ORDER BY urgency DESC, created_at DESC LIMIT 1
  );

  IF v_top_action IS NULL THEN
    -- Fallback 1: Expiring Opportunity
    SELECT o.title, o.id INTO v_urgent_opp
    FROM opportunities o
    JOIN get_ranked_opportunities(p_student_id) ro ON ro.opportunity_id = o.id
    WHERE ro.eligibility_match = TRUE AND o.apply_deadline > NOW()
    ORDER BY o.apply_deadline ASC LIMIT 1;

    IF v_urgent_opp IS NOT NULL THEN
       v_top_action := jsonb_build_object(
         'label', 'Apply for ' || v_urgent_opp.title,
         'action', '/opportunities',
         'priority', 'high'
       );
    ELSIF v_trust.overall_score < 60 THEN
       v_top_action := jsonb_build_object(
         'label', 'Boost your TrustScore: Verify a new skill',
         'action', '/skill_reality',
         'priority', 'medium'
       );
    ELSE
       v_top_action := jsonb_build_object(
         'label', 'Start your daily focus session',
         'action', '/focus',
         'priority', 'stable'
       );
    END IF;
  END IF;

  -- 5. Hub Data Fetching (Real Data)
  -- Opportunity Hub (Top Match)
  SELECT jsonb_build_object(
    'id', o.id,
    'title', o.title,
    'match', ROUND(ro.match_score + ro.urgency_boost),
    'deadline', o.apply_deadline,
    'reason', CASE WHEN o.is_featured THEN 'Curated for your archetype' ELSE 'Matches your skill verification' END
  )
  INTO v_opp FROM opportunities o
  JOIN get_ranked_opportunities(p_student_id) ro ON ro.opportunity_id = o.id
  WHERE ro.eligibility_match = TRUE
  ORDER BY ro.match_score + ro.urgency_boost DESC LIMIT 1;

  -- Career Center
  SELECT name INTO v_next_badge FROM skill_badges
  WHERE id NOT IN (SELECT badge_id FROM student_badges WHERE student_id = p_student_id)
  ORDER BY level ASC LIMIT 1;

  v_career := jsonb_build_object(
    'score', COALESCE(v_dna.placement_score, 0),
    'top_gap', (SELECT skill_name FROM student_skills WHERE student_id = p_student_id ORDER BY proficiency ASC LIMIT 1),
    'next_milestone', COALESCE(v_next_badge, 'Portfolio refinement'),
    'projection_90d', COALESCE(v_dna.readiness_projection_90d, 0)
  );

  -- Team & Network
  v_network := jsonb_build_object(
    'count', (SELECT COUNT(*) FROM student_profiles WHERE college_id = v_profile.college_id AND id != p_student_id),
    'invites', (SELECT COUNT(*) FROM team_members WHERE student_id = p_student_id AND status = 'invited')
  );

  -- Focus & Productivity
  v_focus := jsonb_build_object(
    'focus_time', COALESCE(v_dna.daily_focus_minutes, 0)::text || 'm',
    'streak', COALESCE(v_dna.study_streak, 0),
    'risk', COALESCE(v_dna.focus_risk_level, 'low'),
    'goal_minutes', 120
  );

  -- Scam Center
  v_scam := (
    SELECT jsonb_build_object(
      'alerts', COUNT(*),
      'risk', CASE WHEN COUNT(*) > 5 THEN 'high' WHEN COUNT(*) > 2 THEN 'medium' ELSE 'low' END
    )
    FROM scam_reports WHERE created_at > NOW() - INTERVAL '7 days'
  );

  -- Portfolio Center
  v_portfolio := jsonb_build_object(
    'completion', CASE WHEN (SELECT COUNT(*) FROM student_projects WHERE student_id = p_student_id) > 2 THEN 100 ELSE 60 END,
    'verified_count', (SELECT COUNT(*) FROM student_skills WHERE student_id = p_student_id AND is_verified = TRUE)
  );

  -- 6. Consolidated Nudges
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
    'network_hub', v_network,
    'focus_center', v_focus,
    'scam_center', v_scam,
    'portfolio_center', v_portfolio,
    'nudges', COALESCE(v_nudges, '[]'::jsonb),
    'archetype', v_dna.archetype
  );
END;
$$;

GRANT EXECUTE ON FUNCTION get_student_os_dashboard TO authenticated;
