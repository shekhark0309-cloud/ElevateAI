-- =============================================================================
-- ElevateAI — Tasks & Goals (M17)
-- File: migrations/14_tasks_and_goals.sql
-- =============================================================================

CREATE TABLE IF NOT EXISTS student_tasks (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id   UUID REFERENCES student_profiles(id) ON DELETE CASCADE,
  title        TEXT NOT NULL,
  description  TEXT,
  category     TEXT DEFAULT 'task', -- 'task', 'event', 'deadline', 'study'
  due_at       TIMESTAMPTZ,
  is_completed BOOLEAN DEFAULT FALSE,
  color        TEXT, -- hex code
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at   TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE student_tasks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Students manage own tasks"
  ON student_tasks FOR ALL
  USING (student_id = auth.uid());

-- Seed some initial tasks for the demo
-- Note: Replace with real user ID in app logic
INSERT INTO student_tasks (title, category, is_completed, color)
VALUES
  ('Complete DNA Quiz', 'task', false, '#6200EE'),
  ('Setup Digital Portfolio', 'task', false, '#03DAC5'),
  ('Explore Opportunities', 'task', false, '#BB86FC');
