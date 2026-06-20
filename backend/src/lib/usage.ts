import type { SupabaseClient } from "@supabase/supabase-js";

export type Plan = "free" | "pro" | "team";

export const planLimits: Record<Plan, { aiCallsPerMinute: number; monthlyAiCalls: number }> = {
  free: { aiCallsPerMinute: 1, monthlyAiCalls: 100 },
  pro: { aiCallsPerMinute: 60, monthlyAiCalls: 5000 },
  team: { aiCallsPerMinute: 120, monthlyAiCalls: 20000 }
};

export function normalizePlan(plan: unknown): Plan {
  if (plan === "pro" || plan === "team") {
    return plan;
  }

  return "free";
}

export function currentMonthStart(): string {
  const now = new Date();
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1)).toISOString();
}

export async function getUserPlan(supabase: SupabaseClient, userId: string): Promise<Plan> {
  const { data } = await supabase
    .from("profiles")
    .select("plan")
    .eq("id", userId)
    .maybeSingle();

  return normalizePlan(data?.plan);
}

export async function assertAssistRateLimit(supabase: SupabaseClient, userId: string, plan: Plan) {
  const limit = planLimits[plan];
  const since = new Date(Date.now() - 60_000).toISOString();

  const { count, error } = await supabase
    .from("usage_logs")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId)
    .eq("event_type", "ai_call")
    .gte("created_at", since);

  if (error) {
    throw error;
  }

  if ((count ?? 0) >= limit.aiCallsPerMinute) {
    const retryAfterSeconds = 60;
    return {
      ok: false as const,
      retryAfterSeconds,
      message: "Rate limit exceeded"
    };
  }

  return { ok: true as const };
}

