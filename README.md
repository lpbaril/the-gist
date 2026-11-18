# the-gist

**Stop being the bottleneck of your own software factory.**

`the-gist` is an [Agent Skill](https://agentskills.io) for coding agents (Claude Code, Codex, Gemini CLI, Cursor, and others that read `SKILL.md`). Turn it on and every agent reply shrinks to the gist:

```
✅ Done — password reset by email works; 23/23 tests pass.
Check: `npm run dev` → /forgot-password
Auto: 30-min token expiry, reused existing rate limiter (reversible)
```

When an agent needs you, it first asks a **council of 3+ models from other providers** to challenge its options, then sends you a ranked list you answer with one digit:

```
❓ Which job queue for email + PDF jobs?
1. Inngest — ⭐ Recommended: no infra, works on Vercel
2. BullMQ + Redis — 2nd: cheapest at high volume
3. Postgres (pg-boss) — 3rd: no new service, slower
Council 3/3 → 1 · reply 1–3 · ? for more
```

You type `1`. Done.

More examples: [examples/before-after.md](examples/before-after.md)

## Install

**Any agent (recommended)**, using the open [skills CLI](https://github.com/vercel-labs/skills):
```bash
npx skills add lpbaril/the-gist
```

**Claude Code plugin**:
```
/plugin marketplace add lpbaril/the-gist
/plugin install the-gist@the-gist
```
(As a plugin, the command is `/the-gist:the-gist on`. Install via `npx skills` to get plain `/the-gist on`.)

**Manual**: copy `skills/the-gist/` into your agent's skills folder (e.g. `~/.claude/skills/the-gist/`).

## Use

| You type | What happens |
|---|---|
| `/the-gist on` | Gist mode on for **all** sessions of every installed agent, until you turn it off. Codex: `$the-gist on`. |
| `/the-gist on --project` | On for this repo only (writes `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, `.cursor/rules/`). |
| `/the-gist off` | Back to normal replies. |
| `/the-gist status` | Shows where it's on. |
| `1`, `2`, … | Pick an option. `ok` = take the recommendation. |
| `A1 B2` | Answer several decisions in one message. |
| `?` | Full explanation of the last reply. |
| `2?` | More detail on option 2. |
| `why` | One line per council voice + path to the full debate log. |

### What the agent does in gist mode

- **First line is a status tag**: ✅ Done · ❓ Decision · ⛔ Blocked. Sort 10 sessions in 10 seconds.
- **Hard word limits**: Done ≤ 40 words, Decision ≤ 60, Blocked ≤ 30. Code and paths don't count.
- **Only asks when it matters**: small, reversible choices are made for you and listed on one `Auto:` line. You're only asked about things that are hard to reverse, cost money, touch security or data, or change product direction.
- **Council before every question**: 3+ models from other providers attack the agent's favorite option and rank all options (Borda count). The full debate is saved in `.the-gist/decisions/`.
- **Safety stays**: destructive actions (force push, dropping data, prod deploys) still need your explicit yes.
- **Your language**: replies in the language you write in.

## Council setup

The council uses whatever is available, in this order:

1. **Agent CLIs you already have** (your existing subscriptions, no API key): `codex`, `gemini`, `claude`, `cursor-agent`, `opencode`, `qwen`. The host agent's own provider is skipped, and there's one voice per provider.
2. **OpenRouter** fills the remaining seats: `export OPENROUTER_API_KEY=...` in your shell profile.
3. **Simulated contrarians** if fewer than 3 real voices answer. The reply says so: `Council 2 real + 1 simulated`.

Example: in Claude Code with `codex` and `gemini` installed plus an OpenRouter key, the council is GPT (codex) + Gemini + Grok (OpenRouter).

Check what would run:
```bash
bash ~/.claude/skills/the-gist/scripts/council.sh --host claude --brief brief.md --dry-run
```

Tune voices, timeout and models: copy [`config.example`](config.example) to `~/.the-gist/config`.

**Privacy**: the council brief (≤200 words of context) is sent to the other providers. The skill tells agents never to include secrets or customer data, and to use simulated voices when a decision depends on private data.

**Cost and time**: a council takes about 10–60 s and a few cents with OpenRouter. It only runs for real decisions, not for every reply.

## Files

```
skills/the-gist/
├── SKILL.md                 # the rules agents follow
├── references/formats.md    # exact reply templates
├── references/council.md    # council protocol
└── scripts/
    ├── council.sh           # runs the council (bash 3.2+, curl)
    └── toggle.sh            # on / off / status
```

## Credits

Inspired by the `i-have-adhd` output-shaping skill, [caveman](https://github.com/JuliusBrussee/caveman) (shorter replies), and multi-model council tools like llm-council and PAL MCP `consensus`. `the-gist` combines short replies, one-digit decisions and a council in one skill.

## License

MIT
