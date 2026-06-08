// supabase/functions/sync-auth-profile/index.ts
// ═══════════════════════════════════════════════════════════════
// ElevateAI — Auth User Sync
//
// Triggered when a new user signs up via Supabase Auth.
// Also handles: auth.user webhook (Dashboard → Auth → Hooks)
//
// Actions on new user:
//   1. Creates student_profiles row (if not exists)
//   2. Creates student_dna row (blank template)
//   3. Creates trust_scores row (zero state)
//   4. Sends welcome notification
//   5. Queues DNA recalculation (after profile is filled)
// ═══════════════════════════════════════════════════════════════

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import {
  createServiceClient,
  successResponse,
  errorResponse,
  optionsResponse,
  createNotification,
} from "../_shared/utils.ts";

// ─── Main Handler ─────────────────────────────────────────────

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return optionsResponse();
  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  let body: {
    type?: string;
    event?: string;
    record?: {
      id: string;
      email: string;
      phone?: string;
      user_metadata?: {
        full_name?: string;
        college_id?: string;
        roll_number?: string;
        course?: string;
        branch?: string;
        year_of_study?: number;
      };
    };
    // Direct call
    user_id?: string;
    email?: string;
    user_metadata?: Record<string, unknown>;
  };

  try {
    body = await req.json();
  } catch {
    return errorResponse("Invalid JSON body");
  }

  const supabase = createServiceClient();

  // Handle both webhook format and direct call
  const userId = body.record?.id ?? body.user_id;
  const email = body.record?.email ?? body.email;
  const metadata = body.record?.user_metadata ?? body.user_metadata ?? {};

  if (!userId || !email) {
    return errorResponse("user_id and email are required");
  }

  // Only process on INSERT (new signup)
  if (body.type && body.type !== "INSERT") {
    return successResponse({ skipped: true, reason: "Not a new user event" });
  }

  try {
    await setupNewStudent(supabase, userId, email, metadata as Record<string, string | number>);
    return successResponse({ success: true, user_id: userId });
  } catch (e) {
    console.error("sync-auth-profile error:", e);
    return errorResponse(e instanceof Error ? e.message : "Unexpected error", 500);
  }
});

// ─── Setup Logic ──────────────────────────────────────────────

async function setupNewStudent(
  supabase: ReturnType<typeof createServiceClient>,
  userId: string,
  email: string,
  metadata: Record<string, string | number>
) {
  // ── 1. Check if profile already exists ───────────────────
  const { data: existing } = await supabase
    .from("student_profiles")
    .select("id")
    .eq("id", userId)
    .single();

  if (existing) {
    console.log(`Profile already exists for ${userId}, skipping setup`);
    return;
  }

  // ── 2. Resolve college_id ─────────────────────────────────
  // college_id should be passed in user_metadata during signup
  let collegeId = metadata.college_id as string ?? null;

  if (!collegeId) {
    // Default to first college if not specified (dev/test only)
    const { data: defaultCollege } = await supabase
      .from("colleges")
      .select("id")
      .eq("is_verified", true)
      .limit(1)
      .single();
    collegeId = defaultCollege?.id ?? "c1000000-0000-0000-0000-000000000001";
  }

  // ── 3. Create student_profiles row ───────────────────────
  const profilePayload = {
    id: userId,
    college_id: collegeId,
    full_name: (metadata.full_name as string) ?? email.split("@")[0].replace(/[._]/g, " "),
    email,
    roll_number: metadata.roll_number as string ?? null,
    course: metadata.course as string ?? null,
    branch: metadata.branch as string ?? null,
    year_of_study: metadata.year_of_study as number ?? null,
    is_active: true,
  };

  const { error: profileErr } = await supabase
    .from("student_profiles")
    .insert(profilePayload);

  if (profileErr) {
    throw new Error(`Failed to create profile: ${profileErr.message}`);
  }

  // ── 4. Create student_dna blank template ─────────────────
  const { error: dnaErr } = await supabase
    .from("student_dna")
    .insert({
      student_id: userId,
      archetype: null,
      archetype_confidence: 0,
      top_skills: [],
      goals_short_term: [],
      goals_long_term: [],
      ai_summary: null,
      ai_strengths: [],
      ai_growth_areas: [],
      ai_team_role_hint: null,
      target_roles: [],
      preferred_industries: [],
      availability: {},
    });

  if (dnaErr && !dnaErr.message.includes("duplicate")) {
    console.warn(`DNA creation warning for ${userId}:`, dnaErr.message);
  }

  // ── 5. Create trust_scores zero record ───────────────────
  const { error: trustErr } = await supabase
    .from("trust_scores")
    .insert({
      student_id: userId,
      overall_score: 0,
      tier: "Unverified",
      reliability_score: 0,
      collaboration_score: 0,
      integrity_score: 0,
      skill_validation_score: 0,
      community_score: 0,
    });

  if (trustErr && !trustErr.message.includes("duplicate")) {
    console.warn(`TrustScore creation warning for ${userId}:`, trustErr.message);
  }

  // ── 6. Welcome notification ───────────────────────────────
  await createNotification(
    supabase,
    userId,
    "welcome",
    "🎉 Welcome to ElevateAI!",
    "Your Student Success OS is ready. Complete your profile to unlock your DNA score and start getting matched with opportunities.",
    {
      next_steps: [
        "Complete your profile (course, CGPA, skills)",
        "Add 3+ skills to activate DNA Engine",
        "Explore opportunities matched to your profile",
      ],
    }
  );

  // ── 7. Initial trust score history entry ─────────────────
  await supabase.from("trust_score_history").insert({
    student_id: userId,
    overall_score: 0,
    delta: 0,
    reason: "Account created — TrustScore initialized",
    source: "system",
    snapshot: { tier: "Unverified" },
  });

  console.log(`New student setup complete: ${userId} (${email})`);
}
