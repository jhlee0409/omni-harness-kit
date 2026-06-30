#!/usr/bin/env bash
# outside-voices.sh — Cross-vendor independent verification.
#
# Sends the same prompt to multiple AI vendor CLIs in parallel, then surfaces
# agreement or disagreement. The platform-neutral core of the cross-vendor
# verification module — works the same on Claude Code and OpenCode.
#
# Usage:
#   outside-voices.sh "prompt text"
#   echo "prompt" | outside-voices.sh
#   outside-voices.sh --vendors codex,gemini "prompt text"
#   outside-voices.sh --mode review --prompt-file prompt.txt
#
# Exit codes (3-state consensus signal):
#   0 = all-green    every vendor: exit 0 AND non-empty output
#   2 = degraded     at least one green, at least one not
#   1 = all-dead     no vendor produced green output
#
# Env overrides:
#   OUTSIDE_VOICES_VENDORS  comma-separated vendor list (codex,gemini,...)
#   OUTSIDE_VOICES_TIMEOUT  per-vendor timeout seconds (default 360)
#   OUTSIDE_VOICES_OUT_DIR  artifact directory (default /tmp/outside-voices.<ts>.<pid>)
#   OUTSIDE_VOICES_OFF=1    disable entirely (script exits 0, prints nothing)
#
# Vendor-specific env:
#   CODEX_MODEL              override codex model
#   GEMINI_MODEL             override gemini model
#   ANTIGRAVITY_MODEL        override antigravity (agy) model

set -euo pipefail

# ── Fail-open kill switch ──────────────────────────────────────────
if [ "${OUTSIDE_VOICES_OFF:-0}" = "1" ]; then
  exit 0
fi

# ── Argument parsing ───────────────────────────────────────────────
VENDORS=""
MODE="review"
PROMPT=""
PROMPT_FILE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --vendors)  VENDORS="$2"; shift 2 ;;
    --mode)     MODE="$2"; shift 2 ;;
    --prompt-file) PROMPT_FILE="$2"; shift 2 ;;
    --help|-h)
      sed -n '2,/^$/p' "$0" | sed 's/^# \?//'
      exit 0 ;;
    *)          PROMPT="$1"; shift ;;
  esac
done

if [ -n "$PROMPT_FILE" ]; then
  PROMPT="$(cat "$PROMPT_FILE")"
elif [ -z "$PROMPT" ]; then
  PROMPT="$(cat 2>/dev/null || true)"
fi

if [ -z "$PROMPT" ]; then
  echo "Usage: $0 [--vendors codex,gemini] [--mode review] \"prompt\"" >&2
  echo "       echo \"prompt\" | $0" >&2
  exit 1
fi

# ── Vendor resolution ──────────────────────────────────────────────
if [ -z "$VENDORS" ]; then
  VENDORS="${OUTSIDE_VOICES_VENDORS:-codex,gemini}"
fi

IFS=',' read -ra VENDOR_LIST <<< "$VENDORS"

if [ "${#VENDOR_LIST[@]}" -eq 0 ]; then
  echo "[outside-voices] No vendors specified." >&2
  exit 1
fi

# ── Vendor command registry ────────────────────────────────────────
# Each vendor is defined by two functions:
#   _vendor_<name>_cmd     prints the command string to stdout
#   _vendor_<name>_label   prints the human-readable label
# To add a vendor, add a case branch here.

_vendor_codex_cmd() {
  local model_args=""
  [ -n "${CODEX_MODEL:-}" ] && model_args="-m $CODEX_MODEL"
  echo "codex exec -s read-only $model_args"
}

_vendor_codex_label() { echo "Codex (OpenAI)"; }

_vendor_gemini_cmd() {
  local model_args=""
  [ -n "${GEMINI_MODEL:-}" ] && model_args="--model $GEMINI_MODEL"
  echo "gemini $model_args"
}

_vendor_gemini_label() { echo "Gemini (Google)"; }

_vendor_antigravity_cmd() {
  local model_args=""
  [ -n "${ANTIGRAVITY_MODEL:-}" ] && model_args="--model $ANTIGRAVITY_MODEL"
  local print_timeout="${OUTSIDE_VOICES_TIMEOUT:-360}s"
  echo "agy --print --print-timeout ${print_timeout} ${model_args}"
}

_vendor_antigravity_label() { echo "Antigravity"; }

_vendor_agy_cmd()        { _vendor_antigravity_cmd; }
_vendor_agy_label()      { _vendor_antigravity_label; }

_vendor_dispatch() {
  local vendor="$1" action="$2"
  local fn="_vendor_${vendor}_${action}"
  if declare -f "$fn" >/dev/null 2>&1; then
    "$fn"
  else
    return 1
  fi
}

# ── Pre-flight: verify all vendor CLIs exist ───────────────────────
MISSING=()
for vendor in "${VENDOR_LIST[@]}"; do
  vendor="${vendor##* }"  # trim whitespace
  vendor="${vendor%% }"
  if ! _vendor_dispatch "$vendor" label >/dev/null 2>&1; then
    echo "[outside-voices] Unknown vendor: '$vendor'" >&2
    MISSING+=("$vendor (unknown)")
    continue
  fi
  # Extract the CLI binary name (first word of the command)
  local_bin="$(_vendor_dispatch "$vendor" cmd | awk '{print $1}')"
  if ! command -v "$local_bin" >/dev/null 2>&1; then
    MISSING+=("$vendor (CLI '$local_bin' not found)")
  fi
done

if [ "${#MISSING[@]}" -gt 0 ]; then
  printf '[outside-voices] Skipping — %s\n' "${MISSING[*]}" >&2
  exit 1
fi

# ── Durable output directory ───────────────────────────────────────
OUT_DIR="${OUTSIDE_VOICES_OUT_DIR:-/tmp/outside-voices.$(date +%Y%m%d-%H%M%S).$$}"
mkdir -p "$OUT_DIR"

RESULT_MD="$OUT_DIR/result.md"
echo "[outside-voices] Durable output: $RESULT_MD" >&2
echo "[outside-voices] Vendors: ${VENDOR_LIST[*]} · Mode: $MODE · Timeout: ${OUTSIDE_VOICES_TIMEOUT:-360}s/vendor" >&2

# ── Common framing (identical to all vendors — blindness preserved) ──
FRAMING='[Response rules]
- Be concise: conclusion first, then evidence.
- Cite quantitative metrics (file:line, diff, benchmark numbers).
- Say "unknown" instead of guessing when you lack information.
- Quote code with file_path:line_number format.

[Task]
'

FULL_PROMPT="${FRAMING}${PROMPT}"

# ── Parallel execution ─────────────────────────────────────────────
MODEL_TIMEOUT="${OUTSIDE_VOICES_TIMEOUT:-360}"

declare -a PIDS=()
declare -a OUT_FILES=()
declare -a ERR_FILES=()
declare -a VENDOR_NAMES=()

for i in "${!VENDOR_LIST[@]}"; do
  vendor="${VENDOR_LIST[$i]##* }"
  vendor="${vendor%% }"
  label="$(_vendor_dispatch "$vendor" label)"
  cmd="$(_vendor_dispatch "$vendor" cmd)"

  out_file="$OUT_DIR/${vendor}.out"
  err_file="$OUT_DIR/${vendor}.err"
  OUT_FILES[$i]="$out_file"
  ERR_FILES[$i]="$err_file"
  VENDOR_NAMES[$i]="$label"

  (
    eval "timeout $MODEL_TIMEOUT $cmd" <<< "$FULL_PROMPT" \
      > "$out_file" 2> "$err_file"
  ) &
  PIDS[$i]=$!
done

# ── Collect exit codes ─────────────────────────────────────────────
GREEN_COUNT=0
TOTAL="${#VENDOR_LIST[@]}"

declare -a EXIT_CODES=()
declare -a GREEN_FLAGS=()

for i in "${!PIDS[@]}"; do
  exit_code=0
  wait "${PIDS[$i]}" || exit_code=$?
  EXIT_CODES[$i]=$exit_code

  is_green=0
  if [ "$exit_code" -eq 0 ] && [ -s "${OUT_FILES[$i]}" ]; then
    is_green=1
    GREEN_COUNT=$((GREEN_COUNT + 1))
  fi
  GREEN_FLAGS[$i]=$is_green
done

# ── 3-state status ─────────────────────────────────────────────────
if [ "$GREEN_COUNT" -eq "$TOTAL" ]; then
  STATUS="all-green"
  STATUS_EXIT=0
elif [ "$GREEN_COUNT" -eq 0 ]; then
  STATUS="all-dead"
  STATUS_EXIT=1
else
  STATUS="degraded"
  STATUS_EXIT=2
fi

# ── Unified output (result.md + stdout) ────────────────────────────
{
  echo "STATUS: ${STATUS} (${GREEN_COUNT}/${TOTAL} green)"
  echo ""

  for i in "${!VENDOR_LIST[@]}"; do
    label="${VENDOR_NAMES[$i]}"
    exit_code="${EXIT_CODES[$i]}"
    green="${GREEN_FLAGS[$i]}"
    out_file="${OUT_FILES[$i]}"
    err_file="${ERR_FILES[$i]}"

    marker="GREEN"
    [ "$green" -eq 0 ] && marker="DEAD"

    echo "================================================================"
    echo "${label}  (exit: ${exit_code}, ${marker})"
    echo "================================================================"
    cat "$out_file"
    if [ "$exit_code" -ne 0 ] || [ ! -s "$out_file" ]; then
      echo ""
      echo "[stderr]"
      cat "$err_file" 2>/dev/null || true
    fi
    echo ""
  done
} | tee "$RESULT_MD"

echo "" >&2
echo "[outside-voices] STATUS=${STATUS} (${GREEN_COUNT}/${TOTAL} green) · exit ${STATUS_EXIT} · ${RESULT_MD}" >&2

exit "$STATUS_EXIT"
