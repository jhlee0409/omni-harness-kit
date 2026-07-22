#!/usr/bin/env bash
# Tests for the deterministic repo-map generator (skills/introspect/repomap.sh).
# Throwaway fixtures, no network, bash + python3 only. Run: bash tests/repomap_test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPOMAP="$ROOT/skills/introspect/repomap.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
ok(){ echo "  PASS: $1"; PASS=$((PASS+1)); }
no(){ echo "  FAIL: $1"; FAIL=$((FAIL+1)); }
has(){ grep -qF -- "$2" "$1" && ok "$3" || no "$3 — missing '$2'"; }

echo "[1] node repo → map has name, stack, entry points, layout, tests"
f="$TMP/node"; mkdir -p "$f/src" "$f/tests"
cat > "$f/package.json" <<'J'
{"name":"acme-web","scripts":{"dev":"vite","build":"vite build","test":"vitest run"},"devDependencies":{"vitest":"^1","typescript":"^5"}}
J
: > "$f/tsconfig.json"; : > "$f/package-lock.json"; : > "$f/src/index.ts"; : > "$f/tests/app.test.ts"
out="$f/.claude/repo-map.md"
bash "$REPOMAP" "$f" >/dev/null 2>&1 && ok "repomap exits 0 (node)" || no "repomap failed on node repo"
has "$out" "# Repo map — acme-web" "map titled with project name"
has "$out" "Languages: node, typescript" "stack line present"
has "$out" "## Entry points" "entry points section"
has "$out" 'Test: `vitest run`' "test command surfaced"
has "$out" "## Layout (top level)" "layout section"
has "$out" '`src/`' "src dir listed"
has "$out" "## Where tests live" "test locations section"

echo "[2] custom out-file path is honored"
o2="$TMP/custom-map.md"
bash "$REPOMAP" "$f" "$o2" >/dev/null 2>&1
[ -f "$o2" ] && ok "wrote to explicit out path" || no "explicit out path ignored"

echo "[3] blank repo (no manifest) → graceful map, no crash, no fabricated stack"
b="$TMP/blank"; mkdir -p "$b/lib"
bash "$REPOMAP" "$b" >/dev/null 2>&1 && ok "repomap exits 0 (blank)" || no "repomap crashed on blank repo"
has "$b/.claude/repo-map.md" "No packaged stack detected" "blank repo honestly reports no stack"
if grep -qF '`lib/`' "$b/.claude/repo-map.md"; then ok "layout still mapped on blank repo"; else no "blank repo layout missing"; fi

echo "[4] vendored dirs excluded from layout"
v="$TMP/vend"; mkdir -p "$v/node_modules/pkg" "$v/src"
printf '{"name":"v"}' > "$v/package.json"
bash "$REPOMAP" "$v" >/dev/null 2>&1
if grep -qF '`node_modules/`' "$v/.claude/repo-map.md"; then no "node_modules leaked into layout"; else ok "node_modules excluded from layout"; fi

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
