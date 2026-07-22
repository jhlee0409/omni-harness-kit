#!/usr/bin/env bash
# Tests for the AGENTS.md → CLAUDE.md import wiring (skills/introspect/aliases.sh).
# Run: bash tests/aliases_test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ALIASES="$ROOT/skills/introspect/aliases.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
ok(){ echo "  PASS: $1"; PASS=$((PASS+1)); }
no(){ echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

echo "[1] no CLAUDE.md → created importing AGENTS.md"
a="$TMP/a"; mkdir -p "$a"; printf '# Agent harness\n\nrules\n' > "$a/AGENTS.md"
bash "$ALIASES" "$a" >/dev/null 2>&1 && ok "aliases exits 0" || no "aliases failed"
[ -f "$a/CLAUDE.md" ] && ok "CLAUDE.md created" || no "CLAUDE.md not created"
grep -qx '@AGENTS.md' "$a/CLAUDE.md" && ok "CLAUDE.md imports @AGENTS.md (plain line, not fenced)" || no "no @AGENTS.md import line"

echo "[2] existing CLAUDE.md with user content → block added, user content preserved"
b="$TMP/b"; mkdir -p "$b"; printf '# Agent harness\n' > "$b/AGENTS.md"
printf '# My notes\n\nkeep me\n' > "$b/CLAUDE.md"
bash "$ALIASES" "$b" >/dev/null 2>&1
grep -qF 'keep me' "$b/CLAUDE.md" && ok "user content preserved" || no "user content clobbered"
grep -qx '@AGENTS.md' "$b/CLAUDE.md" && ok "import block appended" || no "import block missing"

echo "[3] re-run is idempotent (import appears once)"
bash "$ALIASES" "$b" >/dev/null 2>&1
n="$(grep -cx '@AGENTS.md' "$b/CLAUDE.md")"
[ "$n" = "1" ] && ok "import not duplicated on re-run ($n)" || no "import duplicated ($n)"

echo "[4] missing AGENTS.md → fail loud, no dangling import written"
c="$TMP/c"; mkdir -p "$c"
if bash "$ALIASES" "$c" >/dev/null 2>&1; then no "should have failed without AGENTS.md"; else ok "exits nonzero when AGENTS.md absent"; fi
[ -f "$c/CLAUDE.md" ] && no "wrote a dangling CLAUDE.md import" || ok "no dangling CLAUDE.md written"

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
