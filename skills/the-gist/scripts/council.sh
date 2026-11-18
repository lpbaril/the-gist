#!/usr/bin/env bash
# the-gist council: ask models from other providers to challenge and rank options.
# Usage: council.sh --host <claude|codex|gemini|cursor|opencode|qwen> --brief FILE
#                   [--voices N] [--timeout SEC] [--log-dir DIR] [--dry-run]
# Portable: bash 3.2+ (macOS default), no required deps beyond curl for OpenRouter.
set -u

VERSION="0.1.0"

# ---------- defaults (override in ~/.the-gist/config, a sourced shell file) ----------
THE_GIST_VOICES="${THE_GIST_VOICES:-3}"
THE_GIST_TIMEOUT="${THE_GIST_TIMEOUT:-180}"
THE_GIST_CLI_ORDER="${THE_GIST_CLI_ORDER-codex gemini claude cursor-agent opencode qwen}"
THE_GIST_OPENROUTER_MODELS="${THE_GIST_OPENROUTER_MODELS:-openai/gpt-5 google/gemini-2.5-pro x-ai/grok-4 deepseek/deepseek-chat}"
THE_GIST_LOG_DIR="${THE_GIST_LOG_DIR:-.the-gist/decisions}"
CONFIG_FILE="${THE_GIST_CONFIG:-$HOME/.the-gist/config}"
# shellcheck source=/dev/null
[ -f "$CONFIG_FILE" ] && . "$CONFIG_FILE"

HOST=""
BRIEF=""
DRY_RUN=0
VOICES="$THE_GIST_VOICES"
TIMEOUT="$THE_GIST_TIMEOUT"
LOG_DIR="$THE_GIST_LOG_DIR"

die() { echo "ERROR: $*" >&2; exit 2; }

while [ $# -gt 0 ]; do
  case "$1" in
    --host) HOST="${2:-}"; shift 2 ;;
    --brief) BRIEF="${2:-}"; shift 2 ;;
    --voices) VOICES="${2:-}"; shift 2 ;;
    --timeout) TIMEOUT="${2:-}"; shift 2 ;;
    --log-dir) LOG_DIR="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --version) echo "$VERSION"; exit 0 ;;
    -h|--help) sed -n '2,5p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

case "$VOICES" in ''|*[!0-9]*) die "--voices must be a number" ;; esac
case "$TIMEOUT" in ''|*[!0-9]*) die "--timeout must be a number" ;; esac

# ---------- host detection ----------
if [ -z "$HOST" ]; then
  if [ -n "${CLAUDECODE:-}" ]; then HOST="claude"
  elif [ -n "${GEMINI_CLI:-}" ]; then HOST="gemini"
  else die "--host is required (claude, codex, gemini, cursor, opencode, qwen)"
  fi
fi

provider_of_host() {
  case "$1" in
    claude|claude-code|anthropic) echo "anthropic" ;;
    codex|openai) echo "openai" ;;
    gemini|gemini-cli|google) echo "google" ;;
    cursor|cursor-agent) echo "cursor" ;;
    opencode) echo "opencode" ;;
    qwen) echo "qwen" ;;
    *) echo "$1" ;;
  esac
}

provider_of_cli() {
  case "$1" in
    codex) echo "openai" ;;
    gemini) echo "google" ;;
    claude) echo "anthropic" ;;
    cursor-agent) echo "cursor" ;;
    opencode) echo "opencode" ;;
    qwen) echo "qwen" ;;
    *) echo "$1" ;;
  esac
}

HOST_PROVIDER="$(provider_of_host "$HOST")"

# ---------- brief ----------
if [ -z "$BRIEF" ]; then
  [ -t 0 ] && die "--brief FILE is required (or pipe the brief on stdin)"
  BRIEF_TEXT="$(cat)"
else
  [ -f "$BRIEF" ] || die "brief not found: $BRIEF"
  BRIEF_TEXT="$(cat "$BRIEF")"
fi
[ -n "$BRIEF_TEXT" ] || die "brief is empty"

# Count options: numbered lines after "OPTIONS:" until a blank line or "YOUR CURRENT PICK".
N_OPTIONS="$(printf '%s\n' "$BRIEF_TEXT" | awk '
  /^[[:space:]]*OPTIONS:/ {on=1; next}
  on && /^[[:space:]]*YOUR CURRENT PICK/ {exit}
  on && /^[[:space:]]*$/ && n>0 {exit}
  on && /^[[:space:]]*[0-9]+[.)]/ {n++}
  END {print n+0}')"
if [ "$N_OPTIONS" -lt 2 ]; then
  N_OPTIONS="$(printf '%s\n' "$BRIEF_TEXT" | grep -cE '^[[:space:]]*[0-9]+[.)]')"
fi
[ "$N_OPTIONS" -ge 2 ] || die "brief needs 2+ numbered options under OPTIONS:"

QUESTION="$(printf '%s\n' "$BRIEF_TEXT" | sed -n 's/^[[:space:]]*QUESTION:[[:space:]]*//p' | head -n1)"
[ -n "$QUESTION" ] || QUESTION="decision"

PROMPT="You are a contrarian reviewer on a decision council for a software project.
Attack the current pick first: find its strongest failure mode. Then rank ALL options best to worst.
If an option is missing that clearly beats them all, propose it.
Do not use tools, do not edit files. Answer in exactly these three lines and nothing else:
RANK: <comma-separated option numbers 1-${N_OPTIONS}, best first>
WHY: <one sentence, max 25 words>
NEW: <a better option in max 12 words, or none>

--- BRIEF ---
${BRIEF_TEXT}"

# ---------- voice selection ----------
# Each voice: "kind|id|provider"  kind = cli | openrouter
SELECTED=""
USED_PROVIDERS=" $HOST_PROVIDER "
COUNT=0

add_voice() { SELECTED="${SELECTED}$1
"; USED_PROVIDERS="${USED_PROVIDERS}$2 "; COUNT=$((COUNT + 1)); }

for cli in $THE_GIST_CLI_ORDER; do
  [ "$COUNT" -ge "$VOICES" ] && break
  prov="$(provider_of_cli "$cli")"
  case "$USED_PROVIDERS" in *" $prov "*) continue ;; esac
  command -v "$cli" >/dev/null 2>&1 || continue
  add_voice "cli|$cli|$prov" "$prov"
done

if [ "$COUNT" -lt "$VOICES" ] && [ -n "${OPENROUTER_API_KEY:-}" ]; then
  for model in $THE_GIST_OPENROUTER_MODELS; do
    [ "$COUNT" -ge "$VOICES" ] && break
    prov="${model%%/*}"
    case "$USED_PROVIDERS" in *" $prov "*) continue ;; esac
    add_voice "openrouter|$model|$prov" "$prov"
  done
fi

SIM_NEEDED=$((VOICES - COUNT))

if [ "$DRY_RUN" -eq 1 ]; then
  echo "HOST: $HOST ($HOST_PROVIDER)"
  echo "OPTIONS: $N_OPTIONS"
  printf '%s' "$SELECTED" | while IFS='|' read -r kind id prov; do
    [ -n "$kind" ] && echo "WOULD_RUN: $kind:$id ($prov)"
  done
  [ -z "${OPENROUTER_API_KEY:-}" ] && echo "NOTE: OPENROUTER_API_KEY not set (OpenRouter voices unavailable)"
  [ "$SIM_NEEDED" -gt 0 ] && echo "SIMULATED_NEEDED: $SIM_NEEDED"
  exit 0
fi

# ---------- helpers ----------
TIMEOUT_BIN=""
if command -v timeout >/dev/null 2>&1; then TIMEOUT_BIN="timeout"
elif command -v gtimeout >/dev/null 2>&1; then TIMEOUT_BIN="gtimeout"
fi

run_with_timeout() {
  secs="$1"; shift
  if [ -n "$TIMEOUT_BIN" ]; then
    "$TIMEOUT_BIN" "$secs" "$@"
    return $?
  fi
  "$@" &
  cmd_pid=$!
  ( sleep "$secs"; kill -TERM "$cmd_pid" 2>/dev/null ) &
  watch_pid=$!
  wait "$cmd_pid"; rc=$?
  kill "$watch_pid" 2>/dev/null
  return $rc
}

json_string() {  # stdin -> JSON string literal (with quotes); prefers jq/python3, awk fallback
  if command -v jq >/dev/null 2>&1; then
    jq -Rs .
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import sys,json; sys.stdout.write(json.dumps(sys.stdin.read()))'
  else
    printf '"'
    awk 'BEGIN{ORS=""} {gsub(/\\/,"\\\\"); gsub(/"/,"\\\""); gsub(/\t/,"\\t"); gsub(/\r/,""); if (NR>1) print "\\n"; print}'
    printf '"'
  fi
}

extract_content() {
  if command -v jq >/dev/null 2>&1; then
    jq -r '.choices[0].message.content // .error.message // empty'
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import sys,json
d=json.load(sys.stdin)
c=(d.get("choices") or [{}])[0].get("message",{}).get("content")
print(c if c else (d.get("error") or {}).get("message",""))'
  else
    sed -n 's/.*"content":"\(.*\)".*/\1/p' | sed 's/\\n/\n/g; s/\\"/"/g'
  fi
}

call_openrouter() {
  model="$1"
  body="{\"model\":\"$model\",\"messages\":[{\"role\":\"user\",\"content\":$(printf '%s' "$PROMPT" | json_string)}],\"temperature\":0.4}"
  printf '%s' "$body" | run_with_timeout "$TIMEOUT" curl -sS https://openrouter.ai/api/v1/chat/completions \
    -H "Authorization: Bearer $OPENROUTER_API_KEY" \
    -H "Content-Type: application/json" \
    -H "X-Title: the-gist council" \
    --data-binary @- | extract_content
}

call_cli() {
  case "$1" in
    codex) run_with_timeout "$TIMEOUT" codex exec --skip-git-repo-check -s read-only "$PROMPT" ;;
    gemini) run_with_timeout "$TIMEOUT" gemini -p "$PROMPT" ;;
    claude) run_with_timeout "$TIMEOUT" claude -p "$PROMPT" ;;
    cursor-agent) run_with_timeout "$TIMEOUT" cursor-agent -p "$PROMPT" --output-format text ;;
    opencode) run_with_timeout "$TIMEOUT" opencode run "$PROMPT" ;;
    qwen) run_with_timeout "$TIMEOUT" qwen -p "$PROMPT" ;;
    *) echo "unsupported cli: $1" >&2; return 1 ;;
  esac
}

# ---------- run voices in parallel ----------
TMP="$(mktemp -d 2>/dev/null || mktemp -d -t thegist)"
trap 'rm -rf "$TMP"' EXIT

i=0
printf '%s' "$SELECTED" > "$TMP/voices"
while IFS='|' read -r kind id prov; do
  [ -n "$kind" ] || continue
  i=$((i + 1))
  echo "$kind|$id|$prov" > "$TMP/$i.meta"
  if [ "$kind" = "cli" ]; then
    ( call_cli "$id" < /dev/null > "$TMP/$i.out" 2> "$TMP/$i.err"; echo $? > "$TMP/$i.rc" ) &
  else
    ( call_openrouter "$id" < /dev/null > "$TMP/$i.out" 2> "$TMP/$i.err"; echo $? > "$TMP/$i.rc" ) &
  fi
done < "$TMP/voices"
wait
TOTAL=$i

# ---------- parse + Borda ----------
field() {  # field NAME FILE -> value of first "NAME:" line, case-insensitive, markdown stripped
  awk -v k="$1" '{
    s = $0; sub(/^[ \t*_#>-]+/, "", s)
    if (toupper(substr(s, 1, length(k))) != k) next
    r = substr(s, length(k) + 1)
    if (!match(r, /^[*_]*:/)) next
    r = substr(r, RLENGTH + 1); sub(/^[*_ \t]+/, "", r); sub(/[*_ \t\r]+$/, "", r)
    print r; exit
  }' "$2" 2>/dev/null
}

o=1; while [ "$o" -le "$N_OPTIONS" ]; do eval "PTS_$o=0"; o=$((o + 1)); done
REAL=0
REPORT=""
TOP_VOTES=""

j=1
while [ "$j" -le "$TOTAL" ]; do
  IFS='|' read -r kind id prov < "$TMP/$j.meta"
  label="$id"; [ "$kind" = "openrouter" ] && label="openrouter:$id"
  rc="$(cat "$TMP/$j.rc" 2>/dev/null || echo 1)"
  rank_raw="$(field RANK "$TMP/$j.out")"
  why="$(field WHY "$TMP/$j.out")"
  new="$(field NEW "$TMP/$j.out")"
  # keep only valid, unique option numbers in order
  ranks=""
  for n in $(printf '%s' "$rank_raw" | tr -c '0-9' ' '); do
    [ "$n" -ge 1 ] 2>/dev/null && [ "$n" -le "$N_OPTIONS" ] || continue
    case " $ranks " in *" $n "*) continue ;; esac
    ranks="$ranks $n"
  done
  ranks="${ranks# }"
  if [ -n "$ranks" ]; then
    REAL=$((REAL + 1))
    p=0
    for n in $ranks; do
      eval "PTS_$n=\$((PTS_$n + N_OPTIONS - p))"
      p=$((p + 1))
    done
    top="${ranks%% *}"
    TOP_VOTES="$TOP_VOTES $label=$top"
    line="VOICE $label ($prov) | RANK: $(echo "$ranks" | tr ' ' ',') | WHY: ${why:-?} | NEW: ${new:-none}"
  else
    if [ "$rc" = "124" ] || [ "$rc" = "143" ]; then err="timeout after ${TIMEOUT}s"
    else err="no valid RANK line (exit $rc): $(cat "$TMP/$j.err" "$TMP/$j.out" 2>/dev/null | head -c 160 | tr '\n' ' ')"
    fi
    line="VOICE $label ($prov) | ERROR: $err"
  fi
  REPORT="$REPORT$line
"
  j=$((j + 1))
done

TALLY=""
o=1; while [ "$o" -le "$N_OPTIONS" ]; do eval "TALLY=\"\$TALLY $o=\$PTS_$o\""; o=$((o + 1)); done
TALLY="${TALLY# }"
SIM_NEEDED=$((VOICES - REAL))

# ---------- log ----------
slug="$(printf '%s' "$QUESTION" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '-' | tr -s '-' | sed 's/^-//; s/-$//' | cut -c1-40)"
mkdir -p "$LOG_DIR" 2>/dev/null
LOG="$LOG_DIR/$(date +%Y%m%d-%H%M%S)-${slug:-decision}.md"
n=2; while [ -e "$LOG" ]; do LOG="$LOG_DIR/$(date +%Y%m%d-%H%M%S)-${slug:-decision}-$n.md"; n=$((n + 1)); done
{
  echo "# Council: $QUESTION"
  echo
  echo "- Date: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "- Host: $HOST ($HOST_PROVIDER)"
  echo "- Real voices: $REAL/$VOICES"
  echo "- Borda tally (voices only, host vote not included): $TALLY"
  echo
  echo "## Brief"
  echo
  printf '%s\n' "$BRIEF_TEXT"
  echo
  echo "## Summary"
  echo
  printf '%s' "$REPORT" | sed 's/^/- /'
  echo
  echo "## Raw answers"
  k=1
  while [ "$k" -le "$TOTAL" ]; do
    IFS='|' read -r kind id prov < "$TMP/$k.meta"
    echo
    echo "### $kind:$id ($prov)"
    echo
    echo '```'
    cat "$TMP/$k.out" 2>/dev/null
    echo '```'
    k=$((k + 1))
  done
} > "$LOG" 2>/dev/null || LOG="(log not written: $LOG_DIR not writable)"

# ---------- output ----------
printf '%s' "$REPORT"
echo "TALLY: $TALLY"
echo "REAL_VOICES: $REAL/$VOICES"
[ "$SIM_NEEDED" -gt 0 ] && echo "SIMULATED_NEEDED: $SIM_NEEDED"
echo "LOG: $LOG"
exit 0
