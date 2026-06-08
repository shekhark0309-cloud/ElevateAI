-- =============================================================================
-- ElevateAI — M4: FocusAI Notifications
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
  v_focus_risk        TEXT;
  v_dna_gap           TEXT;
  v_career_risk       TEXT;
  v_alerts            JSONB := '[]'::JSONB;
BEGIN
  -- 1. Check for Scholarship Deadlines (< 48 hours)
  SELECT title, apply_deadline INTO v_critical_deadline
  FROM v_active_opportunities
  WHERE type = 'scholarship'
    AND apply_deadline BETWEEN NOW() AND (NOW() + INTERVAL '48 hours')
  LIMIT 1;

  IF v_critical_deadline.title IS NOT NULL THEN
    v_alerts := v_alerts || jsonb_build_object(
      'type', 'critical_deadline',
      'title', 'Deadline Alert: ' || v_critical_deadline.title,
      'priority', 'critical',
      'action_label', 'Apply Now',
      'action_url', '/scholarship/details'
    );
  END IF;

  -- 2. Check for Focus Risk (from M5)
  SELECT focus_risk_level INTO v_focus_risk FROM student_dna WHERE student_id = p_student_id;
  IF v_focus_risk = 'critical' OR v_focus_risk = 'high' THEN
    v_alerts := v_alerts || jsonb_build_object(
      'type', 'focus_intervention',
      'title', 'Consistency at Risk: Start a focus session to maintain your score.',
      'priority', 'high',
      'action_label', 'Focus Now',
      'action_url', '/focus'
    );
  END IF;

  -- 3. Check for Skill Gaps (Career Predictor signals)
  -- Simplified: If DSA score is low and student is CS
  IF EXISTS (SELECT 1 FROM student_skills WHERE student_id = p_student_id AND skill_name = 'DSA' AND proficiency < 3) THEN
    v_alerts := v_alerts || jsonb_build_object(
      'type', 'skill_gap',
      'title', 'Placement Ready? Boost your DSA skills for upcoming internships.',
      'priority', 'medium',
      'action_label', 'Take Challenge',
      'action_url', '/skills/challenges'
    );
  END IF;

  RETURN v_alerts;
END;
$$;

-- 3. Trigger: Auto-prioritize notifications on insert
CREATE OR REPLACE FUNCTION prioritize_notification()
RETURNS TRIGGER AS $$
BEGIN
  NEW.priority := CASE
    WHEN NEW.type ILIKE '%deadline%' THEN 'critical'
    WHEN NEW.type ILIKE '%request%' THEN 'high'
    WHEN NEW.type ILIKE '%match%' THEN 'medium'
    ELSE 'low'
  END;

  NEW.urgency := CASE
    WHEN NEW.priority = 'critical' THEN 10
    WHEN NEW.priority = 'high' THEN 8
    WHEN NEW.priority = 'medium' THEN 5
    ELSE 2
  END;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER on_notification_added
  BEFORE INSERT ON notifications
  FOR EACH ROW
  EXECUTE FUNCTION prioritize_notification();

GRANT EXECUTE ON FUNCTION get_focus_ai_priorities TO authenticated;
