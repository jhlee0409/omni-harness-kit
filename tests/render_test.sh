#!/usr/bin/env bash
# Tests for the deterministic agent renderer (render.sh). Because the three generated
# agent files have only pure-data / table-lookup slots, render.sh fills them WITHOUT an
# LLM — so the slot-fill defects the dogfood pass found (wrong store idiom, empty
# backticks, dir-name project_name) become deterministically impossible and testable.
# Builds throwaway fixtures, renders, asserts the output. Run: bash tests/render_test.sh
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RENDER="$ROOT/skills/introspect/render.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
ok(){ echo "  PASS: $1"; PASS=$((PASS+1)); }
no(){ echo "  FAIL: $1"; FAIL=$((FAIL+1)); }
# render <slug> ; output dir = $TMP/<slug>-out
render(){ bash "$RENDER" "$TMP/$1" --out "$TMP/$1-out" >/dev/null 2>&1; echo $?; }
body(){ cat "$TMP/$1-out/$2" 2>/dev/null; }

echo "[1] Go (no framework, no DB, no frontend) — clean architect, name from module"
mkdir -p "$TMP/go"; printf 'module github.com/spf13/cobra\ngo 1.21\n' > "$TMP/go/go.mod"
[ "$(render go)" = "0" ] && ok "render exits 0" || no "render failed"
[ -f "$TMP/go-out/go-architect.md" ] && ok "go-architect.md generated" || no "no architect"
body go go-architect.md | grep -q 'architect for `cobra`' && ok "project_name from module path (cobra)" || no "name wrong"
body go go-architect.md | grep -qF 'go test ./...' && ok "runnable test_cmd rendered" || no "no test_cmd"
[ ! -f "$TMP/go-out/db-verify.md" ] && [ ! -f "$TMP/go-out/ui-verify.md" ] && ok "no db-verify/ui-verify (correct gating)" || no "spurious conditional critic"

echo "[2] no empty () / empty backticks / leftover {{slots}} anywhere"
leak="$(grep -rlE '\{\{[A-Z0-9_]+\}\}' "$TMP"/*-out 2>/dev/null || true)"
[ -z "$leak" ] && ok "no leftover slots" || no "leftover slots in: $leak"
art="$(grep -rnE '`` |\(\)\.' "$TMP/go-out" 2>/dev/null || true)"
[ -z "$art" ] && ok "no empty-backtick / empty-paren artifacts in the frameworkless architect" || no "render artifact: $art"

echo "[3] Rust — name from [package].name"
mkdir -p "$TMP/rs"; printf '[package]\nname = "ripgrep"\n' > "$TMP/rs/Cargo.toml"
[ "$(render rs)" = "0" ] && ok "render exits 0" || no "render failed"
body rs rust-architect.md | grep -q 'architect for `ripgrep`' && ok "name from [package].name" || no "name wrong"

echo "[4] Next.js + Prisma(MySQL) — db-verify uses MySQL idiom (not Postgres), ui-verify generated"
mkdir -p "$TMP/fe/prisma"
printf '{"name":"taxonomy","dependencies":{"next":"^15","react":"^19","@prisma/client":"^5","prisma":"^5"},"scripts":{"dev":"next dev"}}' > "$TMP/fe/package.json"
printf 'datasource db { provider = "mysql" }\n' > "$TMP/fe/prisma/schema.prisma"; : > "$TMP/fe/pnpm-lock.yaml"
[ "$(render fe)" = "0" ] && ok "render exits 0" || no "render failed"
body fe db-verify.md | grep -qF 'SUM(<col> IS NOT NULL)' && ok "MySQL idiom (SUM) rendered" || no "wrong store idiom"
body fe db-verify.md | grep -qF 'Postgres-only' && ok "MySQL row warns against FILTER" || no "no FILTER warning"
[ -f "$TMP/fe-out/ui-verify.md" ] && ok "ui-verify generated (frontend present)" || no "no ui-verify"
body fe ui-verify.md | grep -q 'next dev' && ok "real dev command rendered" || no "dev command missing"

echo "[5] no-test-runner repo — fallback, no empty test command"
mkdir -p "$TMP/nr"; printf '{"name":"plain","dependencies":{"react":"^19"},"scripts":{"dev":"vite"}}' > "$TMP/nr/package.json"; : > "$TMP/nr/package-lock.json"
[ "$(render nr)" = "0" ] && ok "render exits 0" || no "render failed"
body nr node-architect.md | grep -q 'none configured' && ok "no-test-runner fallback rendered" || no "no fallback"

echo "[6] Python + motor — db-verify is MongoDB (\$exists), architect mandate is backend"
mkdir -p "$TMP/py"; printf '[project]\nname="svc"\ndependencies=["fastapi","pytest","motor"]\n' > "$TMP/py/pyproject.toml"
[ "$(render py)" = "0" ] && ok "render exits 0" || no "render failed"
body py db-verify.md | grep -qF '$exists' && ok "MongoDB idiom (\$exists)" || no "wrong store"
body py python-architect.md | grep -qF 'Write the failing test first.' && ok "backend test mandate" || no "wrong mandate"

echo "[7] Playwright dep → ui-verify drives via Playwright"
mkdir -p "$TMP/pw"; printf '{"name":"app","dependencies":{"vue":"^3"},"devDependencies":{"@playwright/test":"^1"},"scripts":{"dev":"vite"}}' > "$TMP/pw/package.json"; : > "$TMP/pw/package-lock.json"
[ "$(render pw)" = "0" ] && ok "render exits 0" || no "render failed"
body pw ui-verify.md | grep -q "repo's Playwright" && ok "Playwright driver note" || no "wrong e2e note"

echo "[8] a pre-existing user agent with a {{SLOT}} must NOT trip a false leak abort (PIPE-01)"
mkdir -p "$TMP/usr/.claude/agents"; printf 'module x\ngo 1.21\n' > "$TMP/usr/go.mod"
printf -- '---\nname: my-own\n---\nUse {{MY_PLACEHOLDER}} here.\n' > "$TMP/usr/.claude/agents/my-own.md"
bash "$RENDER" "$TMP/usr" >/dev/null 2>&1 && ok "render exits 0 despite a user agent carrying {{SLOT}}" || no "false leak abort on a user's agent"
grep -qF '{{MY_PLACEHOLDER}}' "$TMP/usr/.claude/agents/my-own.md" && ok "user's own agent left untouched" || no "user agent was modified/removed"

echo "[9] re-run reaps a stale conditional critic when the data layer is dropped (PIPE-02)"
mkdir -p "$TMP/re"; printf '{"name":"app","dependencies":{"mongodb":"^6"}}' > "$TMP/re/package.json"; : > "$TMP/re/package-lock.json"
bash "$RENDER" "$TMP/re" --out "$TMP/re-out" >/dev/null 2>&1
[ -f "$TMP/re-out/db-verify.md" ] && ok "db-verify generated when data layer present" || no "no db-verify on first run"
printf '{"name":"app","dependencies":{}}' > "$TMP/re/package.json"
bash "$RENDER" "$TMP/re" --out "$TMP/re-out" >/dev/null 2>&1
[ ! -f "$TMP/re-out/db-verify.md" ] && ok "stale db-verify reaped on re-run after data layer dropped" || no "orphan db-verify left behind"

echo "[10] blank slate (no manifest) — render generates nothing and exits 0, no crash"
mkdir -p "$TMP/blank"
[ "$(render blank)" = "0" ] && ok "render exits 0 on a stackless repo" || no "render errored on blank repo"
[ -z "$(ls -A "$TMP/blank-out" 2>/dev/null)" ] && ok "no agent files generated for a stackless repo" || no "generated spurious agents on blank repo"

echo "[11] re-run reaps a stale <old-slug>-architect when the stack slug changes (no orphan)"
mkdir -p "$TMP/drift"; printf '{"name":"app","dependencies":{"react":"^19"},"devDependencies":{"typescript":"^5"}}' > "$TMP/drift/package.json"; : > "$TMP/drift/tsconfig.json"; : > "$TMP/drift/package-lock.json"
bash "$RENDER" "$TMP/drift" --out "$TMP/drift-out" >/dev/null 2>&1
[ -f "$TMP/drift-out/typescript-architect.md" ] && ok "typescript-architect generated first run" || no "no ts architect"
# drop typescript → slug flips to node; re-render into the same dir
printf '{"name":"app","dependencies":{"react":"^19"}}' > "$TMP/drift/package.json"; rm -f "$TMP/drift/tsconfig.json"
bash "$RENDER" "$TMP/drift" --out "$TMP/drift-out" >/dev/null 2>&1
[ -f "$TMP/drift-out/node-architect.md" ] && ok "node-architect generated on re-run" || no "no node architect"
[ ! -f "$TMP/drift-out/typescript-architect.md" ] && ok "stale typescript-architect reaped (no orphan)" || no "orphan typescript-architect left behind"

echo "[12] untrusted manifest content is sanitized — no structural injection into the agent"
mkdir -p "$TMP/evilrepo"
python3 -c "import json;open('$TMP/evilrepo/package.json','w').write(json.dumps({'name':'x](http://evil) **h** \`c\`\nevil: y','dependencies':{'react':'^19'}}))"
: > "$TMP/evilrepo/package-lock.json"
bash "$RENDER" "$TMP/evilrepo" --out "$TMP/evil-out" >/dev/null 2>&1
arch="$(ls "$TMP/evil-out/"*-architect.md 2>/dev/null | head -1)"
[ -n "$arch" ] && ok "architect rendered for the evil repo" || no "no architect generated"
# Precise check: extract the untrusted project_name AS EMBEDDED (between backticks on the
# "architect for `…`" line) and assert the payload's structural-injection chars did NOT
# survive INTO it. A whole-file grep is WRONG — the template body legitimately uses
# **bold** and `file:line` backticks, so those are not evidence of injection.
python3 - "$arch" <<'PY'
import sys, re
body = open(sys.argv[1]).read()
m = re.search(r'architect for `([^`\n]*)`', body)
name = m.group(1) if m else None
bad = name is None or any(c in name for c in '][()*<>{}|#')
sys.exit(1 if bad else 0)
PY
[ $? = 0 ] && ok "structural injection chars stripped from the embedded project_name" || no "structural injection chars survived into the agent name"
python3 - "$arch" <<'PY'
import sys,re
fm=open(sys.argv[1]).read().split('---')[1]
keys=[l.split(':',1)[0] for l in fm.splitlines() if re.match(r'^[a-zA-Z_]+:',l)]
sys.exit(0 if all(k in ('name','description','tools','model') for k in keys) else 1)
PY
[ $? = 0 ] && ok "frontmatter stays valid YAML — no injected key, no multi-line breakout" || no "injected YAML key leaked into frontmatter"

echo "[13] multi-store repo — db-verify covers ALL detected stores (not just data_layer[0])"
mkdir -p "$TMP/multi"; printf '{"name":"app","dependencies":{"mongoose":"^8","pg":"^8","ioredis":"^5"}}' > "$TMP/multi/package.json"; : > "$TMP/multi/package-lock.json"
[ "$(render multi)" = "0" ] && ok "render exits 0" || no "render failed"
{ body multi db-verify.md | grep -qF '$exists' && body multi db-verify.md | grep -qF 'information_schema' && body multi db-verify.md | grep -qF 'HEXISTS'; } \
  && ok "all three store idioms (Mongo/Postgres/Redis) rendered" || no "a store idiom is missing"

echo "[14] duplicate store key (mongoose + Prisma mongodb) is deduped — no 'MongoDB + MongoDB'"
mkdir -p "$TMP/dup/prisma"; printf '{"name":"app","dependencies":{"mongoose":"^8","@prisma/client":"^5"}}' > "$TMP/dup/package.json"
printf 'datasource db { provider = "mongodb" }\n' > "$TMP/dup/prisma/schema.prisma"; : > "$TMP/dup/package-lock.json"
[ "$(render dup)" = "0" ] && ok "render exits 0" || no "render failed"
body dup db-verify.md | grep -qF 'MongoDB + MongoDB' && no "store rendered twice (not deduped)" || ok "duplicate store deduped"

echo "[15] --members renders each monorepo member into its own .claude/agents"
m="$TMP/mono"; mkdir -p "$m/apps/web" "$m/services/api"
printf '{"name":"mono","workspaces":["apps/*","services/*"],"dependencies":{}}' > "$m/package.json"; : > "$m/package-lock.json"
printf '{"name":"web","dependencies":{"react":"^19","next":"^15"},"scripts":{"dev":"next dev"}}' > "$m/apps/web/package.json"; : > "$m/apps/web/package-lock.json"
printf '[project]\nname="api"\ndependencies=["fastapi","pytest","motor"]\n' > "$m/services/api/pyproject.toml"
bash "$RENDER" "$m" --members >/dev/null 2>&1
[ -f "$m/.claude/agents/node-architect.md" ] && ok "root architect rendered" || no "no root architect"
[ -f "$m/apps/web/.claude/agents/ui-verify.md" ] && ok "member apps/web got ui-verify (own frontend)" || no "no member ui-verify"
[ -f "$m/services/api/.claude/agents/python-architect.md" ] && ok "member services/api got python-architect (own stack)" || no "no member architect"
grep -qF '$exists' "$m/services/api/.claude/agents/db-verify.md" 2>/dev/null && ok "member db-verify uses its own store idiom (MongoDB)" || no "member db-verify missing/wrong store"

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
