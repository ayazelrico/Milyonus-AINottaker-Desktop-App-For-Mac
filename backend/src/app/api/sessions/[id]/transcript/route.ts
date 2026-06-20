import { NextResponse } from "next/server";
import { requireUser } from "@/lib/auth";
import { transcriptBatchSchema, uuidSchema } from "@/lib/schemas";
import { handleRouteError, jsonError, readJson } from "@/lib/http";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

type RouteContext = {
  params: Promise<{ id: string }>;
};

export async function POST(request: Request, context: RouteContext) {
  try {
    const auth = await requireUser(request);
    const { id } = await context.params;
    const sessionId = uuidSchema.parse(id);
    const body = transcriptBatchSchema.parse(await readJson(request));

    const { data: session, error: sessionError } = await auth.supabase
      .from("meeting_sessions")
      .select("id")
      .eq("id", sessionId)
      .eq("user_id", auth.user.id)
      .maybeSingle();

    if (sessionError) {
      throw sessionError;
    }

    if (!session) {
      return jsonError("Session not found", 404);
    }

    const rows = body.chunks.map((chunk) => ({
      session_id: sessionId,
      user_id: auth.user.id,
      speaker: chunk.speaker,
      text: chunk.text,
      start_offset_ms: chunk.start_offset_ms ?? null,
      end_offset_ms: chunk.end_offset_ms ?? null
    }));

    const { data, error } = await auth.supabase
      .from("transcript_chunks")
      .insert(rows)
      .select("*");

    if (error) {
      throw error;
    }

    return NextResponse.json({ inserted: data?.length ?? 0, chunks: data ?? [] }, { status: 201 });
  } catch (error) {
    return handleRouteError(error);
  }
}

