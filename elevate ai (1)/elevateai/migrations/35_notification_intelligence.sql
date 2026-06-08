-- =============================================================================
-- ElevateAI — Notification Intelligence Engine (M18 Task 1-12)
-- File: migrations/35_notification_intelligence.sql
-- =============================================================================

-- 1. Extend Notifications with Category
ALTER TABLE notifications
  ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'general', -- general | academic | career | safety | social | focus
  ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;

-- 2. Enhanced Priority Alerts Engine
-- Returns a list of high-priority actions for the student.
CREATE OR REPLACE FUNCTION get_priority_alerts(p_student_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile         RECORD;
  v_dna             RECORD;
  v_trust           RECORD;
  v_focus_intel     JSONB;
  v_alerts          JSONB := '[]'::JSONB;
  v_item            RECORD;
BEGIN
  -- Load Profile/DNA
  SELECT * INTO v_profile FROM student_profiles WHERE id = p_student_id;
  SELECT * INTO v_dna FROM student_dna WHERE student_id = p_student_id;
  SELECT * INTO v_trust FROM trust_scores WHERE student_id = p_student_id;

  -- 1. Scam Alerts
  FOR v_item IN
    SELECT title, id FROM notifications
    WHERE student_id = p_student_id AND type = 'scam_alert' AND is_read = FALSE
    LIMIT 2
  LOOP
    v_alerts := v_alerts || jsonb_build_object(
      'type', 'scam_alert',
      'title', 'Scam Alert: ' || v_item.title,
      'priority', 'critical',
      'action_label', 'Shield Now',
      'action_url', '/scam_shield',
      'reason', 'A potential fraud targeting students was detected.'
    );
  END LOOP;

  -- 2. Deadlines
  FOR v_item IN
    SELECT o.title, o.id FROM opportunities o
    JOIN opportunity_applications oa ON oa.opportunity_id = o.id
    WHERE oa.student_id = p_student_id AND oa.status = 'draft'
      AND o.apply_deadline BETWEEN NOW() AND (NOW() + INTERVAL '48 hours')
    LIMIT 2
  LOOP
    v_alerts := v_alerts || jsonb_build_object(
      'type', 'deadline',
      'title', 'Deadline: ' || v_item.title,
      'priority', 'critical',
      'action_label', 'Complete App',
      'action_url', '/opportunities',
      'reason', 'Application window closing soon.'
    );
  END LOOP;

  -- 3. Focus Recovery
  v_focus_intel := get_focus_intelligence(p_student_id);
  IF (v_focus_intel->>'risk_level') IN ('high', 'critical') THEN
    v_alerts := v_alerts || jsonb_build_object(
      'type', 'focus_recovery',
      'title', 'Restore Streak: ' || (v_focus_intel->>'intervention'),
      'priority', 'high',
      'action_label', 'Focus Now',
      'action_url', '/focus',
      'reason', 'Consistency is key to maintaining your TrustScore tier.'
    );
  END IF;

  -- 4. ERP Sync
  IF NOT v_profile.erp_synced THEN
    v_alerts := v_alerts || jsonb_build_object(
      'type', 'erp_sync',
      'title', 'Link College Records',
      'priority', 'high',
      'action_label', 'Sync Now',
      'action_url', '/profile',
      'reason', 'Unlock verified CGPA and TrustScore boost.'
    );
  END IF;

  -- 5. Skill Gaps
  IF jsonb_array_length(v_dna.skill_gaps) > 0 THEN
    v_alerts := v_alerts || jsonb_build_object(
      'type', 'skill_gap',
      'title', 'Target Skill: ' || (v_dna.skill_gaps->0->>'skill'),
      'priority', 'medium',
      'action_label', 'View Roadmap',
      'action_url', '/career_predictor',
      'reason', 'Closing this gap unlocks 3+ top-tier matches.'
    );
  END IF;

  RETURN v_alerts;
END;
$$;

-- 3. Top Action Wrapper (Single object for UI)
CREATE OR REPLACE FUNCTION get_top_action_engine(p_student_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_alerts JSONB;
  v_first  JSONB;
BEGIN
  v_alerts := get_priority_alerts(p_student_id);
  IF jsonb_array_length(v_alerts) > 0 THEN
    v_first := v_alerts->0;
    RETURN jsonb_build_object(
      'label', v_first->>'title',
      'action', v_first->>'action_url',
      'priority', v_first->>'priority',
      'reason', v_first->>'reason'
    );
  END IF;
  RETURN NULL;
END;
$$;

-- Alias for backward compatibility with M4
CREATE OR REPLACE FUNCTION get_focus_ai_priorities(p_student_id UUID)
RETURNS JSONB AS $$ BEGIN RETURN get_priority_alerts(p_student_id); END; $$ LANGUAGE plpgsql;

-- 3. Update Dashboard to use Top Action Engine
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
  v_focus           JSONB;
  v_nudges          JSONB;
  v_focus_intel     JSONB;
  v_prev_trust      NUMERIC;
  v_overall_trend   TEXT;
  v_project_count   INTEGER;
  v_skill_count     INTEGER;
  v_portfolio_score INTEGER;
  v_focus_goal      INTEGER;
  v_academic        JSONB;
  v_resume          JSONB;
BEGIN
  -- 1. Base Signal Fetching
  SELECT * INTO v_profile FROM student_profiles WHERE id = p_student_id;
  SELECT * INTO v_dna FROM student_dna WHERE student_id = p_student_id;
  SELECT * INTO v_trust FROM trust_scores WHERE student_id = p_student_id;

  -- 2. Intelligence
  v_focus_intel := get_focus_intelligence(p_student_id);
  v_top_action := get_top_action_engine(p_student_id);

  -- 3. Trend Engine
  v_prev_trust := (SELECT overall_score FROM trust_score_history
                    WHERE student_id = p_student_id AND source != 'dna_engine'
                    ORDER BY recorded_at DESC LIMIT 1 OFFSET 1);
  v_overall_trend := CASE
    WHEN v_prev_trust IS NULL THEN 'Insufficient Data'
    WHEN v_trust.overall_score > v_prev_trust THEN 'up'
    WHEN v_trust.overall_score < v_prev_trust THEN 'down'
    ELSE 'stable'
  END;

  -- 4. Focus Metrics
  v_focus_goal := COALESCE(60 + (jsonb_array_length(v_dna.skill_gaps) * 30), 120);

  -- 5. Daily Summary
  v_summary := jsonb_build_object(
    'trust_score', COALESCE(v_trust.overall_score, 0),
    'career_readiness', COALESCE(v_dna.placement_score, 0),
    'focus_score', COALESCE(v_dna.focus_score, 0),
    'productivity_score', COALESCE(v_dna.productivity_score, 0),
    'streak', COALESCE(v_dna.study_streak, 0),
    'trend', v_overall_trend,
    'top_signal', CASE
      WHEN v_trust.reliability_score > 80 THEN 'High Reliability'
      WHEN v_trust.collaboration_score > 80 THEN 'Elite Collaborator'
      WHEN v_trust.skill_validation_score > 80 THEN 'Skill Champion'
      ELSE 'Building Trust'
    END,
    'risk_signal', CASE
      WHEN v_profile.erp_backlogs > 0 THEN 'Academic Backlog'
      WHEN v_trust.reliability_score < 40 THEN 'Inconsistency'
      WHEN v_dna.focus_risk_level = 'high' THEN 'Focus Dropout'
      ELSE NULL
    END
  );

  -- 6. Academic Snapshot
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

  -- 7. Portfolio & Resume
  SELECT COUNT(*) INTO v_project_count FROM student_projects WHERE student_id = p_student_id;
  SELECT COUNT(*) INTO v_skill_count FROM student_skills WHERE student_id = p_student_id AND is_verified = TRUE;
  v_portfolio_score := LEAST(100, (v_project_count * 20) + (v_skill_count * 5));

  v_resume := (
    SELECT jsonb_build_object(
      'pdf_url', pdf_url,
      'created_at', created_at,
      'version', version,
      'template', meta->>'template'
    )
    FROM resume_history
    WHERE student_id = p_student_id
    ORDER BY created_at DESC LIMIT 1
  );

  -- 8. Opportunity Hub
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

  -- 9. Smart Nudges (Urgent Notifications)
  SELECT jsonb_agg(n) INTO v_nudges FROM (
    SELECT title, body, priority as type, action_label, action_url as action, category
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
    'focus_center', jsonb_build_object(
        'today_minutes', COALESCE(v_dna.daily_focus_minutes, 0),
        'risk_level', v_focus_intel->>'risk_level',
        'intervention', v_focus_intel->>'intervention',
        'goal_minutes', v_focus_goal
    ),
    'portfolio_center', jsonb_build_object(
       'completion', v_portfolio_score,
       'project_count', v_project_count,
       'verified_skills', v_skill_count,
       'latest_resume', v_resume
    ),
    'academic_snapshot', v_academic,
    'nudges', COALESCE(v_nudges, '[]'::jsonb),
    'archetype', v_dna.archetype
  );
END;
$$;

-- 4. Trigger: Generate Notification for Reliability Milestones
CREATE OR REPLACE FUNCTION notify_reliability_milestone()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.reliability_score >= 80 AND (OLD.reliability_score < 80 OR OLD.reliability_score IS NULL) THEN
    INSERT INTO notifications (student_id, type, title, body, priority, urgency, category)
    VALUES (
      NEW.student_id,
      'reliability_milestone',
      '💎 Reliability Milestone!',
      'Your institutional reliability has reached 80%+. You are now prioritized for high-trust team matching.',
      'high',
      8,
      'academic'
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER on_reliability_milestone
  AFTER UPDATE OF reliability_score ON trust_scores
  FOR EACH ROW
  EXECUTE FUNCTION notify_reliability_milestone();

GRANT EXECUTE ON FUNCTION get_top_action_engine TO authenticated;
GRANT EXECUTE ON FUNCTION get_priority_alerts TO authenticated;
GRANT EXECUTE ON FUNCTION get_focus_ai_priorities TO authenticated;
