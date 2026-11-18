# the-gist — reply formats

Copy these shapes exactly. Prose word limits: Done 40, Decision 60 (+25 per extra decision in a batch), Blocked 30. Code, paths, commands and numbers don't count.

## ✅ Done

Good:
```
✅ Done — magic-link login works; 14/14 auth tests pass.
Check: `npm run dev` → http://localhost:3000/login
Auto: Resend for email (already in deps), 15-min link expiry (reversible)
```

Good, with an issue:
```
✅ Done, 1 issue — CSV export works; files over 50 MB time out on Vercel (10 s limit).
Check: `npm test -- export`
```

Bad (too long, recap, closer):
```
I've finished implementing the magic link feature. First, I explored the codebase
and found that auth lives in src/auth. Then I added a new route... Let me know if
you'd like me to make any changes!
```

## ❓ Decision

Good:
```
❓ Where should user uploads be stored?
1. Cloudflare R2 — ⭐ Recommended: no egress fees, S3 API
2. AWS S3 — 2nd: team already knows it
3. Postgres bytea — 3rd: simplest, breaks past ~1 GB
Council 3/3 → 1 · reply 1–3 · ? for more
```

Split council:
```
❓ Rewrite the billing module or patch it?
1. Patch now, rewrite in Q3 — ⭐ Recommended: ships this week
2. Rewrite now — 2nd: removes 3 known bugs at once
Council 2/3 → 1 (gemini: 2) · reply 1–2 · ? for more
```

Not enough real voices:
```
Council 2 real + 1 simulated → 1 · reply 1–3 · ? for more
```

## ❓ Batch (several decisions)

Decisions get letters, options get numbers. One message, never one per turn.
```
❓ 2 decisions
A. Auth provider?
   1. Clerk — ⭐ Recommended: fastest, prebuilt UI
   2. Auth.js — 2nd: free, more code
B. Deploy target?
   1. Vercel — ⭐ Recommended: zero config for Next.js
   2. Fly.io — 2nd: cheaper at scale
Council 3/3 → A1, 3/3 → B1 · reply e.g. `A1 B1` · ? for more
```

## Council test (`/the-gist test`)

Build it from the script's VOICE, OPENROUTER, VERDICT and FIX lines. One entry per voice: ✓ with seconds, or ✗ with a 1–3 word cause. Add `openrouter ✗ no key` when the key is not set. Drop the `Fix:` line when FIX is none.

VERDICT OK or PARTIAL:
```
✅ Council test — 2/3 real voices
codex ✓ 12s · gemini ✓ 8s · openrouter ✗ no key
Fix: export OPENROUTER_API_KEY=… for a 3rd voice
```

VERDICT NONE:
```
⛔ Council test — 0/3 real voices
Fix: install `codex` or `gemini` CLI, or export OPENROUTER_API_KEY=…
```

## ⛔ Blocked

```
⛔ Blocked — Stripe test key missing; checkout tests can't run.
Need: STRIPE_SECRET_KEY (test mode) in .env.local
```

## ⏳ Progress (only if the user asked for updates)

```
⏳ 3/5 — schema migrated, API done. Next: UI forms (~20 min).
```

## After `?` (explain mode)

Normal prose, headers, as long as the topic needs. No status tag needed. The next reply returns to gist mode.

## After `why`

```
Council on "Where should user uploads be stored?"
- codex (gpt): 1 — egress costs dominate at your traffic
- gemini: 1 — S3-compatible, easy to migrate away
- openrouter/grok: 2 — team familiarity reduces risk
- me (claude): 1
Log: .the-gist/decisions/20261118-142233-user-uploads.md
```
