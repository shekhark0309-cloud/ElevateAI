# ElevateAI — Security & Performance Notes
## Production Hardening Guide

---

## 1. RLS Audit Checklist

### Critical Tables — Verified Policies

| Table | RLS | Own Read | Own Write | Public Read | Service Write |
|---|---|---|---|---|---|
| `student_profiles` | ✅ | ✅ Full | ✅ Limited fields | ✅ Public fields only | ✅ |
| `student_dna` | ✅ | ✅ | ✅ | ❌ | ✅ |
| `trust_scores` | ✅ | ✅ Full | ❌ | ✅ Score+tier only | ✅ |
| `trust_score_history` | ✅ | ✅ | ❌ | ❌ | ✅ |
| `student_skills` | ✅ | ✅ | ✅ | ✅ Verified only | ✅ |
| `student_badges` | ✅ | ✅ | ✅ | ✅ Verified only | ✅ |
| `opportunities` | ✅ | ✅ Own | ✅ Own | ✅ Active only | ✅ |
| `peer_ratings` | ✅ | ✅ Received | ✅ Own submissions | ❌ | ✅ |
| `notifications` | ✅ | ✅ | ✅ | ❌ | ✅ |
| `scam_reports` | ✅ | ✅ Own | ✅ Own | ✅ Confirmed only | ✅ |

### Sensitive Fields Protection
```sql
-- Verify family_income is NEVER in public queries
-- Test: As an anonymous user, try to read sensitive fields
SET request.jwt.claims TO '{"role": "anon"}';
SELECT family_income, category FROM student_profiles LIMIT 1;
-- Expected: 0 rows (RLS blocks anon access)

-- Test: Student can't read another student's sensitive data
SET request.jwt.claims TO '{"sub": "student-a-id", "role": "authenticated"}';
SELECT family_income FROM student_profiles WHERE id = 'student-b-id';
-- Expected: 0 rows
```

### RLS Policy Gaps to Address
```sql
-- TODO: Add policy to prevent students from updating trust scores directly
-- (Already handled by service_role_only, but add explicit deny)
CREATE POLICY "deny_student_trust_write"
  ON trust_scores FOR INSERT
  USING (FALSE);  -- Block all direct inserts from non-service role

-- TODO: Limit how many notifications a student can self-insert
-- (Prevents notification spam if RLS allows it)
```

---

## 2. Edge Function Security

### Input Validation Patterns
```typescript
// Always validate UUIDs before DB queries
function isValidUUID(str: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(str);
}

// Sanitize all text inputs
function sanitizeText(input: string, maxLength = 1000): string {
  return input.trim().substring(0, maxLength);
}

// Validate student owns the resource they're requesting
async function validateStudentOwnership(
  supabase: SupabaseClient,
  studentId: string,
  requestedStudentId: string,
  allowedRoles = ['service_role']
): Promise<boolean> {
  // Check if it's the student themselves or service role
  if (studentId === requestedStudentId) return true;
  // Add admin role check here
  return false;
}
```

### JWT Validation in Edge Functions
```typescript
// ALWAYS validate JWT for user-facing operations
export async function requireAuth(req: Request): Promise<string> {
  const authHeader = req.headers.get('Authorization');
  if (!authHeader?.startsWith('Bearer ')) {
    throw new Error('Authentication required');
  }
  
  const supabase = createUserClient(authHeader);
  const { data: { user }, error } = await supabase.auth.getUser();
  
  if (error || !user) throw new Error('Invalid or expired token');
  return user.id;
}
```

### Service Role Key Security
```typescript
// ❌ NEVER do this in Edge Functions
const key = req.headers.get('x-service-key'); // Attacker can forge this

// ✅ DO this — use environment variable
const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')! // Auto-injected, safe
);
```

---

## 3. Rate Limiting Strategy

### Per-Function Limits (production settings)

| Function | Limit | Window | Per |
|---|---|---|---|
| `recalculate-dna` | 5 calls | 1 hour | student |
| `match-teams` | 20 calls | 1 hour | student |
| `rank-opportunities` | 30 calls | 1 hour | student |
| `scam-detect` | 100 calls | 1 hour | IP |
| `update-trust-score` | 10 calls | 1 hour | student |

### Production Rate Limiting with Upstash Redis
```typescript
// Replace the in-memory rate limiter in _shared/utils.ts with:
import { Ratelimit } from 'https://esm.sh/@upstash/ratelimit@1.0.0';
import { Redis } from 'https://esm.sh/@upstash/redis@1.25.0';

const redis = new Redis({
  url: Deno.env.get('UPSTASH_REDIS_URL')!,
  token: Deno.env.get('UPSTASH_REDIS_TOKEN')!,
});

const ratelimit = new Ratelimit({
  redis,
  limiter: Ratelimit.slidingWindow(5, '1 h'),
  analytics: true, // Track usage
});

export async function checkRateLimit(identifier: string): Promise<boolean> {
  const { success, limit, reset, remaining } = await ratelimit.limit(identifier);
  return !success; // Returns true if rate limited
}
```

### Supabase Built-in Rate Limits (configure in Dashboard)
- Auth: 30 signup attempts/hour per IP
- Auth: 10 OTP attempts/hour per phone
- Edge Functions: Configure via supabase.com dashboard → Settings → Edge Functions

---

## 4. Performance Optimization

### Critical Indexes (already in schema)
```sql
-- Verify all indexes are being used:
SELECT
  schemaname, tablename, indexname,
  idx_scan, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan DESC;

-- Indexes with 0 scans might be unused:
SELECT indexname FROM pg_stat_user_indexes
WHERE idx_scan = 0 AND schemaname = 'public';
```

### Query Performance Targets

| Query | Target P99 | Strategy |
|---|---|---|
| DNA snapshot | < 50ms | Materialized view |
| Opportunity ranking | < 200ms | SQL function + indexes |
| Team matching | < 100ms | GIN index on skills array |
| Trust leaderboard | < 20ms | Materialized view |
| Notifications | < 30ms | Partial index (unread only) |

### Connection Pooling
```bash
# In Supabase Dashboard → Settings → Database → Connection Pooling
Mode: Transaction (for stateless API/Edge Functions)
Pool Size: 15 (free tier), 25 (pro tier)
Client Connections: 200

# In Flutter, use the REST API (not direct Postgres)
# Direct connections don't scale on free tier
```

### Caching Strategy
```typescript
// Cache opportunity lists (changes rarely) for 15 mins
// In Edge Function, use Upstash Redis:

const cacheKey = `opps:${studentId}:${JSON.stringify(filters)}`;
const cached = await redis.get(cacheKey);
if (cached) return successResponse(JSON.parse(cached));

// ... compute result ...

await redis.setex(cacheKey, 900, JSON.stringify(result)); // 15 min TTL
```

### Materialized View Strategy
```sql
-- Refresh strategy for each materialized view:
-- mv_trust_leaderboard: every 15 mins (pg_cron or Supabase scheduled function)
-- Concurrently refresh (doesn't lock reads):
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_trust_leaderboard;

-- Monitor refresh times:
SELECT last_autoanalyze, last_analyze
FROM pg_stat_user_tables
WHERE relname = 'mv_trust_leaderboard';
```

---

## 5. AI API Cost Optimization

### Token Budget per Function Call

| Function | AI Calls | Tokens (input) | Tokens (output) | Est. Cost/call |
|---|---|---|---|---|
| `recalculate-dna` | 1 | ~800 | ~300 | ~$0.004 |
| `match-teams` (batch 8) | 1 | ~600 | ~200 | ~$0.003 |
| `rank-opportunities` (top 10) | 1 | ~700 | ~300 | ~$0.004 |
| `scam-detect` | 0-1 | ~400 | ~150 | ~$0.002 |

### Cost Control Strategies
```typescript
// 1. Only call AI when meaningful changes occurred
const lastAIUpdate = new Date(existingDNA.last_ai_updated ?? 0);
const hoursSinceLast = (Date.now() - lastAIUpdate.getTime()) / (1000 * 60 * 60);
const significantChange = verifiedSkillsCount > lastVerifiedCount + 2;

if (hoursSinceLast < 24 && !significantChange && !forceRefresh) {
  return existingDNA; // Skip AI call
}

// 2. Use claude-haiku-4-5 for simple scam detection (10x cheaper)
const model = isSophisticatedAnalysis ? 'claude-sonnet-4-5' : 'claude-haiku-4-5-20251001';

// 3. Batch AI calls (one API call for 8 team explanations vs 8 separate calls)
// Already implemented in match-teams function
```

---

## 6. Free Tier Compatibility

### Supabase Free Tier Limits
| Resource | Free Limit | ElevateAI Usage | Action Needed? |
|---|---|---|---|
| Database size | 500 MB | ~50MB initial | ✅ Safe |
| Bandwidth | 5 GB/month | Light initially | ✅ Safe |
| Edge Function invocations | 500,000/month | ~10K/day demo | ✅ Safe |
| Realtime connections | 200 | 50 concurrent | ✅ Safe |
| Storage | 1 GB | Small initially | ✅ Safe |
| Auth users | 50,000 | 15 seed students | ✅ Safe |

### Free Tier Workarounds
```bash
# pg_cron not available on free tier
# Alternative: Use Supabase Scheduled Edge Functions (Dashboard → Edge Functions → Schedule)
# Or: Use GitHub Actions for nightly batch jobs:

# .github/workflows/nightly-jobs.yml
# schedule: '0 21 * * *'  # 2:30 AM IST
# run: curl -X POST $SUPABASE_URL/functions/v1/update-trust-score \
#        -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
#        -d '{"batch_all": true}'
```

---

## 7. Monitoring & Alerting

### Key Metrics to Track
```sql
-- Daily active students
SELECT DATE(created_at), COUNT(DISTINCT student_id)
FROM trust_score_history
WHERE recorded_at > NOW() - INTERVAL '30 days'
GROUP BY 1 ORDER BY 1;

-- DNA update frequency
SELECT DATE(last_ai_updated), COUNT(*)
FROM student_dna
WHERE last_ai_updated > NOW() - INTERVAL '7 days'
GROUP BY 1;

-- Scam detection accuracy
SELECT risk_level, COUNT(*), AVG(risk_score)
FROM scam_reports sr
-- join with manual review outcomes
GROUP BY risk_level;

-- Application funnel
SELECT
  COUNT(*) FILTER (WHERE status = 'submitted') AS submitted,
  COUNT(*) FILTER (WHERE status = 'shortlisted') AS shortlisted,
  COUNT(*) FILTER (WHERE status = 'accepted') AS accepted
FROM opportunity_applications
WHERE created_at > NOW() - INTERVAL '30 days';
```

### Supabase Observability
- **Logs:** Dashboard → Edge Functions → Logs (per function)
- **Query performance:** Dashboard → Database → Query Performance
- **Realtime:** Dashboard → Realtime → Inspector
- **Auth:** Dashboard → Authentication → Users

---

## 8. Security Audit TODO List

- [ ] **Vault for secrets:** Store ERP API credentials in Supabase Vault, not as plain env vars
- [ ] **Audit log table:** Create `admin_audit_log` for all admin actions
- [ ] **CAPTCHA on auth:** Add hCaptcha to prevent signup spam
- [ ] **IP blocklist:** Block known VPN/datacenter IPs from accessing admin functions
- [ ] **Data export controls:** Implement GDPR-compliant data export/delete (required for Indian PDPB)
- [ ] **Penetration test:** Test SQL injection via RPC params, XSS via stored fields
- [ ] **Certificate pinning:** In Flutter app for production
- [ ] **Sensitive field encryption:** Encrypt `family_income` at application layer (not just RLS)

---

## 9. Disaster Recovery

### Backup Strategy
```bash
# Supabase automatically backs up databases daily (Pro tier = 7-day PITR)
# Free tier: Weekly backup only

# For free tier — manual backup before migrations:
pg_dump ${DATABASE_URL} > backup_$(date +%Y%m%d).sql

# Restore:
psql ${DATABASE_URL} < backup_20260601.sql
```

### Zero-Downtime Migration Pattern
```sql
-- Always:
-- 1. Add columns as nullable first
ALTER TABLE student_dna ADD COLUMN new_field TEXT;
-- 2. Backfill data
UPDATE student_dna SET new_field = 'default' WHERE new_field IS NULL;
-- 3. Add constraint after backfill
ALTER TABLE student_dna ALTER COLUMN new_field SET NOT NULL;
-- 4. Never DROP columns without a migration cycle
```
