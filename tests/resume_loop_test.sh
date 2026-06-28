#!/usr/bin/env bash
# Pins the resume-loop contract across THREE files that must agree, or a fresh session
# can't resume: new-spec scaffolds context.md → handoff writes into its block → pickup
# reads it. A 1-char drift in any one (a renamed heading or marker) passes all the other
# suites but silently breaks resume — this test catches that. Run: bash tests/resume_loop_test.sh
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NEWSPEC="$ROOT/skills/new-spec/new-spec.sh"
HANDOFF="$ROOT/skills/handoff/SKILL.md"
PICKUP="$ROOT/skills/pickup/SKILL.md"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
ok(){ echo "  PASS: $1"; PASS=$((PASS+1)); }
no(){ echo "  FAIL: $1"; FAIL=$((FAIL+1)); }
HEADING='## 0. Resume here'
M_START='<!-- resume:start'
M_END='<!-- resume:end -->'

echo "[1] new-spec scaffolds a context.md carrying the resume heading + both markers"
ctx="$( cd "$TMP" && CLAUDE_PLUGIN_ROOT="$ROOT" bash "$NEWSPEC" 'resume contract' >/dev/null 2>&1; ls "$TMP/specs/"*resume-contract/context.md 2>/dev/null )"
[ -s "$ctx" ] && ok "context.md scaffolded" || no "new-spec did not produce context.md"
grep -qF "$HEADING" "$ctx" && ok "context.md has the '$HEADING' heading" || no "context.md missing the resume heading"
grep -qF "$M_START" "$ctx" && grep -qF "$M_END" "$ctx" && ok "context.md has both resume markers" || no "context.md missing a resume marker"

echo "[2] handoff WRITES into the same heading + markers (the update-block call)"
grep -qF "$HEADING" "$HANDOFF" && ok "handoff references the '$HEADING' block" || no "handoff drifted from the resume heading"
grep -qF "$M_START" "$HANDOFF" && grep -qF "$M_END" "$HANDOFF" && ok "handoff uses both resume markers" || no "handoff drifted from the markers context.md ships"

echo "[3] pickup READS the same heading + context.md location"
grep -qF "$HEADING" "$PICKUP" && ok "pickup reads the '$HEADING' block" || no "pickup drifted from the resume heading"
grep -qF 'context.md' "$PICKUP" && ok "pickup reads context.md (where new-spec/handoff write)" || no "pickup doesn't reference context.md"

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
