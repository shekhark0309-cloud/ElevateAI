-- 19_study_buddy_live.sql
-- ═══════════════════════════════════════════════════════════════
-- ElevateAI — Study Buddy & Live Presence
-- ═══════════════════════════════════════════════════════════════

-- 1. Add live study status to student_profiles
ALTER TABLE student_profiles
  ADD COLUMN IF NOT EXISTS is_studying BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS current_study_subject TEXT,
  ADD COLUMN IF NOT EXISTS last_location_update TIMESTAMPTZ;

-- 2. Create a view for discovery
CREATE OR REPLACE VIEW v_live_study_buddies AS
  SELECT
    sp.id,
    sp.full_name,
    sp.college_id,
    sp.avatar_url,
    sp.is_studying,
    sp.current_study_subject,
    dna.top_skills,
    dna.archetype,
    ts.overall_score as trust_score,
    ts.tier as trust_tier
  FROM student_profiles sp
  LEFT JOIN student_dna dna ON dna.student_id = sp.id
  LEFT JOIN trust_scores ts ON ts.student_id = sp.id
  WHERE sp.is_studying = TRUE
    AND sp.is_active = TRUE;

-- 3. RLS
ALTER TABLE student_profiles ENABLE ROW LEVEL SECURITY;
-- (Existing policies usually allow viewing active profiles, but let's be sure)
-- Policies for is_studying and current_study_subject should be handled by existing profile update policies.
