-- =============================================================================
-- ElevateAI — M4: FocusAI Notifications (Updated with Intelligence)
-- File: migrations/24_focus_ai_notifications.sql
-- =============================================================================

-- 1. Upgrade Notifications Table
ALTER TABLE notifications
  ADD COLUMN IF NOT EXISTS priority     TEXT DEFAULT 'medium', -- low | medium | high | critical
  ADD COLUMN IF NOT EXISTS urgency      INTEGER DEFAULT 5,     -- 1-10 (10 being most urgent)
  ADD COLUMN IF NOT EXISTS action_label TEXT,
  ADD COLUMN IF NOT EXISTS action_url   TEXT,
  ADD COLUMN IF NOT EXISTS is_actioned  BOOLEAN DEFAULT FALSE;

-- 2. RPC: get_focus_ai_priorities
-- The "Notification Brain" that scans all modules for high-priority alerts
CREATE OR REPLACE FUNCTION get_focus_ai_priorities(p_student_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_critical_deadline RECORD;
  v_focus_intel       JSONB;
  v_dna_gap           TEXT;
  v_career_risk       TEXT;
  v_alerts            JSONB := '[]'::JSONB;
BEGIN
  -- 1. Check for Scholarship/Opportunity Deadlines (< 48 hours)
  SELECT title, apply_deadline, id INTO v_critical_deadline
  FROM v_active_opportunities
  WHERE apply_deadline BETWEEN NOW() AND (NOW() + INTERVAL '48 hours')
  LIMIT 1;

  IF v_critical_deadline.title IS NOT NULL THEN
    v_alerts := v_alerts || jsonb_build_object(
      'type', 'critical_deadline',
      'title', 'Deadline Alert: ' || v_critical_deadline.title,
      'body', 'You have less than 48 hours to apply. Start a focused application session.',
      'priority', 'critical',
      'action_label', 'Apply Now',
      'action_url', '/opportunities',
      'urgency', 10
    );
  END IF;

  -- 2. Get Focus Intelligence (M5)
  v_focus_intel := get_focus_intelligence(p_student_id);

  IF (v_focus_intel->>'risk_level') IN ('high', 'critical') THEN
    v_alerts := v_alerts || jsonb_build_object(
      'type', 'focus_intervention',
      'title', 'OS Alert: ' || (v_focus_intel->>'intervention'),
      'body', 'Consistency is key to maintaining your Gold TrustScore tier.',
      'priority', v_focus_intel->>'risk_level',
      'action_label', 'Start Session',
      'action_url', '/focus',
      'urgency', CASE WHEN v_focus_intel->>'risk_level' = 'critical' THEN 9 ELSE 7 END
    );
  END IF;

  -- 3. Check for Skill Gaps (M7)
  IF EXISTS (SELECT 1 FROM student_dna WHERE student_id = p_student_id AND jsonb_array_length(skill_gaps) > 0) THEN
    v_alerts := v_alerts || jsonb_build_object(
      'type', 'skill_gap',
      'title', 'Career Growth Opportunity',
      'body', 'Identify and close your top skill gap to increase your internship match score.',
      'priority', 'medium',
      'action_label', 'View Roadmap',
      'action_url', '/career_predictor',
      'urgency', 5
    );
  END IF;

  RETURN v_alerts;
END;
$$;

-- 3. Trigger: Auto-prioritize notifications on insert
CREATE OR REPLACE FUNCTION prioritize_notification()
RETURNS TRIGGER AS $$
BEGIN
  NEW.priority := COALESCE(NEW.priority, CASE
    WHEN NEW.type ILIKE '%deadline%' THEN 'critical'
    WHEN NEW.type ILIKE '%request%' THEN 'high'
    WHEN NEW.type ILIKE '%match%' THEN 'medium'
    ELSE 'low'
  END);

  NEW.urgency := COALESCE(NEW.urgency, CASE
    WHEN NEW.priority = 'critical' THEN 10
    WHEN NEW.priority = 'high' THEN 8
    WHEN NEW.priority = 'medium' THEN 5
    ELSE 2
  END);

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Check and create trigger
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'on_notification_added') THEN
        CREATE TRIGGER on_notification_added
          BEFORE INSERT ON notifications
          FOR EACH ROW
          EXECUTE FUNCTION prioritize_notification();
    END IF;
END $$;

GRANT EXECUTE ON FUNCTION get_focus_ai_priorities TO authenticated;
