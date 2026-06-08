// supabase/functions/refresh-leaderboard/index.ts
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createServiceClient, successResponse, errorResponse } from "../_shared/utils.ts";

serve(async (req: Request) => {
  const supabase = createServiceClient();
  try {
    const { error } = await supabase.rpc('refresh_trust_leaderboard');
    if (error) throw error;
    return successResponse({ refreshed: true, at: new Date().toISOString() });
  } catch (e) {
    return errorResponse(e instanceof Error ? e.message : "Refresh failed", 500);
  }
});
