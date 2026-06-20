import { NextResponse } from "next/server";
import { requireUser } from "@/lib/auth";
import { updateSessionSchema, uuidSchema } from "@/lib/schemas";
import { handleRouteError, jsonError, readJson } from "@/lib/http";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

type RouteContext = {
  params: Promise<{ id: string }>;
};

export async function GET(request: Request, context: RouteContext) {
  try {
    const auth = await requireUser(request);
    const { id } = await context.params;
    const sessionId = uuidSchema.parse(id);

    const { data: session, error: sessionError } = await auth.supabase
      .from("meeting_sessions")
      .select("*")
      .eq("id", sessionId)
      .eq("user_id", auth.user.id)
      .maybeSingle();

    if (sessionError) {
      throw sessionError;
    }

    if (!session) {
      return jsonError("Session not found", 404);
    }

    const { data: transcript, error: transcriptError } = await auth.supabase
      .from("transcript_chunks")
      .select("*")
      .eq("session_id", sessionId)
      .eq("user_id", auth.user.id)
      .order("created_at", { ascending: true });

    if (transcriptError) {
      throw transcriptError;
    }

    return NextResponse.json({ session, transcript_chunks: transcript ?? [] });
  } catch (error) {
    return handleRouteError(error);
  }
}

export async function PATCH(request: Request, context: RouteContext) {
  try {
    const auth = await requireUser(request);
    const { id } = await context.params;
    const sessionId = uuidSchema.parse(id);
    const body = updateSessionSchema.parse(await readJson(request));

    const { data, error } = await auth.supabase
      .from("meeting_sessions")
      .update(body)
      .eq("id", sessionId)
      .eq("user_id", auth.user.id)
      .select("*")
      .maybeSingle();

    if (error) {
      throw error;
    }

    if (!data) {
      return jsonError("Session not found", 404);
    }

    return NextResponse.json({ session: data });
  } catch (error) {
    return handleRouteError(error);
  }
}

