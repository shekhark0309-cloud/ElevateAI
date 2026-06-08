-- =============================================================================
-- ElevateAI — M2: Smart Team Finder Upgrades
-- File: migrations/26_smart_team_finder_upgrades.sql
-- =============================================================================

-- 1. Enhance student_profiles with availability and presence
ALTER TABLE student_profiles
  ADD COLUMN IF NOT EXISTS availability_status TEXT DEFAULT 'Available Now',
  ADD COLUMN IF NOT EXISTS latitude            NUMERIC(9,6),
  ADD COLUMN IF NOT EXISTS longitude           NUMERIC(9,6),
  ADD COLUMN IF NOT EXISTS is_on_campus        BOOLEAN DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS location_label      TEXT,
  ADD COLUMN IF NOT EXISTS current_project_id  UUID REFERENCES teams(id);

-- 2. RPC: get_nearby_teammates
-- Finds students within campus vicinity with matching DNA/Skills
CREATE OR REPLACE FUNCTION get_nearby_teammates(
  p_student_id UUID,
  p_radius_km  NUMERIC DEFAULT 2.0,
  p_limit      INTEGER DEFAULT 10
)
RETURNS TABLE (
  student_id        UUID,
  full_name         TEXT,
  avatar_url        TEXT,
  archetype         archetype_type,
  top_skills        TEXT[],
  trust_score       NUMERIC,
  availability      TEXT,
  distance_meters   INTEGER,
  match_score       INTEGER
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_my_lat NUMERIC;
  v_my_lon NUMERIC;
  v_my_dna RECORD;
BEGIN
  SELECT latitude, longitude INTO v_my_lat, v_my_lon FROM student_profiles WHERE id = p_student_id;
  SELECT * INTO v_my_dna FROM student_dna WHERE student_id = p_student_id;

  RETURN QUERY
  SELECT
    sp.id,
    sp.full_name,
    sp.avatar_url,
    sd.archetype,
    sd.top_skills,
    ts.overall_score as trust_score,
    sp.availability_status,
    -- Simple distance calculation (Haversine simplified for campus)
    (6371000 * acos(cos(radians(v_my_lat)) * cos(radians(sp.latitude)) * cos(radians(sp.longitude) - radians(v_my_lon)) + sin(radians(v_my_lat)) * sin(radians(sp.latitude))))::INTEGER as distance_meters,
    -- DNA Match Score
    (
      CASE WHEN sd.archetype != v_my_dna.archetype THEN 30 ELSE 10 END + -- Synergy
      LEAST(40, array_length(ARRAY(SELECT UNNEST(sd.top_skills) INTERSECT SELECT UNNEST(v_my_dna.top_skills)), 1) * 10) +
      CASE WHEN sp.availability_status = 'Available Now' THEN 20 ELSE 0 END
    )::INTEGER as match_score
  FROM student_profiles sp
  JOIN student_dna sd ON sd.student_id = sp.id
  JOIN trust_scores ts ON ts.student_id = sp.id
  WHERE sp.id != p_student_id
    AND sp.latitude IS NOT NULL
    AND sp.longitude IS NOT NULL
    AND sp.is_active = TRUE
    AND (6371000 * acos(cos(radians(v_my_lat)) * cos(radians(sp.latitude)) * cos(radians(sp.longitude) - radians(v_my_lon)) + sin(radians(v_my_lat)) * sin(radians(sp.latitude)))) <= (p_radius_km * 1000)
  ORDER BY match_score DESC, distance_meters ASC
  LIMIT p_limit;
END;
$$;

-- 3. Extend v_open_teams with availability signals
CREATE OR REPLACE VIEW v_smart_open_teams AS
  SELECT
    vot.*,
    sp.availability_status as leader_availability,
    sp.is_on_campus as leader_on_campus,
    sp.location_label as leader_location
  FROM v_open_teams vot
  JOIN student_profiles sp ON sp.id = vot.leader_id;

GRANT EXECUTE ON FUNCTION get_nearby_teammates TO authenticated;
