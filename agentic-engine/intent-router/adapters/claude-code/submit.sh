#!/usr/bin/env bash
# Intent router — Claude Code UserPromptSubmit hook.
#
# Embeds the user's message, finds the best-matching skill above threshold,
# and suggests it via additionalContext.
#
# Fail-open: any error → empty additionalContext.
#
# Env:
#   HARNESS_INTENT_OFF=1 — disable
#   HARNESS_SKILLS_DIR  — skills directory (default: .claude/skills)
#   HARNESS_INTENT_THRESHOLD — similarity threshold (default: 0.75)

set -euo pipefail

if [[ "${HARNESS_INTENT_OFF:-}" == "1" ]]; then
  echo '{"additionalContext":""}'
  exit 0
fi

JQ="${JQ:-jq}"
INPUT="$(cat)"
PROMPT="$("$JQ" -r '.prompt // ""' <<< "$INPUT" 2>/dev/null || echo "")"

if [[ -z "$PROMPT" ]]; then
  echo '{"additionalContext":""}'
  exit 0
fi

PROJECT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SKILLS_DIR="${HARNESS_SKILLS_DIR:-$PROJECT_DIR/.claude/skills}"

if [[ ! -d "$SKILLS_DIR" ]]; then
  echo '{"additionalContext":""}'
  exit 0
fi

THRESHOLD="${HARNESS_INTENT_THRESHOLD:-0.75}"

RESULT="$(bun -e "
import { createRouter } from '$PROJECT_DIR/agentic-engine/intent-router/src/index.ts';
const r = createRouter('$PROJECT_DIR', undefined, $THRESHOLD);
await r.index('$SKILLS_DIR');
const match = await r.classify(${JSON.stringify(PROMPT)});
if (!match) { console.log(''); process.exit(0); }
console.log('[Intent match] Skill: ' + match.skill + ' (similarity: ' + match.similarity.toFixed(2) + ')');
" 2>/dev/null || echo "")"

if [[ -z "$RESULT" ]]; then
  echo '{"additionalContext":""}'
else
  "$JQ" -nc --arg ctx "$RESULT" '{"additionalContext":$ctx}'
fi
