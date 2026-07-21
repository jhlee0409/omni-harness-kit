#!/usr/bin/env bash
# Tests for protected-branch-guard config precedence (env > repo config > default).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$ROOT/hooks/scripts/protected-branch-guard.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
ok(){ echo "  PASS: $1"; PASS=$((PASS+1)); }
no(){ echo "  FAIL: $1"; FAIL=$((FAIL+1)); }
gitid(){ git -c user.email=t@t.test -c user.name=t "$@"; }

mkrepo(){ # <dir> <branch> [config-json]
  local d="$1"; mkdir -p "$d/.claude"
  ( cd "$d" && git init -q && gitid commit -q --allow-empty -m init && gitid branch -M "$2" )
  [ -n "${3:-}" ] && printf '%s' "$3" > "$d/.claude/harness-kit.json"
}
run(){ printf '{"tool_input":{"command":"%s"}}' "$2" | CLAUDE_PROJECT_DIR="$1" bash "$HOOK" 2>/dev/null; }

echo "[1] default protected branch (main) → ask"
d="$TMP/r1"; mkrepo "$d" main
echo "$(run "$d" "git push origin main")" | grep -q '"permissionDecision":"ask"' && ok "main asks by default" || no "no ask"

echo "[2] non-protected branch (feature) → no-op"
d="$TMP/r2"; mkrepo "$d" feature-x
out="$(run "$d" "git commit -m x")"; [ -z "$out" ] && ok "feature branch silent" || no "asked on feature ($out)"

echo "[3] config makes a custom branch protected"
d="$TMP/r3"; mkrepo "$d" release-2 '{"protected_branches":["release-2"]}'
echo "$(run "$d" "git push")" | grep -q '"permissionDecision":"ask"' && ok "config-listed branch asks" || no "config not honored"

echo "[4] config narrows default: main NOT protected when config omits it"
d="$TMP/r4"; mkrepo "$d" main '{"protected_branches":["release"]}'
out="$(run "$d" "git push origin main")"; [ -z "$out" ] && ok "config overrides default" || no "default leaked ($out)"

echo "[5] env override beats config"
d="$TMP/r5"; mkrepo "$d" main '{"protected_branches":["release"]}'
out="$(printf '{"tool_input":{"command":"git push"}}' | HARNESS_PROTECTED_BRANCHES="main" CLAUDE_PROJECT_DIR="$d" bash "$HOOK" 2>/dev/null)"
echo "$out" | grep -q '"permissionDecision":"ask"' && ok "env override wins" || no "env not honored"

echo "[6] non-git command → no-op"
d="$TMP/r6"; mkrepo "$d" main
out="$(run "$d" "ls -la")"; [ -z "$out" ] && ok "non-git command ignored" || no "fired on non-git ($out)"

echo "[7] look-alikes on a protected branch → no-op (subcommand-aware match)"
d="$TMP/r7"; mkrepo "$d" main; lk=0
for c in "legit commit here" "git pushed already" "git log --grep push" "git stash push" "git diff HEAD commit.txt" "echo 'git commit'"; do
  [ -z "$(run "$d" "$c")" ] || { lk=1; echo "    triggered on: $c"; }
done
[ "$lk" = 0 ] && ok "look-alikes do not trigger the guard" || no "a look-alike triggered the guard"

echo "[8] real commit/push forms on a protected branch → ask (incl. git-level flags)"
d="$TMP/r8"; mkrepo "$d" main; rl=0
for c in "git commit -m x" "git push origin main" "git -c user.email=a@b.c commit -m y" "git -C $d push" "git --no-pager commit -m z"; do
  echo "$(run "$d" "$c")" | grep -q '"permissionDecision":"ask"' || { rl=1; echo "    missed: $c"; }
done
[ "$rl" = 0 ] && ok "real commit/push forms all ask" || no "a real invocation was missed"

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
