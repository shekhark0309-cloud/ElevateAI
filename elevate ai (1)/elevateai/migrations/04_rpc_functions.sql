-- =============================================================================
-- ElevateAI — Additional RPC Functions
-- File: migrations/04_rpc_functions.sql
-- =============================================================================
-- These RPCs implement the core business transactions with proper
-- flywheel effects: every action triggers DNA + TrustScore updates.
-- =============================================================================


-- ─────────────────────────────────────────────────────────────────────────────
-- 1. submit_peer_rating()
--    Submits a peer rating and immediately triggers TrustScore update.
--    Validates: can't rate yourself, must have shared team/context.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION submit_peer_rating(
  p_ratee_id     UUID,
  p_context_type TEXT,             -- 'hackathon','project','mentoring','team'
  p_context_id   UUID,             -- team_id or opportunity_application_id
  p_overall      NUMERIC,          -- 1.0 - 5.0
  p_dimensions   JSONB DEFAULT '{}', -- {"communication":4.5,"reliability":5.0,...}
  p_comment      TEXT DEFAULT NULL,
  p_is_anonymous BOOLEAN DEFAULT FALSE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_rater_id    UUID := auth.uid();
  v_rating_id   UUID;
  v_prev_score  NUMERIC;
  v_new_score   NUMERIC;
  v_collab      NUMERIC;
  v_result      JSONB;
BEGIN
  -- ── Validation ───────────────────────────────────────────────────────────
  IF v_rater_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'P0001';
  END IF;

  IF v_rater_id = p_ratee_id THEN
    RAISE EXCEPTION 'Cannot rate yourself' USING ERRCODE = 'P0002';
  END IF;

  IF p_overall < 1.0 OR p_overall > 5.0 THEN
    RAISE EXCEPTION 'Rating must be between 1.0 and 5.0' USING ERRCODE = 'P0003';
  END IF;

  -- Verify both students exist and are active
  IF NOT EXISTS (
    SELECT 1 FROM student_profiles
    WHERE id = p_ratee_id AND is_active = TRUE AND deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'Target student not found' USING ERRCODE = 'P0004';
  END IF;

  -- Verify they share the context (e.g., same team)
  IF p_context_type = 'team' AND p_context_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM team_members tm1
      JOIN team_members tm2 ON tm1.team_id = tm2.team_id
      WHERE tm1.student_id = v_rater_id
        AND tm2.student_id = p_ratee_id
        AND tm1.team_id = p_context_id
        AND tm1.status = 'active'
        AND tm2.status = 'active'
    ) THEN
      RAISE EXCEPTION 'You must be in the same active team to submit a rating'
        USING ERRCODE = 'P0005';
    END IF;
  END IF;

  -- ── Insert the rating ────────────────────────────────────────────────────
  INSERT INTO peer_ratings (
    rater_id, ratee_id, context_type, context_id,
    overall, dimensions, comment, is_anonymous
  ) VALUES (
    v_rater_id, p_ratee_id, p_context_type, p_context_id,
    p_overall, p_dimensions, p_comment, p_is_anonymous
  )
  RETURNING id INTO v_rating_id;

  -- ── Recalculate collaboration_score immediately ──────────────────────────
  -- (Full recalc via Edge Function runs async; this gives instant feedback)
  SELECT overall_score INTO v_prev_score
  FROM trust_scores WHERE student_id = p_ratee_id;

  SELECT COALESCE(AVG(overall), 0) * 20
  INTO v_collab
  FROM peer_ratings
  WHERE ratee_id = p_ratee_id;

  UPDATE trust_scores
  SET
    collaboration_score = LEAST(100, v_collab),
    overall_score = LEAST(100,
      0.30 * reliability_score +
      0.25 * LEAST(100, v_collab) +
      0.20 * integrity_score +
      0.15 * skill_validation_score +
      0.10 * community_score
    ),
    last_calculated = NOW()
  WHERE student_id = p_ratee_id
  RETURNING overall_score INTO v_new_score;

  -- ── Log the change ───────────────────────────────────────────────────────
  INSERT INTO trust_score_history (
    student_id, overall_score, delta, reason, source, snapshot
  ) VALUES (
    p_ratee_id,
    v_new_score,
    ROUND((v_new_score - v_prev_score)::NUMERIC, 2),
    FORMAT('Peer rating submitted (context: %s)', p_context_type),
    'peer_rating',
    jsonb_build_object(
      'rating_id', v_rating_id,
      'overall', p_overall,
      'context_type', p_context_type,
      'is_anonymous', p_is_anonymous
    )
  );

  -- ── Notify the ratee (if not anonymous) ─────────────────────────────────
  IF NOT p_is_anonymous THEN
    INSERT INTO notifications (student_id, type, title, body, data)
    VALUES (
      p_ratee_id,
      'peer_rating_received',
      '⭐ New Peer Rating!',
      FORMAT('You received a %.1f/5 rating for a %s collaboration.', p_overall, p_context_type),
      jsonb_build_object(
        'rating_id', v_rating_id,
        'overall', p_overall,
        'context_type', p_context_type,
        'trust_delta', ROUND((v_new_score - v_prev_score)::NUMERIC, 2)
      )
    );
  END IF;

  -- ── Also boost rater's community score (rewarding participation) ─────────
  UPDATE trust_scores
  SET
    community_score = LEAST(100, community_score + 0.5),
    overall_score = LEAST(100,
      0.30 * reliability_score +
      0.25 * collaboration_score +
      0.20 * integrity_score +
      0.15 * skill_validation_score +
      0.10 * LEAST(100, community_score + 0.5)
    ),
    last_calculated = NOW()
  WHERE student_id = v_rater_id;

  RETURN jsonb_build_object(
    'success', TRUE,
    'rating_id', v_rating_id,
    'ratee_new_trust_score', v_new_score,
    'trust_delta', ROUND((v_new_score - v_prev_score)::NUMERIC, 2)
  );

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM, 'code', SQLSTATE);
END;
$$;


-- ─────────────────────────────────────────────────────────────────────────────
-- 2. award_badge()
--    Awards a badge to a student with optional verification evidence.
--    Also updates DNA top_skills and TrustScore.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION award_badge(
  p_student_id   UUID,
  p_badge_id     UUID,
  p_evidence_url TEXT DEFAULT NULL,
  p_evidence_meta JSONB DEFAULT '{}',
  p_auto_verify  BOOLEAN DEFAULT FALSE  -- TRUE for system-issued badges
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_badge_name     TEXT;
  v_badge_category badge_category;
  v_badge_level    SMALLINT;
  v_student_badge_id UUID;
  v_verify_status  verify_status;
  v_xp_value       INTEGER;
BEGIN
  -- ── Validate badge exists ────────────────────────────────────────────────
  SELECT name, category, level, xp_value
  INTO v_badge_name, v_badge_category, v_badge_level, v_xp_value
  FROM skill_badges
  WHERE id = p_badge_id AND is_active = TRUE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Badge not found or inactive');
  END IF;

  -- ── Determine verify status ──────────────────────────────────────────────
  v_verify_status := CASE
    WHEN p_auto_verify THEN 'verified'::verify_status
    WHEN p_evidence_url IS NOT NULL THEN 'pending'::verify_status
    ELSE 'pending'::verify_status
  END;

  -- ── Upsert student_badge ─────────────────────────────────────────────────
  INSERT INTO student_badges (
    student_id, badge_id, verify_status,
    evidence_url, evidence_meta,
    verified_at, verified_by
  ) VALUES (
    p_student_id, p_badge_id, v_verify_status,
    p_evidence_url, p_evidence_meta,
    CASE WHEN p_auto_verify THEN NOW() ELSE NULL END,
    CASE WHEN p_auto_verify THEN p_student_id ELSE NULL END
  )
  ON CONFLICT (student_id, badge_id)
  DO UPDATE SET
    verify_status = EXCLUDED.verify_status,
    evidence_url = COALESCE(EXCLUDED.evidence_url, student_badges.evidence_url),
    evidence_meta = EXCLUDED.evidence_meta,
    updated_at = NOW()
  RETURNING id INTO v_student_badge_id;

  -- ── If auto-verified, immediately update TrustScore ──────────────────────
  IF p_auto_verify THEN
    UPDATE trust_scores
    SET
      skill_validation_score = LEAST(100, skill_validation_score + 5 * v_badge_level),
      overall_score = LEAST(100,
        0.30 * reliability_score +
        0.25 * collaboration_score +
        0.20 * integrity_score +
        0.15 * LEAST(100, skill_validation_score + 5 * v_badge_level) +
        0.10 * community_score
      ),
      last_calculated = NOW()
    WHERE student_id = p_student_id;

    -- Log trust history
    INSERT INTO trust_score_history (student_id, overall_score, delta, reason, source)
    SELECT student_id, overall_score,
           5 * v_badge_level,
           FORMAT('Badge awarded: %s (Level %s)', v_badge_name, v_badge_level),
           'badge'
    FROM trust_scores WHERE student_id = p_student_id;
  END IF;

  -- ── Notification ──────────────────────────────────────────────────────────
  INSERT INTO notifications (student_id, type, title, body, data)
  VALUES (
    p_student_id,
    'badge_awarded',
    FORMAT('🏅 Badge %s: %s', CASE WHEN p_auto_verify THEN 'Earned' ELSE 'Submitted' END, v_badge_name),
    CASE
      WHEN p_auto_verify THEN FORMAT('Congratulations! Your "%s" badge has been verified and added to your profile.', v_badge_name)
      ELSE FORMAT('Your "%s" badge submission is under review. You''ll be notified once verified.', v_badge_name)
    END,
    jsonb_build_object(
      'badge_id', p_badge_id,
      'badge_name', v_badge_name,
      'category', v_badge_category,
      'verify_status', v_verify_status,
      'xp_value', v_xp_value
    )
  );

  RETURN jsonb_build_object(
    'success', TRUE,
    'student_badge_id', v_student_badge_id,
    'badge_name', v_badge_name,
    'verify_status', v_verify_status,
    'xp_awarded', CASE WHEN p_auto_verify THEN v_xp_value ELSE 0 END,
    'message', CASE
      WHEN p_auto_verify THEN 'Badge awarded and verified!'
      ELSE 'Badge submitted for verification. Add evidence to speed up review.'
    END
  );

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;


-- ─────────────────────────────────────────────────────────────────────────────
-- 3. create_team_with_members()
--    Creates a team and adds initial members atomically.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION create_team_with_members(
  p_name              TEXT,
  p_tagline           TEXT DEFAULT NULL,
  p_required_skills   TEXT[] DEFAULT '{}',
  p_required_archetypes archetype_type[] DEFAULT '{}',
  p_max_members       SMALLINT DEFAULT 5,
  p_is_open           BOOLEAN DEFAULT TRUE,
  p_initial_members   UUID[] DEFAULT '{}'   -- additional member IDs (besides leader)
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_leader_id   UUID := auth.uid();
  v_college_id  UUID;
  v_team_id     UUID;
  v_member_id   UUID;
BEGIN
  IF v_leader_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF p_max_members < 1 OR p_max_members > 20 THEN
    RAISE EXCEPTION 'Team size must be between 1 and 20';
  END IF;

  -- Get leader's college
  SELECT college_id INTO v_college_id
  FROM student_profiles WHERE id = v_leader_id;

  -- ── Create team ──────────────────────────────────────────────────────────
  INSERT INTO teams (
    name, tagline, leader_id, college_id,
    required_skills, required_archetypes,
    max_members, is_open, status
  ) VALUES (
    p_name, p_tagline, v_leader_id, v_college_id,
    p_required_skills, p_required_archetypes,
    p_max_members, p_is_open, 'forming'
  )
  RETURNING id INTO v_team_id;

  -- ── Add leader as first member ───────────────────────────────────────────
  INSERT INTO team_members (team_id, student_id, role, status, joined_at)
  VALUES (v_team_id, v_leader_id, 'leader', 'active', NOW());

  -- ── Invite initial members ────────────────────────────────────────────────
  FOREACH v_member_id IN ARRAY p_initial_members LOOP
    IF v_member_id != v_leader_id THEN
      INSERT INTO team_members (team_id, student_id, role, status, invited_by)
      VALUES (v_team_id, v_member_id, 'member', 'invited', v_leader_id)
      ON CONFLICT (team_id, student_id) DO NOTHING;

      -- Notify invited members
      INSERT INTO notifications (student_id, type, title, body, data)
      VALUES (
        v_member_id,
        'team_invite',
        '🤝 Team Invitation!',
        FORMAT('You''ve been invited to join team "%s"', p_name),
        jsonb_build_object('team_id', v_team_id, 'team_name', p_name, 'invited_by', v_leader_id)
      );
    END IF;
  END LOOP;

  -- ── Boost leader's community score ───────────────────────────────────────
  UPDATE trust_scores
  SET
    community_score = LEAST(100, community_score + 5),
    overall_score = LEAST(100,
      0.30 * reliability_score + 0.25 * collaboration_score +
      0.20 * integrity_score + 0.15 * skill_validation_score +
      0.10 * LEAST(100, community_score + 5)
    ),
    last_calculated = NOW()
  WHERE student_id = v_leader_id;

  RETURN jsonb_build_object(
    'success', TRUE,
    'team_id', v_team_id,
    'team_name', p_name,
    'members_invited', array_length(p_initial_members, 1),
    'message', FORMAT('Team "%s" created! %s member(s) invited.', p_name, array_length(p_initial_members, 1))
  );

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;


-- ─────────────────────────────────────────────────────────────────────────────
-- 4. apply_to_opportunity()
--    Applies to an opportunity with eligibility validation.
--    Automatically submits if all required fields are present.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION apply_to_opportunity(
  p_opportunity_id UUID,
  p_cover_note     TEXT DEFAULT NULL,
  p_resume_url     TEXT DEFAULT NULL,
  p_answers        JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_student_id     UUID := auth.uid();
  v_app_id         UUID;
  v_opp            RECORD;
  v_student        RECORD;
  v_trust          RECORD;
  v_eligible       BOOLEAN := TRUE;
  v_ineligible_reason TEXT;
  v_auto_submit    BOOLEAN;
BEGIN
  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  -- ── Load opportunity ─────────────────────────────────────────────────────
  SELECT * INTO v_opp FROM opportunities
  WHERE id = p_opportunity_id AND status = 'active' AND deleted_at IS NULL;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Opportunity not found or closed');
  END IF;

  IF v_opp.apply_deadline < NOW() THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Application deadline has passed');
  END IF;

  -- ── Check for duplicate application ──────────────────────────────────────
  IF EXISTS (
    SELECT 1 FROM opportunity_applications
    WHERE opportunity_id = p_opportunity_id
      AND student_id = v_student_id
      AND status NOT IN ('withdrawn')
  ) THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'You have already applied for this opportunity');
  END IF;

  -- ── Load student profile for eligibility ────────────────────────────────
  SELECT sp.*, dna.top_skills
  INTO v_student
  FROM student_profiles sp
  LEFT JOIN student_dna dna ON dna.student_id = sp.id
  WHERE sp.id = v_student_id;

  SELECT overall_score INTO v_trust
  FROM trust_scores WHERE student_id = v_student_id;

  -- ── Eligibility checks ───────────────────────────────────────────────────
  IF ARRAY_LENGTH(v_opp.eligible_states, 1) > 0
     AND v_student.state NOT IN (SELECT UNNEST(v_opp.eligible_states)) THEN
    v_eligible := FALSE;
    v_ineligible_reason := FORMAT('This opportunity is only for students from %s', ARRAY_TO_STRING(v_opp.eligible_states, ', '));
  ELSIF v_opp.min_cgpa IS NOT NULL AND v_student.cgpa < v_opp.min_cgpa THEN
    v_eligible := FALSE;
    v_ineligible_reason := FORMAT('Minimum CGPA required: %.1f (your CGPA: %.1f)', v_opp.min_cgpa, v_student.cgpa);
  ELSIF v_opp.min_year IS NOT NULL AND v_student.year_of_study < v_opp.min_year THEN
    v_eligible := FALSE;
    v_ineligible_reason := FORMAT('This opportunity is for %s year students and above', v_opp.min_year);
  ELSIF v_opp.max_year IS NOT NULL AND v_student.year_of_study > v_opp.max_year THEN
    v_eligible := FALSE;
    v_ineligible_reason := FORMAT('This opportunity is only for students up to year %s', v_opp.max_year);
  ELSIF (v_trust.overall_score ?? 0) < v_opp.min_trust_score THEN
    v_eligible := FALSE;
    v_ineligible_reason := FORMAT('Minimum TrustScore required: %.0f (your score: %.0f). Build your profile to qualify.', v_opp.min_trust_score, COALESCE(v_trust.overall_score, 0));
  END IF;

  IF NOT v_eligible THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'error', 'Eligibility check failed',
      'reason', v_ineligible_reason,
      'eligible', FALSE
    );
  END IF;

  -- ── Create application ────────────────────────────────────────────────────
  v_auto_submit := p_cover_note IS NOT NULL AND p_resume_url IS NOT NULL;

  INSERT INTO opportunity_applications (
    opportunity_id, student_id, status,
    cover_note, resume_url, answers, submitted_at
  ) VALUES (
    p_opportunity_id, v_student_id,
    CASE WHEN v_auto_submit THEN 'submitted' ELSE 'draft' END,
    p_cover_note, p_resume_url, p_answers,
    CASE WHEN v_auto_submit THEN NOW() ELSE NULL END
  )
  RETURNING id INTO v_app_id;

  -- ── Notify student ────────────────────────────────────────────────────────
  INSERT INTO notifications (student_id, type, title, body, data)
  VALUES (
    v_student_id,
    'application_created',
    CASE WHEN v_auto_submit THEN '✅ Application Submitted!' ELSE '📝 Application Draft Saved' END,
    FORMAT(
      CASE WHEN v_auto_submit
        THEN 'Your application for "%s" has been submitted. Good luck!'
        ELSE 'Your draft for "%s" is saved. Add resume to submit.'
      END, v_opp.title
    ),
    jsonb_build_object(
      'application_id', v_app_id,
      'opportunity_id', p_opportunity_id,
      'opportunity_title', v_opp.title,
      'status', CASE WHEN v_auto_submit THEN 'submitted' ELSE 'draft' END
    )
  );

  -- ── Boost community score for engaging ───────────────────────────────────
  IF v_auto_submit THEN
    UPDATE trust_scores
    SET
      community_score = LEAST(100, community_score + 1),
      last_calculated = NOW()
    WHERE student_id = v_student_id;
  END IF;

  RETURN jsonb_build_object(
    'success', TRUE,
    'application_id', v_app_id,
    'status', CASE WHEN v_auto_submit THEN 'submitted' ELSE 'draft' END,
    'opportunity_title', v_opp.title,
    'eligible', TRUE,
    'message', CASE
      WHEN v_auto_submit THEN 'Application submitted successfully!'
      ELSE 'Draft saved. Complete with resume and cover note to submit.'
    END
  );

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;


-- ─────────────────────────────────────────────────────────────────────────────
-- 5. trigger_dna_update_on_events()
--    Helper function: calls async DNA recalculation after key events.
--    Used by other triggers to queue DNA updates.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION notify_dna_update_needed()
RETURNS TRIGGER AS $$
BEGIN
  -- Queue a notification that DNA needs to be recalculated
  -- The actual Edge Function call happens asynchronously
  PERFORM pg_notify(
    'dna_update_needed',
    json_build_object(
      'student_id', COALESCE(NEW.student_id, OLD.student_id),
      'trigger_table', TG_TABLE_NAME,
      'trigger_op', TG_OP
    )::text
  );
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Fire DNA update notification on skill verification
CREATE OR REPLACE TRIGGER notify_dna_on_skill_verify
  AFTER UPDATE OF is_verified ON student_skills
  FOR EACH ROW
  WHEN (NEW.is_verified = TRUE AND OLD.is_verified = FALSE)
  EXECUTE FUNCTION notify_dna_update_needed();

-- Fire DNA update notification on badge verification
CREATE OR REPLACE TRIGGER notify_dna_on_badge_verify
  AFTER UPDATE OF verify_status ON student_badges
  FOR EACH ROW
  WHEN (NEW.verify_status = 'verified' AND OLD.verify_status != 'verified')
  EXECUTE FUNCTION notify_dna_update_needed();

-- Fire DNA update notification on team membership activation
CREATE OR REPLACE TRIGGER notify_dna_on_team_join
  AFTER UPDATE OF status ON team_members
  FOR EACH ROW
  WHEN (NEW.status = 'active' AND OLD.status = 'invited')
  EXECUTE FUNCTION notify_dna_update_needed();


-- ─────────────────────────────────────────────────────────────────────────────
-- 6. get_student_dashboard()
--    Single RPC to power the Flutter home screen.
--    Returns DNA, TrustScore, notifications, recent activity.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION get_student_dashboard(p_student_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_profile    RECORD;
  v_dna        RECORD;
  v_trust      RECORD;
  v_notifs     JSONB;
  v_recent_opp JSONB;
  v_badges     JSONB;
BEGIN
  -- Validate ownership
  IF auth.uid() IS NOT NULL AND auth.uid() != p_student_id THEN
    RAISE EXCEPTION 'Access denied' USING ERRCODE = 'P0001';
  END IF;

  -- Profile + DNA + Trust
  SELECT sp.full_name, sp.avatar_url, sp.year_of_study, sp.cgpa, sp.branch
  INTO v_profile
  FROM student_profiles sp WHERE sp.id = p_student_id;

  SELECT archetype, ai_summary, ai_team_role_hint, top_skills, study_streak
  INTO v_dna
  FROM student_dna WHERE student_id = p_student_id;

  SELECT overall_score, tier, reliability_score, collaboration_score,
         integrity_score, skill_validation_score, community_score
  INTO v_trust
  FROM trust_scores WHERE student_id = p_student_id;

  -- Unread notifications (last 5)
  SELECT COALESCE(
    jsonb_agg(row_to_json(n) ORDER BY n.created_at DESC),
    '[]'::jsonb
  )
  INTO v_notifs
  FROM (
    SELECT id, type, title, body, data, created_at
    FROM notifications
    WHERE student_id = p_student_id AND is_read = FALSE
    ORDER BY created_at DESC LIMIT 5
  ) n;

  -- Recent opportunities (top 3 matching)
  SELECT COALESCE(jsonb_agg(row_to_json(o)), '[]'::jsonb)
  INTO v_recent_opp
  FROM (
    SELECT id, title, type, organizer_name, apply_deadline, is_featured
    FROM v_active_opportunities
    ORDER BY is_featured DESC, apply_deadline ASC
    LIMIT 3
  ) o;

  -- Verified badges count
  SELECT jsonb_build_object(
    'total', COUNT(*),
    'recent', COALESCE(jsonb_agg(jsonb_build_object(
      'name', sb.name, 'icon_url', sb.icon_url
    ) ORDER BY stb.earned_at DESC) FILTER (WHERE row_num <= 3), '[]')
  )
  INTO v_badges
  FROM (
    SELECT stb.*, sb.name, sb.icon_url,
           ROW_NUMBER() OVER (ORDER BY stb.earned_at DESC) AS row_num
    FROM student_badges stb
    JOIN skill_badges sb ON sb.id = stb.badge_id
    WHERE stb.student_id = p_student_id
      AND stb.verify_status = 'verified'
  ) stb, skill_badges sb WHERE stb.badge_id = sb.id;

  RETURN jsonb_build_object(
    'profile', row_to_json(v_profile),
    'dna', row_to_json(v_dna),
    'trust', row_to_json(v_trust),
    'unread_notifications', v_notifs,
    'featured_opportunities', v_recent_opp,
    'badges', v_badges
  );
END;
$$;


-- ─────────────────────────────────────────────────────────────────────────────
-- 7. verify_badge_by_peer()
--    Allows a peer to verify another student's badge.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION verify_badge_by_peer(
  p_student_badge_id UUID,
  p_verdict          verify_status,  -- 'verified' or 'rejected'
  p_note             TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_verifier_id  UUID := auth.uid();
  v_badge        RECORD;
BEGIN
  IF v_verifier_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT sb.*, skb.name AS badge_name
  INTO v_badge
  FROM student_badges sb
  JOIN skill_badges skb ON skb.id = sb.badge_id
  WHERE sb.id = p_student_badge_id
    AND sb.verify_status = 'pending';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Badge not found or not pending verification');
  END IF;

  IF v_badge.student_id = v_verifier_id THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Cannot verify your own badge');
  END IF;

  UPDATE student_badges
  SET
    verify_status = p_verdict,
    verified_by = v_verifier_id,
    verified_at = CASE WHEN p_verdict = 'verified' THEN NOW() ELSE NULL END,
    evidence_meta = evidence_meta || jsonb_build_object(
      'verifier_note', p_note,
      'verified_by_id', v_verifier_id
    )
  WHERE id = p_student_badge_id;

  -- Notify student
  INSERT INTO notifications (student_id, type, title, body, data)
  VALUES (
    v_badge.student_id,
    CASE WHEN p_verdict = 'verified' THEN 'badge_verified' ELSE 'badge_rejected' END,
    CASE WHEN p_verdict = 'verified'
      THEN FORMAT('✅ Badge Verified: %s', v_badge.badge_name)
      ELSE FORMAT('❌ Badge Review Update: %s', v_badge.badge_name)
    END,
    CASE WHEN p_verdict = 'verified'
      THEN FORMAT('Your "%s" badge has been verified by a peer!', v_badge.badge_name)
      ELSE FORMAT('Your "%s" badge submission needs revision. Check the feedback.', v_badge.badge_name)
    END,
    jsonb_build_object(
      'student_badge_id', p_student_badge_id,
      'badge_name', v_badge.badge_name,
      'verdict', p_verdict,
      'verifier_note', p_note
    )
  );

  RETURN jsonb_build_object(
    'success', TRUE,
    'verdict', p_verdict,
    'badge_name', v_badge.badge_name
  );

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;


-- ─────────────────────────────────────────────────────────────────────────────
-- 8. accept_team_invite()
--    Student accepts a team invitation.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION accept_team_invite(p_team_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_student_id UUID := auth.uid();
  v_team_name  TEXT;
  v_cur_count  INTEGER;
  v_max_count  INTEGER;
BEGIN
  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  -- Check invite exists
  IF NOT EXISTS (
    SELECT 1 FROM team_members
    WHERE team_id = p_team_id AND student_id = v_student_id AND status = 'invited'
  ) THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'No pending invite found');
  END IF;

  -- Check team capacity
  SELECT t.name, t.max_members,
         COUNT(tm.id) FILTER (WHERE tm.status = 'active')
  INTO v_team_name, v_max_count, v_cur_count
  FROM teams t
  LEFT JOIN team_members tm ON tm.team_id = t.id
  WHERE t.id = p_team_id
  GROUP BY t.id;

  IF v_cur_count >= v_max_count THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Team is full');
  END IF;

  -- Accept
  UPDATE team_members
  SET status = 'active', joined_at = NOW()
  WHERE team_id = p_team_id AND student_id = v_student_id;

  -- Notify team leader
  INSERT INTO notifications (student_id, type, title, body, data)
  SELECT
    t.leader_id,
    'team_member_joined',
    FORMAT('🎉 New Member Joined: %s', sp.full_name),
    FORMAT('%s has joined your team "%s"!', sp.full_name, v_team_name),
    jsonb_build_object('team_id', p_team_id, 'new_member_id', v_student_id)
  FROM teams t
  JOIN student_profiles sp ON sp.id = v_student_id
  WHERE t.id = p_team_id;

  RETURN jsonb_build_object(
    'success', TRUE,
    'team_name', v_team_name,
    'message', FORMAT('Welcome to team "%s"!', v_team_name)
  );

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;


-- Grant execute permissions on all RPCs
GRANT EXECUTE ON FUNCTION submit_peer_rating TO authenticated;
GRANT EXECUTE ON FUNCTION award_badge TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION create_team_with_members TO authenticated;
GRANT EXECUTE ON FUNCTION apply_to_opportunity TO authenticated;
GRANT EXECUTE ON FUNCTION get_student_dashboard TO authenticated;
GRANT EXECUTE ON FUNCTION verify_badge_by_peer TO authenticated;
GRANT EXECUTE ON FUNCTION accept_team_invite TO authenticated;
GRANT EXECUTE ON FUNCTION get_ranked_opportunities TO authenticated;
