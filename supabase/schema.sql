-- Speakeasy: recordings metadata table
-- Run this once in the Supabase project's SQL Editor (Project → SQL Editor → New query).
-- Video files are NOT stored here yet (local FSAA folder save only, for now) —
-- this table just tracks per-user recording history/stats for cross-device sync.

create table public.recordings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  duration_sec integer not null,
  topic_text text,
  mode text default 'topic'
);

alter table public.recordings enable row level security;

create policy "select own recordings" on public.recordings
  for select using (auth.uid() = user_id);

create policy "insert own recordings" on public.recordings
  for insert with check (auth.uid() = user_id);

create policy "delete own recordings" on public.recordings
  for delete using (auth.uid() = user_id);
