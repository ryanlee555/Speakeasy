# Speakeasy — Progress Log

Living doc. Updated after every change made in this project so any new chat can pick up without re-deriving context.

## Current state (2026-07-27)

- Two static HTML files, no backend:
  - `index.html` — new cutesy-minimal landing page (warm/cozy, same visual system as the app), CTA links to `speakeasy.html`.
  - `speakeasy.html` — the actual practice tool. Camera/mic capture via `getUserMedia` + `MediaRecorder`, all client-side.
- Saving: File System Access API auto-saves `.webm` + `.json` sidecar to a folder the user picks once (permission handle persisted in IndexedDB); browsers without FSAA fall back to a manual download button.
- Stats: a lightweight per-recording record (id, date, duration) is stored in IndexedDB and used to compute **Day Streak** and **Total Mins** for real. **Words/Min and Fillers/Min are still placeholders** (`—`) — no transcription wired in yet.
- Topics: **DONE** — 36 topics across 6 categories (Random, Sports, News, Deep Qs, Debate, Story) × 3 difficulty levels (Easy/Medium/Hard), with filter chips in the topic card. "New topic" and filter clicks both respect the current category/difficulty selection, avoid repeating the last topic shown.
- Duration: **DONE** — 4 presets (1:00/1:30/2:00/3:00) plus a custom `m:ss` input (5s–30min range) that becomes the active duration on Enter/blur.
- Modes: FULL / CAM / AUDIO / TEXT toggle what's visible after a recording. TEXT mode still shows a **hardcoded sample transcript**, not the real recording's speech (unchanged — still phase 3 work).
- Accounts: none yet. Everything is local to one browser profile on one machine — no concept of "users."
- UI: warm, dark, cozy aesthetic — Fraunces serif + Inter sans, brown/ember palette, pill-shaped buttons, soft glow background, minimal hairline borders. **User confirmed they like this look — it's now the shared visual system across both pages.**

## Roadmap (agreed 2026-07-27)

Grouped by dependency, not strict priority order — reorder freely.

### 1. Quick wins (pure frontend, no infra needed) — ✅ done 2026-07-27
- [x] Topic categorization — 6 categories × 3 difficulty levels, filter chips in the topic card
- [x] Custom duration input — `m:ss` or plain seconds, 5s–30min, alongside the existing presets
- [x] Landing page (`index.html`) — cutesy/minimal, matches the app's visual system, CTA into `speakeasy.html`

### 2. Accounts + cloud storage (Supabase)
- [ ] User creates their own Supabase project/account (sign-up itself has to be done by the user, not on their behalf) — get the project URL + anon public key
- [ ] Wire Supabase Auth — sign up / log in modal, session handling
- [ ] Postgres schema — `recordings` table keyed by `user_id`, replacing/augmenting the local IndexedDB metadata store
- [ ] Supabase Storage bucket for video files
- [ ] Save-destination choice exposed to the user: local folder only / cloud only / both — not a forced migration away from local save

### 3. Real stats
- [ ] Pick a speech-to-text approach (candidates: browser-native Web Speech API for a fast free path, vs. server-side Whisper for better accuracy — tradeoffs to discuss when we get here)
- [ ] Compute real WPM + filler-word count from the actual transcript
- [ ] TEXT mode renders the real transcript with real filler-word highlighting (replacing the hardcoded sample)

### 4. Claude API layer (on top of real transcripts)
- [ ] Small server-side proxy (e.g. a Supabase Edge Function) — API keys must never live in client-side code
- [ ] Send the real transcript to Claude for qualitative feedback / coaching notes (clarity, pacing suggestions, etc.)

## Decisions / constraints to remember

- Claude is text-only — it can't transcribe audio directly. Speech-to-text has to happen first (Web Speech API or a Whisper-style service); Claude's role is analyzing the resulting text, not producing it.
- Any API key (Claude, an STT provider, Supabase's service-role key) must go through a server-side function, never embedded client-side. Supabase's anon/public key is the one safe exception for direct client use.
- Local FSAA save is a deliberate, permanent option — not something cloud storage replaces.

## Open questions
- STT provider choice for real stats (phase 3)
- Whether cloud save is opt-in-by-default or opt-out-by-default once accounts exist
- `index.html` and `speakeasy.html` currently duplicate the same CSS block (fonts, variables, base styles) — fine for now at 2 pages, but worth factoring into a shared stylesheet before adding more pages (e.g. an auth page in phase 2)
