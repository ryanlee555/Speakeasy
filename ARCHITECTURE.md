# Speakeasy: how it's built

A technical orientation for someone new to the codebase. For current status and the decision log, see [PROGRESS.md](PROGRESS.md); for the product vision, see [CLAUDE.md](CLAUDE.md).

## The big picture

Speakeasy has no server of its own and no build step. It is three HTML files served as static files. The browser does most of the work, and two hosted services (Vercel and Supabase) fill in what a browser can't do alone.

```
                    ┌──────────────────────────┐
                    │ GitHub (ryanlee555/      │
                    │ Speakeasy, branch main)  │
                    └────────────┬─────────────┘
                                 │ every push auto-deploys
                                 ▼
                    ┌──────────────────────────┐
                    │ Vercel: serves the files │
                    │ speakeasy-beryl.vercel.app│
                    └────────────┬─────────────┘
                                 │ HTML/JS loaded into the user's browser
                                 ▼
 ┌───────────────────────── User's browser ─────────────────────────┐
 │ records (MediaRecorder), transcribes (Whisper/WASM), measures    │
 │ audio (Web Audio), stores local copies (IndexedDB, localStorage) │
 └───────┬──────────────────────────────────────────────┬───────────┘
         │ supabase-js (HTTPS)                          │ model download
         ▼                                              ▼
 ┌──────────────────────────────┐             jsDelivr + Hugging Face
 │ Supabase                     │             (CDNs for code + the
 │  Auth · Postgres · Storage   │             Whisper model files)
 │  Edge Function "coach" ──────┼──► Anthropic API (Claude)
 └──────────────────────────────┘
```

## 1. The frontend: three static HTML files

| File | Size | Role |
|---|---|---|
| [index.html](index.html) | ~340 lines | Landing page. |
| [speakeasy.html](speakeasy.html) | ~9,000 lines | The studio: pick a prompt, record, review, save. Also the sign-in modal and stats. |
| [library.html](library.html) | ~1,700 lines | Saved recordings: playback, transcript, AI coach, rename, delete. |
| [speakeasy-avatars.js](speakeasy-avatars.js) | small | 30 inline SVG avatar icons. |

There are no frameworks and no npm. Each page is plain HTML, CSS and JavaScript in one file. The prompt library (topics and words) is inlined inside `speakeasy.html` on purpose: PROGRESS.md records that a separate JS file once failed to load, so the project chose one file with fewer ways to break.

Trade-off: nothing to install or build, and deploys are trivial. But the files are huge, there is no type checking, and sharing code between pages means copy-paste (the signup handler exists in both `speakeasy.html` and `library.html`, and a fix has to be made in both). If the project keeps growing, moving to a bundler such as Vite is the natural next step.

## 2. Browser APIs doing the heavy lifting

- **`getUserMedia` and `MediaRecorder`** capture camera and mic and encode `.webm`. Bitrate is capped at 1 Mbps video / 96 kbps audio, because Chrome's default (~18 MB/min) would fill Supabase's free 1 GB storage in under an hour.
- **File System Access API** (`showDirectoryPicker`) lets a user pick a local folder and save `.webm` + `.json` files straight to disk. Chrome-only, and scoped per origin, so `localhost` and the Vercel site each need their own folder pick. Browsers without it fall back to a normal download.
- **IndexedDB** keeps a local recording history, and persists the folder handle so the permission survives reloads.
- **localStorage** is used for small caches: transcripts, coach grades, and "did I do today's daily challenge."
- **Whisper in the browser.** `library.html` loads `@huggingface/transformers` from jsDelivr and runs `Xenova/whisper-small.en` in a Web Worker using WebAssembly. Transcription is free and private (audio never leaves the device). The cost is a large first-time model download and slow transcription on weak machines. Results are cached in localStorage and in the database.
- **Web Audio** (`decodeAudioData`) computes pitch and loudness variation from the audio, to feed the coach.

## 3. Vercel (hosting)

Vercel is connected to the GitHub repo. A push to `main` deploys to production at `speakeasy-beryl.vercel.app`; any other branch or PR gets its own preview URL. There is no framework, build command or env vars: it serves static files.

[vercel.json](vercel.json) adds security headers: no MIME sniffing, a Referrer-Policy, `X-Frame-Options: DENY` plus `frame-ancestors 'none'` (no clickjacking via iframes), and a Permissions-Policy allowing camera/mic only for this site. A full Content-Security-Policy was skipped on purpose, since the inline scripts and the Whisper CDN loads would break under a strict one.

Vercel is only the file server. It never sees user accounts or recordings. Emails from Vercel (such as "new sign-in detected") concern the owner's own Vercel login, not app signups.

## 4. Supabase (the entire backend)

Supabase is hosted Postgres plus auth, file storage and serverless functions. Project ID: `niqwjooeuougvvusjznp`. The browser talks to it through `supabase-js`, loaded from jsDelivr.

### Auth
Email + password accounts, handled entirely by Supabase. After login, supabase-js stores the session (a JWT) in localStorage and attaches it to every request. "Confirm email" is **off** (a deliberate choice), so signup returns a live session immediately. Display name and avatar live in Supabase's per-user `user_metadata`, not in a table.

### The anon key is public, and that's fine
The anon key sits in the page source by design: it only identifies the project and carries the lowest-privilege `anon` role. What actually protects data is Row Level Security (below). Never put the **service-role** key in the browser.

### Postgres and Row Level Security (RLS)
The SQL files in [supabase/](supabase/) are the schema history. The dated files were each run once by hand in the Supabase SQL Editor; Supabase does not apply them automatically.

- `public.recordings`: one row per saved take. Columns: `id`, `user_id`, `created_at`, `duration_sec`, `topic_text`, `mode`, `storage_path`, `thumb_path`, `is_daily`, `audio_only`, `target_sec`, `transcript` (jsonb), `coach` (jsonb).
- `public.coach_runs`: one row per AI-coach request, so the function can enforce daily caps.

RLS is the core security idea. Each table has policies like `auth.uid() = user_id`, so even though every browser holds the same anon key, a logged-in user can only read, insert, update or delete **their own rows**. Without these policies anyone could read everyone's data from the browser console. PROGRESS.md's security pass records live probes with only the anon key: reads return nothing, inserts are refused.

### Storage
A **private** bucket `recordings` holds videos and poster frames at `<user_id>/<recording_id>.webm` and `.jpg`. Storage policies require the first path folder to equal `auth.uid()`, so each user has their own folder. Because the bucket is private, the library uses short-lived (1-hour) **signed URLs** to play videos.

### Edge Function: `coach`
[supabase/functions/coach/index.ts](supabase/functions/coach/index.ts) is serverless code (Deno/TypeScript), deployed with the Supabase CLI. It powers the AI coach and is how secrets stay out of the browser:

1. The browser sends the transcript, computed audio metrics, and (for video takes) a few still frames.
2. The function verifies the user's token, then enforces limits: **20 gradings per account per day** and **150 per day site-wide** (the site-wide cap exists because open signup lets someone mint many accounts).
3. It calls the Anthropic API with the `ANTHROPIC_API_KEY` secret, which lives only in Supabase's secrets. Model: `claude-opus-5-5`, asked for structured JSON.
4. It returns scores, reasoning and tips for categories such as pacing, word choice and structure. The browser caches the grade in localStorage and the `coach` column.

The coach is the one feature that costs real money per use, which is why it has two layers of caps.

## 5. Data flow when someone records

1. **Record.** The browser holds the video blob in memory. Nothing is persisted until the user clicks Save.
2. **Save.** The take goes into local IndexedDB. If signed in, it uploads the video and poster to Storage and inserts a `recordings` row. If a local folder is connected, it also writes the file there; otherwise it downloads the file.
3. **Library.** Merges the local and cloud lists. Both share a client-generated UUID, so the merge is exact.
4. **Transcript.** Whisper runs on demand in the browser and caches the result.
5. **Coach.** The browser calls the Edge Function, which calls Claude.

Signed-out users still get the whole recording flow with local stats. Accounts add the cloud library and the coach.

## 6. Smaller design notes

- **Daily Challenge** is date-seeded: everyone gets the same prompt on a given day with no server involved.
- **Stats** (streak, total minutes) come from Supabase when signed in and from IndexedDB when not.

## 7. Things to know before changing anything

- **Free tier risks:** Supabase pauses projects after about a week of inactivity. This already happened once (see PROGRESS.md), so the app needs periodic use.
- **Storage is capped** at 1 GB on the free tier. The bucket has no per-file size or MIME limit yet.
- **Open signup, no email verification:** throwaway accounts are possible. The coach caps contain the cost; CAPTCHA (Authentication → Attack Protection) is the real fix. Turning on email verification also needs custom SMTP and the Site URL set (see PROGRESS.md).
- **Migrations are manual.** Pushing code does not change the database. A new column needs a SQL file run in the dashboard and a note in PROGRESS.md.
- **Edge Function deploys are separate from Vercel:** `supabase functions deploy coach --project-ref niqwjooeuougvvusjznp`.
- **Local dev:** [.claude/launch.json](.claude/launch.json) starts `python3 -m http.server 8080`, a plain static server.
- **Docs:** CLAUDE.md holds the vision and the rule to update PROGRESS.md after every change. PROGRESS.md is the running log.

## Suggested learning path

1. Read [supabase/schema.sql](supabase/schema.sql) and the library migration, then try selecting another user's rows as an ordinary user. It is the best way to feel what RLS does.
2. Open DevTools → Network on the live site while saving a recording. The Storage upload and the `recordings` insert are plain HTTP calls with the JWT attached.
3. Read the coach function top to bottom (~200 lines): auth, validation, rate limiting, a third-party API call.
4. Find `saveRecordingMeta` and the upload code in `speakeasy.html` and trace one save end to end.
