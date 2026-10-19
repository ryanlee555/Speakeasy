-- Speakeasy: AI coach (2026-10-18)
-- Run once in the Supabase SQL Editor, before deploying supabase/functions/coach.

-- 1. Cloud copy of each take's latest grade, so it shows on every device.
--    Shape: { "v":1, "categories":[{"id","score","reasoning","tips"}], "summary", "strength", "focus", "frames", "at" }
--    The existing "update own recordings" policy already covers writing it.
alter table public.recordings
  add column if not exists coach jsonb;

-- 2. One row per grading request. The coach function counts these to cap how
--    many paid Claude calls one account can make per day.
create table if not exists public.coach_runs (
  id         bigserial primary key,
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
create index if not exists coach_runs_user_time on public.coach_runs (user_id, created_at desc);

alter table public.coach_runs enable row level security;

-- Users can log and count their own runs, nothing else. No update/delete
-- policy, so the daily count can't be reset from the browser.
drop policy if exists "insert own coach runs" on public.coach_runs;
create policy "insert own coach runs" on public.coach_runs
  for insert with check (auth.uid() = user_id);

drop policy if exists "read own coach runs" on public.coach_runs;
create policy "read own coach runs" on public.coach_runs
  for select using (auth.uid() = user_id);
