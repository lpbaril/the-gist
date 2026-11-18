#!/usr/bin/env bash
# the-gist toggle: keep gist mode on across sessions until turned off.
# Usage: toggle.sh on|off|status [--project] [--agent claude|codex|gemini|cursor|all]
#   on        add a marked block to each agent's global instruction file
#   on --project   add it to this repo's CLAUDE.md, AGENTS.md, GEMINI.md, .cursor/rules
#   off       remove the block everywhere it was added (same scope flag)
#   status    print where gist mode is on
set -u

START='<!-- the-gist:on -->'
END='<!-- /the-gist -->'

ACTION="${1:-status}"; [ $# -gt 0 ] && shift
SCOPE="global"
AGENT="all"
while [ $# -gt 0 ]; do
  case "$1" in
    --project) SCOPE="project"; shift ;;
    --global) SCOPE="global"; shift ;;
    --agent) AGENT="${2:-all}"; shift 2 ;;
    -h|--help) sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "ERROR: unknown argument: $1" >&2; exit 2 ;;
  esac
done

BLOCK="$START
## Gist mode: ON (the-gist skill)
Follow the \`the-gist\` skill for EVERY reply in this and every new session, until the user types \`/the-gist off\`.
Core rules if the skill is not loaded:
- First line is a status tag: ✅ Done / ❓ Decision / ⛔ Blocked.
- Max prose words: Done 40, Decision 60, Blocked 30. No preamble, no recap, no closing offer.
- Decide reversible small choices yourself; list them on one \`Auto:\` line.
- Decisions: 2-4 numbered options, best first, \"⭐ Recommended: <reason>\", after a council of 3+ models from other providers. User answers with a number; \`?\` = explain, \`2?\` = more on option 2, \`why\` = council reasoning.
- Always confirm destructive or outward-facing actions.
$END"

CURSOR_RULE="---
description: the-gist — gist mode on
alwaysApply: true
---
$BLOCK"

# target list: "path|kind" ; kind = md (append block) or cursor (whole file)
targets() {
  if [ "$SCOPE" = "global" ]; then
    want claude && echo "$HOME/.claude/CLAUDE.md|md|$HOME/.claude"
    want codex && echo "$HOME/.codex/AGENTS.md|md|$HOME/.codex"
    want gemini && echo "$HOME/.gemini/GEMINI.md|md|$HOME/.gemini"
  else
    want claude && echo "$PWD/CLAUDE.md|md|"
    { want codex || want cursor; } && echo "$PWD/AGENTS.md|md|"
    want gemini && echo "$PWD/GEMINI.md|md|"
    want cursor && echo "$PWD/.cursor/rules/the-gist.mdc|cursor|"
  fi
}
want() { [ "$AGENT" = "all" ] || [ "$AGENT" = "$1" ]; }

has_block() { [ -f "$1" ] && grep -qF "$START" "$1"; }

strip_block() {  # remove the block (and the blank line we added before it) in place
  tmp="$1.the-gist.tmp"
  awk -v s="$START" -v e="$END" '
    { a[NR] = $0 }
    END {
      out = 0; skip = 0
      for (i = 1; i <= NR; i++) {
        if (a[i] == s) { skip = 1; if (out > 0 && b[out] == "") out--; continue }
        if (skip) { if (a[i] == e) skip = 0; continue }
        b[++out] = a[i]
      }
      for (i = 1; i <= out; i++) print b[i]
    }' "$1" > "$tmp" && mv "$tmp" "$1"
}

changed=0
case "$ACTION" in
  on)
    while IFS='|' read -r path kind dir; do
      [ -n "$path" ] || continue
      # global: only for agents that are installed (their config dir exists)
      if [ -n "$dir" ] && [ ! -d "$dir" ] && ! command -v "$(basename "$dir" | tr -d .)" >/dev/null 2>&1; then
        continue
      fi
      mkdir -p "$(dirname "$path")"
      if [ "$kind" = "cursor" ]; then
        printf '%s\n' "$CURSOR_RULE" > "$path"; echo "on: $path"; changed=1; continue
      fi
      if has_block "$path"; then echo "already on: $path"; continue; fi
      if [ -s "$path" ]; then printf '\n%s\n' "$BLOCK" >> "$path"; else printf '%s\n' "$BLOCK" > "$path"; fi
      echo "on: $path"; changed=1
    done <<EOF
$(targets)
EOF
    [ "$changed" -eq 0 ] && [ "$SCOPE" = "global" ] && ! grep -qs "$START" "$HOME/.claude/CLAUDE.md" "$HOME/.codex/AGENTS.md" "$HOME/.gemini/GEMINI.md" \
      && echo "no supported agent found (~/.claude, ~/.codex, ~/.gemini); try --project"
    [ "$SCOPE" = "global" ] && echo "note: Cursor has no global rules file; use '--project' in each repo or paste the block into Cursor Settings > Rules."
    ;;
  off)
    while IFS='|' read -r path kind dir; do
      [ -n "$path" ] || continue
      if [ "$kind" = "cursor" ]; then
        if has_block "$path"; then
          rm -f "$path"; rmdir "$(dirname "$path")" "$(dirname "$(dirname "$path")")" 2>/dev/null
          echo "off: $path"; changed=1
        fi
        continue
      fi
      if has_block "$path"; then
        strip_block "$path"
        grep -q '[^[:space:]]' "$path" || rm -f "$path"   # drop files that only held our block
        echo "off: $path"; changed=1
      fi
    done <<EOF
$(targets)
EOF
    [ "$changed" -eq 0 ] && echo "already off ($SCOPE)"
    ;;
  status)
    found=0
    for s in global project; do
      SCOPE="$s"
      while IFS='|' read -r path kind dir; do
        [ -n "$path" ] || continue
        if has_block "$path"; then echo "on ($s): $path"; found=1; fi
      done <<EOF
$(targets)
EOF
    done
    [ "$found" -eq 0 ] && echo "off"
    ;;
  *) echo "ERROR: action must be on, off or status" >&2; exit 2 ;;
esac
exit 0
