-- Speakeasy: cloud video library (run once in Supabase → SQL Editor → New query)
--
-- This unblocks the Library page (library.html): it adds the columns needed to
-- describe a recording fully, creates a PRIVATE storage bucket for the video
-- files, and scopes every object to the user who owns it.
--
-- Safe to re-run: every statement is guarded.

-- ── 1. extra columns on the recordings table ────────────────────────────────
-- storage_path / thumb_path point at objects in the `recordings` bucket.
-- is_daily and audio_only were previously local-only fields on the IndexedDB
-- record; they have to be real columns for a cross-device library to show them.
alter table public.recordings add column if not exists storage_path text;
alter table public.recordings add column if not exists thumb_path   text;
alter table public.recordings add column if not exists is_daily     boolean not null default false;
alter table public.recordings add column if not exists audio_only   boolean not null default false;

-- The client now generates the row id (crypto.randomUUID) so the local
-- IndexedDB record and the cloud row share a key and can be merged. The
-- gen_random_uuid() default stays as a fallback for any insert that omits it.

-- Newest-first listing is the library's only query shape.
create index if not exists recordings_user_created_idx
  on public.recordings (user_id, created_at desc);

-- ── 2. private bucket for the video + poster files ──────────────────────────
insert into storage.buckets (id, name, public)
values ('recordings', 'recordings', false)
on conflict (id) do nothing;

-- ── 3. per-user access, enforced by path ────────────────────────────────────
-- Objects are stored as  <user_id>/<recording_id>.webm  (and .jpg for posters),
-- so the first path segment IS the owner. Comparing it to auth.uid() gives each
-- account its own directory that nobody else can read, write, or delete.
drop policy if exists "recordings read own"   on storage.objects;
drop policy if exists "recordings insert own" on storage.objects;
drop policy if exists "recordings update own" on storage.objects;
drop policy if exists "recordings delete own" on storage.objects;

create policy "recordings read own" on storage.objects
  for select using (
    bucket_id = 'recordings'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "recordings insert own" on storage.objects
  for insert with check (
    bucket_id = 'recordings'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "recordings update own" on storage.objects
  for update using (
    bucket_id = 'recordings'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "recordings delete own" on storage.objects
  for delete using (
    bucket_id = 'recordings'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- ── 4. let a user update their own rows ─────────────────────────────────────
-- schema.sql only granted select / insert / delete. The library needs update
-- so a row can be re-pointed at a file (e.g. a later backfill upload).
drop policy if exists "update own recordings" on public.recordings;
create policy "update own recordings" on public.recordings
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
