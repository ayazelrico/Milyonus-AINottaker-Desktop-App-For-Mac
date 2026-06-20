# Milyonus Backend API

All endpoints require:

```bash
Authorization: Bearer <SUPABASE_USER_JWT>
Content-Type: application/json
```

## Create Session

```bash
curl -X POST "$API_BASE_URL/api/sessions" \
  -H "Authorization: Bearer $SUPABASE_JWT" \
  -H "Content-Type: application/json" \
  -d '{"title":"Sales Call","platform":"zoom"}'
```

Response:

```json
{ "session": { "id": "uuid", "status": "active" } }
```

## List Sessions

```bash
curl "$API_BASE_URL/api/sessions?limit=25&offset=0" \
  -H "Authorization: Bearer $SUPABASE_JWT"
```

## Get Session Detail

```bash
curl "$API_BASE_URL/api/sessions/$SESSION_ID" \
  -H "Authorization: Bearer $SUPABASE_JWT"
```

Response includes `session` and `transcript_chunks`.

## Update Session

```bash
curl -X PATCH "$API_BASE_URL/api/sessions/$SESSION_ID" \
  -H "Authorization: Bearer $SUPABASE_JWT" \
  -H "Content-Type: application/json" \
  -d '{"status":"ended","ended_at":"2026-06-20T18:00:00.000Z","summary":"Short summary"}'
```

## Sync Transcript Chunks

```bash
curl -X POST "$API_BASE_URL/api/sessions/$SESSION_ID/transcript" \
  -H "Authorization: Bearer $SUPABASE_JWT" \
  -H "Content-Type: application/json" \
  -d '{
    "chunks": [
      {
        "speaker": "other",
        "text": "Can you walk me through pricing?",
        "start_offset_ms": 1200,
        "end_offset_ms": 3100
      }
    ]
  }'
```

## Assist Streaming

```bash
curl -N -X POST "$API_BASE_URL/api/assist" \
  -H "Authorization: Bearer $SUPABASE_JWT" \
  -H "Content-Type: application/json" \
  -d '{
    "session_id": "'"$SESSION_ID"'",
    "transcript_context": "Karşı taraf: Bütçemizi netleştirmemiz gerekiyor.",
    "user_question": "Şimdi ne söylemeliyim?",
    "language": "tr"
  }'
```

The response is Server-Sent Events:

```text
event: start
data: {"ok":true}

event: delta
data: {"delta":"..."}

event: done
data: {"latency_ms":1234}
```

## Deepgram Token Grant

Issues a short-lived Deepgram access token for native clients. The server calls
Deepgram with `DEEPGRAM_API_KEY`; the macOS app must never store or send that
long-lived API key directly.

```bash
curl -X POST "$API_BASE_URL/api/deepgram-token" \
  -H "Authorization: Bearer $SUPABASE_JWT" \
  -H "Content-Type: application/json"
```

Response:

```json
{
  "token": "eyJ...",
  "expires_at": "2026-06-20T18:05:00.000Z"
}
```

Common errors:

- `401` when the Supabase JWT is missing or invalid.
- `429` when per-minute token grants are exhausted.
- `500` when required backend environment variables are missing.
- `502` when Deepgram token issuance fails upstream.

## Usage

```bash
curl "$API_BASE_URL/api/usage" \
  -H "Authorization: Bearer $SUPABASE_JWT"
```

Response:

```json
{
  "period_start": "2026-06-01T00:00:00.000Z",
  "plan": "free",
  "ai_calls": 4,
  "ai_call_limit": 100,
  "ai_calls_remaining": 96,
  "stt_minutes": 12
}
```
