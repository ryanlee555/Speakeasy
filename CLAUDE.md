# Speakeasy

A speaking-practice web app: pick a prompt, record yourself answering it on camera/mic, review the clip immediately, and build a habit over time via stats (streak, total minutes, eventually words/min and filler-word rate).

## Vision / end state

Right now it's two static files (`index.html` landing page + `speakeasy.html` app) with everything running client-side — recording, local file save, stats — no backend, no accounts. That's a deliberate starting point, not the destination.

The intended end state, per the user (2026-07-27): **deploy this as a real website where people sign up with their own username/password, and each person's recordings, stats, and topic history are private to their account** — not a single-machine local tool. Supabase is the planned path for auth + database + file storage (see the roadmap in [PROGRESS.md](PROGRESS.md) for the phased plan to get there). Local-folder save stays available as a user choice even after cloud accounts exist — it's not being replaced, just supplemented.

The visual direction — warm, dark, cozy; Fraunces serif + Inter sans; ember/brown accent; pill-shaped controls; soft glow background — was explicitly chosen by the user to replace an earlier pixel/CRT retro look. Keep building in this style; don't drift back toward the old aesthetic.

See [PROGRESS.md](PROGRESS.md) for current state, the active roadmap, and decisions made so far — read it at the start of any session in this project.

## Working agreement

After every change made in this project (features, fixes, redesigns, anything), update `PROGRESS.md`: what changed, what's still open, any new decisions. The goal is that a brand-new chat can open this repo and pick up exactly where the last session left off, without the user having to re-explain context.
