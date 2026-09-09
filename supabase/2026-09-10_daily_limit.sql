-- Speakeasy: record the time limit a recording was made under (run once in
-- Supabase → SQL Editor → New query)
--
-- `duration_sec` is how long the person actually spoke. `target_sec` is the
-- countdown limit they chose before recording: a positive number of seconds,
-- or 0 for "No limit". It matters most for the Daily Challenge — the library
-- shows "Daily Challenge · 2:00 limit" vs "· no limit" so a take reads as a
-- deliberate attempt. NULL means the take predates this column.
--
-- Safe to re-run.

alter table public.recordings add column if not exists target_sec integer;
