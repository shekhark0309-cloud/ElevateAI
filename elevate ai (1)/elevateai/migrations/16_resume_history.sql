-- 16_resume_history.sql
CREATE TABLE IF NOT EXISTS resume_history (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id   UUID NOT NULL REFERENCES student_profiles(id) ON DELETE CASCADE,
  pdf_url      TEXT NOT NULL,
  resume_data  JSONB NOT NULL, -- The JSON used to generate the PDF
  version      INTEGER DEFAULT 1,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE resume_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Students can view own resume history"
  ON resume_history FOR SELECT
  USING (auth.uid() = student_id);

CREATE POLICY "Students can create own resume history"
  ON resume_history FOR INSERT
  WITH CHECK (auth.uid() = student_id);
