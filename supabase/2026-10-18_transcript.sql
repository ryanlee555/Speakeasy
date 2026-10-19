-- Speakeasy: cloud copy of each take's transcript (2026-10-18)
-- Run once in the Supabase SQL Editor.
--
-- Transcripts are generated in the browser (Whisper via transformers.js), so
-- this column is only a cache: it lets a take opened on a second device show
-- its subtitles instantly instead of re-transcribing. Shape:
--   { "v": 1, "model": "Xenova/whisper-small.en", "words": [["Hello", 0.42, 0.80], ...] }
-- Existing RLS policies ("update own recordings") already cover writing it.
-- The page works without this column: transcripts then cache only in the
-- browser that made them.

alter table public.recordings
  add column if not exists transcript jsonb;
