-- =============================================================================
-- ElevateAI — Auth Triggers & User Management
-- File: migrations/05_auth_triggers.sql
-- =============================================================================
-- Handles Supabase Auth ↔ student_profiles synchronization.
-- On every new auth.users INSERT → auto-creates profile + DNA + TrustScore.
-- =============================================================================


-- ─────────────────────────────────────────────────────────────────────────────
-- 1. handle_new_auth_user()
--    Fires on INSERT to auth.users (Supabase's internal auth table).
--    Creates the three core rows every student needs.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION handle_new_auth_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_college_id  UUID;
  v_full_name   TEXT;
  v_roll_number TEXT;
  v_course      TEXT;
  v_branch      TEXT;
  v_year        SMALLINT;
BEGIN
  -- ── Extract metadata passed during signUp() ──────────────────────────────
  -- Flutter app should call: supabase.auth.signUp(email, password, data: {...})
  v_college_id  := (NEW.raw_user_meta_data->>'college_id')::UUID;
  v_full_name   := COALESCE(
    NEW.raw_user_meta_data->>'full_name',
    SPLIT_PART(NEW.email, '@', 1)
  );
  v_roll_number := NEW.raw_user_meta_data->>'roll_number';
  v_course      := NEW.raw_user_meta_data->>'course';
  v_branch      := NEW.raw_user_meta_data->>'branch';
  v_year        := (NEW.raw_user_meta_data->>'year_of_study')::SMALLINT;

  -- ── Resolve college_id (fallback to first verified college) ─────────────
  IF v_college_id IS NULL THEN
    SELECT id INTO v_college_id
    FROM public.colleges
    WHERE is_verified = TRUE
    ORDER BY created_at
    LIMIT 1;
  END IF;

  -- ── Create student_profiles row ──────────────────────────────────────────
  INSERT INTO public.student_profiles (
    id, college_id, full_name, email,
    roll_number, course, branch, year_of_study,
    is_active
  ) VALUES (
    NEW.id,
    COALESCE(v_college_id, 'c1000000-0000-0000-0000-000000000001'), -- Fixed to match seed data
    v_full_name,
    NEW.email,
    v_roll_number,
    v_course,
    v_branch,
    v_year,
    TRUE
  )
  ON CONFLICT (id) DO NOTHING;

  -- ── Create student_dna blank record ──────────────────────────────────────
  INSERT INTO public.student_dna (
    student_id,
    top_skills, goals_short_term, goals_long_term,
    ai_strengths, ai_growth_areas,
    target_roles, preferred_industries,
    availability
  ) VALUES (
    NEW.id,
    '{}', '{}', '{}',
    '{}', '{}',
    '{}', '{}',
    '{}'::JSONB
  )
  ON CONFLICT (student_id) DO NOTHING;

  -- ── Create trust_scores zero record ──────────────────────────────────────
  INSERT INTO public.trust_scores (
    student_id,
    overall_score, tier,
    reliability_score, collaboration_score,
    integrity_score, skill_validation_score, community_score
  ) VALUES (
    NEW.id,
    0, 'Unverified',
    0, 0, 0, 0, 0
  )
  ON CONFLICT (student_id) DO NOTHING;

  -- ── Initial trust history entry ──────────────────────────────────────────
  INSERT INTO public.trust_score_history (
    student_id, overall_score, delta, reason, source
  ) VALUES (
    NEW.id, 0, 0,
    'Account created — TrustScore initialized',
    'system'
  );

  -- ── Welcome notification ─────────────────────────────────────────────────
  INSERT INTO public.notifications (student_id, type, title, body, data)
  VALUES (
    NEW.id,
    'welcome',
    '🎉 Welcome to ElevateAI!',
    'Your Student Success OS is ready. Complete your profile to unlock DNA Engine and start getting matched with opportunities.',
    '{"next_steps": ["Complete your profile", "Add 3+ skills", "Explore matched opportunities"]}'::JSONB
  );

  RETURN NEW;

EXCEPTION WHEN OTHERS THEN
  -- Never block auth signup due to profile creation errors
  -- Log the error but allow the user to be created
  RAISE WARNING 'handle_new_auth_user failed for %: %', NEW.id, SQLERRM;
  RETURN NEW;
END;
$$;


-- ── Attach trigger to auth.users ─────────────────────────────────────────────
-- IMPORTANT: This requires superuser or Supabase Dashboard.
-- Run via: Dashboard → Database → Functions → trigger_on_auth_user_created

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_auth_user();


-- ─────────────────────────────────────────────────────────────────────────────
-- 2. handle_auth_user_deleted()
--    Soft-deletes student profile when auth user is deleted.
--    Preserves data for audit purposes.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION handle_auth_user_deleted()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.student_profiles
  SET
    is_active = FALSE,
    deleted_at = NOW()
  WHERE id = OLD.id;

  -- Withdraw all active applications
  UPDATE public.opportunity_applications
  SET status = 'withdrawn'
  WHERE student_id = OLD.id
    AND status IN ('draft', 'submitted', 'under_review');

  -- Leave all teams
  UPDATE public.team_members
  SET status = 'left', left_at = NOW()
  WHERE student_id = OLD.id
    AND status = 'active';

  RETURN OLD;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'handle_auth_user_deleted failed for %: %', OLD.id, SQLERRM;
  RETURN OLD;
END;
$$;

CREATE OR REPLACE TRIGGER on_auth_user_deleted
  BEFORE DELETE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_auth_user_deleted();


-- ─────────────────────────────────────────────────────────────────────────────
-- 3. handle_auth_user_updated()
--    Syncs email/phone changes from auth.users → student_profiles
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION handle_auth_user_updated()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Sync email changes
  IF NEW.email IS DISTINCT FROM OLD.email THEN
    UPDATE public.student_profiles
    SET email = NEW.email
    WHERE id = NEW.id;
  END IF;

  -- Sync phone changes
  IF NEW.phone IS DISTINCT FROM OLD.phone THEN
    UPDATE public.student_profiles
    SET phone = NEW.phone
    WHERE id = NEW.id;
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'handle_auth_user_updated failed for %: %', NEW.id, SQLERRM;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER on_auth_user_updated
  AFTER UPDATE OF email, phone ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_auth_user_updated();


-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Additional flywheel triggers
-- ─────────────────────────────────────────────────────────────────────────────

-- When team event completes → boost all active members' reliability score
CREATE OR REPLACE FUNCTION boost_trust_on_team_completion()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Only fire when team moves to 'completed'
  IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
    -- Boost reliability for all active members
    UPDATE trust_scores ts
    SET
      reliability_score = LEAST(100, ts.reliability_score + 5),
      community_score   = LEAST(100, ts.community_score + 3),
      overall_score     = LEAST(100,
        0.30 * LEAST(100, ts.reliability_score + 5) +
        0.25 * ts.collaboration_score +
        0.20 * ts.integrity_score +
        0.15 * ts.skill_validation_score +
        0.10 * LEAST(100, ts.community_score + 3)
      ),
      last_calculated   = NOW()
    FROM team_members tm
    WHERE tm.team_id = NEW.id
      AND tm.status = 'active'
      AND ts.student_id = tm.student_id;

    -- Log for all active members
    INSERT INTO trust_score_history (student_id, overall_score, delta, reason, source, snapshot)
    SELECT
      tm.student_id,
      ts.overall_score,
      8,  -- 5 reliability + 3 community
      FORMAT('Team completed: %s', NEW.name),
      'team_completion',
      jsonb_build_object('team_id', NEW.id, 'team_name', NEW.name)
    FROM team_members tm
    JOIN trust_scores ts ON ts.student_id = tm.student_id
    WHERE tm.team_id = NEW.id AND tm.status = 'active';

    -- Notify each member
    INSERT INTO notifications (student_id, type, title, body, data)
    SELECT
      tm.student_id,
      'team_completed',
      '🎯 Team Project Completed!',
      FORMAT('Congrats! Your team "%s" has completed. Your TrustScore has been updated.', NEW.name),
      jsonb_build_object('team_id', NEW.id, 'team_name', NEW.name, 'trust_delta', 8)
    FROM team_members tm
    WHERE tm.team_id = NEW.id AND tm.status = 'active';
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trust_on_team_completion
  AFTER UPDATE OF status ON teams
  FOR EACH ROW
  EXECUTE FUNCTION boost_trust_on_team_completion();


-- When application is accepted → boost integrity score
CREATE OR REPLACE FUNCTION boost_trust_on_acceptance()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.status = 'accepted' AND OLD.status != 'accepted' THEN
    UPDATE trust_scores
    SET
      integrity_score = LEAST(100, integrity_score + 8),
      community_score = LEAST(100, community_score + 5),
      overall_score   = LEAST(100,
        0.30 * reliability_score +
        0.25 * collaboration_score +
        0.20 * LEAST(100, integrity_score + 8) +
        0.15 * skill_validation_score +
        0.10 * LEAST(100, community_score + 5)
      ),
      last_calculated = NOW()
    WHERE student_id = NEW.student_id;

    INSERT INTO trust_score_history (student_id, overall_score, delta, reason, source)
    SELECT student_id, overall_score, 13,
           'Opportunity application accepted',
           'opportunity_accepted'
    FROM trust_scores WHERE student_id = NEW.student_id;

    INSERT INTO notifications (student_id, type, title, body, data)
    VALUES (
      NEW.student_id,
      'application_accepted',
      '🎉 Application Accepted!',
      'Congratulations! Your application was accepted. Your TrustScore received a boost!',
      jsonb_build_object(
        'opportunity_id', NEW.opportunity_id,
        'trust_delta', 13
      )
    );
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trust_on_app_acceptance
  AFTER UPDATE OF status ON opportunity_applications
  FOR EACH ROW
  EXECUTE FUNCTION boost_trust_on_acceptance();


-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Materialized view for leaderboard (refresh every 15 min via pg_cron)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_trust_leaderboard AS
  SELECT
    sp.id,
    sp.full_name,
    sp.college_id,
    sp.course,
    sp.branch,
    sp.year_of_study,
    c.short_name AS college_short_name,
    dna.archetype,
    dna.top_skills,
    ts.overall_score,
    ts.tier,
    RANK() OVER (ORDER BY ts.overall_score DESC) AS rank_overall,
    RANK() OVER (PARTITION BY sp.college_id ORDER BY ts.overall_score DESC) AS rank_college
  FROM student_profiles sp
  JOIN student_dna    dna ON dna.student_id = sp.id
  JOIN trust_scores   ts  ON ts.student_id  = sp.id
  JOIN colleges       c   ON c.id = sp.college_id
  WHERE sp.is_active = TRUE AND sp.deleted_at IS NULL
  ORDER BY ts.overall_score DESC;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_leaderboard_id ON mv_trust_leaderboard(id);
CREATE INDEX IF NOT EXISTS idx_mv_leaderboard_college ON mv_trust_leaderboard(college_id, rank_college);
CREATE INDEX IF NOT EXISTS idx_mv_leaderboard_score ON mv_trust_leaderboard(overall_score DESC);

-- Function to refresh the leaderboard (called by pg_cron)
CREATE OR REPLACE FUNCTION refresh_trust_leaderboard()
RETURNS void
LANGUAGE SQL
SECURITY DEFINER
AS $$
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_trust_leaderboard;
$$;

-- Schedule refresh (requires pg_cron on Pro tier):
-- SELECT cron.schedule('refresh-leaderboard', '*/15 * * * *', 'SELECT refresh_trust_leaderboard()');


-- ─────────────────────────────────────────────────────────────────────────────
-- 6. Performance indexes for high-traffic queries
-- ─────────────────────────────────────────────────────────────────────────────

-- Composite index: student lookup by college + year (team matching)
CREATE INDEX IF NOT EXISTS idx_sp_college_year_active
  ON student_profiles(college_id, year_of_study)
  WHERE is_active = TRUE AND deleted_at IS NULL;

-- Trust score + student for join-heavy leaderboard queries
CREATE INDEX IF NOT EXISTS idx_ts_student_score
  ON trust_scores(student_id, overall_score DESC)
  WHERE is_frozen = FALSE;

-- Opportunities: active + deadline for the main feed
CREATE INDEX IF NOT EXISTS idx_opp_active_deadline
  ON opportunities(apply_deadline ASC)
  WHERE status = 'active' AND deleted_at IS NULL;

-- Notifications: unread count (common query)
CREATE INDEX IF NOT EXISTS idx_notif_unread_count
  ON notifications(student_id, is_read)
  WHERE is_read = FALSE;

-- Applications: student's active apps
CREATE INDEX IF NOT EXISTS idx_apps_student_active
  ON opportunity_applications(student_id, status)
  WHERE status NOT IN ('withdrawn', 'rejected');

-- Team members: active membership
CREATE INDEX IF NOT EXISTS idx_tm_student_active
  ON team_members(student_id)
  WHERE status = 'active';


-- ─────────────────────────────────────────────────────────────────────────────
-- 7. Helper: jsonb_merge() for safe JSONB updates
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION jsonb_merge(original JSONB, override JSONB)
RETURNS JSONB
LANGUAGE SQL
IMMUTABLE
AS $$
  SELECT COALESCE(original, '{}') || COALESCE(override, '{}');
$$;
