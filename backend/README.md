# Milyonus Backend

Next.js App Router API for the Milyonus macOS app.

## Local Development

```bash
cp .env.example .env.local
pnpm install
pnpm dev
```

The API runs at `http://localhost:3000`.

## Environment Variables

```bash
SUPABASE_URL=
SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
OPENAI_API_KEY=
DEEPGRAM_API_KEY=
```

`SUPABASE_SERVICE_ROLE_KEY`, `OPENAI_API_KEY`, and `DEEPGRAM_API_KEY` are server-only. Do not return them from API responses and never embed them in the Swift app.

Normal request handling uses the authenticated user's Supabase JWT with the anon key. This keeps Supabase RLS active as a second safety layer. `SUPABASE_SERVICE_ROLE_KEY` is reserved for future server-only admin tasks.

## Deploy

Deploy through the Vercel GitHub integration or with:

```bash
vercel --prod
```

Set all environment variables in the Vercel project before production traffic.

## Endpoints

See `API.md` for curl examples.
