-- =============================================================================
-- ElevateAI — M19: Peer Application Network Upgrades
-- File: migrations/22_peer_network_upgrades.sql
-- =============================================================================

-- 1. Success Stories Table
CREATE TABLE IF NOT EXISTS success_stories (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id        UUID REFERENCES student_profiles(id) ON DELETE CASCADE,
  opportunity_id    UUID REFERENCES opportunities(id) ON DELETE CASCADE,
  approval_year     INTEGER,
  amount_received   NUMERIC,
  journey_summary   TEXT,
  success_factors   TEXT[] DEFAULT '{}',
  challenges_faced  TEXT,
  strategy          TEXT,
  mistakes_avoided  TEXT,
  document_tips     TEXT,
  application_steps JSONB DEFAULT '[]', -- List of {step: string, date: string, status: string}
  is_verified       BOOLEAN DEFAULT FALSE,
  created_at        TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Guidance Requests (Mentorship Flow)
CREATE TABLE IF NOT EXISTS guidance_requests (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id      UUID REFERENCES student_profiles(id) ON DELETE CASCADE,
  mentor_id         UUID REFERENCES student_profiles(id) ON DELETE CASCADE,
  opportunity_id    UUID REFERENCES opportunities(id) ON DELETE CASCADE,
  subject           TEXT,
  message           TEXT,
  status            TEXT DEFAULT 'pending', -- pending | accepted | declined | completed
  created_at        TIMESTAMPTZ DEFAULT NOW()
);

-- 3. RPC: get_success_story_feed
CREATE OR REPLACE FUNCTION get_success_story_feed(
  p_student_id UUID,
  p_limit      INTEGER DEFAULT 20
)
RETURNS TABLE (
  story_id          UUID,
  student_name      TEXT,
  avatar_url        TEXT,
  opportunity_title TEXT,
  approval_year     INTEGER,
  amount_received   NUMERIC,
  journey_summary   TEXT,
  match_score       INTEGER
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_my_dna RECORD;
BEGIN
  SELECT * INTO v_my_dna FROM student_dna WHERE student_id = p_student_id;

  RETURN QUERY
  SELECT
    ss.id,
    sp.full_name,
    sp.avatar_url,
    o.title,
    ss.approval_year,
    ss.amount_received,
    ss.journey_summary,
    -- Simple match score based on DNA skills overlap
    (CASE WHEN o.required_skills && v_my_dna.top_skills THEN 50 ELSE 20 END) as match_score
  FROM success_stories ss
  JOIN student_profiles sp ON sp.id = ss.student_id
  JOIN opportunities o ON o.id = ss.opportunity_id
  ORDER BY match_score DESC, ss.created_at DESC
  LIMIT p_limit;
END;
$$;

-- 4. RPC: manage_guidance_request
CREATE OR REPLACE FUNCTION manage_guidance_request(
  p_mentor_id      UUID,
  p_opportunity_id UUID,
  p_subject        TEXT,
  p_message        TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_requester_id UUID := auth.uid();
  v_request_id   UUID;
BEGIN
  INSERT INTO guidance_requests (requester_id, mentor_id, opportunity_id, subject, message)
  VALUES (v_requester_id, p_mentor_id, p_opportunity_id, p_subject, p_message)
  RETURNING id INTO v_request_id;

  -- Notify Mentor
  INSERT INTO notifications (student_id, type, title, body, data)
  SELECT p_mentor_id, 'guidance_request', 'New Guidance Request',
         full_name || ' is asking for help with ' || (SELECT title FROM opportunities WHERE id = p_opportunity_id),
         jsonb_build_object('request_id', v_request_id, 'requester_id', v_requester_id)
  FROM student_profiles WHERE id = v_requester_id;

  RETURN jsonb_build_object('success', TRUE, 'request_id', v_request_id);
END;
$$;

-- 5. Add RLS
ALTER TABLE success_stories ENABLE ROW LEVEL SECURITY;
ALTER TABLE guidance_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read verified stories" ON success_stories
  FOR SELECT USING (is_verified = TRUE OR student_id = auth.uid());

CREATE POLICY "Users can manage own requests" ON guidance_requests
  FOR ALL USING (auth.uid() = requester_id OR auth.uid() = mentor_id);

GRANT EXECUTE ON FUNCTION get_success_story_feed TO authenticated;
GRANT EXECUTE ON FUNCTION manage_guidance_request TO authenticated;

-- 6. Enable Realtime
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE guidance_requests;
    END IF;
END $$;
