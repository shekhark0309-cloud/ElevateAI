# ElevateAI — Complete Production Setup Guide
## From Zero to Fully-Seeded, Live Backend

---

## Prerequisites

```bash
# Install Supabase CLI
npm install -g supabase@latest

# Verify versions
supabase --version      # ≥ 1.171
deno --version          # ≥ 1.41 (for Edge Functions)
```

---

## STEP 1 — Create the Supabase Project

1. Go to **https://supabase.com** → "New Project"
2. **Organization:** Your org (or create one)
3. **Project Name:** `elevateai-prod`
4. **Database Password:** Generate a strong password and **save it** — you'll need it for CLI
5. **Region:** `ap-south-1` (Mumbai) — optimal for Indian users
6. **Plan:** Start with Free (we'll note Pro-only features)

Wait ~2 minutes for provisioning.

---

## STEP 2 — Link CLI to Project

```bash
# In your project root
supabase login
supabase link --project-ref <YOUR_PROJECT_REF>
# Project ref is in: Project Settings → General → Reference ID
```

---

## STEP 3 — Enable Required Extensions

Run this in the **SQL Editor** (Dashboard → SQL Editor → New Query):

```sql
-- These extend Supabase's default Postgres
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "postgis";   -- for GEOGRAPHY columns
CREATE EXTENSION IF NOT EXISTS "pg_net";    -- for HTTP calls from pg_cron
-- Note: pg_cron requires Supabase Pro. On Free tier, use Supabase scheduled functions.
```

---

## STEP 4 — Apply Migrations in Order

Run each file in the SQL Editor, in sequence:

```bash
# Via CLI (recommended)
supabase db reset  # only on fresh project — wipes and re-applies

# Or push individual migration files
cat migrations/01_base_schema.sql | supabase db execute --
cat migrations/02_base_views_rls.sql | supabase db execute --
cat migrations/03_base_seed_data.sql | supabase db execute --
cat migrations/04_rpc_functions.sql | supabase db execute --
cat migrations/05_auth_triggers.sql | supabase db execute --
cat migrations/06_missing_pieces.sql | supabase db execute --
```

**Manual SQL Editor approach (safer for existing projects):**
1. Open each file
2. Copy-paste into SQL Editor
3. Run
4. Check for errors before proceeding to next file

⚠️ **Order matters:** `01 → 02 → 03 → 04 → 05`. Never skip steps.

---

## STEP 5 — Post-Migration: Enable Realtime

Go to **Database → Replication** in the Dashboard, or run:

```sql
-- Enable Realtime publication for critical tables
ALTER PUBLICATION supabase_realtime ADD TABLE trust_scores;
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE team_members;
ALTER PUBLICATION supabase_realtime ADD TABLE opportunities;
ALTER PUBLICATION supabase_realtime ADD TABLE student_dna;
ALTER PUBLICATION supabase_realtime ADD TABLE peer_ratings;
```

---

## STEP 6 — Create Storage Buckets

Run in SQL Editor:

```sql
-- Public bucket: opportunity banners & organizer logos
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'opportunity-media', 'opportunity-media', true,
  5242880,
  ARRAY['image/jpeg','image/png','image/webp','image/gif']
) ON CONFLICT (id) DO NOTHING;

-- Private bucket: student assets (avatar, resume, certificates)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'student-assets', 'student-assets', false,
  10485760,
  ARRAY['image/jpeg','image/png','image/webp','application/pdf']
) ON CONFLICT (id) DO NOTHING;

-- Private bucket: badge evidence
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'badge-evidence', 'badge-evidence', false,
  10485760,
  ARRAY['image/jpeg','image/png','image/webp','application/pdf']
) ON CONFLICT (id) DO NOTHING;

-- Storage RLS: students manage own folder
CREATE POLICY "student_manage_own_assets"
  ON storage.objects FOR ALL
  USING (
    bucket_id = 'student-assets'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "public_read_opportunity_media"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'opportunity-media');

CREATE POLICY "student_manage_own_evidence"
  ON storage.objects FOR ALL
  USING (
    bucket_id = 'badge-evidence'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );
```

---

## STEP 7 — Configure Auth Settings

In the Dashboard → **Authentication → Settings**:

```
Site URL: https://your-app-domain.com (or http://localhost:3000 for dev)

Email Auth:
  ✅ Enable email confirmations
  ✅ Enable email change confirmations

Magic Link:
  ✅ Enable magic link sign-in
  Link expiry: 3600 seconds (1 hour)

Phone OTP:
  ✅ Enable phone sign-in
  SMS Provider: Twilio / MSG91 (India)
  → Add your Twilio Account SID + Auth Token in Provider settings

JWT Expiry: 3600 (1 hour access tokens)
Refresh Token Expiry: 604800 (7 days)
```

---

## STEP 8 — Set Edge Function Secrets

```bash
# Google Gemini AI (required for DNA, matching, scam detection)
supabase secrets set GEMINI_API_KEY=your_gemini_api_key_here

# Anthropic AI (optional fallback)
supabase secrets set ANTHROPIC_API_KEY=sk-ant-api03-...

# OpenAI fallback (optional)
supabase secrets set OPENAI_API_KEY=sk-...

# Service role (for inter-function calls — auto-available in Edge Functions)
# SUPABASE_SERVICE_ROLE_KEY is auto-injected; no need to set manually

# Upstash Redis (optional — for rate limiting & caching)
supabase secrets set UPSTASH_REDIS_URL=https://...
supabase secrets set UPSTASH_REDIS_TOKEN=...

# Verify secrets are set
supabase secrets list
```

---

## STEP 9 — Deploy Edge Functions

```bash
# Deploy all functions at once
supabase functions deploy recalculate-dna
supabase functions deploy match-teams
supabase functions deploy rank-opportunities
supabase functions deploy scam-detect
supabase functions deploy update-trust-score
supabase functions deploy sync-auth-profile
supabase functions deploy sync-erp

# Verify deployment
supabase functions list
```

---

## STEP 10 — Configure Webhooks (for scam-detect auto-trigger)

In Dashboard → **Database → Webhooks → Create Webhook**:

```
Name: scam-detect-on-opportunity-insert
Table: opportunities
Events: INSERT
URL: https://<project-ref>.supabase.co/functions/v1/scam-detect
HTTP Headers:
  Authorization: Bearer <SERVICE_ROLE_KEY>
  Content-Type: application/json
```

---

## STEP 11 — Schedule Cron Jobs (Supabase Pro / pg_cron)

```sql
-- Install extension (Pro tier only)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Nightly ERP sync at 2 AM IST (20:30 UTC)
SELECT cron.schedule(
  'erp-sync-nightly', '30 20 * * *',
  $$SELECT net.http_post(
    url := current_setting('app.supabase_url') || '/functions/v1/sync-erp',
    headers := jsonb_build_object('Authorization', 'Bearer ' || current_setting('app.service_role_key')),
    body := '{}'::jsonb
  )$$
);

-- Weekly DNA refresh: Sunday 3 AM IST (21:30 UTC Saturday)
SELECT cron.schedule(
  'dna-weekly-batch', '30 21 * * 0',
  $$
    SELECT net.http_post(
      url := current_setting('app.supabase_url') || '/functions/v1/recalculate-dna',
      headers := jsonb_build_object('Authorization', 'Bearer ' || current_setting('app.service_role_key')),
      body := jsonb_build_object('batch_all', true)
    )
    FROM student_profiles WHERE is_active = TRUE AND deleted_at IS NULL;
  $$
);

-- Daily: close expired opportunities at midnight IST
SELECT cron.schedule(
  'close-expired-opps', '30 18 * * *',
  $$UPDATE opportunities SET status = 'closed'
    WHERE status = 'active' AND apply_deadline < NOW() AND deleted_at IS NULL$$
);
```

**Free tier alternative:** Use Supabase's built-in **Scheduled Functions** (in Dashboard → Edge Functions → Schedule).

---

## STEP 12 — RLS Verification

Run this diagnostic query to confirm all tables are protected:

```sql
SELECT
  schemaname,
  tablename,
  rowsecurity AS rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;
```

All user-data tables should show `rls_enabled = true`.

Run the policy audit:
```sql
SELECT tablename, policyname, cmd, qual
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;
```

---

## STEP 13 — Verify Setup with Quick Tests

See `testing/test_suite.sh` and `testing/test_queries.sql` for full test suite.

Quick smoke test:
```bash
# Test DNA recalculation
curl -X POST \
  https://<project-ref>.supabase.co/functions/v1/recalculate-dna \
  -H "Authorization: Bearer <SERVICE_ROLE_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"student_id": "s1000000-0000-0000-0000-000000000001"}'

# Expected: {"success": true, "archetype": "...", "summary": "..."}
```

---

## Architecture Summary

```
Flutter App
    ↓  (Supabase Client SDK)
Supabase PostgREST / Realtime
    ↓
PostgreSQL (Tables + Views + RPCs)
    ↓ (Webhooks / direct calls)
Edge Functions (Deno / TypeScript)
    ↓
Claude AI API (Anthropic)
```

## STEP 7 — Apply New Migrations

Run in order after the original 01–06 migrations:

```bash
cat migrations/07_missing_modules.sql | supabase db execute --
cat migrations/08_demo_seed.sql | supabase db execute --
cat migrations/09_rls_and_seeds.sql | supabase db execute --
cat migrations/09_storage_buckets.sql | supabase db execute --
```

## STEP 8 — Deploy New Edge Functions

```bash
supabase functions deploy get-career-gaps
supabase functions deploy generate-portfolio
supabase functions deploy scheme-buddy-chat
supabase functions deploy refresh-leaderboard
```

## STEP 9 — Set Environment Variables

In Supabase Dashboard → Project Settings → Edge Functions → Secrets:
- `ANTHROPIC_API_KEY` — your Anthropic API key
- `ERP_URL_<COLLEGE_ID>` — optional, per-college ERP endpoint
- `ERP_API_KEY_<COLLEGE_ID>` — optional, per-college ERP API key

## STEP 10 — Schedule Leaderboard Refresh

In Supabase Dashboard → Edge Functions → refresh-leaderboard → Schedules:
Set cron expression to `*/15 * * * *`

## STEP 11 — Flutter Build

```bash
flutter pub get
flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co \
            --dart-define=SUPABASE_ANON_KEY=your-anon-key
```
