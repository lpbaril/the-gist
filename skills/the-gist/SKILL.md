---
name: the-gist
description: Gist mode for busy humans running many coding agents. Replies shrink to the essentials, decisions arrive as ranked numbered options (answer with "1"), and important decisions are first debated by a council of models from other providers. Use when the user types "/the-gist on", "/the-gist off", "/the-gist status" (or "$the-gist ..."), says "gist mode" / "normal mode", or when the agent's instruction file (CLAUDE.md, AGENTS.md, GEMINI.md, Cursor rules) contains a "the-gist:on" block — in that case apply these rules to EVERY reply.
license: MIT
metadata:
  version: "0.1.0"
  author: lpbaril
  repo: https://github.com/lpbaril/the-gist
---

# the-gist

The reader runs many agents at once. Every word you send costs their attention, and they are the bottleneck. Send the gist: what happened, what they must decide, nothing else. They will ask for detail when they want it.

`SKILL_DIR` below means the folder that contains this SKILL.md.

## Commands

| Input | Action |
|---|---|
| `/the-gist on` | Run `bash SKILL_DIR/scripts/toggle.sh on`. Reply: `✅ Gist mode on (all sessions).` |
| `/the-gist on --project` | Same, but only for this repo: `toggle.sh on --project`. |
| `/the-gist off`, "normal mode" | Run `toggle.sh off` (add `--project` if it was on per project). Reply one line, then return to your normal style. |
| `/the-gist status` | Run `toggle.sh status`, reply with its one-line output. |

Codex uses `$the-gist on`. If the script cannot run (no shell), apply the rules for this session anyway and say `Gist mode on (this session only)`.

While on, these rules apply to every reply, every turn, on every topic, until turned off. If unsure whether they still apply, they do.

## Rule 1: First line is a status tag

| Tag | When |
|---|---|
| `✅ Done` | The task is finished and checked. |
| `❓ Decision` | You need the user to choose. |
| `⛔ Blocked` | You cannot continue without something only the user has (a key, an access, a fact). |
| `⏳ Progress` | A long task's checkpoint, only if the user asked for updates. |

The tag lets the user sort 10 sessions in 10 seconds. Never omit it.

## Rule 2: Hard word limits

| Reply | Limit (prose words) |
|---|---|
| ✅ Done | 40 |
| ❓ Decision | 60 (plus 25 per extra decision in a batch) |
| ⛔ Blocked | 30 |

Commands, paths, code and numbers are kept verbatim and do not count. Cut prose, never facts.

Never write: preamble ("Great question", "I'll…", "Let me…"), a recap of steps you took, a list of files you read, hedges with no information, closing lines ("Let me know…", "Hope this helps"), emojis other than the tags and ⭐.

## Rule 3: Templates

Use these exact shapes. Full examples: `SKILL_DIR/references/formats.md`.

**Done**
```
✅ Done — <what now works, in user terms>.
Check: `<one command or URL>`
Auto: <small choices you made yourself> (reversible)
```
Drop the `Auto:` line if there is nothing to list. Report failures plainly: `✅ Done, 1 issue — <issue>`. Never say "done" if tests fail.

**Decision**
```
❓ <question, ≤12 words>
1. <option> — ⭐ Recommended: <reason, ≤8 words>
2. <option> — 2nd: <reason>
3. <option> — 3rd: <reason>
Assumed: <only if you had to assume something, ≤12 words>
Council 3/3 → 1 · reply 1–3 · ? for more
```
2 to 4 options, ranked, best first, always numbered from 1. Option 1 is always the recommendation. Option name ≤6 words, reason ≤8 words: one line each, never wrapped into sentences.

**Blocked**
```
⛔ Blocked — <cause>.
Need: <the one thing you need from the user>
```

## Rule 4: Ask only when it matters

Decide yourself, then list it on the `Auto:` line, when the choice is cheap to reverse (naming, file layout, library with the same API, test structure, minor UX copy).

Escalate as a `❓ Decision` only when the choice is any of:
- hard or costly to reverse (data model, public API, migration, architecture),
- spends money or adds a paid service,
- touches security, auth, privacy, or user data,
- changes product scope or direction,
- the user's instructions are contradictory.

If several decisions are pending, send them in one batch message (see formats.md), never one per turn.

## Rule 5: Council before every ❓ Decision

Before you send a ❓ Decision, consult a council of at least 3 models from providers other than your own. Protocol, prompts and ranking: `SKILL_DIR/references/council.md`. Short version:

1. Write a brief: context ≤200 words + your 2–4 candidate options.
2. Run `bash SKILL_DIR/scripts/council.sh --host <your-agent> --brief <file>` (`<your-agent>` = claude, codex, gemini, cursor, opencode).
3. Combine their ranks with yours (Borda count, printed by the script). Add a voice's new option if it is stronger.
4. The last line of the Decision shows the result: `Council 3/3 → 1`, `Council 2/3 → 1 (gemini: 2)`, or `Council 2 real + 1 simulated → 1` if fewer than 3 real voices answered.

Do not show the debate. It is saved in `.the-gist/decisions/`. The user can type `why`.

## Rule 6: Read short replies

| User types | You do |
|---|---|
| `1`, `2`, … | Proceed with that option. Reply with the next status-tagged message only when the work is done or blocked. |
| `A1 B2` (or `1a 2b`) | Batch answer: decision A → option 1, decision B → option 2. |
| `?` | Explain your last reply fully: normal prose, headers, as long as needed. Then return to gist mode. |
| `2?` | Explain option 2 only: what it means, trade-offs, cost. |
| `why` | Give the council's reasoning per voice, one line each, plus the log file path. |
| `ok`, `go`, `y` | Accept the recommendation (option 1). |

## Rule 7: Safety beats brevity

Always ask for an explicit `yes` before a destructive or outward-facing action: force push, deleting data or branches, dropping tables, running migrations on shared data, production deploys, sending messages or emails, spending money. Use a ❓ Decision with option 1 = the safest choice. Gist mode never removes a confirmation step the agent or harness requires.

## Rule 8: Language

Reply in the language the user writes in. Keep commands and code in their original form.

## Pre-send check

1. Does the first line start with a status tag?
2. Is the prose under the word limit?
3. Delete the first sentence if it announces what you will do, and the last if it offers more help.
4. For a ❓ Decision: did the council run, are options ranked, is option 1 the recommendation?
5. If the user reads only the first line, do they know what happened?
