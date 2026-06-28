#!/usr/bin/env bash
# introspect detection engine. Emits a JSON stack summary on stdout (consumed by
# the introspect skill) and a human summary on stderr. Built on five verified
# detection lessons (see SKILL.md):
#   L1 layered precedence — declared files beat content guessing.
#   L2 detect at the declaration layer; READ configs statically, NEVER execute.
#   L3 monorepo → flag workspaces + list members; introspect re-runs detect per member.
#   L4 separate "what the repo declares" from "what is installed on the machine".
#   L5 detect the DECLARED (meta-)framework; do not infer transitive libraries.
# Dependency-light: bash + python3 (JSON parse only). Fail-soft: unknowns are "".
set -uo pipefail

TARGET="${1:-.}"
cd "$TARGET" 2>/dev/null || { echo '{"error":"target not found"}'; exit 1; }
# Preflight: the engine parses + emits JSON via python3. Without it, detection would
# emit empty stdout AND exit 0 — a silent fail. Fail loudly instead (like target-not-found).
command -v python3 >/dev/null 2>&1 || { echo '{"error":"python3 not found"}'; exit 1; }
ROOT="$(pwd)"

log() { printf '%s\n' "$*" >&2; }

# --- L4: what is installed on the machine (declared-vs-installed split) ---
installed() { command -v "$1" >/dev/null 2>&1 && echo "$1"; }
INSTALLED="$(for b in node npm pnpm yarn bun python3 go cargo deno; do installed "$b"; done | paste -sd' ' -)"

languages=""; frameworks=""; test_runner=""; test_cmd=""; build_cmd=""; dev_cmd=""
pkg_manager=""; monorepo="false"; data_layer=""; project_name=""
typecheck_cmd=""; lint_cmd=""

# Append $val to the comma-list named by $var. NO eval — $val is attacker-controlled
# (it carries directory names from `find` on an untrusted target repo). printf '%s'
# stores it as inert data; an eval here would run `$(...)` in a crafted dir name (RCE).
add() {
  local var="$1" val="$2"
  [ -n "$val" ] || return 0
  local cur="${!var}"
  printf -v "$var" '%s' "${cur:+$cur,}$val"
}

# --- L1+L2: Node — declaration layer (package.json + lockfile + config files) ---
if [ -f package.json ]; then
  add languages "node"
  # US (\x1f) delimited — a non-whitespace separator so EMPTY middle fields (e.g.
  # no typecheck script) are preserved; tab would collapse (tab is IFS-whitespace).
  IFS=$'\x1f' read -r project_name dev_cmd build_cmd test_cmd typecheck_cmd lint_cmd < <(python3 - <<'PY' 2>/dev/null
import json
try: d=json.load(open("package.json"))
except Exception: d={}
s=d.get("scripts",{}) or {}
f=[d.get("name",""), s.get("dev",s.get("start","")), s.get("build",""), s.get("test",""),
   s.get("typecheck",s.get("type-check","")), s.get("lint","")]
print("\x1f".join((x or "").replace("\x1f"," ") for x in f))
PY
)
  # TypeScript?
  { [ -f tsconfig.json ] || grep -q '"typescript"' package.json 2>/dev/null; } && add languages "typescript"
  # Framework — declared dependency presence (L5: declared, not transitive).
  deps="$(python3 -c 'import json;d=json.load(open("package.json"));print(" ".join({**d.get("dependencies",{}),**d.get("devDependencies",{})}.keys()))' 2>/dev/null || echo "")"
  case " $deps " in
    *" next "*) add frameworks "next.js" ;;
    *" @remix-run/react "*|*" @remix-run/node "*) add frameworks "remix" ;;
    *" astro "*) add frameworks "astro" ;;
    *" react "*) add frameworks "react" ;;
  esac
  case " $deps " in *" nuxt "*) add frameworks "nuxt" ;; *" vue "*) add frameworks "vue" ;; esac
  case " $deps " in *" @sveltejs/kit "*|*" svelte "*) add frameworks "svelte" ;; esac
  case " $deps " in *" @modelcontextprotocol/sdk "*) add frameworks "mcp-server" ;; esac
  case " $deps " in *" @nestjs/core "*) add frameworks "nestjs" ;; esac
  case " $deps " in *" express "*|*" fastify "*|*" koa "*|*" hono "*) add frameworks "node-api" ;; esac
  case " $deps " in *" electron "*) add frameworks "electron" ;; esac
  # Test runner — L2 layered: dep presence, then test script, then config file.
  case " $deps " in
    *" vitest "*) test_runner="vitest" ;;
    *" jest "*) test_runner="jest" ;;
    *" mocha "*) test_runner="mocha" ;;
  esac
  [ -z "$test_runner" ] && { [ -f vitest.config.ts ] && test_runner="vitest"; }
  [ -z "$test_runner" ] && { [ -f jest.config.js ] && test_runner="jest"; }
  # Data layer.
  case " $deps " in *" mongodb "*|*" mongoose "*) add data_layer "mongodb" ;; esac
  case " $deps " in *" pg "*|*" drizzle-orm "*) add data_layer "postgres" ;; esac
  case " $deps " in *" redis "*|*" ioredis "*) add data_layer "redis" ;; esac
  # Prisma: read the datasource provider — do NOT assume postgres (D4 dogfood fix:
  # a MySQL/SQLite repo was getting Postgres-only db-verify queries that error).
  case " $deps " in
    *" prisma "*|*" @prisma/client "*)
      prov="$(grep -hoiE '"(mysql|postgresql|sqlite|mongodb|sqlserver)"' prisma/schema.prisma 2>/dev/null | tr -d '"' | tr '[:upper:]' '[:lower:]' | head -1)"
      case "$prov" in
        mysql)     add data_layer "mysql" ;;
        sqlite)    add data_layer "sqlite" ;;
        mongodb)   add data_layer "mongodb" ;;
        sqlserver) add data_layer "sqlserver" ;;
        *)         add data_layer "postgres" ;;
      esac ;;
  esac
  # Package manager — L1 lockfile precedence.
  if   [ -f pnpm-lock.yaml ]; then pkg_manager="pnpm"
  elif [ -f yarn.lock ];      then pkg_manager="yarn"
  elif [ -f bun.lockb ] || [ -f bun.lock ]; then pkg_manager="bun"
  elif [ -f package-lock.json ]; then pkg_manager="npm"
  fi
  # Fast checks for the verify loop — repo's own script first, else tool presence.
  [ -z "$typecheck_cmd" ] && case " $languages " in *typescript*) typecheck_cmd="tsc --noEmit" ;; esac
  if [ -z "$lint_cmd" ]; then
    case " $deps " in
      *" eslint "*) lint_cmd="eslint ." ;;
      *" @biomejs/biome "*) lint_cmd="biome check" ;;
    esac
  fi
fi

# --- Python ---
if [ -f pyproject.toml ] || [ -f requirements.txt ] || [ -f setup.py ]; then
  add languages "python"
  { [ -z "$test_runner" ] && grep -qsiE 'pytest' pyproject.toml requirements.txt setup.cfg 2>/dev/null; } && test_runner="pytest"
  # A runnable command for the verify loop — the runner name itself (D1 dogfood fix).
  { [ -z "$test_cmd" ] && [ "$test_runner" = "pytest" ]; } && test_cmd="pytest"
  grep -qsiE 'fastapi'   pyproject.toml requirements.txt 2>/dev/null && add frameworks "fastapi"
  grep -qsiE 'django'    pyproject.toml requirements.txt 2>/dev/null && add frameworks "django"
  grep -qsiE 'flask'     pyproject.toml requirements.txt 2>/dev/null && add frameworks "flask"
  grep -qsiE 'gradio'    pyproject.toml requirements.txt 2>/dev/null && add frameworks "gradio"
  grep -qsiE 'streamlit' pyproject.toml requirements.txt 2>/dev/null && add frameworks "streamlit"
  # Data layer — declared DB client in deps (parity with the Node branch; drives db-verify).
  grep -qsiE 'pymongo|motor|mongoengine|beanie' pyproject.toml requirements.txt 2>/dev/null && add data_layer "mongodb"
  grep -qsiE 'psycopg|asyncpg|sqlalchemy|sqlmodel' pyproject.toml requirements.txt 2>/dev/null && add data_layer "postgres"
  grep -qsiE 'redis' pyproject.toml requirements.txt 2>/dev/null && add data_layer "redis"
  # Fast checks for the verify loop.
  { [ -z "$typecheck_cmd" ] && grep -qsiE 'mypy|pyright' pyproject.toml requirements.txt 2>/dev/null; } && typecheck_cmd="mypy ."
  if [ -z "$lint_cmd" ]; then
    grep -qsiE 'ruff'   pyproject.toml requirements.txt 2>/dev/null && lint_cmd="ruff check ."
    { [ -z "$lint_cmd" ] && grep -qsiE 'flake8' pyproject.toml requirements.txt 2>/dev/null; } && lint_cmd="flake8"
  fi
  # Package manager — lockfile precedence (parity with the Node ladder; C3 dogfood fix).
  if [ -z "$pkg_manager" ]; then
    if   [ -f uv.lock ];      then pkg_manager="uv"
    elif [ -f poetry.lock ];  then pkg_manager="poetry"
    elif [ -f Pipfile.lock ]; then pkg_manager="pipenv"
    fi
  fi
  [ -z "$project_name" ] && project_name="$(basename "$ROOT")"
fi

# --- Go / Rust (D1: runnable verify commands; D6: name from the manifest, not the dir) ---
if [ -f go.mod ]; then
  add languages "go"
  [ -z "$test_runner" ]   && test_runner="go test"
  [ -z "$test_cmd" ]      && test_cmd="go test ./..."
  [ -z "$typecheck_cmd" ] && typecheck_cmd="go vet ./..."
  [ -z "$build_cmd" ]     && build_cmd="go build ./..."
  { [ -z "$lint_cmd" ] && { [ -f .golangci.yml ] || [ -f .golangci.yaml ]; }; } && lint_cmd="golangci-lint run"
  # project_name = last segment of the module path (e.g. github.com/spf13/cobra → cobra).
  [ -z "$project_name" ] && project_name="$(awk '/^module /{print $2; exit}' go.mod 2>/dev/null | sed 's#.*/##')"
fi
if [ -f Cargo.toml ]; then
  add languages "rust"
  [ -z "$test_runner" ] && test_runner="cargo test"
  [ -z "$test_cmd" ]    && test_cmd="cargo test"
  [ -z "$build_cmd" ]   && build_cmd="cargo build"
  [ -z "$lint_cmd" ]    && lint_cmd="cargo clippy"
  # project_name from [package].name (a virtual workspace has none → falls back to basename).
  [ -z "$project_name" ] && project_name="$(awk -F'"' '/^\[package\]/{p=1} p&&/^name[[:space:]]*=/{print $2; exit}' Cargo.toml 2>/dev/null)"
fi

# --- Ruby (Gemfile) — promised in §2; implement so the engine matches the doc. ---
if [ -f Gemfile ]; then
  add languages "ruby"
  if grep -qsiE 'rspec' Gemfile Gemfile.lock 2>/dev/null; then
    [ -z "$test_runner" ] && { test_runner="rspec"; test_cmd="bundle exec rspec"; }
  elif grep -qsiE 'minitest|\brake\b' Gemfile Gemfile.lock 2>/dev/null; then
    [ -z "$test_runner" ] && { test_runner="minitest"; test_cmd="rake test"; }
  fi
  grep -qsiE '\brails\b'   Gemfile 2>/dev/null && add frameworks "rails"
  grep -qsiE '\bsinatra\b' Gemfile 2>/dev/null && add frameworks "sinatra"
  [ -f Gemfile.lock ] && [ -z "$pkg_manager" ] && pkg_manager="bundler"
fi

# --- JVM (Maven pom.xml / Gradle build.gradle[.kts]) — promised in §2. ---
if [ -f pom.xml ] || [ -f build.gradle ] || [ -f build.gradle.kts ]; then
  if [ -f build.gradle.kts ] || grep -qsiE 'kotlin' build.gradle pom.xml 2>/dev/null; then
    add languages "kotlin"
  else
    add languages "java"
  fi
  if [ -f pom.xml ]; then
    [ -z "$test_runner" ] && { test_runner="maven"; test_cmd="mvn test"; build_cmd="mvn package"; }
    [ -z "$project_name" ] && project_name="$(grep -oE '<artifactId>[^<]+' pom.xml 2>/dev/null | head -1 | sed 's/<artifactId>//')"
  else
    [ -z "$test_runner" ] && { test_runner="gradle"; test_cmd="./gradlew test"; build_cmd="./gradlew build"; }
  fi
fi

# --- L3: monorepo topology — list member manifests (polyglot-aware) ---
# Scan subtrees so a polyglot repo (e.g. python root + node subdir) is flagged as a
# monorepo and its members listed. This only NAMES members; introspect re-runs this
# detector against each member dir to detect its stack/data-layer (SKILL §3). Excludes
# the root's own manifests.
# D3 (REL-5): the member marker set must equal the root detector's (requirements.txt /
# setup.py / setup.cfg were missing → Python sub-packages were invisible). D7: map each
# manifest to its dir and `sort -u` so a dir with two manifests is not listed twice.
members=""
while IFS= read -r d; do
  add members "$d"
done < <(find . -maxdepth 3 \
          \( -name node_modules -o -name .git -o -name dist -o -name build -o -name .venv \
             -o -name .next -o -name coverage -o -name .turbo -o -name out \) -prune -o \
          \( -name package.json -o -name pyproject.toml -o -name go.mod -o -name Cargo.toml \
             -o -name requirements.txt -o -name setup.py -o -name setup.cfg \
             -o -name Gemfile -o -name pom.xml -o -name build.gradle -o -name build.gradle.kts \) -print 2>/dev/null \
          | grep -vE '^\./(package\.json|pyproject\.toml|go\.mod|Cargo\.toml|requirements\.txt|setup\.py|setup\.cfg|Gemfile|pom\.xml|build\.gradle|build\.gradle\.kts)$' \
          | sed 's#/[^/]*$##; s#^\./##' | sort -u | head -20)
if [ -f pnpm-workspace.yaml ] || [ -f turbo.json ] || [ -f lerna.json ] \
   || grep -qs '"workspaces"' package.json 2>/dev/null || [ -n "$members" ]; then
  monorepo="true"
fi

[ -z "$project_name" ] && project_name="$(basename "$ROOT")"

# --- emit ---
python3 - "$project_name" "$languages" "$frameworks" "$test_runner" "$test_cmd" \
  "$typecheck_cmd" "$lint_cmd" "$build_cmd" "$dev_cmd" "$pkg_manager" "$monorepo" \
  "$data_layer" "$members" "$INSTALLED" "$ROOT" <<'PY'
import json,sys
k=["project_name","languages","frameworks","test_runner","test_cmd","typecheck_cmd","lint_cmd","build_cmd","dev_cmd","package_manager","monorepo","data_layer","members","installed","root"]
v=sys.argv[1:]
lists=("languages","frameworks","data_layer","members")
o={key:(val.split(",") if key in lists and val else ([] if key in lists else (val=="true" if key=="monorepo" else val))) for key,val in zip(k,v)}
o["installed"]=o["installed"].split() if o["installed"] else []
print(json.dumps(o,indent=2))
PY

log "introspect: detected $project_name — langs=[$languages] frameworks=[$frameworks] test=$test_runner monorepo=$monorepo"
