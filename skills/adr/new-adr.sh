#!/usr/bin/env bash
# Scaffold the next ADR: docs/adr/NNNN-<slug>.md
# usage: new-adr.sh <title>   (run from the repo root)
set -euo pipefail
title="${1:?usage: new-adr.sh <title>}"
slug="$(printf '%s' "$title" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-' | sed 's/--*/-/g; s/^-//; s/-$//')"
[ -n "$slug" ] || slug="decision"
root="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
mkdir -p docs/adr
# next number = highest existing NNNN + 1, zero-padded to 4. A glob loop (not ls|grep,
# SC2010) — robust to odd filenames; an empty dir leaves the glob literal, skipped by -e.
last=0
for f in docs/adr/[0-9][0-9][0-9][0-9]-*.md; do
  [ -e "$f" ] || continue
  n="${f##*/}"; n="${n%%-*}"
  [ "$(( 10#$n ))" -gt "$(( 10#$last ))" ] && last="$n"
done
next="$(printf '%04d' "$(( 10#$last + 1 ))")"
out="docs/adr/${next}-${slug}.md"
# Fill via python3 str.replace, NOT sed — a title with '/' breaks sed (`bad flag`) and
# '&' is silently expanded; both are ordinary in titles (CI/CD, Q&A, A/B test).
python3 - "$root/templates/adr.md" "$next" "$title" "$(date +%Y-%m-%d)" > "$out" <<'PY'
import sys
t = open(sys.argv[1]).read()
for k, v in (("{{NUMBER}}", sys.argv[2]), ("{{TITLE}}", sys.argv[3]), ("{{DATE}}", sys.argv[4])):
    t = t.replace(k, v)
sys.stdout.write(t)
PY
echo "$out"
