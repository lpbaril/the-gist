# the-gist — council protocol

Run this before every ❓ Decision. Goal: the user gets options that 3+ independent models from other providers have already challenged, ranked best first.

## 1. Write the brief

Create a temp file (e.g. `.the-gist/brief.md`) with:

```
QUESTION: <one line>
CONTEXT: <≤200 words: project, constraints, what you already know, what you tried>
OPTIONS:
1. <option> — <one-line trade-off>
2. <option> — <one-line trade-off>
3. <option> — <one-line trade-off>
YOUR CURRENT PICK: <n> (the voices are told to challenge it)
```

Rules for the brief:
- Facts only. No secrets, keys, tokens, customer data or private URLs: the brief is sent to other providers.
- Number options 1..N (2 ≤ N ≤ 4). Order doesn't matter yet.
- Include the constraint that decides it (budget, deadline, team size, scale) if you know it.

## 2. Run the council

```bash
bash SKILL_DIR/scripts/council.sh --host <claude|codex|gemini|cursor|opencode> --brief .the-gist/brief.md
```

Options: `--voices N` (default 3), `--timeout SEC` (default 180), `--dry-run` (list voices, call nothing), `--log-dir DIR` (default `.the-gist/decisions`).

How voices are picked (from `~/.the-gist/config` if present, otherwise defaults):
1. Local agent CLIs from a provider other than the host, in this order: codex (OpenAI), gemini (Google), claude (Anthropic), cursor-agent, opencode, qwen. One voice per provider.
2. If fewer than N, OpenRouter models (`OPENROUTER_API_KEY` must be set), skipping providers already used and the host's provider.
3. If still fewer than N, the script prints `SIMULATED_NEEDED: k`.

Each voice sees the brief plus this instruction (built into the script):

> You are a contrarian reviewer on a decision council. Attack the current pick first: find its strongest failure mode. Then rank ALL options best to worst. If an option is missing that clearly beats them all, propose it. Answer in exactly these lines and nothing else:
> RANK: <comma-separated option numbers, best first>
> WHY: <one sentence, ≤25 words>
> NEW: <a better option in ≤12 words, or "none">

The script prints one line per voice, a Borda tally, and the log path:

```
VOICE codex (openai) | RANK: 1,3,2 | WHY: ... | NEW: none
VOICE gemini (google) | RANK: 1,2,3 | WHY: ... | NEW: none
VOICE openrouter:x-ai/grok-4 (x-ai) | RANK: 2,1,3 | WHY: ... | NEW: none
TALLY: 1=8 2=5 3=2
REAL_VOICES: 3/3
LOG: .the-gist/decisions/20261118-142233-user-uploads.md
```

## 3. Simulated voices (only if needed)

If `SIMULATED_NEEDED: k` appears, write k contrarian takes yourself, each from a different stance: (a) cost and operations, (b) security and failure modes, (c) speed of delivery. Rank the options as that stance would. Append them to the log file under `## Simulated voices`. Say so in the reply: `Council 2 real + 1 simulated`.

## 4. Rank

- Add your own ranking as one more voice.
- Borda count: with N options, 1st place = N points, 2nd = N−1, … Add up the voices' points plus your own. Highest total = option 1 in the reply.
- Tie: prefer the more reversible option.
- A `NEW` option proposed by 2+ voices, or by one voice with a reason you can't refute, joins the list. Re-run the council only if it would become the top pick.
- If the council strongly disagrees with your pick (your pick isn't in their top 2), say so: `Council 1/3 → 1 (codex, gemini: 2)`.

## 5. Report

Send the ❓ Decision template (SKILL.md Rule 3). The last line:
- `Council 3/3 → 1` — all real voices put the recommendation first.
- `Council 2/3 → 1 (gemini: 2)` — name dissenters and their pick.
- `Council 2 real + 1 simulated → 1`.

Never paste the debate. `why` shows it.

## Privacy

The brief leaves the machine. If the decision depends on secrets or private data, describe it abstractly ("a 40 GB customer table with PII") or skip external voices and run simulated ones, saying `Council simulated (private data)`.
