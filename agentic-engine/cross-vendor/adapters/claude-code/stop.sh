#!/usr/bin/env bash
# CC adapter — Claude Code Stop hook that triggers cross-vendor verification.
#
# Register in .claude/settings.json:
#   "hooks": {
#     "Stop": [{ "hooks": [{ "type": "command", "command": "bash path/to/cross-vendor/hooks/stop.sh" }] }]
#   }
#
# Reads CC hook JSON from stdin. Extracts the last user prompt, runs
# outside-voices.sh detached (takes minutes), logs the result path.
# Fail-open: any error exits 0 silently (never blocks the session).

set -uo pipefail

ENGINE_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ENGINE_DIR/outside-voices.sh"

# Fail-open kill switch
[ "${OUTSIDE_VOICES_OFF:-0}" = "1" ] && exit 0

# Read hook payload from stdin
INPUT="$(cat)"

# Extract the last user message text (CC sends { "session": { ... }, "stop_hook_active": bool })
PROMPT="$(echo "$INPUT" | jq -r '
  (.session.transcript // []) |
  map(select(.role == "user")) |
  last |
  (.content // .text // "") | tostring
' 2>/dev/null)"

# If jq isn't available or parsing fails, use the raw input
if [ -z "$PROMPT" ] || [ "$PROMPT" = "null" ]; then
  exit 0
fi

# Run detached — don't block the session. Result goes to durable output dir.
nohup bash "$SCRIPT" "$PROMPT" > /dev/null 2>&1 &
echo "[harness-kit] Cross-vendor verification running in background." >&2

exit 0
