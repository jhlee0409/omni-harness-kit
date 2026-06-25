#!/usr/bin/env bash
# Self-contained tests for the introspect detection engine. Builds throwaway
# fixtures in a temp dir, runs detect.sh, asserts the JSON output. No network,
# no deps beyond bash + python3. Run: bash tests/detect_test.sh
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DETECT="$ROOT/skills/introspect/detect.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0

# check <json> <python-index-expr> <expected-substring> <name>
check() {
  local got
  got="$(printf '%s' "$1" | python3 -c "import json,sys;d=json.load(sys.stdin);v=d$2;print(v if isinstance(v,str) else json.dumps(v))" 2>/dev/null)"
  if printf '%s' "$got" | grep -q -- "$3"; then
    echo "  PASS: $4"; PASS=$((PASS+1))
  else
    echo "  FAIL: $4 — got '$got', expected ~ '$3'"; FAIL=$((FAIL+1))
  fi
}

echo "[1] node + typescript + vitest"
f="$TMP/node-ts"; mkdir -p "$f"
cat > "$f/package.json" <<'J'
{"name":"acme-lib","scripts":{"dev":"tsc --watch","build":"tsc","test":"vitest run"},"devDependencies":{"vitest":"^1","typescript":"^5"}}
J
: > "$f/tsconfig.json"; : > "$f/package-lock.json"
j="$(bash "$DETECT" "$f" 2>/dev/null)"
check "$j" "['languages']" "typescript" "typescript detected"
check "$j" "['test_runner']" "vitest" "vitest runner"
check "$j" "['test_cmd']" "vitest run" "test_cmd has no space-bleed"
check "$j" "['build_cmd']" "tsc" "build_cmd correct"
check "$j" "['package_manager']" "npm" "npm from lockfile"

echo "[2] python + pytest + fastapi"
f="$TMP/py"; mkdir -p "$f"
cat > "$f/pyproject.toml" <<'T'
[project]
name = "svc"
dependencies = ["fastapi", "pytest"]
T
j="$(bash "$DETECT" "$f" 2>/dev/null)"
check "$j" "['languages']" "python" "python detected"
check "$j" "['frameworks']" "fastapi" "fastapi detected"
check "$j" "['test_runner']" "pytest" "pytest runner"

echo "[3] next.js + postgres, pnpm"
f="$TMP/next-pg"; mkdir -p "$f"
cat > "$f/package.json" <<'J'
{"name":"web","dependencies":{"next":"^15","react":"^19","pg":"^8"}}
J
: > "$f/pnpm-lock.yaml"
j="$(bash "$DETECT" "$f" 2>/dev/null)"
check "$j" "['frameworks']" "next.js" "next.js detected"
check "$j" "['data_layer']" "postgres" "postgres data layer"
check "$j" "['package_manager']" "pnpm" "pnpm from lockfile"

echo "[4] monorepo (no root manifest) + build-dir prune"
f="$TMP/mono"; mkdir -p "$f/apps/web" "$f/apps/web/dist"
: > "$f/apps/web/package.json"
: > "$f/apps/web/dist/package.json"
j="$(bash "$DETECT" "$f" 2>/dev/null)"
check "$j" "['monorepo']" "true" "monorepo flagged"
check "$j" "['members']" "apps/web" "real member found"
got_members="$(printf '%s' "$j" | python3 -c "import json,sys;print(json.dumps(json.load(sys.stdin)['members']))" 2>/dev/null)"
if printf '%s' "$got_members" | grep -q "dist"; then
  echo "  FAIL: dist/ pruned from members — got $got_members"; FAIL=$((FAIL+1))
else
  echo "  PASS: dist/ pruned from members"; PASS=$((PASS+1))
fi

echo "[5] python + gradio (ML app, no web API framework)"
f="$TMP/py-gradio"; mkdir -p "$f"
cat > "$f/pyproject.toml" <<'T'
[project]
name = "ml-app"
[tool.pytest.ini_options]
testpaths = ["tests"]
T
printf 'torch>=2.0\ngradio>=5.0.0\ntransformers\n' > "$f/requirements.txt"
j="$(bash "$DETECT" "$f" 2>/dev/null)"
check "$j" "['languages']" "python" "python detected"
check "$j" "['frameworks']" "gradio" "gradio detected"
check "$j" "['test_runner']" "pytest" "pytest from pyproject"

echo "[6] verify-loop commands (typecheck fallback + lint from script)"
f="$TMP/checks"; mkdir -p "$f"
cat > "$f/package.json" <<'J'
{"name":"c","scripts":{"test":"vitest run","lint":"eslint src"},"devDependencies":{"vitest":"^1","typescript":"^5","eslint":"^9"}}
J
: > "$f/tsconfig.json"
j="$(bash "$DETECT" "$f" 2>/dev/null)"
check "$j" "['typecheck_cmd']" "tsc --noEmit" "typecheck fallback (tsc --noEmit)"
check "$j" "['lint_cmd']" "eslint src" "lint from repo script (not shifted)"
check "$j" "['test_cmd']" "vitest run" "test_cmd unshifted with empty typecheck"

echo "[7] polyglot: python root + node subtree (per-subtree, always-scan)"
f="$TMP/poly"; mkdir -p "$f/frontend"
printf '[project]\ndependencies=["fastapi","pytest"]\n' > "$f/pyproject.toml"
: > "$f/frontend/package.json"
j="$(bash "$DETECT" "$f" 2>/dev/null)"
check "$j" "['languages']" "python" "root python detected"
check "$j" "['monorepo']" "true" "polyglot flagged monorepo"
check "$j" "['members']" "frontend" "node subtree surfaced as member"

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
