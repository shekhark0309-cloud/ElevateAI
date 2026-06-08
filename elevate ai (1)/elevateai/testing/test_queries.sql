-- =============================================================================
-- ElevateAI — SQL Test Queries
-- File: testing/test_queries.sql
-- Run these in Supabase Dashboard SQL Editor to verify everything works.
-- =============================================================================


-- ─────────────────────────────────────────────────────────────────────────────
-- TEST 1: Schema Health Check
-- ─────────────────────────────────────────────────────────────────────────────

-- 1a. All tables exist
SELECT table_name,
       (SELECT COUNT(*) FROM information_schema.columns
        WHERE table_name = t.table_name AND table_schema = 'public') AS col_count
FROM information_schema.tables t
WHERE table_schema = 'public'
  AND table_name IN (
    'student_profiles', 'student_dna', 'trust_scores', 'trust_score_history',
    'student_skills', 'student_badges', 'skill_badges', 'student_projects',
    'student_achievements', 'teams', 'team_members', 'opportunities',
    'opportunity_applications', 'peer_ratings', 'notifications',
    'scam_reports', 'colleges', 'campus_resources', 'team_performance_logs'
  )
ORDER BY table_name;
-- Expected: 19 rows

-- 1b. RLS enabled on all user tables
SELECT tablename, rowsecurity AS rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;
-- Expected: all user data tables show rls_enabled = true

-- 1c. All triggers installed
SELECT event_object_table AS table_name, trigger_name, event_manipulation
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;

-- 1d. Seed data loaded
SELECT
  (SELECT COUNT(*) FROM colleges)               AS colleges,
  (SELECT COUNT(*) FROM student_profiles)       AS students,
  (SELECT COUNT(*) FROM student_dna)            AS dna_records,
  (SELECT COUNT(*) FROM trust_scores)           AS trust_scores,
  (SELECT COUNT(*) FROM opportunities)          AS opportunities,
  (SELECT COUNT(*) FROM skill_badges)           AS skill_badges;
-- Expected: 3, 15, 15, 15, 25+, 20+


-- ─────────────────────────────────────────────────────────────────────────────
-- TEST 2: DNA Engine
-- ─────────────────────────────────────────────────────────────────────────────

-- 2a. View DNA snapshot for all students
SELECT
  sp.full_name,
  dna.archetype,
  dna.archetype_confidence,
  dna.top_skills,
  dna.ai_summary,
  ts.overall_score AS trust_score,
  ts.tier
FROM student_profiles sp
JOIN student_dna dna ON dna.student_id = sp.id
JOIN trust_scores ts ON ts.student_id = sp.id
ORDER BY ts.overall_score DESC;

-- 2b. Test sync_dna_top_skills trigger
-- Add a verified skill and check top_skills updates
INSERT INTO student_skills (student_id, skill_name, proficiency, is_verified, source)
VALUES (
  's1000000-0000-0000-0000-000000000001',
  'GraphQL', 4, TRUE, 'badge'
)
ON CONFLICT (student_id, skill_name)
DO UPDATE SET is_verified = TRUE, proficiency = 4;

-- Verify top_skills was updated
SELECT top_skills
FROM student_dna
WHERE student_id = 's1000000-0000-0000-0000-000000000001';
-- Expected: GraphQL should appear in top_skills array

-- 2c. DNA version increment trigger
UPDATE student_dna
SET goals_short_term = ARRAY['Win SIH 2025', 'Land Google internship']
WHERE student_id = 's1000000-0000-0000-0000-000000000001';

SELECT version, updated_at
FROM student_dna
WHERE student_id = 's1000000-0000-0000-0000-000000000001';
-- Expected: version increments by 1 each time


-- ─────────────────────────────────────────────────────────────────────────────
-- TEST 3: TrustScore Network
-- ─────────────────────────────────────────────────────────────────────────────

-- 3a. Trust tier auto-update trigger
-- Manually set a score and verify tier updates automatically
UPDATE trust_scores
SET overall_score = 77
WHERE student_id = 's1000000-0000-0000-0000-000000000001';

SELECT student_id, overall_score, tier
FROM trust_scores
WHERE student_id = 's1000000-0000-0000-0000-000000000001';
-- Expected: tier = 'Gold' (75-89 → Gold)

UPDATE trust_scores
SET overall_score = 91
WHERE student_id = 's1000000-0000-0000-0000-000000000001';

SELECT overall_score, tier FROM trust_scores
WHERE student_id = 's1000000-0000-0000-0000-000000000001';
-- Expected: tier = 'Platinum'

-- 3b. Peer rating → trust score trigger
INSERT INTO peer_ratings (rater_id, ratee_id, context_type, overall, dimensions)
VALUES (
  's1000000-0000-0000-0000-000000000002',  -- Priya rates Aarav
  's1000000-0000-0000-0000-000000000001',
  'project',
  4.5,
  '{"communication": 5.0, "reliability": 4.0, "technical": 5.0}'::JSONB
);

-- Check trust score was updated
SELECT ts.overall_score, ts.collaboration_score, ts.tier
FROM trust_scores ts
WHERE ts.student_id = 's1000000-0000-0000-0000-000000000001';

-- Check history was logged
SELECT reason, source, delta, overall_score
FROM trust_score_history
WHERE student_id = 's1000000-0000-0000-0000-000000000001'
ORDER BY recorded_at DESC
LIMIT 3;

-- 3c. Badge verification → skill_validation_score bump
UPDATE student_badges
SET verify_status = 'verified', verified_at = NOW()
WHERE student_id = 's1000000-0000-0000-0000-000000000001'
  AND verify_status = 'pending'
LIMIT 1;

SELECT skill_validation_score, overall_score
FROM trust_scores
WHERE student_id = 's1000000-0000-0000-0000-000000000001';
-- Expected: skill_validation_score + 5

-- 3d. Trust leaderboard
SELECT full_name, overall_score, tier, rank_overall, rank_college
FROM mv_trust_leaderboard
ORDER BY rank_overall
LIMIT 5;
-- Expected: ordered by score DESC


-- ─────────────────────────────────────────────────────────────────────────────
-- TEST 4: Opportunity SQL Ranking Function
-- ─────────────────────────────────────────────────────────────────────────────

-- 4a. Basic ranking for student 1 (Aarav Mehta, Maharashtra, general, B.Tech CSE)
SELECT
  title, type, eligibility_match, match_score,
  apply_deadline::DATE AS deadline
FROM get_ranked_opportunities('s1000000-0000-0000-0000-000000000001')
ORDER BY eligibility_match DESC, match_score DESC
LIMIT 10;

-- 4b. Compare ranking for different students
SELECT
  opp.title,
  r1.match_score AS score_aarav,
  r2.match_score AS score_rohan
FROM get_ranked_opportunities('s1000000-0000-0000-0000-000000000001') r1
JOIN get_ranked_opportunities('s1000000-0000-0000-0000-000000000003') r2
  ON r1.opportunity_id = r2.opportunity_id
JOIN opportunities opp ON opp.id = r1.opportunity_id
ORDER BY r1.match_score DESC
LIMIT 5;
-- Expected: different scores for different students based on eligibility

-- 4c. Student from SC category should see reserved scholarships
SELECT title, type, eligible_categories
FROM get_ranked_opportunities('s1000000-0000-0000-0000-000000000003')  -- Rohan Das, SC
JOIN opportunities o ON o.id = opportunity_id
WHERE eligibility_match = TRUE
  AND 'sc' = ANY(o.eligible_categories::text[]);


-- ─────────────────────────────────────────────────────────────────────────────
-- TEST 5: RPC Functions
-- ─────────────────────────────────────────────────────────────────────────────

-- 5a. Test submit_peer_rating (requires setting role)
SET ROLE authenticated;
SET request.jwt.claims TO '{"sub": "s1000000-0000-0000-0000-000000000002", "role": "authenticated"}';

SELECT submit_peer_rating(
  's1000000-0000-0000-0000-000000000001'::UUID,
  'hackathon',
  NULL,
  4.0,
  '{"communication": 4.0, "reliability": 4.5}'::JSONB,
  'Really solid developer and team player!',
  FALSE
);

RESET ROLE;

-- 5b. Test award_badge (service role)
SELECT award_badge(
  's1000000-0000-0000-0000-000000000001'::UUID,
  (SELECT id FROM skill_badges WHERE category = 'technical' LIMIT 1),
  'https://certificates.example.com/test-cert.pdf',
  '{"test": true}'::JSONB,
  TRUE
);

-- 5c. Test get_student_dashboard
SELECT get_student_dashboard('s1000000-0000-0000-0000-000000000001'::UUID);

-- 5d. Test apply_to_opportunity
SET ROLE authenticated;
SET request.jwt.claims TO '{"sub": "s1000000-0000-0000-0000-000000000001", "role": "authenticated"}';

SELECT apply_to_opportunity(
  (SELECT id FROM opportunities WHERE status = 'active'
   AND apply_deadline > NOW() LIMIT 1),
  'I am extremely passionate about this opportunity and bring strong Python and ML skills.',
  'https://example.com/aarav_resume.pdf',
  '{}'::JSONB
);

RESET ROLE;

-- 5e. Verify application was created
SELECT oa.status, o.title, oa.submitted_at
FROM opportunity_applications oa
JOIN opportunities o ON o.id = oa.opportunity_id
WHERE oa.student_id = 's1000000-0000-0000-0000-000000000001'
ORDER BY oa.created_at DESC
LIMIT 3;


-- ─────────────────────────────────────────────────────────────────────────────
-- TEST 6: Views
-- ─────────────────────────────────────────────────────────────────────────────

-- 6a. DNA Snapshot view
SELECT full_name, archetype, trust_score, trust_tier, top_skills
FROM v_student_dna_snapshot
ORDER BY trust_score DESC;

-- 6b. Active opportunities view
SELECT title, type, apply_deadline::DATE, organizer_trust_score
FROM v_active_opportunities
ORDER BY apply_deadline ASC
LIMIT 10;

-- 6c. Open teams view
SELECT name, leader_name, leader_trust_tier, current_member_count, max_members, required_skills
FROM v_open_teams
ORDER BY leader_trust_score DESC;

-- 6d. Trust leaderboard (global and per-college)
SELECT full_name, overall_score, tier, rank_overall, rank_college, college_short_name
FROM mv_trust_leaderboard
ORDER BY rank_overall
LIMIT 10;


-- ─────────────────────────────────────────────────────────────────────────────
-- TEST 7: Flywheel Effect — End-to-End Scenario
-- ─────────────────────────────────────────────────────────────────────────────
-- Simulate the full student journey:
-- Profile → Skills → Badges → Team → Rating → DNA Update → TrustScore boost

-- Step 1: Record baseline
SELECT
  dna.version AS dna_version,
  ts.overall_score AS trust_score,
  ts.tier,
  array_length(dna.top_skills, 1) AS skills_count
FROM student_dna dna
JOIN trust_scores ts ON ts.student_id = dna.student_id
WHERE dna.student_id = 's1000000-0000-0000-0000-000000000005';  -- Yash Patel

-- Step 2: Add verified skill (should update top_skills in DNA)
INSERT INTO student_skills (student_id, skill_name, proficiency, is_verified, source)
VALUES ('s1000000-0000-0000-0000-000000000005', 'TensorFlow', 4, TRUE, 'project')
ON CONFLICT (student_id, skill_name) DO UPDATE SET is_verified = TRUE;

-- Step 3: Verify badge
UPDATE student_badges
SET verify_status = 'verified', verified_at = NOW()
WHERE student_id = 's1000000-0000-0000-0000-000000000005'
  AND verify_status = 'pending'
LIMIT 1;

-- Step 4: Check updated state
SELECT
  dna.version AS dna_version,
  dna.top_skills,
  ts.overall_score AS trust_score,
  ts.tier,
  ts.skill_validation_score
FROM student_dna dna
JOIN trust_scores ts ON ts.student_id = dna.student_id
WHERE dna.student_id = 's1000000-0000-0000-0000-000000000005';

-- Step 5: Review trust history
SELECT reason, source, delta, overall_score, recorded_at
FROM trust_score_history
WHERE student_id = 's1000000-0000-0000-0000-000000000005'
ORDER BY recorded_at DESC
LIMIT 5;


-- ─────────────────────────────────────────────────────────────────────────────
-- TEST 8: Security & RLS
-- ─────────────────────────────────────────────────────────────────────────────

-- 8a. Verify student can only read own sensitive data
-- (Set JWT claims to student 2, try to read student 1's data)
SET ROLE authenticated;
SET request.jwt.claims TO '{"sub": "s1000000-0000-0000-0000-000000000002", "role": "authenticated"}';

-- This should return empty (student 2 can't read student 1's full profile)
SELECT family_income, category FROM student_profiles
WHERE id = 's1000000-0000-0000-0000-000000000001';
-- Expected: 0 rows (RLS blocks this)

-- This should work (public data)
SELECT full_name, year_of_study FROM student_profiles
WHERE id = 's1000000-0000-0000-0000-000000000001';
-- Expected: 1 row

RESET ROLE;

-- 8b. Verify trust score breakdown is private
SET ROLE authenticated;
SET request.jwt.claims TO '{"sub": "s1000000-0000-0000-0000-000000000002", "role": "authenticated"}';

-- Can't see other student's detailed breakdown
SELECT reliability_score, collaboration_score
FROM trust_scores
WHERE student_id = 's1000000-0000-0000-0000-000000000001';
-- With strict RLS, this should return 0 rows for another student

RESET ROLE;

-- 8c. Self-rating prevention
SET ROLE authenticated;
SET request.jwt.claims TO '{"sub": "s1000000-0000-0000-0000-000000000001", "role": "authenticated"}';

SELECT submit_peer_rating(
  's1000000-0000-0000-0000-000000000001'::UUID,  -- rating yourself
  'test', NULL, 5.0, '{}', NULL, FALSE
);
-- Expected: success=false, error='Cannot rate yourself'

RESET ROLE;


-- ─────────────────────────────────────────────────────────────────────────────
-- TEST 9: Notifications
-- ─────────────────────────────────────────────────────────────────────────────

-- Check all notification types were created during tests
SELECT type, COUNT(*) AS count
FROM notifications
GROUP BY type
ORDER BY count DESC;

-- Check unread count per student
SELECT sp.full_name, COUNT(*) FILTER (WHERE n.is_read = FALSE) AS unread
FROM student_profiles sp
LEFT JOIN notifications n ON n.student_id = sp.id
GROUP BY sp.full_name
ORDER BY unread DESC;

-- Mark notifications as read (simulate Flutter client)
UPDATE notifications
SET is_read = TRUE
WHERE student_id = 's1000000-0000-0000-0000-000000000001'
  AND is_read = FALSE;


-- ─────────────────────────────────────────────────────────────────────────────
-- TEST 10: Performance (explain analyze on critical queries)
-- ─────────────────────────────────────────────────────────────────────────────

-- Should use indexes, not sequential scans
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM v_student_dna_snapshot
ORDER BY trust_score DESC
LIMIT 10;

EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM get_ranked_opportunities('s1000000-0000-0000-0000-000000000001');

EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM notifications
WHERE student_id = 's1000000-0000-0000-0000-000000000001'
  AND is_read = FALSE
ORDER BY created_at DESC;
-- All three should show Index Scan, not Seq Scan
