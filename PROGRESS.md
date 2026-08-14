# Speakeasy — Progress Log

Living doc. Updated after every change made in this project so any new chat can pick up without re-deriving context. See [CLAUDE.md](CLAUDE.md) for the overall project vision/end-state — this file tracks state, roadmap, and decisions only.

## Repo state
`feature/recording-stats` has been merged into `main` (2026-08-10) — `main` now has the current warm/cozy version with Supabase auth, not the old pixel/CRT one.

## Deployment (2026-08-10)
Live at **https://speakeasy-beryl.vercel.app**, deployed via Vercel, connected to the `ryanlee555/Speakeasy` GitHub repo. Continuous deployment is live: pushing to `main` auto-deploys to production; pushing to any other branch or opening a PR gets its own Vercel preview URL. No build step/framework — deployed as a static site. No env vars needed (Supabase anon key is hardcoded client-side, which is the documented safe exception in CLAUDE.md).

## ⚠️ BLOCKER: the Supabase project no longer exists (found 2026-08-13)

**Sign in and sign up are both completely broken, and this is infrastructure, not code.** `niqwjooeuougvvusjznp.supabase.co` returns **NXDOMAIN** — the hostname does not resolve at all. Verified from the shell (`host` returns `not found: 3(NXDOMAIN)` while `supabase.com` and `github.com` resolve fine from the same machine) and independently in the browser, where the app's own page-load `getSession()` call fails with `net::ERR_NAME_NOT_RESOLVED`. The project was created 2026-07-28; free-tier Supabase projects pause after roughly a week of inactivity and are torn down if left paused, which fits the timeline.

Consequences while this is unfixed: every auth call fails identically, no stats can sync, and the new cloud-insert path (see below) cannot be tested. **Logged-out use is completely unaffected** — local IndexedDB stats and local FSAA video save never touched Supabase.

**To fix, the user has to do this part** (it needs their Supabase account):
1. Open [supabase.com/dashboard](https://supabase.com/dashboard) and look at the project. If it is merely paused, restore it and nothing else below is needed.
2. If it is gone, create a new project, then copy the new **Project URL** and **anon/public key**.
3. Replace both values in `speakeasy.html` (single `createClient(...)` call near the top of the auth block).
4. Re-run [supabase/schema.sql](supabase/schema.sql) in the new project's SQL Editor to recreate the `recordings` table and its RLS policies.
5. Optionally turn off "Confirm email" under Authentication → Providers → Email, otherwise every new signup needs a confirmation click before it can log in.

## Content style rule (2026-08-13)
No em dashes anywhere in user-facing copy on either page, and avoid comma-spliced "fragment, fragment" titles/headlines (e.g. the old "Everything you need, nothing you don't." pattern) — write full sentences instead. Applies to both `index.html` and `speakeasy.html`. (The `—` used as an empty-stat placeholder in `speakeasy.html`, e.g. `#statWpm`, is a typographic glyph, not prose, and is exempt.)

## Current state (last updated 2026-08-13)

- Two static HTML files, no build step:
  - `index.html` — landing page (warm/cozy, same visual system as the app). **(2026-08-13) Copy pass:** hero blurb simplified to "A cozy little studio for practicing your public speaking out loud." (the old feature-dot row and the "one prompt, one minute, one honest take." tagline are gone). Section titles rewritten as full sentences instead of comma-fragments (e.g. "You can practice speaking in just a few minutes."). Fixed a CSS specificity bug where `.topnav a` was silently overriding `.nav-cta`'s color, making the header "Sign in" pill render in muted gray instead of black — now `.topnav a.nav-cta` wins and the text is solid black. **(2026-08-13) Redesigned into a real multi-section marketing page:**
    - Sticky header, "Speakeasy" wordmark pinned top-left (the old orange dot next to it is gone), nav links (How it works / Features / About) + a "Sign in" pill on the right.
    - Hero: only the "Speak a little easier." headline remains from the original. The italic tagline and the "Record yourself · Review instantly · Build a streak" dot-row were both deleted, and the blurb was cut to one line (see the copy pass above). "Sign in" (→ `speakeasy.html?auth=1`) is the primary CTA, "Start practicing without an account" the secondary link underneath.
    - New `#how` section: two-column — left is a dashed-border video placeholder (`.video-placeholder`, labeled "demo video coming soon", swap for a real `<video>`/embed later), right is a 4-step numbered list of the actual product flow (pick your mode → hit record → watch it back → build the habit). Step 1 was reworded from "Pick a topic" to "Pick your mode" once Freeplay shipped.
    - `#features` section: 4-card grid, **rewritten 2026-08-13** to describe the actual product direction — Topic mode, Freeplay mode, Notes on every take, Daily Challenge. The last two are not built yet and carry a sage "coming soon" pill (`.soon`) so the public page isn't advertising things that don't work. Remove the pill when each ships.
    - New `#about` section: two-column — left is the founder story (why it was built, the Vinh Giang self-review method, the pressure-practice technique), right is `.about-photos`, two empty dashed placeholders (`.photo-placeholder`) sized for portrait photos — user will drop real photos in later.
    - All sections stack to single-column under 760px; header nav links (except Sign in) hide under 640px. Verified in-browser at desktop and mobile widths.
    - `speakeasy.html` still reads the `auth=1` query param and auto-opens the login modal on load (once, only if not already logged in) — unaffected by this redesign.
  - `speakeasy.html` — the actual practice tool. Camera/mic capture via `getUserMedia` + `MediaRecorder`, all client-side.
- **Accounts: Supabase auth wired up (2026-07-28).** `speakeasy.html` loads `@supabase/supabase-js@2` via CDN and creates a client against the user's project (`https://niqwjooeuougvvusjznp.supabase.co`, anon key hardcoded client-side — safe per the anon-key exception below). Topbar has a "Sign in" pill → modal with Log in / Sign up tabs (email + password via Supabase Auth). Logged-in state shows the user's email in the pill; clicking it while logged in signs out. Login is **optional** — logged-out behavior is unchanged from before (local IndexedDB stats, local FSAA save).
  - Schema lives in [supabase/schema.sql](supabase/schema.sql) — a `recordings` table (`user_id`, `created_at`, `duration_sec`, `topic_text`, `mode`) with RLS policies scoping every row to its owner. **Applied — user ran it in the Supabase SQL Editor on 2026-07-28.**
  - When logged in: new recordings also insert a row into Supabase `recordings` (in addition to, not instead of, the existing local IndexedDB write and local FSAA video save — nothing local changed). Stats (Day Streak, Total Mins) read from Supabase instead of IndexedDB while logged in, and revert to local IndexedDB when logged out.
  - **BUG FIXED 2026-08-13:** the cloud sync described above was documented as done but was never actually implemented. `refreshStats()` *read* from Supabase whenever signed in, but no code ever *inserted* a row (only a `select` existed). Net effect: signed-in users permanently saw 0 Day Streak / 0 Total Mins and nothing ever synced, while logged-out users were fine on local IndexedDB. `saveRecordingMeta()` now awaits the local IndexedDB write and then, only when `session` is truthy, inserts `{user_id, created_at, duration_sec, topic_text, mode}` into Supabase. A failed cloud insert logs and is swallowed so the local save (already committed) still counts. **Local-only path verified in-browser; the signed-in cloud insert has NOT been verified end-to-end yet — needs a real login + a real recording to confirm a row lands in the `recordings` table.**
  - **Auth error copy (2026-08-13):** a dead/paused backend previously surfaced in the modal as a bare "Failed to fetch", which told the user nothing. The submit handler now detects network-level failures (`failed to fetch` / `networkerror` / `load failed`, covering Chrome, Firefox and Safari wording) and shows "Can't reach the server right now. You can keep practicing without an account, your recordings still save locally." Genuine auth errors like "Invalid login credentials" are matched by none of those patterns and still pass through verbatim.
  - **Not done yet:** video file upload to Supabase Storage (metadata/stats only for now — explicit scope decision, see roadmap below). No migration of pre-Supabase local history into an account. Supabase's default "confirm email on sign-up" setting is still on, so a new signup isn't usable until the confirmation link is clicked (or the user turns that off in their dashboard under Authentication → Providers → Email).
- Saving: File System Access API auto-saves `.webm` + `.json` sidecar to a folder the user picks once (permission handle persisted in IndexedDB); browsers without FSAA fall back to a manual download button. Unaffected by the Supabase work above.
- Stats: a lightweight per-recording record (id, date, duration) is stored locally (IndexedDB) and/or in Supabase (see above) and used to compute **Day Streak** and **Total Mins** for real. **Words/Min and Fillers/Min are still placeholders** (`—`) — no transcription wired in yet.
- **Rec modes: Topic vs Freeplay (NEW 2026-08-13).** The right-hand card now has a two-segment toggle (`#recModeSeg`) at the top:
  - **Topic** (default) — unchanged behavior: category/difficulty filter chips, a prompt, and "New topic". Duration presets 1:00 / 1:30 / 2:00 / 3:00, default 1:00. **The planned Daily Challenge is intended to live inside this Topic mode**, alongside today's topic.
  - **Freeplay** — the Vinh Giang self-review method: no prompt at all. Filters, topic text, and the "New topic" button are hidden; the card header switches to "Freeplay" and shows explainer copy. Duration presets swap to 3:00 / 5:00 / 10:00 / 15:00, **default 5:00**.
  - Implementation notes: one shared `.dursel` row whose four preset buttons are relabeled in place per mode (`DUR_PRESETS`), so the existing click listeners keep working. `chosenSec` remembers the selected duration *per mode* independently, including a custom `m:ss` value, and `applyRecMode()` restores it (verified round-tripping presets and customs both ways). Recordings save with `mode:'topic'|'freeplay'`; freeplay saves an empty `topicText`, and its FSAA filename is prefixed `speakeasy_freeplay_`. The `mode`/`topic_text` columns already existed in the Supabase schema, so no migration was needed.
- Topics: **DONE** — 36 topics across 6 categories (Random, Sports, News, Deep Qs, Debate, Story) × 3 difficulty levels (Easy/Medium/Hard), with filter chips in the topic card. "New topic" and filter clicks both respect the current category/difficulty selection, avoid repeating the last topic shown.
- Duration: **DONE** — 4 presets plus a custom `m:ss` input (5s–30min range) that becomes the active duration on Enter/blur. As of 2026-08-13 the four presets are **mode-dependent** (1:00/1:30/2:00/3:00 in Topic, 3:00/5:00/10:00/15:00 in Freeplay) and each mode remembers its own choice — see the Rec modes entry above.
- Modes: FULL / CAM / AUDIO / TEXT toggle what's visible after a recording. TEXT mode still shows a **hardcoded sample transcript**, not the real recording's speech (unchanged — still phase 3 work).
- Library panel (recent-recordings list in the sidebar) still shows **hardcoded sample rows** — not wired to real data yet (local or cloud). This is now a tracked roadmap item (§2.5) and is the blocker for per-recording notes.
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

### 2.5 Practice modes + history (agreed 2026-08-13)
- [x] **Freeplay mode** — no-prompt recording, default 5:00, reviewed via the existing full/cam/audio/text toggles. Done 2026-08-13.
- [ ] **Library wired to real data** — the sidebar Library panel still shows hardcoded rows. Needs to list real recordings (local IndexedDB when logged out, Supabase when logged in) and let the user pick one to re-watch. This is the prerequisite for the two items below.
- [ ] **Per-recording notes** — attach a text note to any recording so the user can look back and see progress. Needs a `notes` column (or a `notes` table) added to the Supabase schema, plus the same field on the local IndexedDB record. Depends on Library being real first.
- [ ] **Daily Challenge** — one globally-shared prompt per day, identical for every user, so people can compare takes with friends. Lives inside **Topic** mode next to today's topic. Needs (a) a much larger prompt library — *user said they will supply one* — and (b) a deterministic same-prompt-for-everyone-per-day selection (e.g. date-seeded index into the shared list, or a `daily_prompts` table in Supabase keyed by date; a date-seeded index needs no backend and is the cheaper first pass).

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
- **Blocked until the Supabase project is restored/recreated (see the blocker at the top):** verifying the signed-in cloud insert end-to-end with a real login + a real recording landing in the `recordings` table. The insert code exists as of 2026-08-13 and before that it never would have worked, but it cannot be confirmed against a host that does not resolve.
- Next Supabase step after that: decide on Storage bucket structure (per-user folder path, RLS policy shape) for the video-upload follow-up.
- Daily Challenge prompt selection: date-seeded index into a shared list (no backend, cheap) vs. a `daily_prompts` Supabase table keyed by date (editable without a deploy). Decide when the bigger prompt library arrives.
