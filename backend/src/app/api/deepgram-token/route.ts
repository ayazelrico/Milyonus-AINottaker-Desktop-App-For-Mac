import { NextResponse } from "next/server";
import { requireUser } from "@/lib/auth";
import { requiredEnv } from "@/lib/env";
import { handleRouteError, jsonError } from "@/lib/http";
import { assertDeepgramTokenGrantRateLimit, getUserPlan } from "@/lib/usage";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const DEEPGRAM_GRANT_URL = "https://api.deepgram.com/v1/auth/grant";
const DEEPGRAM_TOKEN_TTL_SECONDS = 300;

type DeepgramGrantResponse = {
  access_token?: unknown;
  expires_in?: unknown;
};

function expiresAtFromSeconds(seconds: number) {
  return new Date(Date.now() + seconds * 1000).toISOString();
}

export async function POST(request: Request) {
  try {
    const auth = await requireUser(request);
    const plan = await getUserPlan(auth.supabase, auth.user.id);
    const rateLimit = await assertDeepgramTokenGrantRateLimit(
      auth.supabase,
      auth.user.id,
      plan
    );

    if (!rateLimit.ok) {
      return new Response(JSON.stringify({ error: rateLimit.message }), {
        status: 429,
        headers: {
          "content-type": "application/json",
          "retry-after": String(rateLimit.retryAfterSeconds)
        }
      });
    }

    const response = await fetch(DEEPGRAM_GRANT_URL, {
      method: "POST",
      headers: {
        authorization: `Token ${requiredEnv("DEEPGRAM_API_KEY")}`,
        "content-type": "application/json"
      },
      body: JSON.stringify({ ttl_seconds: DEEPGRAM_TOKEN_TTL_SECONDS }),
      cache: "no-store"
    });

    if (!response.ok) {
      const details = { status: response.status };
      return jsonError("Deepgram token grant failed", 502, details);
    }

    const grant = (await response.json()) as DeepgramGrantResponse;

    if (typeof grant.access_token !== "string" || typeof grant.expires_in !== "number") {
      return jsonError("Deepgram token grant returned an invalid response", 502);
    }

    const usageResult = await auth.supabase.from("usage_logs").insert({
      user_id: auth.user.id,
      event_type: "deepgram_token_grant",
      quantity: 1,
      metadata: {
        ttl_seconds: grant.expires_in
      }
    });

    if (usageResult.error) {
      console.error(usageResult.error);
    }

    return NextResponse.json({
      token: grant.access_token,
      expires_at: expiresAtFromSeconds(grant.expires_in)
    });
  } catch (error) {
    return handleRouteError(error);
  }
}
