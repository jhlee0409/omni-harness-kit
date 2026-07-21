#!/usr/bin/env bash
# Cross-runtime conformance for the git commit/push classification that gates the
# protected-branch guard. That decision is implemented SEPARATELY per runtime — CC in a
# shell parser (hooks/scripts/protected-branch-guard.sh) and OpenCode in isGitMutation
# (adapters/opencode/src/git.ts) — so they can drift apart. They did: the CC guard was
# hardened while OpenCode kept a bare substring match, caught only by review. This runs
# ONE shared case table against every runtime's real implementation and fails on any
# disagreement. Codex ships no branch guard by design — asserted as a deliberate
# non-participant, not silent drift. Skips where bun is absent (needed for OpenCode).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0; FAIL=0
ok(){ echo "  PASS: $1"; PASS=$((PASS+1)); }
no(){ echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

command -v bun >/dev/null 2>&1 || { echo "SKIP: bun not installed — cross-runtime conformance needs bun for the OpenCode side"; exit 0; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# Shared case table: a real git commit/push INVOCATION (T) vs a look-alike, an
# argument-position mention, or a non-git command (F). One source of truth per runtime.
cmds=(
  "git commit -m x"
  "git push origin main"
  "git -c user.email=a@b.c commit -m y"
  "git -C /tmp/x push"
  "git --no-pager commit -m z"
  "ls && git push"
  "legit commit here"
  "git pushed already"
  "digit commit"
  "git log --grep push"
  "git stash push"
  "git diff HEAD commit.txt"
  "forgit push"
  "echo 'git commit'"
  "ls -la"
)
expect=( T T T T T T F F F F F F F F F )

# OpenCode verdicts: isGitMutation() over the whole table in one bun call.
oc_raw="$(CASES="$(printf '%s\n' "${cmds[@]}")" OC_GIT="$ROOT/adapters/opencode/src/git.ts" bun -e '
const { isGitMutation } = await import(process.env.OC_GIT);
for (const line of (process.env.CASES ?? "").split("\n")) {
  if (line.length === 0) continue;
  console.log(isGitMutation(line) ? "T" : "F");
}
' 2>/dev/null)"
oc=()
while IFS= read -r _v; do oc+=("$_v"); done <<< "$oc_raw"

# CC verdicts: the guard on a protected branch emits an "ask" iff it classifies a
# real commit/push. Build one protected-branch repo and reuse it.
d="$TMP/repo"; mkdir -p "$d/.claude"
( cd "$d" && git init -q && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init && git branch -M main )
cc_verdict(){ # <cmd> -> T/F
  local out
  out="$(printf '{"tool_input":{"command":"%s"}}' "$1" | CLAUDE_PROJECT_DIR="$d" bash "$ROOT/hooks/scripts/protected-branch-guard.sh" 2>/dev/null)"
  case "$out" in *'"permissionDecision":"ask"'*) echo T ;; *) echo F ;; esac
}

echo "[1] CC guard and OpenCode isGitMutation agree with each other and the spec"
mismatch=0
for i in "${!cmds[@]}"; do
  exp="${expect[$i]}"; ocv="${oc[$i]:-?}"; ccv="$(cc_verdict "${cmds[$i]}")"
  if [ "$ocv" != "$exp" ] || [ "$ccv" != "$exp" ]; then
    mismatch=1
    echo "    DRIFT: [${cmds[$i]}] expected=$exp cc=$ccv opencode=$ocv"
  fi
done
[ "$mismatch" = 0 ] && ok "all ${#cmds[@]} cases classify identically across CC + OpenCode" || no "runtime classification drift (see above)"

echo "[2] Codex ships no branch guard (deliberate non-participant, not silent drift)"
if python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));sys.exit(0 if "PreToolUse" not in d.get("hooks",{}) else 1)' "$ROOT/adapters/codex/hooks.json" 2>/dev/null; then
  ok "adapters/codex/hooks.json has no PreToolUse guard (verify-only tracer)"
else
  no "codex hooks.json now declares a PreToolUse guard — add Codex to the conformance table"
fi

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
