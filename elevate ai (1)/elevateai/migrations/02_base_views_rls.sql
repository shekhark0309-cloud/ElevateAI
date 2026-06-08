-- =============================================================================
-- ElevateAI — Core Views & RLS Policies (Reconstructed)
-- File: migrations/02_base_views_rls.sql
-- =============================================================================

-- ── VIEWS ──────────────────────────────────────────────────────────────────

-- 1. Active Opportunities View
CREATE OR REPLACE VIEW v_active_opportunities AS
  SELECT
    o.*,
    (SELECT COUNT(*) FROM opportunity_applications oa WHERE oa.opportunity_id = o.id) AS apply_count
  FROM opportunities o
  WHERE o.status = 'active'
    AND o.apply_deadline > NOW()
    AND o.deleted_at IS NULL;

-- 2. Open Teams View
CREATE OR REPLACE VIEW v_open_teams AS
  SELECT
    t.*,
    sp.full_name AS leader_name,
    ts.overall_score AS leader_trust_score,
    ts.tier AS leader_trust_tier,
    (SELECT COUNT(*) FROM team_members tm WHERE tm.team_id = t.id AND tm.status = 'active') AS current_member_count
  FROM teams t
  JOIN student_profiles sp ON sp.id = t.leader_id
  JOIN trust_scores ts ON ts.student_id = t.leader_id
  WHERE t.is_open = TRUE
    AND t.status = 'forming'
    AND t.deleted_at IS NULL;

-- 3. Student DNA Snapshot View
CREATE OR REPLACE VIEW v_student_dna_snapshot AS
  SELECT
    sp.id,
    sp.full_name,
    dna.archetype,
    dna.archetype_confidence,
    dna.top_skills,
    dna.ai_summary,
    dna.ai_strengths,
    dna.ai_team_role_hint,
    ts.overall_score AS trust_score,
    ts.tier AS trust_tier
  FROM student_profiles sp
  LEFT JOIN student_dna dna ON dna.student_id = sp.id
  LEFT JOIN trust_scores ts ON ts.student_id = sp.id
  WHERE sp.is_active = TRUE;


-- ── RLS POLICIES ─────────────────────────────────────────────────────────────

-- 1. student_profiles
CREATE POLICY "Public profiles are viewable by everyone"
  ON student_profiles FOR SELECT
  USING (is_active = TRUE);

CREATE POLICY "Students can update own profile"
  ON student_profiles FOR UPDATE
  USING (auth.uid() = id);

-- 2. student_dna
CREATE POLICY "DNA viewable by owner"
  ON student_dna FOR SELECT
  USING (auth.uid() = student_id);

CREATE POLICY "DNA viewable by team members"
  ON student_dna FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM team_members tm1
      JOIN team_members tm2 ON tm1.team_id = tm2.team_id
      WHERE tm1.student_id = auth.uid() AND tm2.student_id = student_dna.student_id
        AND tm1.status = 'active' AND tm2.status = 'active'
    )
  );

-- 3. trust_scores
CREATE POLICY "Trust scores viewable by everyone"
  ON trust_scores FOR SELECT
  USING (TRUE);

-- 4. opportunities
CREATE POLICY "Active opportunities are viewable by everyone"
  ON opportunities FOR SELECT
  USING (status = 'active' AND deleted_at IS NULL);

-- 5. opportunity_applications
CREATE POLICY "Students can view own applications"
  ON opportunity_applications FOR SELECT
  USING (auth.uid() = student_id);

CREATE POLICY "Students can create own applications"
  ON opportunity_applications FOR INSERT
  WITH CHECK (auth.uid() = student_id);

-- 6. teams
CREATE POLICY "Open teams are viewable by everyone"
  ON teams FOR SELECT
  USING (is_open = TRUE OR auth.uid() = leader_id);

-- 7. notifications
CREATE POLICY "Notifications viewable by owner"
  ON notifications FOR SELECT
  USING (auth.uid() = student_id);

CREATE POLICY "Notifications updatable by owner"
  ON notifications FOR UPDATE
  USING (auth.uid() = student_id);


-- ── REALTIME CONFIGURATION ──────────────────────────────────────────────────

-- Enable Realtime for key tables
ALTER PUBLICATION supabase_realtime ADD TABLE trust_scores;
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE team_members;
ALTER PUBLICATION supabase_realtime ADD TABLE student_dna;
ALTER PUBLICATION supabase_realtime ADD TABLE opportunity_applications;
ALTER PUBLICATION supabase_realtime ADD TABLE campus_resources;
ALTER PUBLICATION supabase_realtime ADD TABLE messages;
ALTER PUBLICATION supabase_realtime ADD TABLE conversations;
