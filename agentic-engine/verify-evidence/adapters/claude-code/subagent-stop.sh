#!/usr/bin/env bash
# Verify-evidence capture — Claude Code SubagentStop hook.
#
# Captures verification evidence from critic agent outputs.
# Fail-open: any error → no capture.
#
# Env:
#   HARNESS_EVIDENCE_OFF=1 — disable

set -euo pipefail

if [[ "${HARNESS_EVIDENCE_OFF:-}" == "1" ]]; then
  exit 0
fi

JQ="${JQ:-jq}"
INPUT="$(cat)"
AGENT="$("$JQ" -r '.agent_name // .agent // ""' <<< "$INPUT" 2>/dev/null || echo "")"
OUTPUT="$("$JQ" -r '.output // .result // ""' <<< "$INPUT" 2>/dev/null || echo "")"

if [[ -z "$AGENT" || -z "$OUTPUT" ]]; then
  exit 0
fi

PROJECT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# The engine module lives inside the PLUGIN install, not the consumer repo —
# resolve it via CLAUDE_PLUGIN_ROOT (set by Claude Code for hook invocations),
# never via PROJECT_DIR. A prior version imported from "$PROJECT_DIR/agentic-engine/..."
# which only exists when running inside this repo itself; installed as a plugin
# in any other repo it silently no-op'd (fail-open masked the bug).
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
if [[ -z "$PLUGIN_ROOT" ]]; then
  exit 0
fi

# Pass values via the ENVIRONMENT and keep the bun script single-quoted so bash never
# expands `${...}` / `$` inside JS. Interpolating `${JSON.stringify($AGENT)}` into a
# double-quoted bun -e string is a fatal bash "bad substitution" that kills the hook
# under `set -euo pipefail`. Dynamic import resolves the engine path from the env.
HARNESS_ENGINE="$PLUGIN_ROOT/agentic-engine/verify-evidence/src/index.ts" \
HARNESS_PROJECT_DIR="$PROJECT_DIR" \
HARNESS_AGENT="$AGENT" \
HARNESS_OUTPUT="$OUTPUT" \
bun -e '
const { createEvidenceCapture } = await import(process.env.HARNESS_ENGINE);
const cap = createEvidenceCapture(process.env.HARNESS_PROJECT_DIR);
const record = await cap.capture(process.env.HARNESS_AGENT ?? "", process.env.HARNESS_OUTPUT ?? "");
if (record) {
  process.stderr.write("[evidence] captured: " + record.agent + " → " + record.claim.slice(0, 80) + "\n");
}
' 2>/dev/null || true

exit 0
