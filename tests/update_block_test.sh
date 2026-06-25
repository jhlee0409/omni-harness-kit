#!/usr/bin/env bash
# Tests for the idempotent marked-block updater (introspect re-run safety).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UB="$ROOT/skills/introspect/update-block.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
ok(){ echo "  PASS: $1"; PASS=$((PASS+1)); }
no(){ echo "  FAIL: $1"; FAIL=$((FAIL+1)); }
S="<!-- hk:start -->"; END="<!-- hk:end -->"

f="$TMP/CLAUDE.md"; printf '# Existing\n\nsome content\n' > "$f"

echo "[1] append when no markers exist"
printf '%s\nblock v1\n%s\n' "$S" "$END" | bash "$UB" "$f" "$S" "$END"
{ grep -q "Existing" "$f" && grep -q "block v1" "$f"; } && ok "appended, original preserved" || no "append failed"

echo "[2] re-run replaces in place (no duplicate block)"
printf '%s\nblock v2\n%s\n' "$S" "$END" | bash "$UB" "$f" "$S" "$END"
n=$(grep -c "hk:start" "$f")
{ [ "$n" -eq 1 ] && grep -q "block v2" "$f" && ! grep -q "block v1" "$f"; } && ok "replaced; exactly one marker" || no "not idempotent (markers=$n)"

echo "[3] same content twice → byte-identical file"
printf '%s\nblock v2\n%s\n' "$S" "$END" | bash "$UB" "$f" "$S" "$END"
before="$(cat "$f")"
printf '%s\nblock v2\n%s\n' "$S" "$END" | bash "$UB" "$f" "$S" "$END"
[ "$before" = "$(cat "$f")" ] && ok "re-applying identical block is a no-op" || no "file changed on identical re-apply"

echo "[4] creates the file when absent"
g="$TMP/new.md"
printf '%s\nfresh\n%s\n' "$S" "$END" | bash "$UB" "$g" "$S" "$END"
grep -q "fresh" "$g" && ok "creates file if missing" || no "did not create file"

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
