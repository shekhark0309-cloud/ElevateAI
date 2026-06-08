-- =============================================================================
-- ElevateAI — Core Database Schema (Reconstructed)
-- File: migrations/01_base_schema.sql
-- =============================================================================

-- ── ENUMS ───────────────────────────────────────────────────────────────────

CREATE TYPE archetype_type AS ENUM ('Builder', 'Strategist', 'Creative', 'Executor');
CREATE TYPE trust_tier_type AS ENUM ('Unverified', 'Bronze', 'Silver', 'Gold', 'Platinum');
CREATE TYPE verify_status AS ENUM ('pending', 'verified', 'rejected');
CREATE TYPE badge_category AS ENUM ('technical', 'soft_skills', 'leadership', 'community');
CREATE TYPE opportunity_type AS ENUM ('hackathon', 'internship', 'scholarship', 'fellowship', 'research', 'competition', 'workshop');
CREATE TYPE application_status AS ENUM ('draft', 'submitted', 'under_review', 'shortlisted', 'accepted', 'rejected', 'withdrawn');
CREATE TYPE team_status AS ENUM ('forming', 'active', 'completed', 'disbanded');
CREATE TYPE team_role AS ENUM ('leader', 'member');

-- ── TABLES ──────────────────────────────────────────────────────────────────

-- 1. Colleges
CREATE TABLE colleges (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name         TEXT NOT NULL,
  short_name   TEXT NOT NULL,
  domain       TEXT UNIQUE,
  state        TEXT,
  is_verified  BOOLEAN DEFAULT FALSE,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Student Profiles
CREATE TABLE student_profiles (
  id                UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  college_id        UUID REFERENCES colleges(id),
  full_name         TEXT NOT NULL,
  email             TEXT UNIQUE NOT NULL,
  phone             TEXT UNIQUE,
  roll_number       TEXT,
  course            TEXT,
  branch            TEXT,
  year_of_study     SMALLINT,
  graduation_year   INTEGER,
  cgpa              NUMERIC(3,2),
  avatar_url        TEXT,
  state             TEXT,
  category          TEXT DEFAULT 'general',
  family_income     NUMERIC,
  gender            TEXT,
  is_active         BOOLEAN DEFAULT TRUE,
  created_at        TIMESTAMPTZ DEFAULT NOW(),
  updated_at        TIMESTAMPTZ DEFAULT NOW(),
  deleted_at        TIMESTAMPTZ
);

-- 3. Student DNA
CREATE TABLE student_dna (
  id                     UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id             UUID UNIQUE NOT NULL REFERENCES student_profiles(id) ON DELETE CASCADE,
  archetype              archetype_type,
  archetype_confidence   NUMERIC(3,2) DEFAULT 0,
  ai_summary             TEXT,
  ai_strengths           TEXT[] DEFAULT '{}',
  ai_growth_areas        TEXT[] DEFAULT '{}',
  ai_team_role_hint      TEXT,
  top_skills             TEXT[] DEFAULT '{}',
  goals_short_term       TEXT[] DEFAULT '{}',
  goals_long_term        TEXT[] DEFAULT '{}',
  target_roles           TEXT[] DEFAULT '{}',
  preferred_industries   TEXT[] DEFAULT '{}',
  availability           JSONB DEFAULT '{}',
  prefers_remote         BOOLEAN DEFAULT FALSE,
  team_size_preference   TEXT,
  preferred_study_time   TEXT,
  study_streak           INTEGER DEFAULT 0,
  focus_score            NUMERIC(4,1) DEFAULT 0,
  version                INTEGER DEFAULT 1,
  last_ai_updated        TIMESTAMPTZ,
  updated_at             TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Trust Scores
CREATE TABLE trust_scores (
  id                     UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id             UUID UNIQUE NOT NULL REFERENCES student_profiles(id) ON DELETE CASCADE,
  overall_score          NUMERIC(4,1) DEFAULT 0,
  tier                   trust_tier_type DEFAULT 'Unverified',
  reliability_score      NUMERIC(4,1) DEFAULT 0,
  collaboration_score    NUMERIC(4,1) DEFAULT 0,
  integrity_score        NUMERIC(4,1) DEFAULT 0,
  skill_validation_score NUMERIC(4,1) DEFAULT 0,
  community_score        NUMERIC(4,1) DEFAULT 0,
  erp_attendance_pct     NUMERIC(5,2),
  erp_assignment_score   NUMERIC(5,2),
  erp_synced_at          TIMESTAMPTZ,
  is_frozen              BOOLEAN DEFAULT FALSE,
  last_calculated        TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Trust Score History
CREATE TABLE trust_score_history (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id     UUID NOT NULL REFERENCES student_profiles(id) ON DELETE CASCADE,
  overall_score  NUMERIC(4,1) NOT NULL,
  delta          NUMERIC(4,1) DEFAULT 0,
  reason         TEXT,
  source         TEXT, -- 'system', 'erp', 'peer_rating', 'badge', etc.
  snapshot       JSONB,
  recorded_at    TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Skill Badges (Master list)
CREATE TABLE skill_badges (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name         TEXT NOT NULL,
  slug         TEXT UNIQUE NOT NULL,
  category     badge_category NOT NULL,
  level        SMALLINT DEFAULT 1, -- 1=Beginner, 2=Intermediate, 3=Expert
  xp_value     INTEGER DEFAULT 100,
  icon_url     TEXT,
  description  TEXT,
  is_active    BOOLEAN DEFAULT TRUE,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- 7. Student Badges (Earned)
CREATE TABLE student_badges (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id      UUID NOT NULL REFERENCES student_profiles(id) ON DELETE CASCADE,
  badge_id        UUID NOT NULL REFERENCES skill_badges(id),
  verify_status   verify_status DEFAULT 'pending',
  evidence_url    TEXT,
  evidence_meta   JSONB DEFAULT '{}',
  earned_at       TIMESTAMPTZ DEFAULT NOW(),
  verified_at     TIMESTAMPTZ,
  verified_by     UUID REFERENCES auth.users(id), -- Admin or Peer
  updated_at      TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(student_id, badge_id)
);

-- 8. Student Skills (Verified + Self-reported)
CREATE TABLE student_skills (
  student_id   UUID NOT NULL REFERENCES student_profiles(id) ON DELETE CASCADE,
  skill_name   TEXT NOT NULL,
  proficiency  SMALLINT CHECK (proficiency BETWEEN 1 AND 5),
  is_verified  BOOLEAN DEFAULT FALSE,
  source       TEXT, -- 'self', 'badge', 'project', 'endorsement'
  updated_at   TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (student_id, skill_name)
);

-- 9. Opportunities
CREATE TABLE opportunities (
  id                     UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title                  TEXT NOT NULL,
  type                   opportunity_type NOT NULL,
  organizer_name         TEXT NOT NULL,
  organizer_id           UUID, -- If organizer is on the platform
  organizer_trust_score  NUMERIC(4,1),
  description            TEXT,
  prize_amount           NUMERIC,
  stipend_amount         NUMERIC,
  apply_deadline         TIMESTAMPTZ NOT NULL,
  event_start            TIMESTAMPTZ,
  event_end              TIMESTAMPTZ,
  banner_url             TEXT,
  apply_url              TEXT,
  required_skills        TEXT[] DEFAULT '{}',
  eligible_states        TEXT[] DEFAULT '{}',
  eligible_categories    TEXT[] DEFAULT '{}',
  eligible_courses       TEXT[] DEFAULT '{}',
  min_year               SMALLINT,
  max_year               SMALLINT,
  min_cgpa               NUMERIC(3,2),
  max_family_income      NUMERIC,
  min_trust_score        NUMERIC DEFAULT 0,
  is_featured            BOOLEAN DEFAULT FALSE,
  is_verified            BOOLEAN DEFAULT FALSE,
  status                 TEXT DEFAULT 'active', -- 'active', 'closed', 'cancelled'
  meta                   JSONB DEFAULT '{}',
  posted_by              UUID REFERENCES auth.users(id),
  created_at             TIMESTAMPTZ DEFAULT NOW(),
  updated_at             TIMESTAMPTZ DEFAULT NOW(),
  deleted_at             TIMESTAMPTZ
);

-- 10. Opportunity Applications
CREATE TABLE opportunity_applications (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  opportunity_id  UUID NOT NULL REFERENCES opportunities(id),
  student_id      UUID NOT NULL REFERENCES student_profiles(id) ON DELETE CASCADE,
  status          application_status DEFAULT 'draft',
  cover_note      TEXT,
  resume_url      TEXT,
  answers         JSONB DEFAULT '{}',
  submitted_at    TIMESTAMPTZ,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(opportunity_id, student_id)
);

-- 11. Teams
CREATE TABLE teams (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name                TEXT NOT NULL,
  tagline             TEXT,
  leader_id           UUID NOT NULL REFERENCES student_profiles(id),
  college_id          UUID REFERENCES colleges(id),
  opportunity_id      UUID REFERENCES opportunities(id), -- If team is for specific opp
  required_skills     TEXT[] DEFAULT '{}',
  required_archetypes archetype_type[] DEFAULT '{}',
  max_members         SMALLINT DEFAULT 5,
  is_open             BOOLEAN DEFAULT TRUE,
  status              team_status DEFAULT 'forming',
  created_at          TIMESTAMPTZ DEFAULT NOW(),
  updated_at          TIMESTAMPTZ DEFAULT NOW(),
  deleted_at          TIMESTAMPTZ
);

-- 12. Team Members
CREATE TABLE team_members (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  team_id      UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  student_id   UUID NOT NULL REFERENCES student_profiles(id) ON DELETE CASCADE,
  role         team_role DEFAULT 'member',
  status       TEXT DEFAULT 'invited', -- 'invited', 'active', 'left', 'removed'
  joined_at    TIMESTAMPTZ,
  invited_by   UUID REFERENCES student_profiles(id),
  left_at      TIMESTAMPTZ,
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(team_id, student_id)
);

-- 13. Peer Ratings
CREATE TABLE peer_ratings (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  rater_id       UUID NOT NULL REFERENCES student_profiles(id),
  ratee_id       UUID NOT NULL REFERENCES student_profiles(id),
  context_type   TEXT NOT NULL, -- 'team', 'hackathon', 'mentorship'
  context_id     UUID, -- team_id or opportunity_id
  overall        NUMERIC(3,2) CHECK (overall BETWEEN 1 AND 5),
  dimensions     JSONB DEFAULT '{}', -- communication, reliability, technical
  comment        TEXT,
  is_anonymous   BOOLEAN DEFAULT FALSE,
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

-- 14. Notifications
CREATE TABLE notifications (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id   UUID NOT NULL REFERENCES student_profiles(id) ON DELETE CASCADE,
  type         TEXT NOT NULL,
  title        TEXT NOT NULL,
  body         TEXT,
  data         JSONB DEFAULT '{}',
  is_read      BOOLEAN DEFAULT FALSE,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- 15. Scam Reports
CREATE TABLE scam_reports (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reported_by     UUID REFERENCES student_profiles(id),
  opportunity_id  UUID REFERENCES opportunities(id),
  category        TEXT NOT NULL,
  status          TEXT DEFAULT 'pending', -- 'pending', 'investigating', 'confirmed', 'dismissed'
  title           TEXT,
  description     TEXT,
  evidence_urls   TEXT[] DEFAULT '{}',
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- 16. Student Projects
CREATE TABLE student_projects (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id   UUID NOT NULL REFERENCES student_profiles(id) ON DELETE CASCADE,
  title        TEXT NOT NULL,
  description  TEXT,
  tech_stack   TEXT[] DEFAULT '{}',
  role         TEXT,
  outcome      TEXT,
  github_url   TEXT,
  live_url     TEXT,
  is_featured  BOOLEAN DEFAULT FALSE,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- 17. Student Achievements
CREATE TABLE student_achievements (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id        UUID NOT NULL REFERENCES student_profiles(id) ON DELETE CASCADE,
  title             TEXT NOT NULL,
  achievement_type  TEXT, -- 'award', 'certification', 'publication'
  issued_by         TEXT,
  issued_at         DATE,
  credential_url    TEXT,
  is_verified       BOOLEAN DEFAULT FALSE,
  created_at        TIMESTAMPTZ DEFAULT NOW()
);

-- ── ENABLE RLS ON ALL TABLES ──────────────────────────────────────────────

ALTER TABLE colleges ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_dna ENABLE ROW LEVEL SECURITY;
ALTER TABLE trust_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE trust_score_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE skill_badges ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_badges ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_skills ENABLE ROW LEVEL SECURITY;
ALTER TABLE opportunities ENABLE ROW LEVEL SECURITY;
ALTER TABLE opportunity_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE peer_ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE scam_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_achievements ENABLE ROW LEVEL SECURITY;
