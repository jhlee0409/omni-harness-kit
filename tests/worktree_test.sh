#!/usr/bin/env bash
# Tests for the new-worktree scaffolder.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/skills/worktree/new-worktree.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
ok(){ echo "  PASS: $1"; PASS=$((PASS+1)); }
no(){ echo "  FAIL: $1"; FAIL=$((FAIL+1)); }
gitid(){ git -c user.email=t@t.test -c user.name=t "$@"; }

mkdir -p "$TMP/myrepo"
( cd "$TMP/myrepo" && git init -q && gitid commit -q --allow-empty -m init && gitid branch -M main )

echo "[1] creates ../<repo>-<slug> on a new branch"
dest="$(cd "$TMP/myrepo" && bash "$SCRIPT" "Fix Login Bug" 2>/dev/null)"
{ [ -d "$dest" ] && [ "$(basename "$dest")" = "myrepo-fix-login-bug" ]; } && ok "worktree dir created ($dest)" || no "bad dest ($dest)"
br="$(git -C "$dest" branch --show-current 2>/dev/null)"
[ "$br" = "fix-login-bug" ] && ok "on branch fix-login-bug" || no "wrong branch ($br)"

echo "[2] it is a real linked worktree of the repo"
git -C "$TMP/myrepo" worktree list 2>/dev/null | grep -q "myrepo-fix-login-bug" && ok "registered as a worktree" || no "not in worktree list"

echo "[3] refuses to clobber an existing destination"
( cd "$TMP/myrepo" && bash "$SCRIPT" "Fix Login Bug" >/dev/null 2>&1 ) && no "should have failed on existing dest" || ok "refuses existing destination"

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
