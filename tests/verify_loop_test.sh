#!/usr/bin/env bash
# Isolated tests for the verify-loop Stop hook. Builds throwaway git repos with a
# generated .claude/harness-kit.json and asserts the hook's behavior. No network.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$ROOT/hooks/scripts/verify-loop.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
ok(){ echo "  PASS: $1"; PASS=$((PASS+1)); }
no(){ echo "  FAIL: $1"; FAIL=$((FAIL+1)); }
gitid(){ git -c user.email=t@t.test -c user.name=t "$@"; }

# mkproj <dir> <config-json> <dirty|clean> — config is committed so it isn't itself "dirty"
mkproj(){
  local d="$1"; mkdir -p "$d/.claude"; printf '%s' "$2" > "$d/.claude/harness-kit.json"
  ( cd "$d" && git init -q && gitid add -A && gitid commit -q -m init )
  [ "$3" = dirty ] && echo changed > "$d/work.txt"
}

echo "[1] config + dirty + non-blocking → reminder names the verify command"
d="$TMP/p1"; mkproj "$d" '{"verify_command":"tsc --noEmit && vitest run","blocking":false}' dirty
out="$(CLAUDE_PROJECT_DIR="$d" bash "$HOOK" 2>&1 1>/dev/null)"
echo "$out" | grep -q "tsc --noEmit && vitest run" && ok "reminder contains the verify command" || no "no reminder (got: $out)"

echo "[2] config + dirty + blocking → JSON decision=block"
d="$TMP/p2"; mkproj "$d" '{"verify_command":"pytest","blocking":true}' dirty
out="$(CLAUDE_PROJECT_DIR="$d" bash "$HOOK" 2>/dev/null)"
echo "$out" | python3 -c 'import json,sys;d=json.load(sys.stdin);sys.exit(0 if d.get("decision")=="block" and "pytest" in d.get("reason","") else 1)' \
  && ok "blocking emits decision=block with the command" || no "no block json (got: $out)"

echo "[3] no config → silent no-op, exit 0"
d="$TMP/p3"; mkdir -p "$d"; ( cd "$d" && git init -q )
out="$(CLAUDE_PROJECT_DIR="$d" bash "$HOOK" 2>&1)"; rc=$?
{ [ -z "$out" ] && [ "$rc" = 0 ]; } && ok "silent when no config" || no "expected silence (rc=$rc out=$out)"

echo "[4] config present but clean repo → no nudge"
d="$TMP/p4"; mkproj "$d" '{"verify_command":"pytest","blocking":false}' clean
out="$(CLAUDE_PROJECT_DIR="$d" bash "$HOOK" 2>&1)"
[ -z "$out" ] && ok "no nudge when nothing changed" || no "nudged on a clean repo (got: $out)"

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
