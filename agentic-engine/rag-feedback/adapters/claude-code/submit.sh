#!/usr/bin/env bash
# RAG feedback injection — Claude Code UserPromptSubmit hook.
#
# Extracts the user's prompt, runs the retriever, and injects matching
# feedback memories as additionalContext.
#
# Fail-open: any error → empty additionalContext (the session continues).
#
# Config (.claude/harness-kit.json):
#   { "feedback_dir": ".claude/feedback", "embedding_provider": "openai" }
#
# Env:
#   HARNESS_FEEDBACK_DIR — override feedback directory
#   HARNESS_EMBEDDING_PROVIDER — openai | google | ollama
#   HARNESS_RAG_OFF=1 — disable entirely

set -euo pipefail

JQ="${JQ:-jq}"

# Kill switch
if [[ "${HARNESS_RAG_OFF:-}" == "1" ]]; then
  echo '{"additionalContext":""}'
  exit 0
fi

# Read stdin (CC hook payload)
INPUT="$(cat)"
PROMPT="$("$JQ" -r '.prompt // ""' <<< "$INPUT" 2>/dev/null || echo "")"

if [[ -z "$PROMPT" ]]; then
  echo '{"additionalContext":""}'
  exit 0
fi

PROJECT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
FEEDBACK_DIR="${HARNESS_FEEDBACK_DIR:-$PROJECT_DIR/.claude/feedback}"

if [[ ! -d "$FEEDBACK_DIR" ]]; then
  echo '{"additionalContext":""}'
  exit 0
fi

# Run the retriever (Bun one-liner for embedding + cosine similarity)
RESULT="$(bun -e "
import { createRetriever } from '$PROJECT_DIR/agentic-engine/rag-feedback/src/index.ts';
const r = createRetriever('$PROJECT_DIR');
await r.index('$FEEDBACK_DIR');
const hits = await r.retrieve(${JSON.stringify(PROMPT)}, 3);
if (hits.length === 0) { console.log(''); process.exit(0); }
const lines = ['[Relevant feedback from past sessions]'];
for (const h of hits) {
  lines.push('• (' + h.similarity.toFixed(2) + ') ' + h.id);
  lines.push(h.content.split('\n').slice(0, 10).join('\n'));
  lines.push('');
}
console.log(lines.join('\n'));
" 2>/dev/null || echo "")"

if [[ -z "$RESULT" ]]; then
  echo '{"additionalContext":""}'
else
  "$JQ" -nc --arg ctx "$RESULT" '{"additionalContext":$ctx}'
fi
