#!/usr/bin/env bash
# introspect detection engine. Emits a JSON stack summary on stdout (consumed by
# the introspect skill) and a human summary on stderr. Built on five verified
# detection lessons (see SKILL.md):
#   L1 layered precedence — declared files beat content guessing.
#   L2 detect at the declaration layer; READ configs statically, NEVER execute.
#   L3 monorepo → flag workspaces; per-subtree detection avoids polyglot mislabel.
#   L4 separate "what the repo declares" from "what is installed on the machine".
#   L5 detect the DECLARED (meta-)framework; do not infer transitive libraries.
# Dependency-light: bash + python3 (JSON parse only). Fail-soft: unknowns are "".
set -uo pipefail

TARGET="${1:-.}"
cd "$TARGET" 2>/dev/null || { echo '{"error":"target not found"}'; exit 1; }
ROOT="$(pwd)"

log() { printf '%s\n' "$*" >&2; }

# --- L4: what is installed on the machine (declared-vs-installed split) ---
installed() { command -v "$1" >/dev/null 2>&1 && echo "$1"; }
INSTALLED="$(for b in node npm pnpm yarn bun python3 go cargo deno; do installed "$b"; done | paste -sd' ' -)"

languages=""; frameworks=""; test_runner=""; test_cmd=""; build_cmd=""; dev_cmd=""
pkg_manager=""; monorepo="false"; data_layer=""; project_name=""
typecheck_cmd=""; lint_cmd=""

add() { local var="$1" val="$2"; [ -n "$val" ] && eval "$var=\"\${$var:+\$$var,}$val\""; }

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
f=[d.get("name",""), s.get("dev",s.get("start","")) or "-", s.get("build","-"), s.get("test","-"),
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
  case " $deps " in *" pg "*|*" prisma "*|*" drizzle-orm "*) add data_layer "postgres" ;; esac
  case " $deps " in *" redis "*|*" ioredis "*) add data_layer "redis" ;; esac
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
  grep -qsiE 'fastapi'   pyproject.toml requirements.txt 2>/dev/null && add frameworks "fastapi"
  grep -qsiE 'django'    pyproject.toml requirements.txt 2>/dev/null && add frameworks "django"
  grep -qsiE 'flask'     pyproject.toml requirements.txt 2>/dev/null && add frameworks "flask"
  grep -qsiE 'gradio'    pyproject.toml requirements.txt 2>/dev/null && add frameworks "gradio"
  grep -qsiE 'streamlit' pyproject.toml requirements.txt 2>/dev/null && add frameworks "streamlit"
  # Fast checks for the verify loop.
  { [ -z "$typecheck_cmd" ] && grep -qsiE 'mypy|pyright' pyproject.toml requirements.txt 2>/dev/null; } && typecheck_cmd="mypy ."
  if [ -z "$lint_cmd" ]; then
    grep -qsiE 'ruff'   pyproject.toml requirements.txt 2>/dev/null && lint_cmd="ruff check ."
    { [ -z "$lint_cmd" ] && grep -qsiE 'flake8' pyproject.toml requirements.txt 2>/dev/null; } && lint_cmd="flake8"
  fi
  [ -z "$project_name" ] && project_name="$(basename "$ROOT")"
fi

# --- Go / Rust ---
[ -f go.mod ] && { add languages "go"; [ -z "$test_runner" ] && test_runner="go test"; }
[ -f Cargo.toml ] && { add languages "rust"; [ -z "$test_runner" ] && test_runner="cargo test"; }

# --- L3: monorepo topology + per-subtree detection (polyglot-aware) ---
# Always scan subtrees so a polyglot repo (e.g. python root + node subdir) is not
# mislabelled by its root language alone. Excludes the root's own manifests.
members=""
while IFS= read -r m; do
  d="$(dirname "$m")"; add members "${d#./}"
done < <(find . -maxdepth 3 \
          \( -name node_modules -o -name .git -o -name dist -o -name build -o -name .venv \
             -o -name .next -o -name coverage -o -name .turbo -o -name out \) -prune -o \
          \( -name package.json -o -name pyproject.toml -o -name go.mod -o -name Cargo.toml \) -print 2>/dev/null \
          | grep -vE '^\./(package\.json|pyproject\.toml|go\.mod|Cargo\.toml)$' | head -20)
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
