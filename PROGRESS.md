# Speakeasy — Progress Log

Living doc. Updated after every change made in this project so any new chat can pick up without re-deriving context. See [CLAUDE.md](CLAUDE.md) for the overall project vision/end-state — this file tracks state, roadmap, and decisions only.

## Repo state
`feature/recording-stats` has been merged into `main` (2026-08-10) — `main` now has the current warm/cozy version with Supabase auth, not the old pixel/CRT one.

## Deployment (2026-08-10)
Live at **https://speakeasy-beryl.vercel.app**, deployed via Vercel, connected to the `ryanlee555/Speakeasy` GitHub repo. Continuous deployment is live: pushing to `main` auto-deploys to production; pushing to any other branch or opening a PR gets its own Vercel preview URL. No build step/framework — deployed as a static site. No env vars needed (Supabase anon key is hardcoded client-side, which is the documented safe exception in CLAUDE.md).

## 🎯 WHAT TO WORK ON NEXT (priority order, last set 2026-09-09)

Read this first. Everything above P3 is small; the big lifts are flagged.

### ✅ P0 — DONE 2026-09-09
The Supabase side of the cloud library is fully set up and **verified end to end.**
- `supabase/2026-09-08_library.sql` was run: the four columns exist, the private
  `recordings` bucket exists, and the per-user storage policies are live.
- "Confirm email" is **off** — a fresh signup now returns a working session with
  no email click.
- **Round trip verified 2026-09-09** two ways: (1) from the shell with a real
  throwaway user token — upload to own folder succeeds, upload into another
  user's folder is refused with "violates row-level security policy", metadata
  insert with the new columns returns 201, signed URL works, delete works; and
  (2) **by the user in the live app** — signed in, recorded a clip, hit Save, and
  the take appears in `library.html` with a real poster thumbnail and plays back.
- The local browser-download fallback also fired (no save folder connected on the
  vercel origin), so that path is confirmed too.
- Housekeeping: a couple of `rktest+…@gmail.com` throwaway users are sitting in
  Authentication → Users. Harmless; delete them whenever.

### P1 — quick UI cleanups the user asked for 2026-09-09 (all small, do together)
1. **Favicon + tab identity.** ~~No page has an icon.~~ **Partly done 2026-09-09:**
   an inline SVG data-URI favicon (a waveform — five rounded bars, the centre bar
   ember `#C87941`, the rest cream `#F2E4D4`, on a `#3A2A20` circle; user-supplied
   markup) plus `<meta name="theme-color" content="#100d0b">` are now in the
   `<head>` of all three pages (`index.html`, `speakeasy.html`, `library.html`),
   inserted right after the viewport meta. **Still to do:** Open Graph / Twitter
   card tags (title, description, image) so a shared link previews as more than a
   bare URL, and optionally a real `favicon.svg` + `apple-touch-icon.png` for a
   proper phone home-screen icon.
2. **Trim the studio sidebar** ("remove stats and library on main page"). The
   studio (`speakeasy.html`) right column currently stacks: the prompt card, a
   **Stats** panel (Words/min + Fillers/min are still `—` placeholders, only Day
   Streak + Total Mins are real), and a **Library** panel (last 20, links to
   `library.html`). Now that `library.html` exists as the real home for history,
   the user wants this column decluttered. **Confirm with them before cutting:**
   likely remove the sidebar Library panel entirely (redundant with the nav
   "Library" link and "View all →"), and either remove Stats too or cut it down
   to just Day Streak + Total Mins until real WPM/fillers exist. The "Library"
   topbar pill and the studio→library links should stay.
3. **Copy pass.** "Tweaking some phrases and wordings" — no specific list given
   yet. Do a read-through of all three pages with the user and fix whatever they
   flag. Keep the content style rule in mind (no em dashes in user-facing copy,
   full sentences not comma-fragments).
4. **"0 min practiced" reads as broken.** On `library.html` the header does
   `Math.round(totalSec/60)`, so several short test clips total "0 min". Show
   seconds under a minute, or `<1 min`, or round up. Same rounding is in the
   studio Stats panel (`#statMins`) — fix both or fix it in one shared helper if
   Stats survives item 2.

### P2 — video retention, so storage stops being a worry
The 1 GB free tier is the real constraint. At the current capped 1 Mbps that is
roughly **2 hours of video**, and the library already shows a usage meter so it
will be visible when it starts filling.

**Design decision to make first: expire the file, keep the row.** Deleting a
recording's metadata would break Day Streak and Total Mins retroactively, which
is the opposite of what a habit app should do. So a retention sweep should
`storage.remove()` the `.webm` + `.jpg` and then `update` the row to null out
`storage_path` / `thumb_path`. The row survives, stats survive, and the library
renders it exactly like today's pre-cloud rows: listed, no video, explained.

**And note the framing this gives you for free:** the cloud becomes a rolling
window (last N days) while the **local FSAA folder stays the permanent archive**,
which fits CLAUDE.md's rule that local save is never replaced by cloud. Worth
saying that in the UI so expiry reads as intentional, not as data loss.

Two ways to run the sweep:
- **(a) Client-side on library load — recommended first pass.** In
  `library.html`, after `loadAll()`, find rows older than the cutoff that still
  have a `storage_path`, remove the objects, null the columns. No backend, fits
  the project's zero-infra pattern. Weakness: only runs when someone opens the
  page, so a dormant account never reclaims space.
- **(b) A scheduled Supabase Edge Function + `pg_cron`.** Correct and runs
  regardless of visits, but it is real backend setup and `pg_cron` has to be
  enabled. Do this only if (a) proves insufficient.

Still to decide: the window (30 / 60 / 90 days), whether it is user-configurable
or fixed, and whether cards should show "expires in N days".

### P3 — product features already scoped
- **Per-recording notes** (roadmap §2.5). Was next before the library work
  jumped the queue. Now easier than it was: `library.html` is the natural home
  for writing and reading notes, and a `notes text` column is a one-line addition
  to the migration pattern already established.
- **Real stats** (roadmap §3). Words/Min and Fillers/Min are still `—`
  placeholders and TEXT mode still shows a hardcoded transcript. Needs a
  speech-to-text decision first (Web Speech API for a free fast path vs. a
  Whisper-style service for accuracy). This is the biggest remaining lift and
  everything in §4 depends on it.
- **Claude coaching layer** (roadmap §4). Blocked on real transcripts existing.
  Remember the constraint: any API key must go through a server-side function,
  never client-side.

### P4 — housekeeping worth doing eventually
- **`index.html` still has three placeholders**: the "demo video coming soon"
  box in How It Works, and two empty photo slots in About.
- **Shared CSS.** Three pages now duplicate the same ~200 lines of variables and
  base styles. It was tolerable at two pages; at three it is worth extracting,
  but only if the `file://` lesson from the prompt library is respected (a
  stylesheet link has the same second-file failure mode, so inline-at-build or
  accept the duplication).
- **`recentIds` does not persist** across reloads, so prompt repeat-avoidance
  resets each session. Low impact with 1,043 items.
- **The daily prompt is computed once at page load**, so a tab left open across
  UTC midnight shows yesterday's until reloaded.

## ✅ RESOLVED (2026-08-14): the Supabase project is back

The 2026-08-13 blocker below is **fixed — no code change was needed.** The project had been paused, not destroyed; it now resolves and responds normally. Verified 2026-08-14 from the shell:
- `host niqwjooeuougvvusjznp.supabase.co` → resolves (was NXDOMAIN).
- `GET /auth/v1/health` with the anon key → `{"version":"v2.195.0","name":"GoTrue",...}`, so Auth is up.
- `GET /rest/v1/recordings?select=id&limit=1` with the anon key → **200 `[]`**, so the `recordings` table still exists with its RLS policies intact (empty result is correct for an unauthenticated anon caller). **The schema did not need re-running.**
- The app's page-load `getSession()` no longer throws — `speakeasy.html` loads with a completely clean console.

Existing credentials in `speakeasy.html` are still valid; nothing to swap. Still worth doing in the dashboard: turn off "Confirm email" under Authentication → Providers → Email, otherwise every new signup needs a confirmation click before it can log in. Note the same pause-on-inactivity risk remains for a free-tier project, so expect this to recur if the app sits unused for a week or two.

<details>
<summary>Original blocker text (2026-08-13), kept for history</summary>

**Sign in and sign up are both completely broken, and this is infrastructure, not code.** `niqwjooeuougvvusjznp.supabase.co` returns **NXDOMAIN** — the hostname does not resolve at all. Verified from the shell (`host` returns `not found: 3(NXDOMAIN)` while `supabase.com` and `github.com` resolve fine from the same machine) and independently in the browser, where the app's own page-load `getSession()` call fails with `net::ERR_NAME_NOT_RESOLVED`. The project was created 2026-07-28; free-tier Supabase projects pause after roughly a week of inactivity and are torn down if left paused, which fits the timeline.

Consequences while this is unfixed: every auth call fails identically, no stats can sync, and the new cloud-insert path (see below) cannot be tested. **Logged-out use is completely unaffected** — local IndexedDB stats and local FSAA video save never touched Supabase.
</details>

## Content style rule (2026-08-13)
No em dashes anywhere in user-facing copy on either page, and avoid comma-spliced "fragment, fragment" titles/headlines (e.g. the old "Everything you need, nothing you don't." pattern) — write full sentences instead. Applies to both `index.html` and `speakeasy.html`. (The `—` used as an empty-stat placeholder in `speakeasy.html`, e.g. `#statWpm`, is a typographic glyph, not prose, and is exempt.)

## Current state (last updated 2026-09-08)

- Three static HTML files plus one data file, no build step:
  - **The prompt/word library (added 2026-09-08) is now inlined directly into `speakeasy.html`** as its first `<script>` block, ahead of the app script. 1,043 items: 585 topic prompts + 458 single words, every item tagged `{id, mode, category, difficulty, text}`. It defines `window.SPEAKEASY_LIBRARY` plus two helpers, `pickPrompt(mode, category, difficulty, {recent})` and `categoriesFor(mode)`. This is what pushes `speakeasy.html` to ~197KB.
    - **Why inlined, not a `<script src>` (changed same day 2026-09-08):** it first shipped as a separate `speakeasy-library.js` loaded by a script tag, and that broke — the page showed "Prompt library didn't load" for the user even though localhost and Vercel both served the file fine (200, correct bytes). A second-file dependency fails in too many ordinary situations: opening `speakeasy.html` straight from Finder (`file://`), a stale HTML cache paired with a not-yet-propagated JS file, a flaky network on first load. Inlining removes the whole class of failure and matches the project's single-file nature. `speakeasy-library.js` has been deleted from the repo.
    - `speakeasy-library.json` is kept as the **canonical, portable copy of the data** (same 1,043 items). The app does not read it — it exists for a future server/build step, and as the thing to regenerate the inlined block from.
  - `index.html` — landing page (warm/cozy, same visual system as the app). **(2026-08-13) Copy pass:** hero blurb simplified to "A cozy little studio for practicing your public speaking out loud." (the old feature-dot row and the "one prompt, one minute, one honest take." tagline are gone). Section titles rewritten as full sentences instead of comma-fragments (e.g. "You can practice speaking in just a few minutes."). Fixed a CSS specificity bug where `.topnav a` was silently overriding `.nav-cta`'s color, making the header "Sign in" pill render in muted gray instead of black — now `.topnav a.nav-cta` wins and the text is solid black. **(2026-08-13) Redesigned into a real multi-section marketing page:**
    - Sticky header, "Speakeasy" wordmark pinned top-left (the old orange dot next to it is gone), nav links (How it works / Features / About) + a "Sign in" pill on the right.
    - Hero: only the "Speak a little easier." headline remains from the original. The italic tagline and the "Record yourself · Review instantly · Build a streak" dot-row were both deleted, and the blurb was cut to one line (see the copy pass above). "Sign in" (→ `speakeasy.html?auth=1`) is the primary CTA, "Start practicing without an account" the secondary link underneath.
    - New `#how` section: two-column — left is a dashed-border video placeholder (`.video-placeholder`, labeled "demo video coming soon", swap for a real `<video>`/embed later), right is a 4-step numbered list of the actual product flow (pick your mode → hit record → watch it back → build the habit). Step 1 was reworded from "Pick a topic" to "Pick your mode" once Freeplay shipped.
    - `#features` section: **now a 5-card grid (2026-09-08)** — Topic mode, Words mode, Freeplay mode, Notes on every take, Daily Challenge. "Notes on every take" is not built yet and carries a sage "coming soon" pill (`.soon`); the Daily Challenge pill was removed when it shipped (2026-09-08). Remove the remaining pill when Notes ships. Breakpoints were rebalanced for the 5th card: 5 columns at full width, 3 under 1080px (which lands the three shipped modes on row 1 and the two "coming soon" on row 2 — reads well), 2 under 760px, 1 under 520px. The Topic mode card copy now cites the real library size ("Hundreds of prompts across thirteen categories"), and How-it-works step 1 mentions all three modes.
    - New `#about` section: two-column — left is the founder story (why it was built, the Vinh Giang self-review method, the pressure-practice technique), right is `.about-photos`, two empty dashed placeholders (`.photo-placeholder`) sized for portrait photos — user will drop real photos in later.
    - All sections stack to single-column under 760px; header nav links (except Sign in) hide under 640px. Verified in-browser at desktop and mobile widths.
    - `speakeasy.html` still reads the `auth=1` query param and auto-opens the login modal on load (once, only if not already logged in) — unaffected by this redesign.
  - `speakeasy.html` — the actual practice tool. Camera/mic capture via `getUserMedia` + `MediaRecorder`, all client-side.
  - `library.html` — **NEW 2026-09-08.** The per-account video library. See its own section below.
- **Cloud video library (NEW 2026-09-08).** This unblocked roadmap §2's long-deferred "Supabase Storage bucket" item. Videos now upload to Supabase Storage under `<user_id>/<recording_id>.webm`, with a poster frame at `<user_id>/<recording_id>.jpg`, and `library.html` renders them as a gallery or list.
  - **Migration [supabase/2026-09-08_library.sql](supabase/2026-09-08_library.sql) was run 2026-09-09** and the round trip is verified (see the P0 note near the top). It added `storage_path` / `thumb_path` / `is_daily` / `audio_only` columns, a `(user_id, created_at desc)` index, the **private** `recordings` bucket, four `storage.objects` policies, and an `update` policy on `public.recordings`. The `cloudInsert()` five-column fallback stays in the code as belt-and-suspenders.
  - **Per-user isolation is enforced by path.** Objects live under a folder named for the owner's uid, and every storage policy compares `(storage.foldername(name))[1] = auth.uid()::text`. That gives each account its own directory that nobody else can read, write or delete — no application-level check to forget.
  - **Recording ids are now client-generated UUIDs** (`crypto.randomUUID()`), used as **both** the IndexedDB key and the Supabase row `id`. That shared key is what lets the library merge the local and cloud stores without guessing. Pre-UUID records have no shared key, so `loadAll()` falls back to a timestamp-within-4s + same-duration heuristic to avoid showing them twice.
  - **Bitrate is capped at 1 Mbps video / 96 kbps audio** (`REC_BITRATE`, applied via `makeRecorder()`). Chrome's MediaRecorder default is ~2.5 Mbps ≈ 18 MB/min, which would fill Supabase's 1 GB free tier in under an hour; 1 Mbps is ~8 MB/min (~2 hours) and is still fine for reviewing posture and delivery. `new MediaRecorder(stream, opts)` is wrapped in try/catch since some browsers reject the bitrate hints.
  - **Poster frames** are grabbed by `capturePoster()` off the live preview inside `recorder.onstop`, *before* the element is switched to playback — a 480px-wide canvas, deliberately **not** mirrored so it matches the unflipped saved file. Encoded to JPEG at 0.72 on save. Audio-only takes get no poster.
  - **Upload is additive and never blocks the local save.** `saveRecordingMeta()` still writes IndexedDB first; `uploadToCloud()` failures are logged and swallowed, and the metadata row still lands (pointing at nothing). `cloudInsert()` tries the full row and **falls back to the original five columns** if the migration hasn't been run, so an un-migrated project keeps syncing instead of silently losing every insert.
  - Local FSAA folder save is **unchanged and still happens**, per CLAUDE.md's rule that local save is a permanent option rather than something cloud replaces.
- **Capture: camera+mic OR audio-only (2026-09-08).** The enable-capture overlay has two buttons: **"Enable camera"** (`getUserMedia({video:true,audio:true})`) and **"Just record audio"** (`getUserMedia({audio:true})`). Both route through one `startStream(withVideo)` helper. Audio-only sets `document.body.classList.add('audio-only')`, which forces the `.audioviz` equalizer visual over the (video-less) screen in idle / recording / review via `body.audio-only:not(.mode-text) .audioviz{display:flex}`. **The equalizer bars are static** (no animation — removed 2026-09-08 per user; they keep their inline heights). The recording **timer badge shows in audio-only too** (`.badge{z-index:4}` lifts it above the audioviz, which is `pointer-events:none`). In audio-only review the FULL and CAM mode buttons are disabled and the player opens in AUDIO. Recordings carry `audioOnly:true` on the local IndexedDB record (not sent to Supabase) and the Library row appends " · audio".
- **Switch capture mode mid-session (2026-09-08).** Once capture is on, a `#capBar` under the screen shows **"Switch to audio only"** / **"Turn on camera"** (`#switchCapBtn`, label from `audioOnly`; no emoji). Clicking it calls `startStream(audioOnly)` — which stops the old stream's tracks and re-runs `getUserMedia` for the other mode. `updateCapBar()` shows it only when `stream && !recording && !is-review`; `startRecording()` hides it, `resetToIdle()` brings it back. **Gotcha fixed 2026-09-08:** `.capbar{display:flex}` overrode the `hidden` attribute (author `display` beats UA `[hidden]{display:none}`), so the button showed before any capture was enabled — needed an explicit `.capbar[hidden]{display:none}`. `recorder.start()` is wrapped in try/catch (surfaces "could not start recording, try re-enabling capture" instead of throwing).
- **Review player: click-to-play + smooth scrubber (2026-09-08).** After a recording stops (or when a Library clip is opened), the review `<video>` no longer autoplays — it lands **paused on the first frame** with a circular ▶ play hint (`.playhint`, shown via `body.is-review.paused:not(.mode-text)`). Clicking anywhere on the clip toggles play/pause. A `.scrub` bar sits directly under the screen (visible only in `body.is-review`): an `<input type=range step="any">` whose track is an **ember fill gradient driven by a `--pct` CSS var** (0–100) with a custom round ember thumb, plus current / total time labels. While playing, a **`requestAnimationFrame` loop** (`scrubFrame`) repaints the position every frame so the thumb glides instead of stepping on `timeupdate` (~4 Hz); `timeupdate` only handles the paused/seek case (`if(scrubbing||scrubRaf) return`). Dragging (`input` → `change`) seeks; `paintScrub(pct)` is the single place that writes `scrub.value` + `--pct`. Fresh `MediaRecorder` webm blobs report `duration === Infinity` in Chromium until a seek forces it, so `syncDuration()` does the standard `currentTime = 1e101` then `= 0` dance on `loadedmetadata`. Overlay layers (`.audioviz`, `.playhint`, `.scrline`, `.badge`) are `pointer-events:none` so the click always reaches the video. During review the badge shows the recorded clip length. **Verified in-browser** against a real sample clip: lands paused, click plays, the rAF loop advances the fill with sub-integer values each frame, drag seeks, click pauses.
- **Accounts: Supabase auth wired up (2026-07-28).** `speakeasy.html` loads `@supabase/supabase-js@2` via CDN and creates a client against the user's project (`https://niqwjooeuougvvusjznp.supabase.co`, anon key hardcoded client-side — safe per the anon-key exception below). Topbar has a "Sign in" pill → modal with Log in / Sign up tabs (email + password via Supabase Auth). Logged-in state shows the user's email in the pill; clicking it while logged in signs out. Login is **optional** — logged-out behavior is unchanged from before (local IndexedDB stats, local FSAA save).
  - Schema lives in [supabase/schema.sql](supabase/schema.sql) — a `recordings` table (`user_id`, `created_at`, `duration_sec`, `topic_text`, `mode`) with RLS policies scoping every row to its owner. **Applied — user ran it in the Supabase SQL Editor on 2026-07-28.**
  - When logged in: new recordings also insert a row into Supabase `recordings` (in addition to, not instead of, the existing local IndexedDB write and local FSAA video save — nothing local changed). Stats (Day Streak, Total Mins) read from Supabase instead of IndexedDB while logged in, and revert to local IndexedDB when logged out.
  - **BUG FIXED 2026-08-13:** the cloud sync described above was documented as done but was never actually implemented. `refreshStats()` *read* from Supabase whenever signed in, but no code ever *inserted* a row (only a `select` existed). Net effect: signed-in users permanently saw 0 Day Streak / 0 Total Mins and nothing ever synced, while logged-out users were fine on local IndexedDB. `saveRecordingMeta()` now awaits the local IndexedDB write and then, only when `session` is truthy, inserts `{user_id, created_at, duration_sec, topic_text, mode}` into Supabase. A failed cloud insert logs and is swallowed so the local save (already committed) still counts. **Local-only path verified in-browser. Signed-in cloud insert also verified end-to-end 2026-08-14** — real login + real recording produced a row in the `recordings` table (correct `user_id`, `duration_sec`, `topic_text`), confirmed via the Supabase Table Editor.
  - **Auth error copy (2026-08-13):** a dead/paused backend previously surfaced in the modal as a bare "Failed to fetch", which told the user nothing. The submit handler now detects network-level failures (`failed to fetch` / `networkerror` / `load failed`, covering Chrome, Firefox and Safari wording) and shows "Can't reach the server right now. You can keep practicing without an account, your recordings still save locally." Genuine auth errors like "Invalid login credentials" are matched by none of those patterns and still pass through verbatim.
  - **Video upload to Storage shipped 2026-09-08** (see the cloud video library entry above); this line used to say it was deferred. Still not done: no migration of pre-Supabase local history into an account (those takes show as "local only" in the library instead). Supabase's default "confirm email on sign-up" setting is still on, so a new signup isn't usable until the confirmation link is clicked (or the user turns that off in their dashboard under Authentication → Providers → Email).
- **Save is now explicit, not automatic (2026-08-14).** Previously, hitting stop immediately wrote the video (FSAA) and the metadata (IndexedDB/Supabase) with no way to back out — a bad take got persisted before you'd even watched it back. Now `recorder.onstop` only builds the review player and stashes the blob/filename/metadata in `pendingBlob`/`pendingBase`/`pendingMeta`; nothing is written to disk, IndexedDB, or Supabase until the user clicks the new **💾 Save** button that appears next to the record button during review. The main record button also relabels to **↺ Retake** during review. **As of 2026-09-08, Retake no longer immediately starts a new recording** — the click handler is a three-way dispatch (recording → stop; reviewing → `resetToIdle()`; idle → `startRecording()`), so Retake discards the pending take and returns to the idle "● Rec" start state (live preview back, modes disabled, scrubber/Save hidden). The user then hits Rec when they're ready. Nothing was ever persisted, so discard is just state cleanup. Clicking Save runs `saveRecordingMeta()` (IndexedDB + cloud insert if signed in) and, if a save folder is connected (`dirHandle` set), writes the file via FSAA; **otherwise it now falls back to a plain browser download** (works in every browser, not just FSAA ones) rather than blocking the user from saving at all. This subsumes the old separate "↓ Save .webm" fallback button for non-FSAA browsers, which is removed — one Save action covers both paths now.
  - **Bug fixed 2026-08-14 (introduced by the same-day Library refactor below):** `autoSave()`'s `.json` sidecar write referenced a `now` variable that no longer existed in scope after `fsaaBase()` was extracted out, throwing on every save and silently skipping the sidecar (the `.webm` itself still wrote fine, since that happens first) while misreporting "save failed, check folder" even though the video had actually saved. Fixed by using `new Date()` directly at the point of the sidecar write.
- **Mirror toggle (2026-08-14, moved 2026-09-08).** Flips the camera preview horizontally via `.mirror{transform:scaleX(-1)}` on the video element, default off. This is a **display-only flip** — it affects the live preview and any in-browser playback (same `<video>` element for both), but not the actual saved `.webm` bytes, which are unflipped exactly as the camera captured them. Worth remembering if the saved file looks "backwards" compared to what was on screen — that's expected, not a bug. **As of 2026-09-08 it lives in the Rec Studio panel header** (right-aligned in the `.phead--split` row, `.toggle--mini`), not the top bar, so it's clearly associated with the preview it affects. The top bar now holds only Sign in / CRT / SFX.
- **Bug fixed 2026-08-18: top-bar toggles invisible on phone-width screens.** `.topbar` laid out the brand mark and the toggle pills (then Sign in / Mirror / CRT / SFX; Mirror has since moved to the studio panel) in a single non-wrapping flex row. On narrow viewports the row was wider than the screen, and because `body{overflow-x:hidden}` is set, anything past the right edge was clipped with no way to scroll to it — confirmed in-browser at 360px width, where SFX was fully cut off and Mirror only survived by luck of fitting. Fixed with a `@media (max-width:520px)` rule that stacks `.topbar` into a column (brand mark on its own row, toggles wrapping onto a full-width row below). Verified in-browser at both 360px (all four toggles now visible, none clipped) and desktop width (unchanged, still one row).
- Saving: File System Access API writes `.webm` + `.json` sidecar to a folder the user picks once (permission handle persisted in IndexedDB), now triggered by the explicit Save action above rather than automatically; browsers without FSAA (or without a folder connected) fall back to a manual download, also via the Save button. Unaffected by the Supabase work above.
  - **Gotcha confirmed 2026-08-14:** the saved folder handle is scoped **per origin** (`localhost:8080` and `speakeasy-beryl.vercel.app` are different origins, each needs its own SET SAVE DIR click). FSAA itself works on Vercel (any HTTPS origin qualifies as a secure context) — verified this only needs the one-time per-origin folder pick, no other change.
- Stats: a lightweight per-recording record (id, date, duration) is stored locally (IndexedDB) and/or in Supabase (see above) and used to compute **Day Streak** and **Total Mins** for real. **Words/Min and Fillers/Min are still placeholders** (`—`) — no transcription wired in yet.
- **Rec modes: Topic vs Words vs Freeplay (Words added 2026-09-08).** The right-hand card has a three-segment toggle (`#recModeSeg`) at the top:
  - **Topic** (default) — category/difficulty filter chips, a prompt, a difficulty pill, and "New topic". Duration presets 1:00 / 1:30 / 2:00 / 3:00, default 1:00. Shows the **daily topic** card (see the Daily Challenge entry below).
  - **Words (NEW 2026-09-08)** — hands you one random word and nothing else; you talk about it. Same filter-chip UI as Topic but with the 8 word categories, and the word renders large and ember-colored via `.topic.is-word`. Duration presets are shorter: 0:30 / 1:00 / 1:30 / 2:00, **default 1:00**. The card header reads "Your word" and the reroll button relabels to "New word". Shows the **daily word** card.
  - **Freeplay** — the Vinh Giang self-review method: no prompt at all. Filters, prompt text, and the reroll button are hidden; the card header switches to "Freeplay" and shows explainer copy. Duration presets swap to 3:00 / 5:00 / 10:00 / 15:00, **default 5:00**.
  - Implementation notes: one shared `.dursel` row whose four preset buttons are relabeled in place per mode (`DUR_PRESETS`), so the existing click listeners keep working. `chosenSec` remembers the selected duration *per mode* independently, including a custom `m:ss` value, and `applyRecMode()` restores it. As of 2026-09-08 the **category/difficulty filter selections and the on-screen prompt are also remembered per mode** (`selected` and `currentText`), so toggling Topic → Words → Topic restores each mode's chips and prompt rather than rerolling. Recordings save with `mode:'topic'|'words'|'freeplay'`; freeplay saves an empty `topicText` while words saves the word itself (so it shows in the Library). FSAA filenames are prefixed per mode: `speakeasy_` (topic, unchanged so old files still match), `speakeasy_words_`, `speakeasy_freeplay_`. The Supabase `mode` column is plain `text` with no CHECK constraint, so **`'words'` needed no migration.**
- Topics/words: **DONE, and massively expanded 2026-09-08.** Was 36 hardcoded topics in a literal `topics` array inside `speakeasy.html`; now 1,043 items from the inlined `SPEAKEASY_LIBRARY` block (see above), and the old array is deleted.
  - **Topic: 13 categories** (Random, Sports, News, Deep Qs, Debate, Story, What If, Tech, Work, Culture, Explain, Pitch, Humor), 45 prompts each.
  - **Words: 8 categories** (Objects, Abstract, Emotions, Places, Actions, Nature, People, Weird), ~57 each.
  - All items carry a difficulty (easy/medium/hard) meaning something consistent: easy = start talking immediately, hard = abstract or demands a real argument. For words, easy is concrete ("Key") and hard is abstract ("Entropy").
  - The category chip row is now **rendered from the library at runtime** (`renderCatFilters()`) rather than hardcoded in HTML, since the two modes have different category sets. Both chip rows use delegated click handlers because the chips get rebuilt on every mode switch.
  - Reroll avoids repeats via a session-scoped `recentIds` list (capped at 60) passed to `pickPrompt`'s `recent` option, which is stronger than the old "don't repeat the immediately previous one" rule. **Not persisted across reloads** — worth writing to IndexedDB alongside recordings if repeat-avoidance should survive a refresh.
  - A `libOK` guard remains as belt-and-suspenders: if `SPEAKEASY_LIBRARY` or its helpers are somehow missing (e.g. a parse error in the inlined block), the prompt slot shows "Prompt library failed to initialize. Try reloading the page." and recording, saving and stats keep working. With the library inlined this should be effectively impossible to hit.
- **Daily Challenge — one per mode (NEW 2026-09-08, extended same day).** A card at the top of the prompt pane (`#dailyCard`, shown in Topic and Words modes, hidden in Freeplay) showing today's date and one shared prompt that is **the same for every user on a given UTC day, with no backend**. Topic mode gets a **daily topic** ("◆ Daily Challenge"); Words mode gets a **daily word** ("◆ Daily Word") — two independent picks, so the two modes never show the same daily.
  - **Selection:** `computeDaily()` takes the UTC epoch-day number (`Date.UTC(y,m,d)/864e5`, floored) and, per mode, maps it to `(epochDay*mult + off) % poolLen`. Topic: `mult 362, off 61` over the 585 `mode:'topic'` items (362 coprime to 585 = 3²·5·13, and doesn't alias the 45-prompt category blocks — all 13 categories in the first 11 days). Words: `mult 283, off 193` over the 458 `mode:'word'` items (283 coprime to 458 = 2·229). Both are **full permutations** — every prompt used once before any repeat (~1.6 yr / ~1.25 yr cycles). Different offsets keep the topic-of-the-day and word-of-the-day uncorrelated. A given calendar date maps to fixed prompts forever, which is what lets two people compare takes.
  - **Interaction:** the button ("Do today's challenge" / "Do today's word") loads the daily into the main prompt slot, sets `dailyActive[mode]`, and shows a "◆ Today's Daily Challenge/Word" tag above the prompt. **When active the card gets louder, not smaller (changed 2026-09-08 per user):** ember border + ember glow (`box-shadow`) + brighter tint, the prompt stays fully visible and brightens to `--ink`, the label flips from "◆ Daily Challenge" to "✓ Daily Challenge · in progress", and the button reads "✓ Doing today's challenge/word". (Earlier it collapsed the card's prompt to avoid showing it twice — the user wanted the opposite, a clear "you're on this task" state.) Clicking again, or "New topic/word" / any filter chip, opts back out. `dailyActive` and the picked items are per-mode objects (`{topic,words}`), so each mode's daily state is independent and survives a Topic↔Words round-trip via `currentItem[mode]`.
  - **Difficulty indicator:** the daily card shows the prompt's easy/medium/hard pill under the phrase (`#dailyDiff`, colour-coded sage/ember/rec). This is the **only** place a difficulty pill appears — the standalone one that briefly lived under every rolled prompt was removed 2026-09-08 per user; `currentItem[mode]` still holds the full picked item for the per-mode restore-on-toggle.
  - **Tagging:** a recording made while `dailyActive[recMode]` is true (Topic or Words) is saved with `isDaily:true` and `dailyId` (the prompt's stable `t####` / `w####` id) on the **local IndexedDB record only** — extra fields on the object, no schema change. The Library row for a daily take shows a `◆` mark and the label "Daily" instead of "Topic"/"Words".
  - **Cloud tagging is deliberately NOT wired yet.** `saveRecordingMeta()`'s Supabase insert still sends only the 5 existing columns (`user_id, created_at, duration_sec, topic_text, mode`), so signed-in users' daily takes sync fine but won't carry the `◆` mark in the Library (cloud rows have no `isDaily`). Wiring it needs an `is_daily boolean` column on the `recordings` table + a migration for the existing project; bundle that with the next Supabase change (e.g. Storage) rather than forcing a migration now. The shared-prompt feature — the actual point — works fully regardless of login.
  - **Known limitation:** `computeDaily()` runs once at page load. A tab left open across a UTC midnight keeps showing yesterday's prompt until reload. Fine for v1.
  - **Verified in-browser 2026-09-08:** both pickers deterministic across reloads and each a full-length cycle with no repeats (585 topic / 458 word); Topic shows a daily topic + Words shows a different daily word, each with its own difficulty pill; activate loads the daily into the main slot with the matching tag/pill and collapses the card; "New topic/word" and filter chips opt out; Topic↔Words round-trip keeps each mode's daily state independent; a driven daily save (camera/mic unavailable in the automated browser) produces a local record with `isDaily:true` and a `◆ … Daily …` Library row while a normal save does not; desktop and 375px mobile both clean, no overflow, no console errors. Landing page: the "coming soon" pill is removed from the Daily Challenge feature card.
- **`library.html` — the library page (NEW 2026-09-08).** Third static page, linked from a "Library" pill in the studio topbar and a "View all →" link on the sidebar panel.
  - **Auth-gated by design.** Signed out you get a single card ("Your library lives with your account") with Create an account / I already have one / a link back to the studio. The recordings list is never rendered without a session, because rows are private to the account that made them.
  - **Gallery view**: responsive `auto-fill minmax(230px,1fr)` grid. Video takes show their poster; a video whose poster is missing gets a subtle diagonal-stripe "no preview" tile; **every audio-only take gets the same static equalizer tile** (no animation — one identical stagnant graphic, as asked).
  - **List view**: table with Title / Type / When / Length / delete. Length hides under 720px.
  - **Title** is the topic or word spoken about; Freeplay reads "Freeplay session". **Type** is a colour-coded badge — Topic (dim), Words (sage), Freeplay (faint), **Daily Challenge (ember)**, where `is_daily` wins over the base mode. **When** is full date plus time of day.
  - Filter chips (All / Topic / Words / Freeplay / Daily Challenge) and a Gallery/List segment. Clicking a card or row opens a modal player using a 1-hour signed URL; native `controls` are used there rather than the studio's custom scrubber, since a library wants volume and fullscreen too.
  - **Local-only takes are shown, not hidden** — anything recorded while signed out, or before cloud upload existed, appears with a "local only" badge and plays from the FSAA folder if the previously granted handle is still valid (same origin, so the handle carries over from the studio). If permission lapsed, a "Reconnect save folder" button re-requests it on a real click.
  - **Delete** removes the storage objects, the Supabase row, and the local IndexedDB record, behind a `confirm()` naming the take. A failure on any leg is logged and the UI still updates.
  - **Storage meter** reads `storage.list(user_id)` and shows "X of 1 GB used" so the free-tier ceiling is visible rather than a surprise.
  - **Verified in-browser 2026-09-08** against a stubbed session and a representative record set: gate shows signed out and the list never renders; gallery and list both render correct titles, badges, dates and durations; filters count correctly (daily pulls its items out of the topic/words buckets); poster / no-preview / audio tiles each render for the right case; play affordance appears only on playable rows; both "no video" fallbacks show the right explanation (missing bucket vs. local-only vs. never uploaded); delete removes the item and recomputes the header stats without crashing when the backend call fails; 375px mobile is single-column with no overflow.
- Duration: **DONE** — 4 presets plus a custom `m:ss` input (5s–30min range) that becomes the active duration on Enter/blur. Presets are **mode-dependent** (1:00/1:30/2:00/3:00 in Topic, 0:30/1:00/1:30/2:00 in Words, 3:00/5:00/10:00/15:00 in Freeplay) and each mode remembers its own choice. **A 5th "No limit" button (`data-sec="0"`, `.dur-nolimit`) was added 2026-09-08** — see the timer entry below.
- **Timer is a countdown, not a stopwatch (2026-09-08).** `setTimer()` (called every 250ms while `recording`): if `targetSec > 0` it shows **time remaining** counting down from the chosen duration, goes red in the last 5s, and calls `stopRecording()` the instant `remain <= 0` — so a 1:00 topic starts at 1:00 and ends itself at 0:00. If `targetSec === 0` ("No limit" selected) it counts **up** from 0:00 and never auto-stops — the user hits STOP whenever. `renderDurations()` treats `chosenSec[mode] === 0` as the no-limit state (activates `.dur-nolimit`, no preset/custom match). `stopRecording()` was extracted from the old inline stop branch so `setTimer` can call it; the record button handler is `recording → stopRecording` / `is-review → resetToIdle` / else `startRecording`. During review the badge shows the finished clip's length.
- Modes: FULL / CAM / AUDIO / TEXT toggle what's visible after a recording. TEXT mode still shows a **hardcoded sample transcript**, not the real recording's speech (unchanged — still phase 3 work). For an **audio-only** take FULL and CAM are disabled and the player opens in AUDIO.
- Library panel rows label all three modes as of 2026-09-08 (`MODE_LABELS`), so a Words take reads e.g. `Sep 8 · Words · 1:00 · "Complacency"`. Library panel (recent-recordings list in the sidebar) **now shows real data** (local IndexedDB or Supabase, no more hardcoded rows) with click-to-replay for local recordings. Done 2026-08-14, see roadmap §2.5 for detail. This was the blocker for per-recording notes — that item is next.
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
- [x] **Supabase Storage bucket for video files — done 2026-09-08.** Private `recordings` bucket, objects at `<user_id>/<recording_id>.webm` + `.jpg` poster, policies keyed on the first path segment vs `auth.uid()`. Needs [supabase/2026-09-08_library.sql](supabase/2026-09-08_library.sql) run once. Full detail in Current state.
- [x] **Save-destination decided 2026-09-08: both, automatically.** Signed in, a saved take goes to Supabase Storage *and* the local FSAA folder; signed out it stays local. Deliberately not exposed as a user-facing toggle — CLAUDE.md makes local save permanent, and auto-upload matches how metadata already syncs, so there was nothing meaningful left to choose. Revisit only if the 1 GB ceiling starts to bite.
- [x] **Ran [supabase/2026-09-08_library.sql](supabase/2026-09-08_library.sql)** — done 2026-09-09.
- [x] **Turned off "Confirm email"** — done 2026-09-09; a fresh signup now returns a session with no email click.
- [x] **Round trip verified end to end 2026-09-09** — shell test with a real user token (own-folder upload OK, cross-user upload refused by RLS, new-column insert 201, signed URL OK, delete OK) and the user confirmed in the live app: signed in, recorded, Saved, and the take shows in `library.html` with a poster thumbnail and plays back. Browser-download fallback also fired (no save folder on that origin).
- [ ] **Video retention / expiry (NEW, requested 2026-09-08)** — auto-remove cloud video files older than N days so the 1 GB tier stops being a ceiling. **Expire the file, keep the row**: `storage.remove()` the `.webm` + `.jpg`, then null `storage_path`/`thumb_path`, so Day Streak and Total Mins are never rewritten by a cleanup. Cloud becomes a rolling window; the local FSAA folder stays the permanent archive, which is consistent with CLAUDE.md. Start with a client-side sweep on `library.html` load (no backend, fits the project); escalate to a `pg_cron` + Edge Function only if dormant accounts holding space becomes a real problem. Open: window length (30/60/90), fixed vs. user-configurable, and whether to show "expires in N days" on cards. Full reasoning in P1 at the top.

### 2.5 Practice modes + history (agreed 2026-08-13)
- [x] **Freeplay mode** — no-prompt recording, default 5:00, reviewed via the existing full/cam/audio/text toggles. Done 2026-08-13.
- [x] **Big prompt library + Words mode — done 2026-09-08.** The 36 hardcoded topics became a 1,043-item library covering 13 topic categories and 8 word categories, and a third rec mode (Words) was added to use it. Shipped first as a separate `speakeasy-library.js`, then **inlined into `speakeasy.html` the same day** after the script-tag version failed to load for the user (see Current state for the full reasoning). Full detail in Current state above. **Verified in-browser 2026-09-08**: library present (1,043 items), all 13 topic / 8 word category chips render and rebuild correctly on mode switch, filtering by category+difficulty returns only matching items (12 consecutive rolls of Emotions/Hard were all in-pool and all unique), per-mode filter/duration/prompt memory round-trips correctly across all three modes, Freeplay is unchanged, clean console, and after inlining a fresh load makes **no request for any prompt file** (only Google Fonts + the Supabase CDN remain as external deps). Save path exercised directly (camera/mic aren't available in the automated browser): filenames come out `speakeasy_…` / `speakeasy_words_…` / `speakeasy_freeplay_…`, and Library rows render with correct Topic/Words/Freeplay labels. Desktop and 375px mobile both verified with no horizontal overflow.
- [x] **Library wired to real data — done 2026-08-14.** Sidebar Library panel now lists real recordings instead of hardcoded rows: newest-first, capped at 20, sourced from local IndexedDB when logged out / Supabase `recordings` when logged in (same source-switching pattern as stats). Each row shows date, mode (Topic/Freeplay), duration, and truncated topic text (Freeplay rows have none). No WPM column — still a `—` placeholder everywhere else, so it's correctly omitted here too.
  - **Click-to-replay works for local recordings only**, and this is a deliberate scope decision, not a stopgap: FSAA actually supports reading a previously-granted folder back (not just writing to it), so clips saved locally can be replayed in the browser today without needing Storage at all. The recorder's `onstop` handler now computes one shared `base` filename (via new `fsaaBase()` helper) and passes it to *both* the IndexedDB record (as `fsaaFile`) and the actual saved file, so a Library row knows exactly which file to reopen. Clicking a row calls `playLibraryRecord()`, which reads the file via the existing `dirHandle`, builds a blob URL, and drops it into the same review player used right after recording.
  - Cloud-sourced rows (signed in) never get `fsaaFile` — the Supabase `recordings` table has no such column and doesn't need one — so those rows render correctly as non-playable. This is intentional and matches reality: video Storage is still deferred, so there is no video to play back for a cloud row yet. Clicking a non-playable/disconnected row shows an inline status message instead of failing silently (e.g. "reconnect your save folder (SET SAVE DIR) to watch local recordings").
  - **Verified in-browser 2026-08-14** by injecting real records via the app's own `saveRecordingMeta()`/`refreshStats()` functions (camera/mic aren't available in the automated browser environment, so an actual end-to-end recording couldn't be driven there): list renders correctly with real dates/modes/durations/topics, empty-state message shows/hides correctly, the local ↔ cloud source switch was exercised directly (toggling `session`) and both branches render without errors, and the playable-row click path was confirmed to hit `playLibraryRecord()` and show the correct fallback message when no folder is connected. **Click-to-replay against a real saved `.webm` file confirmed working by the user 2026-08-14** — recorded locally with a real folder granted, clicked the row in the Library list, and the clip played back. Library panel is fully done, both the list and local playback.
- [ ] **Per-recording notes** — attach a text note to any recording so the user can look back and see progress. Needs a `notes` column (or a `notes` table) added to the Supabase schema, plus the same field on the local IndexedDB record. Depends on Library being real first.
- [x] **Daily Challenge — done 2026-09-08.** One globally-shared prompt per day, identical for every user, at the top of Topic mode. Went with the date-seeded no-backend approach: `(utcEpochDay*362 + 61) % 585` over the topic prompts, 362 chosen so the sequence is a full permutation that also doesn't alias with the category blocks. Recordings tagged `isDaily` locally; a `◆`/"Daily" marker in the Library. Cloud tagging (an `is_daily` column) deferred to bundle with the next Supabase change — the shared-prompt feature works regardless. Full detail + verification in Current state above.

### 2.6 Polish + presentation
- [ ] **Site icon / favicon (NEW, requested 2026-09-08)** — no page has one, so tabs and bookmarks show a blank sheet. Prefer an **inline SVG data-URI** in each `<head>` so no second file can 404 (the same failure that bit the prompt library). Bundle with `theme-color` and Open Graph tags so shared links preview properly. See P2 at the top.
- [ ] Replace the three `index.html` placeholders: the "demo video coming soon" box and the two About photo slots.

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
- ~~Daily Challenge needs a bigger prompt library first~~ / ~~per-day selection mechanism undecided~~ — **both resolved 2026-09-08**: library landed, and the date-seeded `%585` picker shipped. Remaining Daily follow-up is just cloud tagging (`is_daily` column), bundled with the next Supabase change.
- Should `recentIds` (the session's already-shown prompt ids) persist to IndexedDB so repeat-avoidance survives a page reload? Currently in-memory only, capped at 60. With 1,043 items the practical repeat rate is low, so this is a nicety rather than a real problem.
- `index.html` and `speakeasy.html` currently duplicate the same CSS block (fonts, variables, base styles) — fine for now at 2 pages, but worth factoring into a shared stylesheet before adding more pages (e.g. an auth page in phase 2)
- ~~Verifying the signed-in cloud insert end-to-end~~ — **CONFIRMED 2026-08-14.** User signed up for a real account, recorded a clip, and the Supabase Table Editor shows the row landed correctly: real `user_id`, `duration_sec: 3`, `topic_text` matching the recorded topic. The insert path written 2026-08-13 works end-to-end against a live backend. This closes out the last open item from Roadmap §2 (Accounts + cloud storage) other than Storage/video upload, which is explicitly deferred.
- ~~Next Supabase step: decide on Storage bucket structure (per-user folder path, RLS policy shape)~~ — **resolved 2026-09-08**: private `recordings` bucket, `<user_id>/<recording_id>.<ext>`, policies comparing `(storage.foldername(name))[1]` to `auth.uid()`.
- ~~Daily Challenge prompt selection: date-seeded vs. a `daily_prompts` table~~ — **resolved 2026-09-08**, shipped the date-seeded `(utcEpochDay*362+61)%585` picker. A `daily_prompts` table is only worth revisiting if you want to hand-curate specific prompts for specific dates without a deploy.
