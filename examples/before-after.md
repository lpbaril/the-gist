# Before / after

## 1. Task finished

**Before (182 words)**
> I've completed the implementation of the password reset flow. Here's a summary of what I did:
>
> 1. First, I explored the existing authentication code in `src/auth/` to understand the current structure. I noticed that you're using NextAuth with a credentials provider.
> 2. I created a new API route at `src/app/api/auth/reset/route.ts` that generates a secure token using `crypto.randomBytes` and stores it in the `password_reset_tokens` table.
> 3. I added a migration for the new table…
> 4. I wrote an email template using your existing Resend setup…
> 5. I added tests…
>
> All 23 tests are passing. A few things to note: I chose a 30-minute expiry for tokens, which is a common default, and I reused the existing rate limiter. Let me know if you'd like me to adjust anything or if you have any questions!

**After (27 words)**
```
✅ Done — password reset by email works; 23/23 tests pass.
Check: `npm run dev` → /forgot-password
Auto: 30-min token expiry, reused existing rate limiter (reversible)
```

## 2. Decision needed

**Before (240+ words)** — three paragraphs comparing queues, ending with "What would you prefer?"

**After (41 words)**
```
❓ Which job queue for email + PDF jobs?
1. Inngest — ⭐ Recommended: no infra, works on Vercel
2. BullMQ + Redis — 2nd: cheapest at high volume
3. Postgres (pg-boss) — 3rd: no new service, slower
Council 3/3 → 1 · reply 1–3 · ? for more
```

User replies: `1`

## 3. Blocked

**Before**
> I tried to run the integration tests, but it seems there might be an issue with the database connection. It looks like the `DATABASE_URL` environment variable may not be set in your environment. Could you possibly check…

**After**
```
⛔ Blocked — DATABASE_URL not set; integration tests can't connect.
Need: DATABASE_URL in .env.test (Neon branch URL works)
```

## 4. Two decisions at once

```
❓ 2 decisions
A. Multi-tenant data model?
   1. tenant_id column + RLS — ⭐ Recommended: one DB, Postgres enforces isolation
   2. Schema per tenant — 2nd: stronger isolation, painful migrations
B. Billing?
   1. Stripe Checkout — ⭐ Recommended: hosted, ships today
   2. Lemon Squeezy — 2nd: handles global sales tax
Council 3/3 → A1, 2/3 → B1 (grok: 2) · reply e.g. `A1 B1` · ? for more
```

User replies: `A1 B2`
