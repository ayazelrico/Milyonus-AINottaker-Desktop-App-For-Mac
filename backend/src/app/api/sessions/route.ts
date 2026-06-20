import { NextRequest, NextResponse } from "next/server";
import { requireUser } from "@/lib/auth";
import { createSessionSchema } from "@/lib/schemas";
import { handleRouteError, readJson } from "@/lib/http";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(request: NextRequest) {
  try {
    const auth = await requireUser(request);
    const limit = Math.min(Number(request.nextUrl.searchParams.get("limit") ?? 25), 100);
    const offset = Math.max(Number(request.nextUrl.searchParams.get("offset") ?? 0), 0);

    const { data, error, count } = await auth.supabase
      .from("meeting_sessions")
      .select("*", { count: "exact" })
      .eq("user_id", auth.user.id)
      .order("started_at", { ascending: false })
      .range(offset, offset + limit - 1);

    if (error) {
      throw error;
    }

    return NextResponse.json({ sessions: data ?? [], count: count ?? 0, limit, offset });
  } catch (error) {
    return handleRouteError(error);
  }
}

export async function POST(request: Request) {
  try {
    const auth = await requireUser(request);
    const body = createSessionSchema.parse(await readJson(request));

    const { data, error } = await auth.supabase
      .from("meeting_sessions")
      .insert({
        user_id: auth.user.id,
        title: body.title ?? null,
        platform: body.platform ?? null,
        status: "active"
      })
      .select("*")
      .single();

    if (error) {
      throw error;
    }

    await auth.supabase.from("usage_logs").insert({
      user_id: auth.user.id,
      event_type: "session_started",
      quantity: 1,
      metadata: { session_id: data.id }
    });

    return NextResponse.json({ session: data }, { status: 201 });
  } catch (error) {
    return handleRouteError(error);
  }
}

