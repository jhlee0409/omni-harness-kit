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

# The engine module lives in the PLUGIN install, not the consumer repo — resolve it
# via CLAUDE_PLUGIN_ROOT, never PROJECT_DIR (which only holds the module when running
# inside this repo itself; installed elsewhere it silently no-op'd — the same bug
# fixed for verify-evidence in 761c26e). PROJECT_DIR stays the cache/data location.
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
if [[ -z "$PLUGIN_ROOT" ]]; then
  echo '{"additionalContext":""}'
  exit 0
fi

THRESHOLD="${HARNESS_INTENT_THRESHOLD:-0.75}"

# Pass values via the ENVIRONMENT and keep the bun script single-quoted so bash never
# expands `${...}` / `$` inside JS. Interpolating `${JSON.stringify(PROMPT)}` into a
# double-quoted bun -e string is a fatal bash "bad substitution" that kills the hook
# under `set -euo pipefail`. Dynamic import resolves the engine path from the env.
RESULT="$(
  HARNESS_ENGINE="$PLUGIN_ROOT/agentic-engine/intent-router/src/index.ts" \
  HARNESS_PROJECT_DIR="$PROJECT_DIR" \
  HARNESS_SKILLS_DIR="$SKILLS_DIR" \
  HARNESS_THRESHOLD="$THRESHOLD" \
  HARNESS_PROMPT="$PROMPT" \
  bun -e '
const { createRouter } = await import(process.env.HARNESS_ENGINE);
const r = createRouter(process.env.HARNESS_PROJECT_DIR, undefined, Number(process.env.HARNESS_THRESHOLD));
await r.index(process.env.HARNESS_SKILLS_DIR);
const match = await r.classify(process.env.HARNESS_PROMPT ?? "");
if (!match) { console.log(""); process.exit(0); }
console.log("[Intent match] Skill: " + match.skill + " (similarity: " + match.similarity.toFixed(2) + ")");
' 2>/dev/null || echo "")"

if [[ -z "$RESULT" ]]; then
  echo '{"additionalContext":""}'
else
  "$JQ" -nc --arg ctx "$RESULT" '{"additionalContext":$ctx}'
fi
