import { NextResponse } from "next/server";
import { ZodError } from "zod";

export function jsonError(message: string, status = 400, details?: unknown) {
  return NextResponse.json({ error: message, details }, { status });
}

export function handleRouteError(error: unknown) {
  if (error instanceof ZodError) {
    return jsonError("Invalid request body", 400, error.flatten());
  }

  if (error instanceof Error && error.name === "AuthError") {
    return jsonError(error.message, 401);
  }

  console.error(error);
  return jsonError("Internal server error", 500);
}

export async function readJson(request: Request): Promise<unknown> {
  try {
    return await request.json();
  } catch {
    return {};
  }
}

