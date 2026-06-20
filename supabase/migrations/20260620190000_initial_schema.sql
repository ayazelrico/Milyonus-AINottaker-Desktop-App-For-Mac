-- Milyonus initial Supabase schema.
-- SECURITY: SUPABASE_SERVICE_ROLE_KEY must only be used by the Vercel backend.
-- Never embed SUPABASE_SERVICE_ROLE_KEY, OPENAI_API_KEY, or DEEPGRAM_API_KEY in the Swift app.

create extension if not exists "pgcrypto";

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  plan text not null default 'free',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_plan_check check (plan in ('free', 'pro', 'team'))
);

create table if not exists public.meeting_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text,
  platform text,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  status text not null default 'active',
  summary text,
  created_at timestamptz not null default now(),
  constraint meeting_sessions_platform_check check (
    platform is null or platform in ('zoom', 'teams', 'meet', 'other')
  ),
  constraint meeting_sessions_status_check check (status in ('active', 'ended', 'discarded'))
);

create table if not exists public.transcript_chunks (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.meeting_sessions(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  speaker text not null,
  text text not null,
  start_offset_ms integer,
  end_offset_ms integer,
  created_at timestamptz not null default now(),
  constraint transcript_chunks_speaker_check check (speaker in ('user', 'other')),
  constraint transcript_chunks_offsets_check check (
    start_offset_ms is null
    or end_offset_ms is null
    or end_offset_ms >= start_offset_ms
  )
);

create table if not exists public.ai_interactions (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.meeting_sessions(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  prompt_context text,
  user_question text,
  ai_response text,
  model text not null default 'gpt-4o',
  latency_ms integer,
  created_at timestamptz not null default now()
);

create table if not exists public.usage_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  event_type text not null,
  quantity numeric not null default 1,
  metadata jsonb,
  created_at timestamptz not null default now()
);

create index if not exists meeting_sessions_user_started_idx
  on public.meeting_sessions (user_id, started_at desc);

create index if not exists transcript_chunks_session_created_idx
  on public.transcript_chunks (session_id, created_at);

create index if not exists transcript_chunks_user_created_idx
  on public.transcript_chunks (user_id, created_at);

create index if not exists ai_interactions_session_created_idx
  on public.ai_interactions (session_id, created_at);

create index if not exists usage_logs_user_created_idx
  on public.usage_logs (user_id, created_at);

drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name')
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.meeting_sessions enable row level security;
alter table public.transcript_chunks enable row level security;
alter table public.ai_interactions enable row level security;
alter table public.usage_logs enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
on public.profiles for select
using (auth.uid() = id);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
on public.profiles for insert
with check (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
on public.profiles for update
using (auth.uid() = id)
with check (auth.uid() = id);

drop policy if exists "profiles_delete_own" on public.profiles;
create policy "profiles_delete_own"
on public.profiles for delete
using (auth.uid() = id);

drop policy if exists "meeting_sessions_select_own" on public.meeting_sessions;
create policy "meeting_sessions_select_own"
on public.meeting_sessions for select
using (auth.uid() = user_id);

drop policy if exists "meeting_sessions_insert_own" on public.meeting_sessions;
create policy "meeting_sessions_insert_own"
on public.meeting_sessions for insert
with check (auth.uid() = user_id);

drop policy if exists "meeting_sessions_update_own" on public.meeting_sessions;
create policy "meeting_sessions_update_own"
on public.meeting_sessions for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "meeting_sessions_delete_own" on public.meeting_sessions;
create policy "meeting_sessions_delete_own"
on public.meeting_sessions for delete
using (auth.uid() = user_id);

drop policy if exists "transcript_chunks_select_own" on public.transcript_chunks;
create policy "transcript_chunks_select_own"
on public.transcript_chunks for select
using (auth.uid() = user_id);

drop policy if exists "transcript_chunks_insert_own_session" on public.transcript_chunks;
create policy "transcript_chunks_insert_own_session"
on public.transcript_chunks for insert
with check (
  auth.uid() = user_id
  and exists (
    select 1
    from public.meeting_sessions
    where meeting_sessions.id = transcript_chunks.session_id
      and meeting_sessions.user_id = auth.uid()
  )
);

drop policy if exists "transcript_chunks_update_own" on public.transcript_chunks;
create policy "transcript_chunks_update_own"
on public.transcript_chunks for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "transcript_chunks_delete_own" on public.transcript_chunks;
create policy "transcript_chunks_delete_own"
on public.transcript_chunks for delete
using (auth.uid() = user_id);

drop policy if exists "ai_interactions_select_own" on public.ai_interactions;
create policy "ai_interactions_select_own"
on public.ai_interactions for select
using (auth.uid() = user_id);

drop policy if exists "ai_interactions_insert_own_session" on public.ai_interactions;
create policy "ai_interactions_insert_own_session"
on public.ai_interactions for insert
with check (
  auth.uid() = user_id
  and exists (
    select 1
    from public.meeting_sessions
    where meeting_sessions.id = ai_interactions.session_id
      and meeting_sessions.user_id = auth.uid()
  )
);

drop policy if exists "ai_interactions_update_own" on public.ai_interactions;
create policy "ai_interactions_update_own"
on public.ai_interactions for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "ai_interactions_delete_own" on public.ai_interactions;
create policy "ai_interactions_delete_own"
on public.ai_interactions for delete
using (auth.uid() = user_id);

drop policy if exists "usage_logs_select_own" on public.usage_logs;
create policy "usage_logs_select_own"
on public.usage_logs for select
using (auth.uid() = user_id);

drop policy if exists "usage_logs_insert_own" on public.usage_logs;
create policy "usage_logs_insert_own"
on public.usage_logs for insert
with check (auth.uid() = user_id);

drop policy if exists "usage_logs_update_own" on public.usage_logs;
create policy "usage_logs_update_own"
on public.usage_logs for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "usage_logs_delete_own" on public.usage_logs;
create policy "usage_logs_delete_own"
on public.usage_logs for delete
using (auth.uid() = user_id);

