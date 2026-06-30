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

bun -e "
import { createEvidenceCapture } from '$PROJECT_DIR/agentic-engine/verify-evidence/src/index.ts';
const cap = createEvidenceCapture('$PROJECT_DIR');
const record = await cap.capture(${JSON.stringify($AGENT)}, ${JSON.stringify($OUTPUT)});
if (record) {
  process.stderr.write('[evidence] captured: ' + record.agent + ' → ' + record.claim.slice(0, 80) + '\n');
}
" 2>/dev/null || true

exit 0
