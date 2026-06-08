-- =============================================================================
-- ElevateAI — M12: Campus Intelligence & Dashboard Integration
-- File: migrations/32_campus_intelligence.sql
-- =============================================================================

-- 1. Function to get nearby study buddies with counts
CREATE OR REPLACE FUNCTION get_nearby_buddy_stats(p_college_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_online INTEGER;
  v_top_subject TEXT;
BEGIN
  SELECT COUNT(*) INTO v_total_online
  FROM student_profiles
  WHERE college_id = p_college_id
    AND is_study_buddy_mode = TRUE
    AND updated_at > NOW() - INTERVAL '30 minutes';

  SELECT current_study_subject INTO v_top_subject
  FROM student_profiles
  WHERE college_id = p_college_id
    AND is_study_buddy_mode = TRUE
    AND current_study_subject IS NOT NULL
  GROUP BY current_study_subject
  ORDER BY COUNT(*) DESC
  LIMIT 1;

  RETURN jsonb_build_object(
    'online_count', COALESCE(v_total_online, 0),
    'trending_subject', COALESCE(v_top_subject, 'General Study')
  );
END;
$$;

-- 2. Function to recommend resources based on DNA and Focus
CREATE OR REPLACE FUNCTION get_resource_recommendation(p_student_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_dna RECORD;
  v_rec_type TEXT;
  v_resource RECORD;
BEGIN
  SELECT archetype INTO v_dna FROM student_dna WHERE student_id = p_student_id;

  v_rec_type := CASE
    WHEN v_dna.archetype = 'Builder' THEN 'lab_equipment'
    WHEN v_dna.archetype = 'Researcher' THEN 'library_seat'
    WHEN v_dna.archetype = 'Creative' THEN 'classroom'
    ELSE 'library_seat'
  END;

  SELECT * INTO v_resource
  FROM campus_resources
  WHERE resource_type = v_rec_type
    AND is_available = TRUE
  ORDER BY capacity DESC
  LIMIT 1;

  IF v_resource.id IS NULL THEN
    SELECT * INTO v_resource FROM campus_resources WHERE is_available = TRUE LIMIT 1;
  END IF;

  RETURN jsonb_build_object(
    'id', v_resource.id,
    'name', v_resource.name,
    'location', v_resource.location_label,
    'type', v_resource.resource_type,
    'reason', CASE
      WHEN v_dna.archetype = 'Builder' THEN 'Matches your Builder DNA'
      ELSE 'Quiet space for focus'
    END
  );
END;
$$;

-- 3. Update get_student_os_dashboard to include real Campus Intelligence
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
  v_campus_buddy    JSONB;
  v_resource_rec    JSONB;
BEGIN
  -- 1. Base Signal Fetching
  SELECT * INTO v_profile FROM student_profiles WHERE id = p_student_id;
  SELECT * INTO v_dna FROM student_dna WHERE student_id = p_student_id;
  SELECT * INTO v_trust FROM trust_scores WHERE student_id = p_student_id;

  -- 2. REAL TREND ENGINE
  v_prev_trust := (SELECT overall_score FROM trust_score_history
                    WHERE student_id = p_student_id AND source != 'dna_engine'
                    ORDER BY recorded_at DESC LIMIT 1 OFFSET 1);
  v_trust_trend := CASE
    WHEN v_prev_trust IS NULL THEN 'stable'
    WHEN v_trust.overall_score > v_prev_trust + 0.5 THEN 'up'
    WHEN v_trust.overall_score < v_prev_trust - 0.5 THEN 'down'
    ELSE 'stable'
  END;

  v_prev_career := (SELECT (snapshot->>'placement_score')::NUMERIC FROM trust_score_history
                     WHERE student_id = p_student_id AND source = 'dna_engine'
                     ORDER BY recorded_at DESC LIMIT 1 OFFSET 1);
  v_career_trend := CASE
    WHEN v_prev_career IS NULL THEN 'stable'
    WHEN v_dna.placement_score > v_prev_career THEN 'up'
    WHEN v_dna.placement_score < v_prev_career THEN 'down'
    ELSE 'stable'
  END;

  v_overall_trend := CASE
    WHEN v_trust_trend = 'up' OR v_career_trend = 'up' THEN 'up'
    WHEN v_trust_trend = 'down' AND v_career_trend = 'down' THEN 'down'
    ELSE 'stable'
  END;

  -- 3. DAILY OS SUMMARY
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

  -- 4. TOP ACTION ENGINE
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
    SELECT o.title, o.id INTO v_urgent_opp
    FROM opportunities o
    JOIN get_ranked_opportunities(p_student_id) ro ON ro.opportunity_id = o.id
    WHERE ro.eligibility_match = TRUE AND o.apply_deadline > NOW()
    ORDER BY o.apply_deadline ASC LIMIT 1;

    IF v_urgent_opp IS NOT NULL AND (SELECT apply_deadline FROM opportunities WHERE id = v_urgent_opp.id) < (NOW() + INTERVAL '72 hours') THEN
       v_top_action := jsonb_build_object('label', 'Apply: ' || v_urgent_opp.title, 'action', '/opportunities', 'priority', 'high');
    ELSIF v_dna.skill_gaps IS NOT NULL AND jsonb_array_length(v_dna.skill_gaps) > 0 THEN
       v_top_action := jsonb_build_object('label', 'Fill Gap: ' || (v_dna.skill_gaps->0->>'skill'), 'action', '/skill_reality', 'priority', 'medium');
    ELSE
       v_top_action := jsonb_build_object('label', 'Log your focus hours today', 'action', '/focus', 'priority', 'stable');
    END IF;
  END IF;

  -- 5. CAMPUS INTELLIGENCE (Task 10)
  v_campus_buddy := get_nearby_buddy_stats(v_profile.college_id);
  v_resource_rec := get_resource_recommendation(p_student_id);

  -- 6. HUB DATA PIPELINE

  -- Opportunity Hub
  SELECT jsonb_build_object(
    'id', o.id,
    'title', o.title,
    'match', ROUND(ro.match_score + ro.urgency_boost),
    'deadline', o.apply_deadline,
    'reason', ro.match_reason
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

  -- Focus & Productivity
  v_focus := jsonb_build_object(
    'today_minutes', COALESCE(v_dna.daily_focus_minutes, 0),
    'risk_level', COALESCE(v_dna.focus_risk_level, 'low'),
    'goal_minutes', 120
  );

  -- Scholarship Hub
  SELECT COUNT(*) INTO v_matching_schemes
  FROM get_ranked_opportunities(p_student_id) ro
  JOIN opportunities o ON o.id = ro.opportunity_id
  WHERE ro.eligibility_match = TRUE AND o.type = 'scholarship';

  RETURN jsonb_build_object(
    'summary', v_summary,
    'top_action', v_top_action,
    'opportunity_hub', v_opp,
    'career_center', v_career,
    'network_hub', jsonb_build_object(
       'invites', (SELECT COUNT(*) FROM team_members WHERE student_id = p_student_id AND status = 'invited'),
       'nearby_buddies', v_campus_buddy->>'online_count',
       'trending_subject', v_campus_buddy->>'trending_subject'
    ),
    'focus_center', v_focus,
    'campus_hub', jsonb_build_object(
       'labs', (SELECT COUNT(*) FROM campus_resources WHERE college_id = v_profile.college_id AND resource_type = 'lab_equipment' AND is_available = TRUE),
       'spaces', (SELECT COUNT(*) FROM campus_resources WHERE college_id = v_profile.college_id AND resource_type = 'library_seat' AND is_available = TRUE),
       'recommendation', v_resource_rec,
       'current_booking', (SELECT row_to_json(b) FROM (SELECT r.name, rb.booked_until FROM resource_bookings rb JOIN campus_resources r ON r.id = rb.resource_id WHERE rb.student_id = p_student_id AND rb.status = 'active' AND rb.booked_until > NOW() ORDER BY rb.booked_from ASC LIMIT 1) b)
    ),
    'scam_center', jsonb_build_object('count', (SELECT COUNT(*) FROM scam_reports WHERE created_at > NOW() - INTERVAL '7 days')),
    'scholarship_hub', jsonb_build_object(
       'matches', v_matching_schemes,
       'deadline', (SELECT apply_deadline FROM opportunities WHERE type = 'scholarship' AND status = 'active' ORDER BY apply_deadline ASC LIMIT 1),
       'mentors', (SELECT COUNT(DISTINCT student_id) FROM opportunity_applications WHERE opportunity_id IN (SELECT id FROM opportunities WHERE type = 'scholarship') AND status = 'accepted')
    ),
    'portfolio_center', jsonb_build_object(
       'completion', (SELECT COUNT(*) FROM student_projects WHERE student_id = p_student_id) * 25,
       'verified_count', (SELECT COUNT(*) FROM student_skills WHERE student_id = p_student_id AND is_verified = TRUE)
    ),
    'nudges', (SELECT jsonb_agg(n) FROM (SELECT title, body, priority as type, action_label, COALESCE(data->>'route', action_url, '/notifications') as action FROM notifications WHERE student_id = p_student_id AND is_read = FALSE ORDER BY urgency DESC LIMIT 5) n),
    'archetype', v_dna.archetype
  );
END;
$$;

GRANT EXECUTE ON FUNCTION get_nearby_buddy_stats TO authenticated;
GRANT EXECUTE ON FUNCTION get_resource_recommendation TO authenticated;
GRANT EXECUTE ON FUNCTION get_student_os_dashboard TO authenticated;
