#!/usr/bin/env bash
# Self-contained tests for the introspect detection engine. Builds throwaway
# fixtures in a temp dir, runs detect.sh, asserts the JSON output. No network,
# no deps beyond bash + python3. Run: bash tests/detect_test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DETECT="$ROOT/skills/introspect/detect.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
ok(){ echo "  PASS: $1"; PASS=$((PASS+1)); }
no(){ echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

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

echo "[2] python + pytest + fastapi + motor (Mongo) — data layer drives db-verify"
f="$TMP/py"; mkdir -p "$f"
cat > "$f/pyproject.toml" <<'T'
[project]
name = "svc"
dependencies = ["fastapi", "pytest", "motor"]
T
j="$(bash "$DETECT" "$f" 2>/dev/null)"
check "$j" "['languages']" "python" "python detected"
check "$j" "['frameworks']" "fastapi" "fastapi detected"
check "$j" "['test_runner']" "pytest" "pytest runner"
check "$j" "['data_layer']" "mongodb" "python Mongo client (motor) → data_layer mongodb"

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

echo "[8] security: a command-substitution in a member dir name must NOT execute (no-eval add)"
f="$TMP/evil"; mkdir -p "$f/m\$(touch $TMP/RCE_MARKER)x"
: > "$f/m\$(touch $TMP/RCE_MARKER)x/package.json"
rm -f "$TMP/RCE_MARKER"
bash "$DETECT" "$f" >/dev/null 2>&1
if [ -e "$TMP/RCE_MARKER" ]; then
  echo "  FAIL: RCE — detect.sh executed a dir-name command substitution"; FAIL=$((FAIL+1))
else
  echo "  PASS: no RCE — crafted member dir name treated as inert data"; PASS=$((PASS+1))
fi

echo "[9] Go (dogfood D1/D6): runnable verify cmds + name from module path, not dir basename"
f="$TMP/go"; mkdir -p "$f"
printf 'module github.com/spf13/cobra\n\ngo 1.21\n' > "$f/go.mod"
j="$(bash "$DETECT" "$f" 2>/dev/null)"
check "$j" "['project_name']" "cobra" "Go name from module path (not dir 'go')"
check "$j" "['test_cmd']" "go test ./..." "Go test_cmd runnable"
check "$j" "['typecheck_cmd']" "go vet" "Go typecheck filled"
check "$j" "['build_cmd']" "go build ./..." "Go build_cmd filled"

echo "[10] Rust (dogfood D1/D6): cargo verify cmds + name from [package].name"
f="$TMP/rs"; mkdir -p "$f"
printf '[package]\nname = "ripgrep"\nversion = "1.0.0"\n' > "$f/Cargo.toml"
j="$(bash "$DETECT" "$f" 2>/dev/null)"
check "$j" "['project_name']" "ripgrep" "Rust name from [package].name (not dir 'rs')"
check "$j" "['test_cmd']" "cargo test" "Rust test_cmd runnable"
check "$j" "['lint_cmd']" "cargo clippy" "Rust lint_cmd filled"

echo "[11] Prisma datasource provider (dogfood D4): MySQL must NOT map to postgres"
f="$TMP/pm"; mkdir -p "$f/prisma"
printf '{"name":"app","dependencies":{"@prisma/client":"^5","prisma":"^5"}}' > "$f/package.json"
printf 'datasource db {\n  provider = "mysql"\n}\ngenerator client {\n  provider = "prisma-client-js"\n}\n' > "$f/prisma/schema.prisma"
: > "$f/package-lock.json"
j="$(bash "$DETECT" "$f" 2>/dev/null)"
check "$j" "['data_layer']" "mysql" "Prisma mysql provider → mysql (not postgres; generator ignored)"

echo "[12] monorepo members (dogfood D3 REL-5 + D7 dedup)"
f="$TMP/mono"; mkdir -p "$f/svc" "$f/worker"
printf '{"name":"root"}' > "$f/package.json"
printf '{"name":"svc"}' > "$f/svc/package.json"
printf '[project]\nname="svc"\n' > "$f/svc/pyproject.toml"
printf 'flask\n' > "$f/worker/requirements.txt"
j="$(bash "$DETECT" "$f" 2>/dev/null)"
check "$j" "['members']" "worker" "requirements.txt-only sub-package surfaced as member (REL-5)"
dupcount="$(printf '%s' "$j" | python3 -c "import json,sys;m=json.load(sys.stdin)['members'];print(m.count('svc'))")"
[ "$dupcount" = "1" ] && { echo "  PASS: dir with 2 manifests listed once (D7 dedup)"; PASS=$((PASS+1)); } || { echo "  FAIL: svc listed $dupcount times (dup-member bug)"; FAIL=$((FAIL+1)); }

echo "[13] Ruby (Gemfile) — promised in SKILL §2, now implemented"
f="$TMP/rb"; mkdir -p "$f"; printf 'source "x"\ngem "rails"\ngem "rspec"\n' > "$f/Gemfile"; : > "$f/Gemfile.lock"
j="$(bash "$DETECT" "$f" 2>/dev/null)"
check "$j" "['languages']" "ruby" "ruby detected"
check "$j" "['frameworks']" "rails" "rails framework"
check "$j" "['test_cmd']" "bundle exec rspec" "rspec test_cmd"
check "$j" "['package_manager']" "bundler" "bundler from Gemfile.lock"

echo "[14] JVM (Maven pom.xml) — promised in SKILL §2, now implemented"
f="$TMP/jv"; mkdir -p "$f"; printf '<project><artifactId>myapp</artifactId></project>\n' > "$f/pom.xml"
j="$(bash "$DETECT" "$f" 2>/dev/null)"
check "$j" "['languages']" "java" "java detected"
check "$j" "['test_cmd']" "mvn test" "maven test_cmd"
check "$j" "['project_name']" "myapp" "name from pom.xml artifactId"

echo "[15] blank slate (no manifest) — graceful empty, valid JSON, no crash"
f="$TMP/blank"; mkdir -p "$f"
j="$(bash "$DETECT" "$f" 2>/dev/null)"
printf '%s' "$j" | python3 -c "import json,sys;d=json.load(sys.stdin);sys.exit(0 if d['languages']==[] and d['frameworks']==[] and d['test_runner']=='' else 1)" \
  && ok "blank repo → all-empty detection, valid JSON" || no "blank repo broke detection"

echo "[16] shell (fallback) — bash tooling repo with a *_test.sh suite, no packaged manifest"
f="$TMP/sh"; mkdir -p "$f/tests"
: > "$f/tests/foo_test.sh"
printf '#!/usr/bin/env bash\necho hi\n' > "$f/run.sh"
j="$(bash "$DETECT" "$f" 2>/dev/null)"
check "$j" "['languages']" "shell" "shell detected as fallback stack"
check "$j" "['test_runner']" "shell" "shell test_runner"
check "$j" "['test_cmd']" 'do bash "$t"; done' "shell test_cmd is a runnable loop"

echo "[17] shell must NOT override a real stack (node repo that also has tests/*_test.sh)"
f="$TMP/nodeplussh"; mkdir -p "$f/tests"
printf '{"name":"n","scripts":{"test":"vitest run"},"devDependencies":{"vitest":"^1"}}' > "$f/package.json"
: > "$f/tests/foo_test.sh"
j="$(bash "$DETECT" "$f" 2>/dev/null)"
check "$j" "['languages']" "node" "node still detected"
printf '%s' "$j" | python3 -c "import json,sys;sys.exit(0 if 'shell' not in json.load(sys.stdin)['languages'] else 1)" \
  && ok "shell fallback suppressed when a real stack exists" || no "shell wrongly added over node"

echo "[18] Cargo [workspace] (D5): members glob included, exclude honored"
f="$TMP/cw"; mkdir -p "$f/crates/a" "$f/crates/b" "$f/vendored"
cat > "$f/Cargo.toml" <<'T'
[workspace]
members = ["crates/*"]
exclude = ["vendored"]
T
: > "$f/crates/a/Cargo.toml"; : > "$f/crates/b/Cargo.toml"; : > "$f/vendored/Cargo.toml"
j="$(bash "$DETECT" "$f" 2>/dev/null)"
check "$j" "['members']" "crates/a" "workspace member crates/a listed"
check "$j" "['members']" "crates/b" "workspace member crates/b listed"
printf '%s' "$j" | python3 -c "import json,sys;sys.exit(0 if 'vendored' not in json.load(sys.stdin)['members'] else 1)" \
  && ok "excluded crate 'vendored' dropped from members (D5)" || no "excluded crate leaked into members"

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
