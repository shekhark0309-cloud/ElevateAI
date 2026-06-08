-- BUILD 1: Skill Challenges and Challenge Attempts
CREATE TABLE IF NOT EXISTS skill_challenges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  badge_id UUID REFERENCES skill_badges(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  problem_statement TEXT NOT NULL,
  starter_code TEXT,
  expected_output TEXT,
  challenge_type TEXT CHECK (challenge_type IN ('code_debug','code_write','quiz','mini_project')) DEFAULT 'code_write',
  difficulty TEXT CHECK (difficulty IN ('beginner','intermediate','advanced')) DEFAULT 'beginner',
  time_limit_minutes INTEGER DEFAULT 30,
  evaluation_criteria JSONB DEFAULT '{"correctness":50,"efficiency":30,"readability":20}',
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS challenge_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID REFERENCES student_profiles(id) ON DELETE CASCADE NOT NULL,
  challenge_id UUID REFERENCES skill_challenges(id) NOT NULL,
  submitted_code TEXT,
  submitted_answer JSONB,
  ai_score INTEGER CHECK (ai_score BETWEEN 0 AND 100),
  ai_feedback TEXT,
  ai_breakdown JSONB,
  passed BOOLEAN DEFAULT FALSE,
  badge_awarded UUID REFERENCES student_badges(id),
  attempt_number INTEGER DEFAULT 1,
  time_taken_seconds INTEGER,
  status TEXT CHECK (status IN ('in_progress','submitted','evaluated','failed')) DEFAULT 'in_progress',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  evaluated_at TIMESTAMPTZ
);

ALTER TABLE skill_challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE challenge_attempts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "public_read_challenges" ON skill_challenges FOR SELECT USING (is_active = TRUE);
CREATE POLICY "own_attempts" ON challenge_attempts FOR ALL USING (student_id = auth.uid());
-- Check if realtime exists before adding to publication
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE challenge_attempts;
    END IF;
END $$;

-- Seed starter challenges
INSERT INTO skill_challenges (badge_id, title, problem_statement, starter_code, expected_output, challenge_type, difficulty)
SELECT id,
  'Python List Manipulation',
  'Write a function called find_duplicates(lst) that takes a list of integers and returns a new list containing only the elements that appear more than once, without duplicates, sorted in ascending order.',
  'def find_duplicates(lst):\n    # Your code here\n    pass\n\n# Test: find_duplicates([1, 2, 3, 2, 4, 3, 5]) should return [2, 3]',
  '[2, 3]',
  'code_write', 'beginner'
FROM skill_badges WHERE name ILIKE '%python%' LIMIT 1;

-- BUILD 5: Team Events
CREATE TABLE IF NOT EXISTS team_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id UUID REFERENCES teams(id) ON DELETE CASCADE NOT NULL,
  opportunity_id UUID REFERENCES opportunities(id),
  event_name TEXT NOT NULL,
  ended_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  debrief_deadline TIMESTAMPTZ DEFAULT NOW() + INTERVAL '48 hours',
  debrief_completed BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE team_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "team_member_read_events" ON team_events FOR SELECT
  USING (EXISTS (SELECT 1 FROM team_members WHERE team_id = team_events.team_id AND student_id = auth.uid()));

-- BUILD 6: Smart Digest
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS is_batched BOOLEAN DEFAULT FALSE;

-- BUILD 3: DNA Quiz RPC
CREATE OR REPLACE FUNCTION submit_dna_quiz(
  p_student_id UUID,
  p_responses  JSONB  -- [{"question_id": "uuid", "selected_option": "a"|"b"|"c"|"d"}]
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_counts       JSONB := '{"Builder":0,"Strategist":0,"Creative":0,"Executor":0}'::JSONB;
  v_resp         RECORD;
  v_question     RECORD;
  v_opt          TEXT;
  v_archetype    TEXT;
  v_max_count    INTEGER := 0;
  v_total        INTEGER := 0;
  v_confidence   NUMERIC;
  v_arch_count   INTEGER;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM student_profiles WHERE id = p_student_id AND is_active = TRUE) THEN
    RAISE EXCEPTION 'Student not found' USING ERRCODE = 'P0001';
  END IF;

  IF jsonb_array_length(p_responses) < 3 THEN
    RAISE EXCEPTION 'At least 3 responses required' USING ERRCODE = 'P0002';
  END IF;

  -- Delete previous responses for this student
  DELETE FROM dna_quiz_responses WHERE student_id = p_student_id;

  -- Insert new responses and tally archetype votes
  FOR v_resp IN SELECT * FROM jsonb_array_elements(p_responses) LOOP
    SELECT * INTO v_question
    FROM dna_quiz_questions
    WHERE id = (v_resp.value->>'question_id')::UUID;

    IF NOT FOUND THEN CONTINUE; END IF;

    v_opt := v_resp.value->>'selected_option';

    -- Map selected option to archetype
    v_archetype := CASE v_opt
      WHEN 'a' THEN v_question.archetype_a
      WHEN 'b' THEN v_question.archetype_b
      WHEN 'c' THEN v_question.archetype_c
      WHEN 'd' THEN v_question.archetype_d
      ELSE NULL
    END;

    IF v_archetype IS NULL THEN CONTINUE; END IF;

    -- Insert individual response
    INSERT INTO dna_quiz_responses (student_id, question_id, selected_option)
    VALUES (p_student_id, v_question.id, v_opt)
    ON CONFLICT DO NOTHING;

    -- Increment tally
    v_arch_count := COALESCE((v_counts->>v_archetype)::INTEGER, 0) + 1;
    v_counts := jsonb_set(v_counts, ARRAY[v_archetype], to_jsonb(v_arch_count));
    v_total := v_total + 1;
  END LOOP;

  IF v_total = 0 THEN
    RAISE EXCEPTION 'No valid responses processed' USING ERRCODE = 'P0003';
  END IF;

  -- Find dominant archetype (highest count)
  SELECT key INTO v_archetype
  FROM jsonb_each_text(v_counts)
  ORDER BY value::INTEGER DESC
  LIMIT 1;

  v_max_count := (v_counts->>v_archetype)::INTEGER;
  v_confidence := ROUND((v_max_count::NUMERIC / v_total::NUMERIC), 2);

  -- Update student_dna with archetype
  UPDATE student_dna
  SET archetype = v_archetype::archetype_type,
      archetype_confidence = v_confidence,
      updated_at = NOW()
  WHERE student_id = p_student_id;

  -- Seed initial TrustScore integrity for completing onboarding
  UPDATE trust_scores SET
    integrity_score = GREATEST(integrity_score, 40),
    community_score = GREATEST(community_score, 10),
    last_calculated = NOW()
  WHERE student_id = p_student_id;

  -- Notify student
  INSERT INTO notifications (student_id, type, title, body, data)
  VALUES (
    p_student_id, 'dna_quiz_complete',
    '🧬 Archetype Unlocked: ' || v_archetype || '!',
    'Your Work Style DNA has been set. Team matches and opportunities will now be personalised.',
    jsonb_build_object('archetype', v_archetype, 'confidence', v_confidence, 'scores', v_counts)
  );

  RETURN jsonb_build_object(
    'archetype', v_archetype,
    'confidence', v_confidence,
    'scores', v_counts,
    'total_responses', v_total
  );
END;
$$;
GRANT EXECUTE ON FUNCTION submit_dna_quiz TO authenticated;
