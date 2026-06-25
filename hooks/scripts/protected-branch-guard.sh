#!/usr/bin/env bash
# PreToolUse(Bash) guard — ask before a `git commit`/`git push` on a protected branch.
# Generic, self-contained, dependency-light (python3 only for JSON parse). Fail-open:
# any error exits 0 so the guard can never block normal work. Bypass: HARNESS_GUARD_OFF=1.
set -uo pipefail
[ "${HARNESS_GUARD_OFF:-0}" = "1" ] && exit 0

input="$(cat)"
cmd="$(printf '%s' "$input" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null)" || exit 0

case "$cmd" in
  *"git commit"*|*"git push"*) ;;
  *) exit 0 ;;
esac

branch="$(git branch --show-current 2>/dev/null)" || exit 0
[ -z "$branch" ] && exit 0

# Protected branches. Override via HARNESS_PROTECTED_BRANCHES="main develop ...".
protected="${HARNESS_PROTECTED_BRANCHES:-main master develop pre-develop release}"
for p in $protected; do
  if [ "$branch" = "$p" ]; then
    reason="You are on protected branch '$branch'. Commit/push here only with intent — prefer a feature branch."
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' "$reason"
    exit 0
  fi
done
exit 0
