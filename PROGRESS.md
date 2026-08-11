# Speakeasy — Progress Log

Living doc. Updated after every change made in this project so any new chat can pick up without re-deriving context. See [CLAUDE.md](CLAUDE.md) for the overall project vision/end-state — this file tracks state, roadmap, and decisions only.

## Repo state
`feature/recording-stats` has been merged into `main` (2026-08-10) — `main` now has the current warm/cozy version with Supabase auth, not the old pixel/CRT one.

## Deployment (2026-08-10)
Live at **https://speakeasy-beryl.vercel.app**, deployed via Vercel, connected to the `ryanlee555/Speakeasy` GitHub repo. Continuous deployment is live: pushing to `main` auto-deploys to production; pushing to any other branch or opening a PR gets its own Vercel preview URL. No build step/framework — deployed as a static site. No env vars needed (Supabase anon key is hardcoded client-side, which is the documented safe exception in CLAUDE.md).

## Current state (2026-07-28)

- Two static HTML files, no build step:
  - `index.html` — cutesy-minimal landing page (warm/cozy, same visual system as the app). **(2026-08-10)** "Sign in" is now the primary CTA (links to `speakeasy.html?auth=1`), with "Start practicing without an account" as a subtler secondary link underneath — nudges people toward accounts since logged-out recordings aren't saved to the cloud. `speakeasy.html` reads the `auth=1` query param and auto-opens the login modal on load (once, only if not already logged in).
  - `speakeasy.html` — the actual practice tool. Camera/mic capture via `getUserMedia` + `MediaRecorder`, all client-side.
- **Accounts: Supabase auth wired up (2026-07-28).** `speakeasy.html` loads `@supabase/supabase-js@2` via CDN and creates a client against the user's project (`https://niqwjooeuougvvusjznp.supabase.co`, anon key hardcoded client-side — safe per the anon-key exception below). Topbar has a "Sign in" pill → modal with Log in / Sign up tabs (email + password via Supabase Auth). Logged-in state shows the user's email in the pill; clicking it while logged in signs out. Login is **optional** — logged-out behavior is unchanged from before (local IndexedDB stats, local FSAA save).
  - Schema lives in [supabase/schema.sql](supabase/schema.sql) — a `recordings` table (`user_id`, `created_at`, `duration_sec`, `topic_text`, `mode`) with RLS policies scoping every row to its owner. **Applied — user ran it in the Supabase SQL Editor on 2026-07-28.**
  - When logged in: new recordings also insert a row into Supabase `recordings` (in addition to, not instead of, the existing local IndexedDB write and local FSAA video save — nothing local changed). Stats (Day Streak, Total Mins) read from Supabase instead of IndexedDB while logged in, and revert to local IndexedDB when logged out.
  - **Not done yet:** video file upload to Supabase Storage (metadata/stats only for now — explicit scope decision, see roadmap below). No migration of pre-Supabase local history into an account. Supabase's default "confirm email on sign-up" setting is still on, so a new signup isn't usable until the confirmation link is clicked (or the user turns that off in their dashboard under Authentication → Providers → Email).
- Saving: File System Access API auto-saves `.webm` + `.json` sidecar to a folder the user picks once (permission handle persisted in IndexedDB); browsers without FSAA fall back to a manual download button. Unaffected by the Supabase work above.
- Stats: a lightweight per-recording record (id, date, duration) is stored locally (IndexedDB) and/or in Supabase (see above) and used to compute **Day Streak** and **Total Mins** for real. **Words/Min and Fillers/Min are still placeholders** (`—`) — no transcription wired in yet.
- Topics: **DONE** — 36 topics across 6 categories (Random, Sports, News, Deep Qs, Debate, Story) × 3 difficulty levels (Easy/Medium/Hard), with filter chips in the topic card. "New topic" and filter clicks both respect the current category/difficulty selection, avoid repeating the last topic shown.
- Duration: **DONE** — 4 presets (1:00/1:30/2:00/3:00) plus a custom `m:ss` input (5s–30min range) that becomes the active duration on Enter/blur.
- Modes: FULL / CAM / AUDIO / TEXT toggle what's visible after a recording. TEXT mode still shows a **hardcoded sample transcript**, not the real recording's speech (unchanged — still phase 3 work).
- Library panel (recent-recordings list in the sidebar) still shows **hardcoded sample rows** — not wired to real data yet (local or cloud). Known gap, unrelated to the Supabase work.
- UI: warm, dark, cozy aesthetic — Fraunces serif + Inter sans, brown/ember palette, pill-shaped buttons, soft glow background, minimal hairline borders. Shared visual system across both pages; the new auth modal follows the same system.

## Roadmap (agreed 2026-07-27)

Grouped by dependency, not strict priority order — reorder freely.

### 1. Quick wins (pure frontend, no infra needed) — ✅ done 2026-07-27
- [x] Topic categorization — 6 categories × 3 difficulty levels, filter chips in the topic card
- [x] Custom duration input — `m:ss` or plain seconds, 5s–30min, alongside the existing presets
- [x] Landing page (`index.html`) — cutesy/minimal, matches the app's visual system, CTA into `speakeasy.html`

### 2. Accounts + cloud storage (Supabase)
- [x] User creates their own Supabase project/account — done 2026-07-28, project URL + anon key obtained
- [x] Wire Supabase Auth — sign up / log in modal, session handling — done 2026-07-28, see Current state above
- [x] Postgres schema — `recordings` table keyed by `user_id` — SQL in [supabase/schema.sql](supabase/schema.sql), **applied to the live project 2026-07-28**
- [ ] Supabase Storage bucket for video files — explicitly deferred; metadata-only sync for now
- [ ] Save-destination choice exposed to the user (local / cloud / both) — deferred along with Storage; not meaningful until there's an actual cloud video destination to choose. Metadata currently syncs automatically and additively whenever logged in, local save is untouched

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
- ~~Whether cloud save is opt-in-by-default or opt-out-by-default once accounts exist~~ — resolved 2026-07-28: metadata sync is automatic/additive once logged in, local save stays untouched; revisit for video once Storage is wired
- `index.html` and `speakeasy.html` currently duplicate the same CSS block (fonts, variables, base styles) — fine for now at 2 pages, but worth factoring into a shared stylesheet before adding more pages (e.g. an auth page in phase 2)
- Next Supabase step: decide on Storage bucket structure (per-user folder path, RLS policy shape) for the video-upload follow-up; verify end-to-end with a real signed-up user + a recorded clip landing in the `recordings` table
