-- =============================================================================
-- ElevateAI — M11: Campus Connect Upgrades
-- File: migrations/21_campus_connect_upgrades.sql
-- =============================================================================

-- 1. Extend campus_connections with more types and metadata
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'connection_status') THEN
    CREATE TYPE connection_status AS ENUM ('pending', 'accepted', 'declined', 'blocked');
  END IF;
END $$;

-- Update existing table if needed (it was TEXT in 07_missing_modules.sql)
-- For now, keeping it as TEXT for flexibility but adding a check constraint
ALTER TABLE campus_connections
  DROP CONSTRAINT IF EXISTS campus_connections_status_check;

ALTER TABLE campus_connections
  ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}';

-- 2. Enhance teams table for Study Groups
ALTER TABLE teams
  ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'project'; -- 'project' | 'study_group' | 'hackathon' | 'social'

-- 3. RPC: get_student_discovery_feed
-- Intelligent student discovery based on DNA, Skills, and Goals
CREATE OR REPLACE FUNCTION get_student_discovery_feed(
  p_student_id   UUID,
  p_filter_type  TEXT DEFAULT 'all', -- 'skills', 'goals', 'dna', 'college'
  p_limit        INTEGER DEFAULT 20
)
RETURNS TABLE (
  student_id       UUID,
  full_name        TEXT,
  avatar_url       TEXT,
  course           TEXT,
  year_of_study    SMALLINT,
  archetype        archetype_type,
  trust_score      NUMERIC,
  top_skills       TEXT[],
  shared_skills    TEXT[],
  shared_interests TEXT[],
  match_score      INTEGER,
  compatibility    JSONB
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_my_dna RECORD;
  v_my_profile RECORD;
BEGIN
  -- Get current student's signals
  SELECT * INTO v_my_dna FROM student_dna WHERE student_id = p_student_id;
  SELECT * INTO v_my_profile FROM student_profiles WHERE id = p_student_id;

  RETURN QUERY
  SELECT
    sp.id,
    sp.full_name,
    sp.avatar_url,
    sp.course,
    sp.year_of_study,
    sd.archetype,
    ts.overall_score as trust_score,
    sd.top_skills,
    -- Calculate shared skills
    ARRAY(SELECT UNNEST(sd.top_skills) INTERSECT SELECT UNNEST(v_my_dna.top_skills)) as shared_skills,
    -- Calculate shared interests/goals
    ARRAY(SELECT UNNEST(sd.goals_short_term) INTERSECT SELECT UNNEST(v_my_dna.goals_short_term)) as shared_interests,
    -- Match Score (DNA + Skills + College)
    (
      (CASE WHEN sd.archetype = v_my_dna.archetype THEN 20 ELSE 10 END) +
      (LEAST(30, array_length(ARRAY(SELECT UNNEST(sd.top_skills) INTERSECT SELECT UNNEST(v_my_dna.top_skills)), 1) * 10)) +
      (CASE WHEN sp.college_id = v_my_profile.college_id THEN 20 ELSE 0 END) +
      (CASE WHEN sp.branch = v_my_profile.branch THEN 15 ELSE 0 END)
    )::INTEGER as match_score,
    -- Compatibility breakdown
    jsonb_build_object(
      'collaboration', CASE WHEN sd.archetype = 'Builder' AND v_my_dna.archetype = 'Strategist' THEN 95 ELSE 70 END,
      'study', CASE WHEN sp.course = v_my_profile.course THEN 90 ELSE 60 END,
      'dna_synergy', CASE WHEN sd.archetype != v_my_dna.archetype THEN 85 ELSE 65 END
    ) as compatibility
  FROM student_profiles sp
  JOIN student_dna sd ON sd.student_id = sp.id
  JOIN trust_scores ts ON ts.student_id = sp.id
  WHERE sp.id != p_student_id
    AND sp.is_active = TRUE
    AND (
      p_filter_type = 'all' OR
      (p_filter_type = 'skills' AND sd.top_skills && v_my_dna.top_skills) OR
      (p_filter_type = 'college' AND sp.college_id = v_my_profile.college_id) OR
      (p_filter_type = 'dna' AND sd.archetype = v_my_dna.archetype)
    )
    -- Exclude already connected or pending
    AND NOT EXISTS (
      SELECT 1 FROM campus_connections
      WHERE (student_a_id = p_student_id AND student_b_id = sp.id)
         OR (student_a_id = sp.id AND student_b_id = p_student_id)
    )
  ORDER BY match_score DESC
  LIMIT p_limit;
END;
$$;

-- 4. RPC: manage_campus_connection
-- Handles sending, accepting, and declining connection requests
CREATE OR REPLACE FUNCTION manage_campus_connection(
  p_target_student_id UUID,
  p_action            TEXT, -- 'request', 'accept', 'decline'
  p_connection_type   TEXT DEFAULT 'study_buddy',
  p_subject           TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_my_id UUID := auth.uid();
  v_conn_id UUID;
BEGIN
  IF p_action = 'request' THEN
    INSERT INTO campus_connections (student_a_id, student_b_id, connection_type, subject, status)
    VALUES (v_my_id, p_target_student_id, p_connection_type, p_subject, 'pending')
    ON CONFLICT (student_a_id, student_b_id, connection_type) DO NOTHING
    RETURNING id INTO v_conn_id;

    -- Notification
    INSERT INTO notifications (student_id, type, title, body, data)
    SELECT p_target_student_id, 'connection_request', 'New Connection Request',
           full_name || ' wants to connect as a ' || p_connection_type,
           jsonb_build_object('sender_id', v_my_id, 'connection_type', p_connection_type)
    FROM student_profiles WHERE id = v_my_id;

  ELSIF p_action = 'accept' THEN
    UPDATE campus_connections
    SET status = 'accepted'
    WHERE student_b_id = v_my_id AND student_a_id = p_target_student_id
    RETURNING id INTO v_conn_id;

    -- Notification
    INSERT INTO notifications (student_id, type, title, body, data)
    SELECT p_target_student_id, 'connection_accepted', 'Connection Accepted!',
           full_name || ' accepted your connection request.',
           jsonb_build_object('accepter_id', v_my_id)
    FROM student_profiles WHERE id = v_my_id;

    -- Boost TrustScore for networking
    UPDATE trust_scores SET community_score = LEAST(100, community_score + 2)
    WHERE student_id IN (v_my_id, p_target_student_id);

  END IF;

  RETURN jsonb_build_object('success', TRUE, 'connection_id', v_conn_id);
END;
$$;

GRANT EXECUTE ON FUNCTION get_student_discovery_feed TO authenticated;
-- 5. M18: Scheme Buddy Enhancements
ALTER TABLE student_dna
  ADD COLUMN IF NOT EXISTS preferred_language TEXT DEFAULT 'auto';

