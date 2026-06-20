# Deepgram Token Strategy

## Backend contract

`POST /api/deepgram-token` is the only production path for native clients to get
Deepgram credentials. It requires the same Supabase user JWT as the rest of the
backend API and returns:

```json
{
  "token": "eyJ...",
  "expires_at": "2026-06-20T18:05:00.000Z"
}
```

The endpoint calls Deepgram's `/v1/auth/grant` API with
`ttl_seconds: 300`. Deepgram accepts a TTL from 1 to 3600 seconds and defaults to
30 seconds when omitted; five minutes gives the app enough room for initial
connection and reconnect attempts while keeping leaked tokens short-lived.

The long-lived `DEEPGRAM_API_KEY` must exist only in the backend runtime
environment, such as Vercel project environment variables. The API key used for
token grants needs Member or higher permissions in Deepgram.

## Swift client usage for Faz 9

- Request a token from `/api/deepgram-token` immediately before opening a
  Deepgram streaming WebSocket.
- Use the returned token as a Deepgram access token for the connection. Do not
  send or persist the long-lived project API key in the app.
- If the WebSocket closes because of auth, network, or app lifecycle changes,
  request a fresh backend token before reconnecting.
- Do not close an otherwise healthy WebSocket just because `expires_at` passes.
  Deepgram documents that streaming WebSocket connections can outlive the token
  TTL because the token is validated when the connection is established.
- The app can refresh the token shortly before expiry only as reconnect
  preparation. The refreshed token should be used for the next WebSocket
  connection, not injected into an already-open stream.

## Usage and limits

Successful grants are logged to `usage_logs` with
`event_type = 'deepgram_token_grant'`. The MVP limiter counts grant events in
the last minute:

- `free`: 12 grants/minute
- `pro`: 60 grants/minute
- `team`: 120 grants/minute

If usage grows beyond MVP needs, move this limiter to Redis or another
distributed rate limiter so concurrent serverless instances share one counter.
