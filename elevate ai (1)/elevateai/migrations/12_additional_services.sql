-- ISSUE 2.2: Campus TV / Radio
CREATE TABLE IF NOT EXISTS broadcast_schedule (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ NOT NULL,
  host_name TEXT,
  category TEXT, -- 'news', 'sports', 'educational', 'entertainment'
  thumbnail_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS recordings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  video_url TEXT NOT NULL,
  thumbnail_url TEXT,
  duration_seconds INTEGER,
  category TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS radio_shows (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  host_name TEXT,
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ NOT NULL,
  stream_url TEXT,
  is_live BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE broadcast_schedule ENABLE ROW LEVEL SECURITY;
ALTER TABLE recordings ENABLE ROW LEVEL SECURITY;
ALTER TABLE radio_shows ENABLE ROW LEVEL SECURITY;

CREATE POLICY "public_read_schedule" ON broadcast_schedule FOR SELECT USING (true);
CREATE POLICY "public_read_recordings" ON recordings FOR SELECT USING (true);
CREATE POLICY "public_read_radio" ON radio_shows FOR SELECT USING (true);

-- ISSUE 2.3: Trust Score Events
CREATE TABLE IF NOT EXISTS trust_score_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID REFERENCES student_profiles(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL, -- 'badge_earned', 'peer_review', 'attendance', 'project_completed'
  dimension TEXT NOT NULL,  -- 'credibility', 'reliability', 'social', 'competency', 'integrity'
  delta DECIMAL NOT NULL,
  reason_key TEXT NOT NULL,
  source_id UUID,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE trust_score_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own_trust_events" ON trust_score_events FOR SELECT USING (student_id = auth.uid());

-- ISSUE 2.5: Schemes
CREATE TABLE IF NOT EXISTS schemes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  eligibility_criteria JSONB NOT NULL DEFAULT '{}',
  amount_min INT,
  amount_max INT,
  deadline DATE,
  category TEXT,
  state TEXT,
  source_url TEXT,
  is_active BOOL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE schemes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "public_read_schemes" ON schemes FOR SELECT USING (is_active = true);
