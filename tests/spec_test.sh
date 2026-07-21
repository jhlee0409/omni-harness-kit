#!/usr/bin/env bash
# Tests for the new-spec scaffolder.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/skills/new-spec/new-spec.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
ok(){ echo "  PASS: $1"; PASS=$((PASS+1)); }
no(){ echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

echo "[1] scaffolds the triplet"
out="$(cd "$TMP" && CLAUDE_PLUGIN_ROOT="$ROOT" bash "$SCRIPT" "My Cool Feature")"
{ [ -f "$TMP/$out/spec.md" ] && [ -f "$TMP/$out/plan.md" ] && [ -f "$TMP/$out/context.md" ]; } \
  && ok "spec/plan/context created ($out)" || no "missing files ($out)"

echo "[2] slug normalized + name interpolated"
echo "$out" | grep -qE 'specs/[0-9]{8}-my-cool-feature$' && ok "slug normalized" || no "bad slug ($out)"
grep -q "Spec: My Cool Feature" "$TMP/$out/spec.md" && ok "name interpolated" || no "name not filled"

echo "[3] re-run does not clobber an edited file"
echo "EDITED" >> "$TMP/$out/spec.md"
( cd "$TMP" && CLAUDE_PLUGIN_ROOT="$ROOT" bash "$SCRIPT" "My Cool Feature" >/dev/null 2>&1 )
grep -q "EDITED" "$TMP/$out/spec.md" && ok "existing file preserved" || no "clobbered edit"

echo "[4] non-ASCII (Korean) name preserved in slug (not collapsed to fallback)"
out2="$(cd "$TMP" && CLAUDE_PLUGIN_ROOT="$ROOT" bash "$SCRIPT" "라이브 스케줄러")"
echo "$out2" | grep -q '라이브-스케줄러' && ok "Korean slug preserved" || no "Korean collapsed ($out2)"
[ -f "$TMP/$out2/spec.md" ] && ok "spec created for Korean name" || no "no spec for Korean name"

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
