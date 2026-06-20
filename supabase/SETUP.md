# Supabase Setup

This folder contains Milyonus database migrations and Auth setup notes.

## Apply Migrations

Install and log in to the Supabase CLI, link the project, then apply migrations:

```bash
supabase login
supabase link --project-ref <your-project-ref>
supabase db push
```

For local development:

```bash
supabase start
supabase db reset
```

## Auth Providers

Enable these providers in Supabase Dashboard > Authentication > Providers:

- Email: enable magic link sign-in.
- Google: enable Google OAuth and paste the Google OAuth client ID and client secret from Google Cloud Console.

Set the redirect URLs to the production Vercel backend URL and any local development URL used by the app/backend during testing.

## Environment Variables

Backend/Vercel:

```bash
SUPABASE_URL=
SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
```

Swift app:

```bash
SUPABASE_URL=
SUPABASE_ANON_KEY=
```

`SUPABASE_SERVICE_ROLE_KEY` IS SERVER-ONLY. NEVER PUT IT IN THE SWIFT APP, A FRONTEND BUNDLE, A CLIENT RESPONSE, OR A LOG.

## RLS Notes

All application tables have Row Level Security enabled. Policies only allow a user to select, insert, update, or delete their own rows.

`transcript_chunks` includes a denormalized `user_id` in addition to `session_id`. This keeps RLS policies and backend batch inserts simple and fast while still checking that inserted chunks belong to a session owned by the authenticated user.

The backend should prefer user JWT Supabase clients for normal request handling so RLS remains an additional safety layer. Reserve `SUPABASE_SERVICE_ROLE_KEY` for server-only admin tasks that truly require bypassing RLS.

