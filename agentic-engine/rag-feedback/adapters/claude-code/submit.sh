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

# Retrieve when there is anything to retrieve FROM: curated feedback memories and/or
# the past-session verification-evidence log (the verify→feedback loop). Stand down
# only when neither exists.
if [[ ! -d "$FEEDBACK_DIR" && ! -f "$PROJECT_DIR/.harness-kit/evidence.jsonl" ]]; then
  echo '{"additionalContext":""}'
  exit 0
fi

# The engine module lives in the PLUGIN install, not the consumer repo — resolve it
# via CLAUDE_PLUGIN_ROOT, never PROJECT_DIR (which only holds the module when running
# inside this repo itself; installed elsewhere it silently no-op'd — the same bug
# fixed for verify-evidence in 761c26e). PROJECT_DIR stays the cache/data location.
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
if [[ -z "$PLUGIN_ROOT" ]]; then
  echo '{"additionalContext":""}'
  exit 0
fi

# Run the retriever. Pass every value through the ENVIRONMENT and keep the bun script
# single-quoted so bash never expands `${...}` / `$` inside JS — interpolating
# `${JSON.stringify(PROMPT)}` into a double-quoted bun -e string is a fatal bash "bad
# substitution" that kills the hook under `set -euo pipefail`. Dynamic import resolves
# the engine path from the env too.
RESULT="$(
  HARNESS_ENGINE="$PLUGIN_ROOT/agentic-engine/rag-feedback/src/index.ts" \
  HARNESS_PROJECT_DIR="$PROJECT_DIR" \
  HARNESS_FEEDBACK_DIR="$FEEDBACK_DIR" \
  HARNESS_PROMPT="$PROMPT" \
  bun -e '
const { createRetriever } = await import(process.env.HARNESS_ENGINE);
const r = createRetriever(process.env.HARNESS_PROJECT_DIR);
await r.index(process.env.HARNESS_FEEDBACK_DIR);
const hits = await r.retrieve(process.env.HARNESS_PROMPT ?? "", 3);
if (hits.length === 0) { console.log(""); process.exit(0); }
const lines = ["[Relevant feedback from past sessions]"];
for (const h of hits) {
  lines.push("• (" + h.similarity.toFixed(2) + ") " + h.id);
  lines.push(h.content.split("\n").slice(0, 10).join("\n"));
  lines.push("");
}
console.log(lines.join("\n"));
' 2>/dev/null || echo "")"

if [[ -z "$RESULT" ]]; then
  echo '{"additionalContext":""}'
else
  "$JQ" -nc --arg ctx "$RESULT" '{"additionalContext":$ctx}'
fi
