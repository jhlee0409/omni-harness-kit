#!/usr/bin/env bash
# Scaffold a spec triplet: specs/YYYYMMDD-<slug>/{spec,plan,context}.md
# usage: new-spec.sh <name>   (run from the repo root)
set -euo pipefail
name="${1:?usage: new-spec.sh <name>}"
# Slug via python3 (NOT tr -cd 'a-z0-9-') so non-ASCII names (e.g. Korean) survive
# instead of collapsing to the "spec" fallback. Keeps unicode word chars + hyphen.
slug="$(printf '%s' "$name" | python3 -c 'import sys,re
s=re.sub(r"\s+","-",sys.stdin.read().strip().lower())
s=re.sub(r"[^\w-]","",s,flags=re.U).replace("_","-")
print(re.sub(r"-{2,}","-",s).strip("-"))')"
[ -n "$slug" ] || slug="spec"
root="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
dir="specs/$(date +%Y%m%d)-${slug}"
mkdir -p "$dir"
today="$(date +%Y-%m-%d)"
for f in spec plan context; do
  if [ -f "$dir/$f.md" ]; then echo "exists (skipped): $dir/$f.md" >&2; continue; fi
  # python3 str.replace, NOT sed — a name with '/' or '&' would crash/corrupt sed.
  python3 - "$root/templates/spec/$f.md" "$name" "$today" > "$dir/$f.md" <<'PY'
import sys
t = open(sys.argv[1]).read()
t = t.replace("{{NAME}}", sys.argv[2]).replace("{{DATE}}", sys.argv[3])
sys.stdout.write(t)
PY
done
echo "$dir"
