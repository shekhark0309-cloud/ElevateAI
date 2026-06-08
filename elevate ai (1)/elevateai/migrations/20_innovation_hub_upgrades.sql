-- =============================================================================
-- ElevateAI — M3: Campus Innovation Hub Upgrades
-- File: migrations/20_innovation_hub_upgrades.sql
-- =============================================================================

-- 1. Enhance project_ideas table with missing AI validation fields
ALTER TABLE project_ideas
  ADD COLUMN IF NOT EXISTS problem_statement    TEXT,
  ADD COLUMN IF NOT EXISTS solution             TEXT,
  ADD COLUMN IF NOT EXISTS target_users          TEXT,
  ADD COLUMN IF NOT EXISTS innovation_score     NUMERIC(4,2),
  ADD COLUMN IF NOT EXISTS feasibility_score    NUMERIC(4,2),
  ADD COLUMN IF NOT EXISTS market_potential      TEXT,
  ADD COLUMN IF NOT EXISTS technical_complexity  TEXT,
  ADD COLUMN IF NOT EXISTS suggested_improvements TEXT[],
  ADD COLUMN IF NOT EXISTS potential_risks       TEXT[],
  ADD COLUMN IF NOT EXISTS category              TEXT,
  ADD COLUMN IF NOT EXISTS tags                  TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS open_roles            TEXT[] DEFAULT '{}';

-- 2. RPC: get_innovation_hub_feed
-- Handles trending, newest, and DNA-matching ideas
CREATE OR REPLACE FUNCTION get_innovation_hub_feed(
  p_student_id   UUID,
  p_sort_by      TEXT DEFAULT 'trending',
  p_category     TEXT DEFAULT 'All',
  p_limit        INTEGER DEFAULT 20
)
RETURNS TABLE (
  idea_id            UUID,
  creator_name       TEXT,
  title              TEXT,
  description        TEXT,
  required_skills    TEXT[],
  innovation_score   NUMERIC,
  collaborator_count INTEGER,
  match_score        NUMERIC,
  created_at         TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_student_skills TEXT[];
  v_student_goals  TEXT[];
BEGIN
  -- Get student DNA signals for matching
  SELECT top_skills, career_goals
  INTO v_student_skills, v_student_goals
  FROM student_dna
  WHERE student_id = p_student_id;

  RETURN QUERY
  SELECT
    pi.id,
    sp.full_name,
    pi.title,
    pi.description,
    pi.required_skills,
    pi.innovation_score,
    COALESCE(array_length(pi.collaborators, 1), 0) as collaborator_count,
    -- Match score calculation based on DNA
    (
      CASE WHEN pi.required_skills && v_student_skills THEN 40 ELSE 0 END +
      CASE WHEN pi.category = ANY(v_student_goals) THEN 30 ELSE 0 END +
      COALESCE(pi.innovation_score * 0.2, 0)
    ) as match_score,
    pi.created_at
  FROM project_ideas pi
  JOIN student_profiles sp ON sp.id = pi.creator_id
  WHERE (p_category = 'All' OR pi.category = p_category)
  ORDER BY
    CASE WHEN p_sort_by = 'trending' THEN (COALESCE(array_length(pi.collaborators, 1), 0) * 10 + pi.innovation_score) END DESC,
    CASE WHEN p_sort_by = 'newest' THEN pi.created_at END DESC,
    CASE WHEN p_sort_by = 'recommended' THEN (
      CASE WHEN pi.required_skills && v_student_skills THEN 40 ELSE 0 END +
      CASE WHEN pi.category = ANY(v_student_goals) THEN 30 ELSE 0 END
    ) END DESC
  LIMIT p_limit;
END;
$$;
GRANT EXECUTE ON FUNCTION get_innovation_hub_feed TO authenticated;

-- 3. RPC: join_project_idea
-- Handles joining an idea and updating collaborator list
CREATE OR REPLACE FUNCTION join_project_idea(
  p_idea_id    UUID,
  p_student_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE project_ideas
  SET collaborators = array_append(collaborators, p_student_id)
  WHERE id = p_idea_id
    AND NOT (collaborators @> ARRAY[p_student_id]);

  -- Trigger a notification to the creator
  INSERT INTO notifications (student_id, type, title, body, data)
  SELECT
    creator_id,
    'new_collaborator',
    'New Team Member!',
    'Someone just joined your idea: ' || title,
    jsonb_build_object('idea_id', p_idea_id, 'student_id', p_student_id)
  FROM project_ideas
  WHERE id = p_idea_id;
END;
$$;
GRANT EXECUTE ON FUNCTION join_project_idea TO authenticated;
