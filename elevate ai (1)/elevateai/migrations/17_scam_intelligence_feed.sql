-- 17_scam_intelligence_feed.sql
-- ═══════════════════════════════════════════════════════════════
-- ElevateAI — Scam Intelligence Feed Extensions
-- ═══════════════════════════════════════════════════════════════

-- 1. Extend scam_reports with severity and metadata
ALTER TABLE scam_reports
  ADD COLUMN IF NOT EXISTS severity TEXT DEFAULT 'medium', -- low, medium, high, critical
  ADD COLUMN IF NOT EXISTS risk_score INTEGER DEFAULT 50,
  ADD COLUMN IF NOT EXISTS is_trending BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS verified_at TIMESTAMPTZ;

-- 2. Create a public view for the community feed (privacy focused)
CREATE OR REPLACE VIEW v_scam_intelligence_feed AS
  SELECT
    sr.id,
    sr.title,
    sr.description,
    sr.category,
    sr.status,
    sr.severity,
    sr.risk_score,
    sr.is_trending,
    sr.created_at,
    sr.opportunity_id,
    o.organizer_name as opportunity_organizer,
    (SELECT count(*) FROM scam_reports sr2 WHERE sr2.opportunity_id = sr.opportunity_id) as report_count
  FROM scam_reports sr
  LEFT JOIN opportunities o ON o.id = sr.opportunity_id
  WHERE sr.status != 'dismissed'
  ORDER BY sr.is_trending DESC, sr.created_at DESC;

-- 3. Update get_student_dashboard to include scam alerts
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
  v_scam_alerts JSONB;
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

  -- NEW: Scam Alerts (latest 2 critical/high)
  SELECT COALESCE(jsonb_agg(row_to_json(s)), '[]'::jsonb)
  INTO v_scam_alerts
  FROM (
    SELECT title, category, severity, created_at
    FROM v_scam_intelligence_feed
    WHERE severity IN ('high', 'critical')
    LIMIT 2
  ) s;

  RETURN jsonb_build_object(
    'profile', row_to_json(v_profile),
    'dna', row_to_json(v_dna),
    'trust', row_to_json(v_trust),
    'unread_notifications', v_notifs,
    'featured_opportunities', v_recent_opp,
    'badges', v_badges,
    'scam_alerts', v_scam_alerts
  );
END;
$$;

-- 4. Notification trigger for critical scams
CREATE OR REPLACE FUNCTION notify_critical_scam()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.severity = 'critical' OR (NEW.severity = 'high' AND NEW.status = 'confirmed') THEN
    INSERT INTO notifications (student_id, type, title, body, data)
    SELECT id, 'critical_scam_alert', '🚨 CRITICAL SCAM ALERT', NEW.title,
           jsonb_build_object('scam_id', NEW.id, 'severity', NEW.severity)
    FROM student_profiles
    WHERE is_active = TRUE;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER tr_notify_critical_scam
  AFTER INSERT OR UPDATE OF severity, status ON scam_reports
  FOR EACH ROW
  EXECUTE FUNCTION notify_critical_scam();
