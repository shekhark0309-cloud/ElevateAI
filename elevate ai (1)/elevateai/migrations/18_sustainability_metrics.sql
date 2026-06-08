-- 18_sustainability_metrics.sql
-- ═══════════════════════════════════════════════════════════════
-- ElevateAI — Sustainability Dashboard & Metrics
-- ═══════════════════════════════════════════════════════════════

-- 1. Function to calculate personal sustainability impact
CREATE OR REPLACE FUNCTION get_student_sustainability_impact(p_student_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_opt_out_count INTEGER;
  v_static_opt_outs INTEGER := 0;
  v_total_meals_saved INTEGER;
  v_food_saved_kg NUMERIC;
  v_co2_saved_kg NUMERIC;
  v_participation_rate NUMERIC;
  v_college_id UUID;
  v_campus_total_saved_kg NUMERIC;
BEGIN
  -- Get student's college
  SELECT college_id INTO v_college_id FROM student_profiles WHERE id = p_student_id;

  -- Count individual opt-out dates (assuming 3 meals per date)
  SELECT array_length(opt_out_dates, 1) * 3 INTO v_opt_out_count
  FROM meal_preferences WHERE student_id = p_student_id;
  v_opt_out_count := COALESCE(v_opt_out_count, 0);

  -- Count static opt-outs (e.g. if they never eat breakfast)
  -- For a simple metric, assume they've been opted out for the last 30 days if boolean is false
  SELECT
    (CASE WHEN opt_in_breakfast = FALSE THEN 30 ELSE 0 END) +
    (CASE WHEN opt_in_lunch = FALSE THEN 30 ELSE 0 END) +
    (CASE WHEN opt_in_dinner = FALSE THEN 30 ELSE 0 END)
  INTO v_static_opt_outs
  FROM meal_preferences WHERE student_id = p_student_id;
  v_static_opt_outs := COALESCE(v_static_opt_outs, 0);

  v_total_meals_saved := v_opt_out_count + v_static_opt_outs;
  v_food_saved_kg := v_total_meals_saved * 0.35; -- 0.35kg per meal (matches Edge Function)
  v_co2_saved_kg := v_food_saved_kg * 2.5; -- 2.5kg CO2 per kg food waste

  -- Campus total
  SELECT SUM(waste_kg_saved) INTO v_campus_total_saved_kg
  FROM meal_predictions WHERE college_id = v_college_id;
  v_campus_total_saved_kg := COALESCE(v_campus_total_saved_kg, 0);

  -- Participation rate: % of students in college who have some meal preference set
  SELECT (COUNT(DISTINCT mp.student_id)::NUMERIC / NULLIF(COUNT(DISTINCT sp.id), 0) * 100)
  INTO v_participation_rate
  FROM student_profiles sp
  LEFT JOIN meal_preferences mp ON mp.student_id = sp.id
  WHERE sp.college_id = v_college_id;

  RETURN jsonb_build_object(
    'personal_impact', jsonb_build_object(
      'meals_saved', v_total_meals_saved,
      'food_saved_kg', ROUND(v_food_saved_kg, 2),
      'co2_saved_kg', ROUND(v_co2_saved_kg, 2),
      'contribution_score', LEAST(100, (v_total_meals_saved * 2))
    ),
    'campus_impact', jsonb_build_object(
      'total_food_saved_kg', ROUND(v_campus_total_saved_kg, 2),
      'participation_rate', ROUND(v_participation_rate, 1),
      'active_students', (SELECT COUNT(*) FROM meal_preferences WHERE student_id IN (SELECT id FROM student_profiles WHERE college_id = v_college_id))
    ),
    'weekly_trends', (
      SELECT jsonb_agg(t) FROM (
        SELECT meal_date, SUM(waste_kg_saved) as waste_saved
        FROM meal_predictions
        WHERE college_id = v_college_id
        AND meal_date > NOW() - INTERVAL '7 days'
        GROUP BY meal_date
        ORDER BY meal_date ASC
      ) t
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION get_student_sustainability_impact TO authenticated;

-- 2. Update get_student_dashboard to include sustainability summary
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
  v_sustainability_summary JSONB;
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

  -- Scam Alerts (latest 2 critical/high)
  SELECT COALESCE(jsonb_agg(row_to_json(s)), '[]'::jsonb)
  INTO v_scam_alerts
  FROM (
    SELECT title, category, severity, created_at
    FROM v_scam_intelligence_feed
    WHERE severity IN ('high', 'critical')
    LIMIT 2
  ) s;

  -- Sustainability Summary
  SELECT jsonb_build_object(
    'meals_saved', (COALESCE(array_length(opt_out_dates, 1), 0) * 3) +
                   (CASE WHEN opt_in_breakfast = FALSE THEN 30 ELSE 0 END) +
                   (CASE WHEN opt_in_lunch = FALSE THEN 30 ELSE 0 END) +
                   (CASE WHEN opt_in_dinner = FALSE THEN 30 ELSE 0 END)
  ) INTO v_sustainability_summary
  FROM meal_preferences WHERE student_id = p_student_id;

  RETURN jsonb_build_object(
    'profile', row_to_json(v_profile),
    'dna', row_to_json(v_dna),
    'trust', row_to_json(v_trust),
    'unread_notifications', v_notifs,
    'featured_opportunities', v_recent_opp,
    'badges', v_badges,
    'scam_alerts', v_scam_alerts,
    'sustainability', v_sustainability_summary
  );
END;
$$;
