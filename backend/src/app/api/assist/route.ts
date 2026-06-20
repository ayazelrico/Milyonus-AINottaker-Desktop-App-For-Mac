import { assistRequestSchema } from "@/lib/schemas";
import { assertAssistRateLimit, getUserPlan } from "@/lib/usage";
import { getOpenAI } from "@/lib/env";
import { handleRouteError, jsonError, readJson } from "@/lib/http";
import { requireUser } from "@/lib/auth";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const SYSTEM_PROMPT = `Sen Milyonus adlı bir canlı toplantı asistanısın. Kullanıcı şu anda devam eden bir toplantıda ve sana transcript'in son kısmını gösteriyorum. Görevin:
- Kısa, aksiyon odaklı öneriler ver (madde madde, 3-5 madde, gereksiz uzatma).
- Eğer kullanıcı açık bir soru sorduysa önce ona doğrudan cevap ver.
- Eğer soru yoksa: "şimdi ne söylemeli", takip sorusu önerisi, veya toplantının kısa özeti gibi bağlama en uygun yardımı sun.
- Toplantı dili neyse o dilde cevap ver (Türkçe transcript'e Türkçe cevap).
- Asla uydurma bilgi verme; transcript'te olmayan bir şeyi varsaymış gibi sunma.`;

function sse(event: string, data: unknown) {
  return `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
}

export async function POST(request: Request) {
  try {
    const auth = await requireUser(request);
    const body = assistRequestSchema.parse(await readJson(request));

    const { data: session, error: sessionError } = await auth.supabase
      .from("meeting_sessions")
      .select("id,user_id,status")
      .eq("id", body.session_id)
      .eq("user_id", auth.user.id)
      .maybeSingle();

    if (sessionError) {
      throw sessionError;
    }

    if (!session) {
      return jsonError("Session not found", 404);
    }

    const plan = await getUserPlan(auth.supabase, auth.user.id);
    const rateLimit = await assertAssistRateLimit(auth.supabase, auth.user.id, plan);

    if (!rateLimit.ok) {
      return new Response(JSON.stringify({ error: rateLimit.message }), {
        status: 429,
        headers: {
          "content-type": "application/json",
          "retry-after": String(rateLimit.retryAfterSeconds)
        }
      });
    }

    const encoder = new TextEncoder();
    const startedAt = Date.now();

    const stream = new ReadableStream<Uint8Array>({
      async start(controller) {
        let aiResponse = "";

        try {
          const completion = await getOpenAI().chat.completions.create({
            model: "gpt-4o",
            stream: true,
            messages: [
              { role: "system", content: SYSTEM_PROMPT },
              {
                role: "user",
                content: [
                  `Dil tercihi: ${body.language}`,
                  `Kullanıcı sorusu: ${body.user_question || "(yok)"}`,
                  "Son transcript context:",
                  body.transcript_context
                ].join("\n\n")
              }
            ]
          });

          controller.enqueue(encoder.encode(sse("start", { ok: true })));

          for await (const chunk of completion) {
            const delta = chunk.choices[0]?.delta?.content ?? "";

            if (delta) {
              aiResponse += delta;
              controller.enqueue(encoder.encode(sse("delta", { delta })));
            }
          }

          const latencyMs = Date.now() - startedAt;

          const interactionResult = await auth.supabase.from("ai_interactions").insert({
            session_id: body.session_id,
            user_id: auth.user.id,
            prompt_context: body.transcript_context.slice(0, 20000),
            user_question: body.user_question ?? null,
            ai_response: aiResponse,
            model: "gpt-4o",
            latency_ms: latencyMs
          });

          if (interactionResult.error) {
            console.error(interactionResult.error);
          }

          const usageResult = await auth.supabase.from("usage_logs").insert({
            user_id: auth.user.id,
            event_type: "ai_call",
            quantity: 1,
            metadata: {
              session_id: body.session_id,
              model: "gpt-4o",
              latency_ms: latencyMs
            }
          });

          if (usageResult.error) {
            console.error(usageResult.error);
          }

          controller.enqueue(encoder.encode(sse("done", { latency_ms: latencyMs })));
        } catch (error) {
          console.error(error);
          controller.enqueue(encoder.encode(sse("error", { message: "Assist request failed" })));
        } finally {
          controller.close();
        }
      }
    });

    return new Response(stream, {
      headers: {
        "content-type": "text/event-stream; charset=utf-8",
        "cache-control": "no-cache, no-transform",
        connection: "keep-alive"
      }
    });
  } catch (error) {
    return handleRouteError(error);
  }
}

