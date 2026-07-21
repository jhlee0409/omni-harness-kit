#!/usr/bin/env bash
# Integration tests for the agentic-engine Claude Code hook ADAPTERS (the shell
# scripts), which the bun unit suites do not cover — they test src/ only. This runs
# the real submit.sh / subagent-stop.sh end-to-end against the real engine with the
# deterministic offline `local` embedding provider, so a real match/capture is
# asserted without a network model or API key. Skips cleanly where bun is absent.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0; FAIL=0
ok(){ echo "  PASS: $1"; PASS=$((PASS+1)); }
no(){ echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

command -v bun >/dev/null 2>&1 || { echo "SKIP: bun not installed — adapter integration tests need bun"; exit 0; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
consumer="$TMP/consumer"
mkdir -p "$consumer/.claude/skills/live-scheduler" "$consumer/.claude/feedback"
( cd "$consumer" && git init -q )
printf -- '---\nname: live-scheduler\ndescription: manage the live broadcast schedule and rundown\n---\nbody\n' \
  > "$consumer/.claude/skills/live-scheduler/SKILL.md"
printf 'Lesson: always verify the live broadcast schedule against the real store before shipping.\n' \
  > "$consumer/.claude/feedback/live.md"

INTENT="$ROOT/agentic-engine/intent-router/adapters/claude-code/submit.sh"
RAG="$ROOT/agentic-engine/rag-feedback/adapters/claude-code/submit.sh"
EVID="$ROOT/agentic-engine/verify-evidence/adapters/claude-code/subagent-stop.sh"
run_adapter(){ # <hook> <stdin-json> [extra-env...]
  local hook="$1" payload="$2"; shift 2
  ( cd "$consumer" && printf '%s' "$payload" \
      | env CLAUDE_PLUGIN_ROOT="$ROOT" HARNESS_EMBEDDING_PROVIDER=local "$@" bash "$hook" 2>/dev/null )
}

echo "[1] intent-router adapter emits a real match with the local provider"
out="$(run_adapter "$INTENT" '{"prompt":"manage the live broadcast schedule and rundown"}' HARNESS_INTENT_THRESHOLD=0.1)"
printf '%s' "$out" | python3 -c 'import sys,json;json.loads(sys.stdin.read())' 2>/dev/null && ok "valid JSON" || no "invalid JSON ($out)"
printf '%s' "$out" | grep -q 'Intent match' && printf '%s' "$out" | grep -q 'live-scheduler' \
  && ok "matched skill surfaced in additionalContext" || no "no intent match ($out)"

echo "[2] rag-feedback adapter retrieves the feedback memory"
out="$(run_adapter "$RAG" '{"prompt":"how do I verify the live schedule"}')"
printf '%s' "$out" | python3 -c 'import sys,json;json.loads(sys.stdin.read())' 2>/dev/null && ok "valid JSON" || no "invalid JSON ($out)"
printf '%s' "$out" | grep -q 'Relevant feedback' && ok "feedback surfaced in additionalContext" || no "no feedback retrieved ($out)"

echo "[3] verify-evidence adapter captures a recognized critic's claim to the JSONL log"
run_adapter "$EVID" '{"agent_name":"claim-checker","output":"VERIFIED: counts match the real store"}' >/dev/null
log="$consumer/.harness-kit/evidence.jsonl"
[ -f "$log" ] && grep -q 'claim-checker' "$log" && ok "evidence captured to .harness-kit/evidence.jsonl" || no "no evidence line written"

echo "[4] adapters stand down cleanly (valid empty JSON) when CLAUDE_PLUGIN_ROOT is unset"
out="$(cd "$consumer" && printf '{"prompt":"anything"}' | HARNESS_EMBEDDING_PROVIDER=local bash "$INTENT" 2>/dev/null)"
[ "$out" = '{"additionalContext":""}' ] && ok "stands down without PLUGIN_ROOT" || no "bad stand-down ($out)"

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
