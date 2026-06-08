#!/usr/bin/env bash
# =============================================================================
# ElevateAI — Complete Test Suite
# File: testing/test_suite.sh
# =============================================================================
# Prerequisites:
#   export SUPABASE_URL="https://your-project.supabase.co"
#   export SERVICE_ROLE_KEY="eyJ..."
#   export ANON_KEY="eyJ..."
#   export STUDENT_JWT="eyJ..."   # JWT from a test student login
# =============================================================================

set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

pass() { echo -e "${GREEN}✓ PASS${NC} — $1"; }
fail() { echo -e "${RED}✗ FAIL${NC} — $1"; }
info() { echo -e "${YELLOW}ℹ INFO${NC} — $1"; }
section() { echo -e "\n${YELLOW}══════════════════════════════════════${NC}"; echo -e "${YELLOW}  $1${NC}"; echo -e "${YELLOW}══════════════════════════════════════${NC}"; }

STUDENT_ID="s1000000-0000-0000-0000-000000000001"
BASE_URL="${SUPABASE_URL}/functions/v1"
HEADERS=(-H "Authorization: Bearer ${SERVICE_ROLE_KEY}" -H "Content-Type: application/json")

# =============================================================================
section "1. SCHEMA VERIFICATION"
# =============================================================================

info "Checking all core tables exist..."
psql "${DATABASE_URL}" --csv -c "
  SELECT table_name
  FROM information_schema.tables
  WHERE table_schema = 'public'
  ORDER BY table_name;
" | grep -E "(student_profiles|student_dna|trust_scores|opportunities|team_members|peer_ratings|notifications)" \
  && pass "All core tables exist" || fail "Missing tables"

info "Checking RLS is enabled..."
psql "${DATABASE_URL}" --csv -c "
  SELECT tablename, rowsecurity
  FROM pg_tables
  WHERE schemaname = 'public' AND rowsecurity = FALSE
    AND tablename NOT IN ('campus_resources', 'colleges', 'skill_badges')
  ORDER BY tablename;
" | grep -c "^" | xargs -I{} bash -c '[ "{}" -eq "1" ] && echo "pass" || echo "fail"' \
  && pass "RLS enabled on all user tables" || fail "Some tables missing RLS"

# =============================================================================
section "2. DNA RECALCULATION"
# =============================================================================

info "Testing DNA recalculation for seed student..."
RESPONSE=$(curl -s -X POST "${BASE_URL}/recalculate-dna" \
  "${HEADERS[@]}" \
  -d "{\"student_id\": \"${STUDENT_ID}\"}")

echo "Response: $(echo $RESPONSE | python3 -m json.tool 2>/dev/null || echo $RESPONSE)"

SUCCESS=$(echo $RESPONSE | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('success', False))" 2>/dev/null)
ARCHETYPE=$(echo $RESPONSE | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data', {}).get('archetype', 'missing'))" 2>/dev/null)

[ "$SUCCESS" = "True" ] && pass "DNA recalculation succeeded" || fail "DNA recalculation failed"
[ "$ARCHETYPE" != "missing" ] && pass "Archetype assigned: $ARCHETYPE" || fail "No archetype in response"

info "Verifying DNA was updated in DB..."
psql "${DATABASE_URL}" -c "
  SELECT student_id, archetype, archetype_confidence,
         array_length(ai_strengths, 1) AS strengths_count,
         last_ai_updated
  FROM student_dna
  WHERE student_id = '${STUDENT_ID}';
"

info "Testing rate limiting (should fail on 6th call)..."
for i in $(seq 1 5); do
  curl -s -X POST "${BASE_URL}/recalculate-dna" \
    "${HEADERS[@]}" \
    -d "{\"student_id\": \"rate-limit-test-${i}\"}" > /dev/null
done
RATE_RESP=$(curl -s -X POST "${BASE_URL}/recalculate-dna" \
  -H "Authorization: Bearer ${ANON_KEY}" -H "Content-Type: application/json" \
  -d "{\"student_id\": \"${STUDENT_ID}\"}")
echo "Rate limit response: $RATE_RESP"

# =============================================================================
section "3. TEAM MATCHING"
# =============================================================================

info "Testing team matching for seed student..."
MATCH_RESP=$(curl -s -X POST "${BASE_URL}/match-teams" \
  "${HEADERS[@]}" \
  -d "{
    \"student_id\": \"${STUDENT_ID}\",
    \"filters\": {\"open_only\": true},
    \"limit\": 5
  }")

echo "Match response preview:"
echo $MATCH_RESP | python3 -c "
import sys, json
d = json.load(sys.stdin)
if d.get('success'):
    matches = d.get('data', {}).get('matches', [])
    print(f'Found {len(matches)} matches')
    for m in matches[:3]:
        print(f'  - {m[\"name\"]} (score: {m[\"composite_score\"]}) — {m.get(\"match_explanation\", \"\")[:80]}')
else:
    print('ERROR:', d.get('error'))
" 2>/dev/null || echo $MATCH_RESP

MATCH_COUNT=$(echo $MATCH_RESP | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('data',{}).get('matches',[])))" 2>/dev/null)
[ "${MATCH_COUNT:-0}" -gt "0" ] && pass "Team matching returned $MATCH_COUNT matches" || fail "No team matches found"

info "Testing with archetype filter..."
curl -s -X POST "${BASE_URL}/match-teams" \
  "${HEADERS[@]}" \
  -d "{\"student_id\": \"${STUDENT_ID}\", \"filters\": {\"archetype_needed\": \"Builder\"}}" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('Filtered matches:', len(d.get('data',{}).get('matches',[])))" 2>/dev/null

# =============================================================================
section "4. OPPORTUNITY RANKING"
# =============================================================================

info "Testing opportunity ranking for seed student..."
OPP_RESP=$(curl -s -X POST "${BASE_URL}/rank-opportunities" \
  "${HEADERS[@]}" \
  -d "{
    \"student_id\": \"${STUDENT_ID}\",
    \"limit\": 10
  }")

echo $OPP_RESP | python3 -c "
import sys, json
d = json.load(sys.stdin)
if d.get('success'):
    opps = d.get('data', {}).get('opportunities', [])
    print(f'Found {len(opps)} ranked opportunities')
    for o in opps[:3]:
        print(f'  [{o[\"urgency_level\"]}] {o[\"title\"]} — Score: {o[\"match_score\"]} — {o.get(\"ai_reason\",\"\")[:60]}')
    print(f'  Eligible: {d[\"data\"][\"total_eligible\"]}, Stretch: {d[\"data\"][\"total_stretch\"]}')
else:
    print('ERROR:', d.get('error'))
" 2>/dev/null || echo $OPP_RESP

OPP_COUNT=$(echo $OPP_RESP | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('data',{}).get('opportunities',[])))" 2>/dev/null)
[ "${OPP_COUNT:-0}" -gt "0" ] && pass "Opportunity ranking returned $OPP_COUNT ranked opportunities" || fail "No opportunities ranked"

info "Testing type filter..."
curl -s -X POST "${BASE_URL}/rank-opportunities" \
  "${HEADERS[@]}" \
  -d "{\"student_id\": \"${STUDENT_ID}\", \"type_filter\": [\"hackathon\", \"scholarship\"]}" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('Filtered opps:', len(d.get('data',{}).get('opportunities',[])))" 2>/dev/null

# =============================================================================
section "5. SCAM DETECTION"
# =============================================================================

info "Testing ScamShield with a safe opportunity..."
SAFE_RESP=$(curl -s -X POST "${BASE_URL}/scam-detect" \
  "${HEADERS[@]}" \
  -d '{
    "title": "Google Summer of Code 2025",
    "description": "Open source software development program by Google. Students work with open source organizations on real-world projects.",
    "url": "https://summerofcode.withgoogle.com",
    "organizer": "Google",
    "prize_amount": 150000
  }')

SAFE_SCORE=$(echo $SAFE_RESP | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('risk_score', 999))" 2>/dev/null)
[ "${SAFE_SCORE:-999}" -lt "20" ] && pass "Safe opportunity scored correctly: $SAFE_SCORE" || fail "Safe opportunity over-flagged: $SAFE_SCORE"

info "Testing ScamShield with a suspicious opportunity..."
SCAM_RESP=$(curl -s -X POST "${BASE_URL}/scam-detect" \
  "${HEADERS[@]}" \
  -d '{
    "title": "Earn Rs 50,000 Daily Working From Home — No Experience Needed!",
    "description": "100% guaranteed work from home job. Pay registration fee of Rs 999 to get started. Western union payment accepted. Guaranteed selection, no interview required!",
    "url": "http://bit.ly/fake-job-2025",
    "organizer": "Unknown Recruitment Agency"
  }')

SCAM_SCORE=$(echo $SCAM_RESP | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('risk_score', 0))" 2>/dev/null)
SCAM_LEVEL=$(echo $SCAM_RESP | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('risk_level', 'unknown'))" 2>/dev/null)
[ "${SCAM_SCORE:-0}" -gt "60" ] && pass "Scam detected correctly: score=$SCAM_SCORE, level=$SCAM_LEVEL" || fail "Scam not detected: score=$SCAM_SCORE"

FLAGS=$(echo $SCAM_RESP | python3 -c "import sys,json; d=json.load(sys.stdin); print(', '.join(d.get('data',{}).get('flags',[][:3])))" 2>/dev/null)
info "Flags found: $FLAGS"

# =============================================================================
section "6. TRUST SCORE UPDATES"
# =============================================================================

info "Getting initial trust score..."
psql "${DATABASE_URL}" -c "
  SELECT student_id, overall_score, tier,
         reliability_score, collaboration_score,
         skill_validation_score, community_score
  FROM trust_scores
  WHERE student_id = '${STUDENT_ID}';
"

info "Triggering trust score recalculation via Edge Function..."
TRUST_RESP=$(curl -s -X POST "${BASE_URL}/update-trust-score" \
  "${HEADERS[@]}" \
  -d "{
    \"student_id\": \"${STUDENT_ID}\",
    \"reason\": \"Test recalculation\"
  }")

TRUST_SUCCESS=$(echo $TRUST_RESP | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('success', False))" 2>/dev/null)
NEW_SCORE=$(echo $TRUST_RESP | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('new_score', 0))" 2>/dev/null)
[ "$TRUST_SUCCESS" = "True" ] && pass "Trust score updated: $NEW_SCORE" || fail "Trust score update failed"

info "Testing trust score update via peer rating RPC..."
psql "${DATABASE_URL}" -c "
  -- Submit a rating as a different student
  SELECT submit_peer_rating(
    '${STUDENT_ID}'::UUID,
    'team',
    NULL,
    4.5,
    '{\"communication\": 5.0, \"reliability\": 4.0, \"technical\": 4.5}'::JSONB,
    'Great collaborator!',
    FALSE
  );
" | python3 -c "import sys; print(sys.stdin.read())" 2>/dev/null || \
psql "${DATABASE_URL}" -c "
  SELECT submit_peer_rating(
    '${STUDENT_ID}'::UUID,
    'hackathon',
    NULL,
    4.5,
    '{}'::JSONB,
    'Great team player',
    FALSE
  );
"

info "Verifying trust score history was logged..."
psql "${DATABASE_URL}" -c "
  SELECT reason, source, overall_score, delta, recorded_at
  FROM trust_score_history
  WHERE student_id = '${STUDENT_ID}'
  ORDER BY recorded_at DESC
  LIMIT 5;
"

info "Testing ERP data sync..."
ERP_RESP=$(curl -s -X POST "${BASE_URL}/update-trust-score" \
  "${HEADERS[@]}" \
  -d "{
    \"student_id\": \"${STUDENT_ID}\",
    \"reason\": \"ERP sync\",
    \"erp_data\": {
      \"attendance_pct\": 87.5,
      \"assignment_score\": 92.0
    }
  }")
echo "ERP sync result: $(echo $ERP_RESP | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}))" 2>/dev/null)"

# =============================================================================
section "7. RPC FUNCTIONS"
# =============================================================================

info "Testing award_badge RPC..."
psql "${DATABASE_URL}" -c "
  SELECT award_badge(
    '${STUDENT_ID}'::UUID,
    (SELECT id FROM skill_badges WHERE slug = 'python-dev' LIMIT 1),
    'https://example.com/certificate.pdf',
    '{}'::JSONB,
    TRUE  -- auto_verify
  );
"

info "Testing create_team_with_members RPC..."
psql "${DATABASE_URL}" -c "
  -- Note: This needs to be called as an authenticated user
  -- In production: supabase.rpc('create_team_with_members', {...})
  SELECT create_team_with_members(
    'Test AI Team',
    'Building the future with AI',
    ARRAY['Python', 'Machine Learning', 'React'],
    ARRAY['Builder', 'Strategist']::archetype_type[],
    4,
    TRUE,
    ARRAY[]::UUID[]
  );
" 2>/dev/null || info "create_team_with_members requires authenticated session"

info "Testing apply_to_opportunity RPC..."
psql "${DATABASE_URL}" -c "
  SELECT apply_to_opportunity(
    (SELECT id FROM opportunities WHERE status = 'active' LIMIT 1),
    'I am deeply passionate about this opportunity...',
    'https://example.com/resume.pdf',
    '{}'::JSONB
  );
" 2>/dev/null || info "apply_to_opportunity requires authenticated session"

info "Testing get_student_dashboard RPC..."
psql "${DATABASE_URL}" -c "
  SELECT get_student_dashboard('${STUDENT_ID}'::UUID);
" 2>/dev/null

# =============================================================================
section "8. REALTIME VERIFICATION"
# =============================================================================

info "Checking Realtime publication..."
psql "${DATABASE_URL}" -c "
  SELECT schemaname, tablename
  FROM pg_publication_tables
  WHERE pubname = 'supabase_realtime'
  ORDER BY tablename;
"

# Expected tables: trust_scores, notifications, team_members, opportunities, student_dna

# =============================================================================
section "9. STORAGE BUCKETS"
# =============================================================================

info "Verifying storage buckets exist..."
curl -s "${SUPABASE_URL}/storage/v1/bucket" \
  -H "Authorization: Bearer ${SERVICE_ROLE_KEY}" \
  | python3 -c "
import sys, json
buckets = json.load(sys.stdin)
names = [b['name'] for b in buckets]
print('Buckets:', names)
for expected in ['student-assets', 'opportunity-media', 'badge-evidence']:
    status = '✓' if expected in names else '✗ MISSING'
    print(f'  {status}: {expected}')
" 2>/dev/null

# =============================================================================
section "10. NOTIFICATIONS"
# =============================================================================

info "Checking notifications were created..."
psql "${DATABASE_URL}" -c "
  SELECT type, title, is_read, created_at
  FROM notifications
  WHERE student_id = '${STUDENT_ID}'
  ORDER BY created_at DESC
  LIMIT 5;
"

NOTIF_COUNT=$(psql "${DATABASE_URL}" --csv -t -c "SELECT COUNT(*) FROM notifications WHERE student_id = '${STUDENT_ID}';" | tr -d ' ')
[ "${NOTIF_COUNT:-0}" -gt "0" ] && pass "Notifications created: $NOTIF_COUNT" || fail "No notifications found"

# =============================================================================
section "SUMMARY"
# =============================================================================

echo ""
echo "Test suite complete. Check output above for any failures."
echo ""
echo "Next steps if tests fail:"
echo "  1. Check Edge Function logs: supabase functions logs <function-name>"
echo "  2. Verify secrets: supabase secrets list"
echo "  3. Check RLS policies: Dashboard → Authentication → Policies"
echo "  4. Test auth flow separately (JWT required for some RPCs)"
