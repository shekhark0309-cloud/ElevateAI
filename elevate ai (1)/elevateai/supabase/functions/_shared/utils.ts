// supabase/functions/_shared/utils.ts
// ═══════════════════════════════════════════════════════════════
// ElevateAI — Shared Utilities for all Edge Functions
// ═══════════════════════════════════════════════════════════════

import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

// ─── Types ────────────────────────────────────────────────────

export interface StudentFullProfile {
  id: string;
  full_name: string;
  college_id: string;
  course: string;
  branch: string;
  year_of_study: number;
  graduation_year: number;
  cgpa: number;
  state: string;
  category: string;
  family_income: number;
  gender: string;
  // Relations
  student_dna?: StudentDNA;
  trust_scores?: TrustScore;
  student_skills?: StudentSkill[];
  student_badges?: StudentBadge[];
  student_projects?: StudentProject[];
  student_achievements?: StudentAchievement[];
}

export interface StudentDNA {
  id: string;
  student_id: string;
  archetype: "Builder" | "Strategist" | "Creative" | "Executor" | null;
  archetype_confidence: number;
  top_skills: string[];
  goals_short_term: string[];
  goals_long_term: string[];
  ai_summary: string | null;
  ai_strengths: string[];
  ai_growth_areas: string[];
  ai_team_role_hint: string | null;
  preferred_study_time: string | null;
  availability: Record<string, string[]>;
  target_roles: string[];
  preferred_industries: string[];
  prefers_remote: boolean;
  team_size_preference: string | null;
  version: number;
  last_ai_updated: string | null;
}

export interface TrustScore {
  id: string;
  student_id: string;
  overall_score: number;
  tier: "Unverified" | "Bronze" | "Silver" | "Gold" | "Platinum";
  reliability_score: number;
  collaboration_score: number;
  integrity_score: number;
  skill_validation_score: number;
  community_score: number;
  is_frozen: boolean;
  erp_attendance_pct?: number;
  erp_assignment_score?: number;
}

export interface StudentSkill {
  skill_name: string;
  proficiency: number;
  is_verified: boolean;
  source: string;
}

export interface StudentBadge {
  verify_status: string;
  earned_at: string;
  skill_badges: { name: string; category: string; level: number; xp_value: number };
}

export interface StudentProject {
  title: string;
  description: string;
  tech_stack: string[];
  role: string;
  outcome: string;
  is_featured: boolean;
}

export interface StudentAchievement {
  title: string;
  achievement_type: string;
  issued_by: string;
  is_verified: boolean;
}

export interface APIResponse<T = unknown> {
  success: boolean;
  data?: T;
  error?: string;
  code?: string;
}

// ─── Supabase Clients ──────────────────────────────────────────

/**
 * Creates a service-role Supabase client (bypasses RLS).
 * Used only in trusted Edge Functions.
 */
export function createServiceClient(): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
  return createClient(url, key, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

/**
 * Creates a user-scoped client using the JWT from the request.
 * Respects RLS — use for user-initiated actions.
 */
export function createUserClient(authHeader: string): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  return createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

// ─── Auth Helper ─────────────────────────────────────────────

export async function getAuthenticatedUser(req: Request) {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return { user: null, error: "Missing Authorization header" };

  const supabase = createUserClient(authHeader);
  const { data: { user }, error } = await supabase.auth.getUser();

  if (error || !user) return { user: null, error: error?.message || "Invalid token" };
  return { user, error: null };
}

// ─── Response Helpers ─────────────────────────────────────────

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

export function successResponse<T>(data: T, status = 200): Response {
  return new Response(JSON.stringify({ success: true, data }), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

export function errorResponse(error: string, status = 400, code?: string): Response {
  return new Response(JSON.stringify({ success: false, error, code }), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

export function optionsResponse(): Response {
  return new Response(null, { status: 204, headers: corsHeaders });
}

// ─── Notification Helper ──────────────────────────────────────

export async function createNotification(
  supabase: SupabaseClient,
  studentId: string,
  type: string,
  title: string,
  body: string,
  data: Record<string, unknown> = {}
): Promise<void> {
  await supabase.from("notifications").insert({
    student_id: studentId,
    type,
    title,
    body,
    data,
  });
}

// ─── Rate Limiting (In-Memory + Redis Ready) ──────────────────

const rateLimitMap = new Map<string, { count: number; resetAt: number }>();

/**
 * Simple sliding-window rate limiter.
 * PRO TIP: For production, use Upstash Redis (https://upstash.com)
 * to share limits across Edge Function instances.
 */
export function isRateLimited(key: string, maxRequests: number, windowMs: number): boolean {
  // Check for Redis override first
  // const redisUrl = Deno.env.get("UPSTASH_REDIS_URL");
  // if (redisUrl) { /* Implement Redis-based limit */ }

  const now = Date.now();
  const entry = rateLimitMap.get(key);

  if (!entry || now > entry.resetAt) {
    rateLimitMap.set(key, { count: 1, resetAt: now + windowMs });
    return false;
  }

  if (entry.count >= maxRequests) return true;
  entry.count++;
  return false;
}

// ─── AI Client Helper ─────────────────────────────────────────

export interface AIMessage {
  role: "user" | "assistant";
  content: string;
}

/**
 * Calls AI with fallback logic.
 * Models used: Claude 3.5 Sonnet (Primary), GPT-4o (Fallback)
 */
export async function callAI(
  messages: AIMessage[],
  systemPrompt: string,
  maxTokens = 1000
): Promise<string> {
  const anthropicKey = Deno.env.get("ANTHROPIC_API_KEY");

  if (anthropicKey) {
    try {
      const response = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-api-key": anthropicKey,
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify({
          model: "claude-3-5-sonnet-20241022",
          max_tokens: maxTokens,
          system: systemPrompt,
          messages,
        }),
      });

      if (response.ok) {
        const data = await response.json();
        return data.content[0].text;
      }
      console.warn("Anthropic API error, trying fallback:", await response.text());
    } catch (e) {
      console.warn("Anthropic fetch failed, trying fallback:", e);
    }
  }

  // Fallback: OpenAI
  const openaiKey = Deno.env.get("OPENAI_API_KEY");
  if (openaiKey) {
    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${openaiKey}`,
      },
      body: JSON.stringify({
        model: "gpt-4o",
        max_tokens: maxTokens,
        messages: [{ role: "system", content: systemPrompt }, ...messages],
      }),
    });

    if (response.ok) {
      const data = await response.json();
      return data.choices[0].message.content;
    }
  }

  throw new Error("AI services unavailable. Please check API keys.");
}

export function parseAIJson<T>(text: string): T {
  const cleaned = text.replace(/```json\n?/g, "").replace(/```\n?/g, "").trim();
  try {
    return JSON.parse(cleaned) as T;
  } catch {
    const match = cleaned.match(/\{[\s\S]*\}|\[[\s\S]*\]/);
    if (match) return JSON.parse(match[0]) as T;
    throw new Error("Could not parse AI response as JSON");
  }
}

// ─── TrustScore Logic ──────────────────────────────────────────

export function calculateTrustTier(score: number): TrustScore["tier"] {
  if (score >= 90) return "Platinum";
  if (score >= 75) return "Gold";
  if (score >= 55) return "Silver";
  if (score >= 30) return "Bronze";
  return "Unverified";
}

export function computeOverallTrustScore(dimensions: {
  reliability_score: number;
  collaboration_score: number;
  integrity_score: number;
  skill_validation_score: number;
  community_score: number;
}): number {
  const score =
    0.30 * dimensions.reliability_score +
    0.25 * dimensions.collaboration_score +
    0.20 * dimensions.integrity_score +
    0.15 * dimensions.skill_validation_score +
    0.10 * dimensions.community_score;
  return Math.min(100, Math.max(0, Math.round(score * 10) / 10));
}

// ─── Reliability Intelligence ──────────────────────────────────

export interface ReliabilityInsight {
  status: string;
  explanation: string;
  is_warning: boolean;
  color: string;
}

/**
 * Generates reliability insights based on TrustScore and Skill performance.
 * Logic as per PS #4 requirements.
 */
export function analyzeReliability(trustScore: number, skillScore: number): ReliabilityInsight {
  if (skillScore > 85 && trustScore < 50) {
    return {
      status: "Reliability Risk",
      explanation: "Highly skilled but shows inconsistency in commitments or peer collaboration.",
      is_warning: true,
      color: "red"
    };
  }
  if (skillScore > 80 && trustScore > 80) {
    return {
      status: "Elite Contributor",
      explanation: "Exceptional skills combined with a proven track record of reliability.",
      is_warning: false,
      color: "green"
    };
  }
  if (trustScore > 90) {
    return {
      status: "Highly Trusted",
      explanation: "Top-tier reliability and integrity as validated by college records and peers.",
      is_warning: false,
      color: "blue"
    };
  }
  if (trustScore < 40) {
    return {
      status: "Reliability Improvement Needed",
      explanation: "Needs to build a more consistent record of task completion and participation.",
      is_warning: true,
      color: "orange"
    };
  }
  return {
    status: "Standard Reliability",
    explanation: "Reliable team member with a balanced collaboration history.",
    is_warning: false,
    color: "grey"
  };
}
