#!/usr/bin/env bash
# Generation-contract tests — the DETERMINISTIC contract around the (probabilistic)
# introspect generation step. Two silent-breakage classes a pass/fail test CAN own:
#   M2 referential integrity — every agent/skill the spine routes to actually exists,
#      so a rename/delete (this kit's deletion-bias value invites churn) cannot ship a
#      spine that points at a dead agent.
#   M1 slot contract — every {{SLOT}} in the generated templates is documented as
#      fillable in the introspect SKILL, so template/SKILL drift (a slot that would
#      render literally into a user's CLAUDE.md) is caught.
# Pure bash + grep, no deps. Run: bash tests/generation_contract_test.sh
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SPINE="$ROOT/templates/CLAUDE.md.spine"
SKILL="$ROOT/skills/introspect/SKILL.md"
PASS=0; FAIL=0
ok(){ echo "  PASS: $1"; PASS=$((PASS+1)); }
no(){ echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

echo "[1] referential integrity — every critic the spine ## Critics routes to exists"
crit="$(grep -oE '^- `[a-z][a-z-]+`' "$SPINE" | tr -d '`' | sed 's/^- //')"
[ -n "$crit" ] || no "no critic bullets parsed from the spine (parser drift)"
for a in $crit; do
  [ -f "$ROOT/agents/$a.md" ] && ok "critic '$a' → agents/$a.md" || no "spine routes to missing agent '$a'"
done

echo "[2] referential integrity — the tdd-runner agent named in the spine exists"
if grep -q 'tdd-runner' "$SPINE"; then
  [ -f "$ROOT/agents/tdd-runner.md" ] && ok "tdd-runner → agents/tdd-runner.md" || no "spine names tdd-runner but agents/tdd-runner.md missing"
fi

echo "[3] referential integrity — every /harness-kit:<skill> the spine names exists"
for s in $(grep -oE '/harness-kit:[a-z][a-z-]+' "$SPINE" | sed 's#/harness-kit:##' | sort -u); do
  [ -d "$ROOT/skills/$s" ] && ok "skill '/harness-kit:$s' → skills/$s/" || no "spine names /harness-kit:$s but skills/$s/ missing"
done

echo "[4] slot contract — every {{SLOT}} in the generated templates is documented in SKILL"
slots="$(grep -hoE '[{][{][A-Z0-9_]+[}][}]' \
          "$SPINE" \
          "$ROOT/templates/agents/stack-architect.md" \
          "$ROOT/templates/agents/db-verify.md" \
          "$ROOT/templates/agents/ui-verify.md" | sort -u)"
[ -n "$slots" ] || no "no slots parsed from the templates (parser drift)"
for slot in $slots; do
  grep -qF "$slot" "$SKILL" && ok "$slot documented in SKILL" \
    || no "$slot used in a template but NOT documented in SKILL §4 — would render literally"
done

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
