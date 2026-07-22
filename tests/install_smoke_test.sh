#!/usr/bin/env bash
# Fresh-install end-to-end smoke. Packages the CURRENT tree exactly as it would be
# installed as a plugin (tracked + untracked-non-ignored files), points
# CLAUDE_PLUGIN_ROOT at that isolated copy, and runs the introspect engine against
# throwaway target repos as a brand-new user would. This catches what unit tests
# CANNOT: path-resolution bugs (a script that works in the dev checkout but breaks
# from an installed location), a skill/agent that ships broken or not at all, and a
# generated spine that routes to a file the install didn't ship (dangling link).
# Deterministic parts only — the LLM-filled spine prose is out of scope by design.
# Run: bash tests/install_smoke_test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
ok(){ echo "  PASS: $1"; PASS=$((PASS+1)); }
no(){ echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

# --- package the current tree as an installed plugin would receive it ---
INSTALLED="$TMP/installed"; mkdir -p "$INSTALLED"
( cd "$ROOT" && { git ls-files; git ls-files --others --exclude-standard; } ) \
  | tar -C "$ROOT" -cf - -T - | tar -C "$INSTALLED" -xf -
export CLAUDE_PLUGIN_ROOT="$INSTALLED"

echo "[1] the install ships every skill the kit advertises (incl. the new ones)"
for s in blast-radius localize assess introspect new-spec; do
  [ -f "$INSTALLED/skills/$s/SKILL.md" ] && ok "skills/$s ships" || no "skills/$s missing from install"
done
[ -f "$INSTALLED/skills/introspect/repomap.sh" ] \
  && ok "repomap.sh ships" || no "repomap.sh missing from install"
echo "[2] node target: render from the INSTALLED tree generates the architect, no slot leak"
t="$TMP/node"; mkdir -p "$t/src"
printf '{"name":"acme","scripts":{"dev":"vite","build":"vite build","test":"vitest run"},"devDependencies":{"vitest":"^1","typescript":"^5"}}' > "$t/package.json"
: > "$t/tsconfig.json"; : > "$t/package-lock.json"; : > "$t/src/index.ts"
bash "$INSTALLED/skills/introspect/render.sh" "$t" >/dev/null 2>&1 \
  && ok "render exits 0 from the installed tree" || no "render failed from install location"
arch="$t/.claude/agents/typescript-architect.md"
[ -f "$arch" ] && ok "typescript-architect generated" || no "architect not generated"
if [ -f "$arch" ]; then
  grep -q '{{' "$arch" && no "unfilled slot leaked into installed-render architect" || ok "no slot leak in generated architect"
fi

echo "[3] repo-map generates from the installed tree with the repo's real commands"
bash "$INSTALLED/skills/introspect/repomap.sh" "$t" >/dev/null 2>&1
[ -f "$t/.claude/repo-map.md" ] && ok "repo-map.md generated" || no "repo-map not generated from install"
grep -qF 'vitest run' "$t/.claude/repo-map.md" 2>/dev/null \
  && ok "repo-map surfaces the repo's real test command" || no "repo-map missing real test command"

echo "[4] shell target: end-to-end shell detection → architect carrying a runnable test loop"
sh="$TMP/sh"; mkdir -p "$sh/tests"; : > "$sh/tests/foo_test.sh"; printf '#!/usr/bin/env bash\n' > "$sh/run.sh"
bash "$INSTALLED/skills/introspect/render.sh" "$sh" >/dev/null 2>&1
sa="$sh/.claude/agents/shell-architect.md"
[ -f "$sa" ] && ok "shell-architect generated from install" || no "no shell-architect from install"
grep -qF 'do bash "$t"; done' "$sa" 2>/dev/null \
  && ok "shell architect carries the runnable test loop" || no "shell architect missing the test loop"

echo "[5] referential integrity IN THE SHIPPED TREE — spine routes resolve to shipped files"
SPINE="$INSTALLED/templates/CLAUDE.md.spine"
for s in $(grep -oE '/harness-kit:[a-z][a-z-]+' "$SPINE" | sed 's#/harness-kit:##' | sort -u); do
  [ -d "$INSTALLED/skills/$s" ] && ok "spine route /harness-kit:$s → shipped skill" \
    || no "spine routes to /harness-kit:$s but skills/$s not shipped"
done
crit="$(grep -oE '^- `[a-z][a-z-]+`' "$SPINE" | tr -d '`' | sed 's/^- //')"
for a in $crit; do
  [ -f "$INSTALLED/agents/$a.md" ] && ok "spine critic $a → shipped agent" \
    || no "spine critic $a but agents/$a.md not shipped"
done
echo "[6] AGENTS.md-canonical wiring works from the installed tree"
ag="$TMP/ag"; mkdir -p "$ag"; printf '# Agent harness — x\n\nrules\n' > "$ag/AGENTS.md"
bash "$INSTALLED/skills/introspect/aliases.sh" "$ag" >/dev/null 2>&1 \
  && ok "aliases.sh runs from install" || no "aliases.sh failed from install"
grep -qx '@AGENTS.md' "$ag/CLAUDE.md" 2>/dev/null \
  && ok "CLAUDE.md imports the canonical AGENTS.md" || no "CLAUDE.md missing @AGENTS.md import"


echo ""
echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
