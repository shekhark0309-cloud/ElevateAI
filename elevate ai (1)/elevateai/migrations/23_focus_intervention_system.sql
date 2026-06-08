-- =============================================================================
-- ElevateAI — M5: Smart Focus Intervention
-- File: migrations/23_focus_intervention_system.sql
-- =============================================================================

-- 1. Focus Sessions Table
CREATE TABLE IF NOT EXISTS focus_sessions (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id        UUID NOT NULL REFERENCES student_profiles(id) ON DELETE CASCADE,
  start_at          TIMESTAMPTZ DEFAULT NOW(),
  end_at            TIMESTAMPTZ,
  duration_seconds  INTEGER DEFAULT 0,
  status            TEXT DEFAULT 'active', -- active | paused | completed | cancelled
  focus_mode        TEXT DEFAULT 'deep_work', -- deep_work | study | project
  created_at        TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Focus Metrics & Streaks
ALTER TABLE student_dna
  ADD COLUMN IF NOT EXISTS daily_focus_minutes   INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS weekly_focus_minutes  INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS productivity_score    NUMERIC(5,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_activity_at      TIMESTAMPTZ DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS focus_risk_level      TEXT DEFAULT 'low', -- low | medium | high | critical
  ADD COLUMN IF NOT EXISTS streak_start_date     DATE;

-- 3. RPC: get_focus_intelligence
-- Calculates risk level, productivity, and generates actionable nudges
CREATE OR REPLACE FUNCTION get_focus_intelligence(p_student_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_dna               RECORD;
  v_last_challenge    TIMESTAMPTZ;
  v_last_task         TIMESTAMPTZ;
  v_last_app          TIMESTAMPTZ;
  v_risk_level        TEXT := 'low';
  v_productivity      NUMERIC := 0;
  v_days_inactive     INTEGER;
  v_intervention_msg  TEXT;
  v_streak            INTEGER;
BEGIN
  -- 1. Fetch current status
  SELECT * INTO v_dna FROM student_dna WHERE student_id = p_student_id;

  -- 2. Analyze activity signals
  SELECT MAX(created_at) INTO v_last_challenge FROM challenge_attempts WHERE student_id = p_student_id;
  SELECT MAX(updated_at) INTO v_last_task FROM student_tasks WHERE student_id = p_student_id AND is_completed = TRUE;
  SELECT MAX(created_at) INTO v_last_app FROM opportunity_applications WHERE student_id = p_student_id;

  v_days_inactive := EXTRACT(DAY FROM (NOW() - COALESCE(v_dna.last_activity_at, NOW())))::INTEGER;

  -- 3. Determine Risk Level
  IF v_days_inactive >= 7 THEN v_risk_level := 'critical';
  ELSIF v_days_inactive >= 4 THEN v_risk_level := 'high';
  ELSIF v_days_inactive >= 2 THEN v_risk_level := 'medium';
  ELSE v_risk_level := 'low';
  END IF;

  -- 4. Calculate Productivity Score (0-100)
  -- Logic: Sessions (40%) + Challenges (30%) + Tasks (20%) + Apps (10%)
  v_productivity := LEAST(100,
    (COALESCE(v_dna.daily_focus_minutes, 0) * 0.5) +
    (CASE WHEN v_last_challenge > NOW() - INTERVAL '24 hours' THEN 20 ELSE 0 END) +
    (CASE WHEN v_last_task > NOW() - INTERVAL '24 hours' THEN 15 ELSE 0 END)
  );

  -- 5. Generate Personalized Intervention
  v_intervention_msg := CASE
    WHEN v_risk_level = 'critical' THEN 'Your progress is stalling. Re-engage with a 15-min focus session today.'
    WHEN v_risk_level = 'high' THEN 'Your streak is at risk! Complete one task to keep the momentum.'
    WHEN v_dna.archetype = 'Builder' AND v_productivity < 40 THEN 'A Builder needs consistency. Start a Project Focus session now.'
    WHEN v_dna.archetype = 'Creative' AND v_days_inactive > 1 THEN 'New inspiration awaits. Check out trending ideas in the hub.'
    ELSE 'You are doing great! Keep maintaining your focus score.'
  END;

  -- 6. Update DNA for persistence
  UPDATE student_dna SET
    focus_risk_level = v_risk_level,
    productivity_score = v_productivity,
    focus_score = (focus_score * 0.7 + v_productivity * 0.3) -- Moving average
  WHERE student_id = p_student_id;

  RETURN jsonb_build_object(
    'risk_level', v_risk_level,
    'productivity_score', ROUND(v_productivity, 1),
    'days_inactive', v_days_inactive,
    'intervention', v_intervention_msg,
    'today_minutes', v_dna.daily_focus_minutes,
    'current_streak', v_dna.study_streak
  );
END;
$$;

-- 4. RPC: manage_focus_session
CREATE OR REPLACE FUNCTION manage_focus_session(
  p_action   TEXT, -- start | end
  p_mode     TEXT DEFAULT 'deep_work',
  p_duration INTEGER DEFAULT 0 -- in seconds, only for 'end'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_student_id UUID := auth.uid();
  v_session_id UUID;
BEGIN
  IF p_action = 'start' THEN
    INSERT INTO focus_sessions (student_id, focus_mode, status)
    VALUES (v_student_id, p_mode, 'active')
    RETURNING id INTO v_session_id;

    RETURN jsonb_build_object('success', TRUE, 'session_id', v_session_id);

  ELSIF p_action = 'end' THEN
    UPDATE focus_sessions
    SET end_at = NOW(),
        duration_seconds = p_duration,
        status = 'completed'
    WHERE student_id = v_student_id AND status = 'active'
    RETURNING id INTO v_session_id;

    -- Update daily minutes in DNA
    UPDATE student_dna SET
      daily_focus_minutes = daily_focus_minutes + (p_duration / 60),
      last_activity_at = NOW()
    WHERE student_id = v_student_id;

    RETURN jsonb_build_object('success', TRUE, 'session_id', v_session_id);
  END IF;

  RETURN jsonb_build_object('success', FALSE, 'error', 'Invalid action');
END;
$$;

-- 5. RLS & Permissions
ALTER TABLE focus_sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Students manage own sessions" ON focus_sessions FOR ALL USING (student_id = auth.uid());

GRANT EXECUTE ON FUNCTION get_focus_intelligence TO authenticated;
GRANT EXECUTE ON FUNCTION manage_focus_session TO authenticated;

-- 6. Enable Realtime
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE focus_sessions;
    END IF;
END $$;
