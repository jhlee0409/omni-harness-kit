#!/usr/bin/env bash
# Tests for the stack-conditional critics (db-verify / ui-verify): the templates
# exist with the slots introspect fills, the spine exposes the slot that lists
# them, the introspect store-table covers every store detect.sh can surface, and
# the detection signals that TRIGGER generation are actually emitted. Generation
# itself is LLM-driven (introspect reads + fills the template), so this guards the
# deterministic contract around it. Run: bash tests/conditional_critics_test.sh
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DETECT="$ROOT/skills/introspect/detect.sh"
SKILL="$ROOT/skills/introspect/SKILL.md"
SPINE="$ROOT/templates/CLAUDE.md.spine"
DBV="$ROOT/templates/agents/db-verify.md"
UIV="$ROOT/templates/agents/ui-verify.md"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
ok(){ echo "  PASS: $1"; PASS=$((PASS+1)); }
no(){ echo "  FAIL: $1"; FAIL=$((FAIL+1)); }
has(){ grep -q -F -- "$2" "$1"; }

echo "[1] db-verify template exists with its fill slots"
[ -f "$DBV" ] && ok "db-verify template present" || no "missing $DBV"
for slot in '{{PROJECT_NAME}}' '{{STORE}}' '{{STORE_VERIFY_HOWTO}}'; do
  has "$DBV" "$slot" && ok "db-verify has $slot" || no "db-verify missing $slot"
done
has "$DBV" "does NOT bundle" && ok "db-verify states the kit bundles no client" || no "db-verify missing no-bundle honesty"
grep -qi 'read-only' "$DBV" && ok "db-verify is read-only" || no "db-verify not marked read-only"

echo "[2] ui-verify template exists with its fill slots"
[ -f "$UIV" ] && ok "ui-verify template present" || no "missing $UIV"
for slot in '{{PROJECT_NAME}}' '{{FRAMEWORK}}' '{{DEV_COMMAND}}' '{{E2E_NOTE}}'; do
  has "$UIV" "$slot" && ok "ui-verify has $slot" || no "ui-verify missing $slot"
done
has "$UIV" "does NOT bundle a browser driver" && ok "ui-verify states no bundled driver" || no "ui-verify missing no-bundle honesty"

echo "[3] spine exposes the conditional-critics slot"
has "$SPINE" '{{CONDITIONAL_CRITICS}}' && ok "spine has {{CONDITIONAL_CRITICS}}" || no "spine missing slot"

echo "[4] introspect store-table covers every store detect.sh surfaces"
for store in mongodb postgres redis; do
  grep -q "\b$store\b" "$SKILL" && ok "SKILL store-table mentions $store" || no "SKILL missing $store mapping"
done
has "$SKILL" 'templates/agents/db-verify.md' && ok "SKILL generates from db-verify template" || no "SKILL not wired to db-verify template"
has "$SKILL" 'templates/agents/ui-verify.md' && ok "SKILL generates from ui-verify template" || no "SKILL not wired to ui-verify template"

echo "[5] detection emits the signals that trigger generation"
f="$TMP/mongo-api"; mkdir -p "$f"
cat > "$f/package.json" <<'J'
{"name":"api","dependencies":{"express":"^4","mongodb":"^6"}}
J
: > "$f/package-lock.json"
j="$(bash "$DETECT" "$f" 2>/dev/null)"
printf '%s' "$j" | grep -q 'mongodb' && ok "data_layer mongodb surfaced → db-verify triggers" || no "mongodb not surfaced ($j)"

f="$TMP/next-app"; mkdir -p "$f"
cat > "$f/package.json" <<'J'
{"name":"web","dependencies":{"next":"^15","react":"^19"}}
J
: > "$f/package-lock.json"
j="$(bash "$DETECT" "$f" 2>/dev/null)"
printf '%s' "$j" | grep -q 'next.js' && ok "frontend next.js surfaced → ui-verify triggers" || no "frontend not surfaced ($j)"

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
