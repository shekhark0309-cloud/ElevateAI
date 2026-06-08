-- =============================================================================
-- ElevateAI — Missing Modules & RPCs
-- File: migrations/07_missing_modules.sql
-- =============================================================================

-- ── 1. M3: Campus Innovation Hub ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS project_ideas (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  creator_id      UUID REFERENCES student_profiles(id) ON DELETE CASCADE,
  title           TEXT NOT NULL,
  description     TEXT,
  required_skills TEXT[] DEFAULT '{}',
  stage           TEXT DEFAULT 'idea', -- idea | building | launched
  collaborators   UUID[] DEFAULT '{}',
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ── 2. M11: Campus Connect ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS campus_connections (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_a_id    UUID REFERENCES student_profiles(id) ON DELETE CASCADE,
  student_b_id    UUID REFERENCES student_profiles(id) ON DELETE CASCADE,
  connection_type TEXT NOT NULL, -- 'study_buddy' | 'lunch' | 'interest_circle'
  subject         TEXT,
  status          TEXT DEFAULT 'pending', -- pending | accepted | declined
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(student_a_id, student_b_id, connection_type)
);

-- ── 3. M12: Smart Campus Resources ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS campus_resources (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  college_id      UUID REFERENCES colleges(id),
  resource_type   TEXT NOT NULL, -- 'library_seat' | 'classroom' | 'lab_equipment'
  name            TEXT NOT NULL,
  capacity        INTEGER DEFAULT 1,
  is_available    BOOLEAN DEFAULT TRUE,
  available_from  TIMESTAMPTZ,
  available_until TIMESTAMPTZ,
  location_label  TEXT, -- e.g. "Library Block B, Seat 42"
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS resource_bookings (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id      UUID REFERENCES student_profiles(id) ON DELETE CASCADE,
  resource_id     UUID REFERENCES campus_resources(id) ON DELETE CASCADE,
  booked_from     TIMESTAMPTZ NOT NULL,
  booked_until    TIMESTAMPTZ NOT NULL,
  status          TEXT DEFAULT 'active', -- active | cancelled | expired
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ── 4. M13: Hostel & Cafeteria ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS meal_preferences (
  student_id      UUID PRIMARY KEY REFERENCES student_profiles(id) ON DELETE CASCADE,
  opt_in_breakfast BOOLEAN DEFAULT TRUE,
  opt_in_lunch     BOOLEAN DEFAULT TRUE,
  opt_in_dinner    BOOLEAN DEFAULT TRUE,
  opt_out_dates    DATE[] DEFAULT '{}', -- specific dates to skip
  updated_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS meal_predictions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  college_id      UUID REFERENCES colleges(id),
  meal_date       DATE NOT NULL,
  meal_type       TEXT NOT NULL, -- breakfast | lunch | dinner
  predicted_count INTEGER,
  actual_count    INTEGER,
  waste_kg_saved  NUMERIC(6,2),
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(college_id, meal_date, meal_type)
);

-- ── 5. M14: Work Style DNA Quiz ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS dna_quiz_questions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  question_text   TEXT NOT NULL,
  option_a        TEXT NOT NULL,
  option_b        TEXT NOT NULL,
  option_c        TEXT NOT NULL,
  option_d        TEXT NOT NULL,
  archetype_a     TEXT NOT NULL, -- which archetype option_a maps to
  archetype_b     TEXT NOT NULL,
  archetype_c     TEXT NOT NULL,
  archetype_d     TEXT NOT NULL,
  display_order   INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS dna_quiz_responses (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id      UUID REFERENCES student_profiles(id) ON DELETE CASCADE,
  question_id     UUID REFERENCES dna_quiz_questions(id),
  selected_option TEXT NOT NULL, -- 'a' | 'b' | 'c' | 'd'
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ── 6. M16: Open Roles Board ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS role_postings (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  creator_id      UUID REFERENCES student_profiles(id) ON DELETE CASCADE,
  team_id         UUID REFERENCES teams(id),
  role_title      TEXT NOT NULL,
  required_skills TEXT[] NOT NULL,
  description     TEXT,
  commitment_weeks INTEGER DEFAULT 3,
  domain          TEXT, -- e.g. 'climate-tech', 'fintech'
  status          TEXT DEFAULT 'open', -- open | filled | closed
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS role_applications (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  posting_id      UUID REFERENCES role_postings(id) ON DELETE CASCADE,
  applicant_id    UUID REFERENCES student_profiles(id) ON DELETE CASCADE,
  message         TEXT,
  status          TEXT DEFAULT 'pending',
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(posting_id, applicant_id)
);

-- ── 7. M7: Career Predictor Extensions ─────────────────────────────────────
ALTER TABLE student_dna
  ADD COLUMN IF NOT EXISTS placement_score     NUMERIC(5,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS salary_range_min    INTEGER, -- in LPA
  ADD COLUMN IF NOT EXISTS salary_range_max    INTEGER,
  ADD COLUMN IF NOT EXISTS career_readiness_at TIMESTAMPTZ;

-- ── 8. RLS POLICIES ─────────────────────────────────────────────────────────
ALTER TABLE student_skills       ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_projects     ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE scam_reports         ENABLE ROW LEVEL SECURITY;
ALTER TABLE peer_ratings         ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_ideas        ENABLE ROW LEVEL SECURITY;
ALTER TABLE role_postings        ENABLE ROW LEVEL SECURITY;
ALTER TABLE campus_resources     ENABLE ROW LEVEL SECURITY;
ALTER TABLE meal_preferences     ENABLE ROW LEVEL SECURITY;

-- student_skills policies
DO $$ BEGIN
  CREATE POLICY "Students can manage own skills" ON student_skills FOR ALL USING (auth.uid() = student_id);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Verified skills visible to all" ON student_skills FOR SELECT USING (is_verified = TRUE);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- peer_ratings policies
DO $$ BEGIN
  CREATE POLICY "Rater can create rating" ON peer_ratings FOR INSERT WITH CHECK (auth.uid() = rater_id);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Ratee can read own ratings" ON peer_ratings FOR SELECT USING (auth.uid() = ratee_id OR auth.uid() = rater_id);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- scam_reports policies
DO $$ BEGIN
  CREATE POLICY "Authenticated can report scams" ON scam_reports FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Anyone can view scam reports" ON scam_reports FOR SELECT USING (TRUE);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- role_postings policies
DO $$ BEGIN
  CREATE POLICY "Anyone can view open roles" ON role_postings FOR SELECT USING (status = 'open');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Creators manage own postings" ON role_postings FOR ALL USING (auth.uid() = creator_id);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- campus_resources policies
DO $$ BEGIN
  CREATE POLICY "Anyone can view resources" ON campus_resources FOR SELECT USING (TRUE);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- meal_preferences policies
DO $$ BEGIN
  CREATE POLICY "Students manage own meal prefs" ON meal_preferences FOR ALL USING (auth.uid() = student_id);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;


-- ── 9. RPC FUNCTIONS ────────────────────────────────────────────────────────

-- 9A. calculate_placement_score()
CREATE OR REPLACE FUNCTION calculate_placement_score(p_student_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_skill_count     INTEGER;
  v_badge_count     INTEGER;
  v_trust_score     NUMERIC;
  v_cgpa            NUMERIC;
  v_archetype       TEXT;
  v_placement_score NUMERIC;
  v_salary_min      INTEGER;
  v_salary_max      INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_skill_count FROM student_skills
    WHERE student_id = p_student_id AND proficiency >= 3;

  SELECT COUNT(*) INTO v_badge_count FROM student_badges
    WHERE student_id = p_student_id AND verify_status = 'verified';

  SELECT overall_score INTO v_trust_score FROM trust_scores
    WHERE student_id = p_student_id;

  SELECT cgpa, (SELECT archetype FROM student_dna WHERE student_id = p_student_id)
    INTO v_cgpa, v_archetype
  FROM student_profiles WHERE id = p_student_id;

  -- Weighted placement score formula
  v_placement_score := LEAST(100,
    (COALESCE(v_skill_count, 0) * 3) +
    (COALESCE(v_badge_count, 0) * 8) +
    (COALESCE(v_trust_score, 0) * 0.2) +
    (COALESCE(v_cgpa, 0) * 4)
  );

  -- Salary prediction (simple band based on score)
  v_salary_min := CASE
    WHEN v_placement_score >= 80 THEN 12
    WHEN v_placement_score >= 60 THEN 8
    WHEN v_placement_score >= 40 THEN 5
    ELSE 3
  END;
  v_salary_max := v_salary_min + 4;

  -- Update student_dna
  UPDATE student_dna SET
    placement_score = v_placement_score,
    salary_range_min = v_salary_min,
    salary_range_max = v_salary_max,
    career_readiness_at = NOW()
  WHERE student_id = p_student_id;

  RETURN jsonb_build_object(
    'placement_score', ROUND(v_placement_score::NUMERIC, 1),
    'salary_min_lpa', v_salary_min,
    'salary_max_lpa', v_salary_max,
    'skill_count', v_skill_count,
    'badge_count', v_badge_count,
    'trust_score', ROUND(COALESCE(v_trust_score, 0)::NUMERIC, 1)
  );
END;
$$;
GRANT EXECUTE ON FUNCTION calculate_placement_score TO authenticated;

-- 9B. get_peer_success_stories()
CREATE OR REPLACE FUNCTION get_peer_success_stories(
  p_student_id     UUID,
  p_opportunity_id UUID
)
RETURNS TABLE (
  peer_id        UUID,
  peer_name      TEXT,
  peer_trust_score NUMERIC,
  peer_trust_tier  TEXT,
  common_college   BOOLEAN,
  applied_at       TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_college_id UUID;
BEGIN
  SELECT college_id INTO v_college_id FROM student_profiles WHERE id = p_student_id;

  RETURN QUERY
  SELECT
    sp.id,
    sp.full_name,
    ts.overall_score,
    ts.tier,
    (sp.college_id = v_college_id) AS common_college,
    oa.submitted_at
  FROM opportunity_applications oa
  JOIN student_profiles sp ON sp.id = oa.student_id
  JOIN trust_scores ts ON ts.student_id = oa.student_id
  WHERE oa.opportunity_id = p_opportunity_id
    AND oa.status IN ('accepted', 'submitted')
    AND oa.student_id != p_student_id
  ORDER BY common_college DESC, ts.overall_score DESC
  LIMIT 10;
END;
$$;
GRANT EXECUTE ON FUNCTION get_peer_success_stories TO authenticated;

-- 9C. submit_scam_report()
CREATE OR REPLACE FUNCTION submit_scam_report(
  p_opportunity_id   UUID DEFAULT NULL,
  p_scam_type        TEXT DEFAULT 'fake_opportunity',
  p_description      TEXT DEFAULT NULL,
  p_evidence_url     TEXT DEFAULT NULL,
  p_severity         TEXT DEFAULT 'medium',
  p_title            TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_reporter_id UUID := auth.uid();
  v_report_id   UUID;
  v_report_count INTEGER;
  v_final_title TEXT;
BEGIN
  IF v_reporter_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'P0001';
  END IF;

  IF p_title IS NULL AND p_opportunity_id IS NOT NULL THEN
    SELECT title INTO v_final_title FROM opportunities WHERE id = p_opportunity_id;
    v_final_title := 'Scam Report: ' || v_final_title;
  ELSE
    v_final_title := COALESCE(p_title, 'New Scam Report');
  END IF;

  INSERT INTO scam_reports (reported_by, opportunity_id, category, description, evidence_urls, severity, title)
  VALUES (v_reporter_id, p_opportunity_id, p_scam_type, p_description, ARRAY[p_evidence_url], p_severity, v_final_title)
  RETURNING id INTO v_report_id;

  -- Count total reports for this opportunity
  SELECT COUNT(*) INTO v_report_count FROM scam_reports
  WHERE opportunity_id = p_opportunity_id;

  -- Auto-flag opportunity after 3+ reports
  IF p_opportunity_id IS NOT NULL AND v_report_count >= 3 THEN
    UPDATE opportunities SET status = 'flagged' WHERE id = p_opportunity_id;
  END IF;

  -- Boost reporter's community_score for participating
  UPDATE trust_scores SET
    community_score = LEAST(100, community_score + 1.0),
    overall_score = LEAST(100,
      0.30 * reliability_score + 0.25 * collaboration_score +
      0.20 * integrity_score + 0.15 * skill_validation_score +
      0.10 * LEAST(100, community_score + 1.0)
    )
  WHERE student_id = v_reporter_id;

  RETURN jsonb_build_object(
    'success', TRUE,
    'report_id', v_report_id,
    'total_reports', v_report_count,
    'opportunity_flagged', v_report_count >= 3
  );
END;
$$;
GRANT EXECUTE ON FUNCTION submit_scam_report TO authenticated;

-- 9D. get_scheme_path()
CREATE OR REPLACE FUNCTION get_scheme_path(
  p_student_id     UUID,
  p_opportunity_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_student RECORD;
  v_opp     RECORD;
  v_eligible BOOLEAN;
  v_success_prob NUMERIC;
  v_doc_checklist TEXT[];
BEGIN
  SELECT sp.*, sd.top_skills, ts.overall_score as trust_score
  INTO v_student
  FROM student_profiles sp
  LEFT JOIN student_dna sd ON sd.student_id = sp.id
  LEFT JOIN trust_scores ts ON ts.student_id = sp.id
  WHERE sp.id = p_student_id;

  SELECT * INTO v_opp FROM opportunities WHERE id = p_opportunity_id;

  -- Eligibility check
  v_eligible := (
    (array_length(v_opp.eligible_states, 1) IS NULL OR v_student.state = ANY(v_opp.eligible_states)) AND
    (v_opp.min_cgpa IS NULL OR v_student.cgpa >= v_opp.min_cgpa) AND
    (v_opp.max_family_income IS NULL OR v_student.family_income <= v_opp.max_family_income)
  );

  -- Success probability (simple model)
  v_success_prob := CASE
    WHEN NOT v_eligible THEN 5
    WHEN v_student.cgpa >= 8.5 THEN 75 + RANDOM() * 15
    WHEN v_student.cgpa >= 7.0 THEN 55 + RANDOM() * 20
    ELSE 35 + RANDOM() * 20
  END;

  -- Document checklist
  v_doc_checklist := ARRAY[
    'Aadhaar Card (front and back)',
    'College ID Card',
    'Latest marksheet / grade report',
    'Bank account passbook (first page)',
    'Income certificate (issued in last 6 months)'
  ];

  IF v_opp.type = 'scholarship' THEN
    v_doc_checklist := v_doc_checklist || ARRAY['Caste/Category certificate (if applicable)', 'Domicile certificate'];
  END IF;

  RETURN jsonb_build_object(
    'eligible', v_eligible,
    'success_probability', ROUND(v_success_prob::NUMERIC, 0),
    'document_checklist', v_doc_checklist,
    'apply_now_recommendation', v_eligible AND EXTRACT(DAY FROM (v_opp.apply_deadline - NOW())) <= 30,
    'days_until_deadline', EXTRACT(DAY FROM (v_opp.apply_deadline - NOW()))::INTEGER,
    'reason', CASE
      WHEN NOT v_eligible THEN 'You do not meet all eligibility criteria for this scheme'
      WHEN v_success_prob > 65 THEN 'Strong profile match — apply immediately'
      ELSE 'Eligible but competitive — strengthen your profile first'
    END
  );
END;
$$;
GRANT EXECUTE ON FUNCTION get_scheme_path TO authenticated;
