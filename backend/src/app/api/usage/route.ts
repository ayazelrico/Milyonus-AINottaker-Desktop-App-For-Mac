import { NextResponse } from "next/server";
import { requireUser } from "@/lib/auth";
import { currentMonthStart, getUserPlan, planLimits } from "@/lib/usage";
import { handleRouteError } from "@/lib/http";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  try {
    const auth = await requireUser(request);
    const plan = await getUserPlan(auth.supabase, auth.user.id);
    const since = currentMonthStart();

    const { count: aiCallCount, error: aiError } = await auth.supabase
      .from("usage_logs")
      .select("id", { count: "exact", head: true })
      .eq("user_id", auth.user.id)
      .eq("event_type", "ai_call")
      .gte("created_at", since);

    if (aiError) {
      throw aiError;
    }

    const { data: sttRows, error: sttError } = await auth.supabase
      .from("usage_logs")
      .select("quantity")
      .eq("user_id", auth.user.id)
      .eq("event_type", "stt_minute")
      .gte("created_at", since);

    if (sttError) {
      throw sttError;
    }

    const sttMinutes = (sttRows ?? []).reduce((total, row) => {
      const quantity = typeof row.quantity === "number" ? row.quantity : Number(row.quantity ?? 0);
      return total + quantity;
    }, 0);

    const monthlyLimit = planLimits[plan].monthlyAiCalls;
    const aiCalls = aiCallCount ?? 0;

    return NextResponse.json({
      period_start: since,
      plan,
      ai_calls: aiCalls,
      ai_call_limit: monthlyLimit,
      ai_calls_remaining: Math.max(monthlyLimit - aiCalls, 0),
      stt_minutes: sttMinutes
    });
  } catch (error) {
    return handleRouteError(error);
  }
}

