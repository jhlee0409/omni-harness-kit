#!/usr/bin/env bash
# Create an isolated git worktree for a task: ../<repo>-<slug> on a new branch.
# usage: new-worktree.sh <slug> [base]   (run from the repo root; base default HEAD)
set -euo pipefail
slug="${1:?usage: new-worktree.sh <slug> [base]}"
# Slug via python3 (NOT tr -cd 'a-z0-9-') so non-ASCII slugs (e.g. Korean) survive
# instead of collapsing to empty. Keeps unicode word chars + hyphen (valid git ref).
slug="$(printf '%s' "$slug" | python3 -c 'import sys,re
s=re.sub(r"\s+","-",sys.stdin.read().strip().lower())
s=re.sub(r"[^\w-]","",s,flags=re.U).replace("_","-")
print(re.sub(r"-{2,}","-",s).strip("-"))')"
[ -n "$slug" ] || { echo "empty slug" >&2; exit 1; }
base="${2:-HEAD}"
top="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "not a git repo" >&2; exit 1; }
repo="$(basename "$top")"
dest="$(cd "$top/.." && pwd)/${repo}-${slug}"
[ -e "$dest" ] && { echo "exists: $dest" >&2; exit 1; }
git worktree add "$dest" -b "$slug" "$base" >&2
echo "$dest"
