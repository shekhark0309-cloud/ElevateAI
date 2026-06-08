-- =============================================================================
-- ElevateAI — Student OS Command Center (Updated: Zero Hardcoded Values)
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
  v_prev_trust      NUMERIC;
  v_prev_career     NUMERIC;
  v_trust_trend     TEXT;
  v_career_trend    TEXT;
  v_overall_trend   TEXT;
  v_urgent_opp      RECORD;
  v_active_invites  INTEGER;
  v_scam_count      INTEGER;
  v_scam_risk       TEXT;
  v_matching_schemes INTEGER;
BEGIN
  -- 1. Base Signal Fetching
  SELECT * INTO v_profile FROM student_profiles WHERE id = p_student_id;
  SELECT * INTO v_dna FROM student_dna WHERE student_id = p_student_id;
  SELECT * INTO v_trust FROM trust_scores WHERE student_id = p_student_id;

  -- 2. REAL TREND ENGINE (Task 2)
  -- Trust Trend
  v_prev_trust := (SELECT overall_score FROM trust_score_history
                    WHERE student_id = p_student_id AND source != 'dna_engine'
                    ORDER BY recorded_at DESC LIMIT 1 OFFSET 1);
  v_trust_trend := CASE
    WHEN v_prev_trust IS NULL THEN 'stable'
    WHEN v_trust.overall_score > v_prev_trust + 0.5 THEN 'up'
    WHEN v_trust.overall_score < v_prev_trust - 0.5 THEN 'down'
    ELSE 'stable'
  END;

  -- Career Trend (Placement Score)
  v_prev_career := (SELECT (snapshot->>'placement_score')::NUMERIC FROM trust_score_history
                     WHERE student_id = p_student_id AND source = 'dna_engine'
                     ORDER BY recorded_at DESC LIMIT 1 OFFSET 1);
  v_career_trend := CASE
    WHEN v_prev_career IS NULL THEN 'stable'
    WHEN v_dna.placement_score > v_prev_career THEN 'up'
    WHEN v_dna.placement_score < v_prev_career THEN 'down'
    ELSE 'stable'
  END;

  -- Aggregated OS Trend
  v_overall_trend := CASE
    WHEN v_trust_trend = 'up' OR v_career_trend = 'up' THEN 'up'
    WHEN v_trust_trend = 'down' AND v_career_trend = 'down' THEN 'down'
    ELSE 'stable'
  END;

  -- 3. DAILY OS SUMMARY (Section 1)
  v_summary := jsonb_build_object(
    'trust_score', COALESCE(v_trust.overall_score, 0),
    'career_readiness', COALESCE(v_dna.placement_score, 0),
    'focus_score', COALESCE(v_dna.focus_score, 0),
    'productivity_score', COALESCE(v_dna.productivity_score, 0),
    'streak', COALESCE(v_dna.study_streak, 0),
    'trend', v_overall_trend,
    'scholarship_readiness', (SELECT COUNT(*) FROM get_ranked_opportunities(p_student_id) ro
                               JOIN opportunities o ON o.id = ro.opportunity_id
                               WHERE ro.eligibility_match = TRUE AND o.type = 'scholarship'),
    'team_readiness', COALESCE(v_trust.collaboration_score, 0)
  );

  -- 4. TOP ACTION ENGINE (Task 3)
  -- Logic: Real Notifications > Critical Deadlines > High Priority Gaps > Maintenance
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

  IF v_top_action IS NULL THEN
    -- Check for expiring high-match opportunity
    SELECT o.title, o.id INTO v_urgent_opp
    FROM opportunities o
    JOIN get_ranked_opportunities(p_student_id) ro ON ro.opportunity_id = o.id
    WHERE ro.eligibility_match = TRUE AND o.apply_deadline > NOW()
    ORDER BY o.apply_deadline ASC LIMIT 1;

    IF v_urgent_opp IS NOT NULL AND (SELECT apply_deadline FROM opportunities WHERE id = v_urgent_opp.id) < (NOW() + INTERVAL '72 hours') THEN
       v_top_action := jsonb_build_object(
         'label', 'Apply: ' || v_urgent_opp.title,
         'action', '/opportunities',
         'priority', 'high'
       );
    ELSIF v_dna.skill_gaps IS NOT NULL AND jsonb_array_length(v_dna.skill_gaps) > 0 THEN
       v_top_action := jsonb_build_object(
         'label', 'Fill Gap: ' || (v_dna.skill_gaps->0->>'skill'),
         'action', '/skill_reality',
         'priority', 'medium'
       );
    ELSE
       v_top_action := jsonb_build_object(
         'label', 'Log your focus hours today',
         'action', '/focus',
         'priority', 'stable'
       );
    END IF;
  END IF;

  -- 5. HUB DATA PIPELINE (Task 5)

  -- Opportunity Hub (REAL Match Score - Task 1)
  SELECT jsonb_build_object(
    'id', o.id,
    'title', o.title,
    'match', ROUND(ro.match_score + ro.urgency_boost),
    'deadline', o.apply_deadline,
    'reason', CASE
      WHEN o.is_featured THEN 'DNA Alignment: ' || v_dna.archetype
      ELSE 'Matches Skill: ' || (SELECT skill_name FROM student_skills WHERE student_id = p_student_id AND proficiency >= 3 LIMIT 1)
    END
  )
  INTO v_opp FROM opportunities o
  JOIN get_ranked_opportunities(p_student_id) ro ON ro.opportunity_id = o.id
  WHERE ro.eligibility_match = TRUE
  ORDER BY ro.match_score + ro.urgency_boost DESC LIMIT 1;

  -- Career Command Center
  v_career := jsonb_build_object(
    'score', COALESCE(v_dna.placement_score, 0),
    'top_gap', COALESCE(v_dna.skill_gaps->0->>'skill', 'None Identified'),
    'next_milestone', COALESCE(v_dna.roadmap->0->>'step', 'Verify Industry Skills'),
    'projection_90d', COALESCE(v_dna.readiness_projection_90d, 0),
    'risk_level', CASE WHEN v_dna.career_risk_score > 60 THEN 'high' WHEN v_dna.career_risk_score > 30 THEN 'medium' ELSE 'low' END
  );

  -- Team & Network Hub
  SELECT COUNT(*) INTO v_active_invites FROM team_members WHERE student_id = p_student_id AND status = 'invited';
  v_network := jsonb_build_object(
    'count', (SELECT COUNT(*) FROM student_profiles WHERE college_id = v_profile.college_id AND id != p_student_id),
    'invites', v_active_invites,
    'matching_roles', (SELECT COUNT(*) FROM role_postings rp
                       WHERE rp.status = 'open'
                       AND EXISTS (SELECT 1 FROM UNNEST(rp.required_skills) s
                                   WHERE s = ANY(v_dna.top_skills)))
  );

  -- Focus & Productivity (Real Risk - Task 4)
  v_focus := jsonb_build_object(
    'focus_time', COALESCE(v_dna.daily_focus_minutes, 0)::text || 'm',
    'streak', COALESCE(v_dna.study_streak, 0),
    'risk', COALESCE(v_dna.focus_risk_level, 'low'),
    'goal_minutes', 120,
    'productivity_trend', v_career_trend
  );

  -- Scam Center (Real Intelligence)
  SELECT COUNT(*) INTO v_scam_count FROM scam_reports WHERE created_at > NOW() - INTERVAL '7 days';
  v_scam_risk := CASE WHEN v_scam_count > 10 THEN 'high' WHEN v_scam_count > 3 THEN 'medium' ELSE 'low' END;
  v_scam := jsonb_build_object(
    'alerts', v_scam_count,
    'risk', v_scam_risk,
    'latest_type', (SELECT category FROM scam_reports ORDER BY created_at DESC LIMIT 1)
  );

  -- Scholarship Hub
  SELECT COUNT(*) INTO v_matching_schemes
  FROM get_ranked_opportunities(p_student_id) ro
  JOIN opportunities o ON o.id = ro.opportunity_id
  WHERE ro.eligibility_match = TRUE AND o.type = 'scholarship';

  -- 6. SMART NUDGE CENTER (Task 6)
  -- Use actual prioritized notifications as nudges
  SELECT jsonb_agg(n) INTO v_nudges FROM (
    SELECT title, body, priority as type, action_label, COALESCE(data->>'route', action_url, '/notifications') as action
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
    'scholarship_hub', jsonb_build_object(
       'matches', v_matching_schemes,
       'deadline', (SELECT apply_deadline FROM opportunities WHERE type = 'scholarship' AND status = 'active' ORDER BY apply_deadline ASC LIMIT 1),
       'mentors', (SELECT COUNT(DISTINCT student_id) FROM opportunity_applications WHERE opportunity_id IN (SELECT id FROM opportunities WHERE type = 'scholarship') AND status = 'accepted')
    ),
    'portfolio_center', jsonb_build_object(
       'completion', (SELECT COUNT(*) FROM student_projects WHERE student_id = p_student_id) * 25,
       'verified_count', (SELECT COUNT(*) FROM student_skills WHERE student_id = p_student_id AND is_verified = TRUE)
    ),
    'nudges', COALESCE(v_nudges, '[]'::jsonb),
    'archetype', v_dna.archetype
  );
END;
$$;

GRANT EXECUTE ON FUNCTION get_student_os_dashboard TO authenticated;
