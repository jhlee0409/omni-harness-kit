#!/usr/bin/env bash
# Read-only maintainability audit engine. Emits cheap, DETERMINISTIC structural
# signals (not model taste) as JSON on stdout, for the `assess` skill to render as
# a findings table. Signals chosen for evidence of predicting maintenance pain:
#   - size outliers (large files are harder to change safely)
#   - churn (git history; frequently-rewritten files) — a known rework proxy
#   - hotspots = size x churn — the strongest practical predictor in the literature
#   - test discoverability (is there a runnable verify command + any tests?)
#   - lint/static debt count (only if the stack's linter is already installed)
# NOT a stored metric / grade / dashboard: this is a one-shot, on-demand snapshot.
# No absolute "quality score" — ranked hotspots + a baseline the caller may diff.
# Dependency-light: bash + python3 (+ optional git / the stack's own linter).
# Usage: assess.sh <target-dir>
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
DETECT="$HERE/../introspect/detect.sh"
TARGET="${1:?usage: assess.sh <target-dir>}"

command -v python3 >/dev/null 2>&1 || { echo '{"error":"python3 not found"}'; exit 1; }
[ -d "$TARGET" ] || { echo '{"error":"target not found"}'; exit 1; }

json_file="$(mktemp)"
trap 'rm -f "$json_file"' EXIT
bash "$DETECT" "$TARGET" 2>/dev/null > "$json_file"

# Churn: file -> commit count over the recent window, if this is a git repo.
# Read into python via a temp file (US-delimited "count\tpath" lines).
churn_file="$(mktemp)"
trap 'rm -f "$json_file" "$churn_file"' EXIT
if git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1; then
  git -C "$TARGET" log --since="90 days ago" --name-only --pretty=format: 2>/dev/null \
    | grep -v '^$' | sort | uniq -c | sort -rn > "$churn_file" || true
fi

# Optional lint debt: run the stack's linter ONLY if its binary is already present
# (never install). Count of findings; degrade to "tool not installed".
lint_tool=""; lint_count="-1"
langs="$(python3 -c 'import json,sys;print(" ".join(json.load(open(sys.argv[1])).get("languages",[])))' "$json_file" 2>/dev/null || echo "")"
run_lint() { ( cd "$TARGET" && eval "$1" ) 2>/dev/null | grep -cE "$2" || true; }
case " $langs " in
  *" shell "*)  command -v shellcheck >/dev/null 2>&1 && { lint_tool="shellcheck"; lint_count="$(run_lint 'find . -name "*.sh" -not -path "*/node_modules/*" | xargs -r shellcheck -S warning -f gcc' ':[0-9]+:[0-9]+:')"; } ;;
  *" go "*)     command -v go >/dev/null 2>&1 && { lint_tool="go vet"; lint_count="$(run_lint 'go vet ./...' '.')"; } ;;
  *" rust "*)   command -v cargo >/dev/null 2>&1 && { lint_tool="cargo clippy"; lint_count="$(run_lint 'cargo clippy --message-format short' 'warning|error')"; } ;;
  *" python "*) command -v ruff >/dev/null 2>&1 && { lint_tool="ruff"; lint_count="$(run_lint 'ruff check .' ':[0-9]+:')"; } ;;
esac

python3 - "$TARGET" "$json_file" "$churn_file" "$lint_tool" "$lint_count" <<'PY'
import json, os, sys, subprocess

target, json_file, churn_file, lint_tool, lint_count = sys.argv[1:6]
d = json.load(open(json_file))

SRC_EXT = {".py",".js",".jsx",".ts",".tsx",".go",".rs",".rb",".java",".kt",".c",
           ".h",".cc",".cpp",".hpp",".cs",".php",".swift",".scala",".sh",".bash",
           ".lua",".vue",".svelte"}
VENDOR = {"node_modules",".git","dist","build",".venv",".next","coverage",".turbo",
          "out","target","__pycache__","vendor"}
BIG = 400  # a file over this many lines is a size-outlier candidate

# Tracked source files (prefer git; fallback walk).
files = []
try:
    out = subprocess.run(["git","-C",target,"ls-files"], capture_output=True,
                         text=True, timeout=20)
    if out.returncode == 0 and out.stdout.strip():
        files = [f for f in out.stdout.splitlines()
                 if os.path.splitext(f)[1] in SRC_EXT]
except Exception:
    pass
if not files:
    for root, ds, fs in os.walk(target):
        ds[:] = [x for x in ds if x not in VENDOR and not x.startswith(".")]
        for f in fs:
            if os.path.splitext(f)[1] in SRC_EXT:
                files.append(os.path.relpath(os.path.join(root, f), target))

def loc(rel):
    try:
        with open(os.path.join(target, rel), "rb") as fh:
            return sum(1 for _ in fh)
    except OSError:
        return 0

sizes = {f: loc(f) for f in files}
outliers = sorted(((n, f) for f, n in sizes.items() if n >= BIG), reverse=True)[:10]

# Churn map from git.
churn = {}
try:
    for line in open(churn_file):
        line = line.strip()
        if not line:
            continue
        c, _, path = line.partition(" ")
        path = path.strip()
        if path:
            churn[path] = int(c)
except OSError:
    pass

# Hotspots = files ranked by size x churn (both signals present). Strongest predictor.
hotspots = []
for f in files:
    ch = churn.get(f, 0)
    if ch and sizes.get(f, 0):
        hotspots.append({"file": f, "loc": sizes[f], "churn_90d": ch,
                         "score": sizes[f] * ch})
hotspots.sort(key=lambda x: x["score"], reverse=True)
hotspots = hotspots[:10]

# Test discoverability.
test_cmd = d.get("test_cmd", "") or ""
test_files = [f for f in files
              if any(k in os.path.basename(f).lower() for k in ("test", "spec"))
              or "/test" in ("/" + f).lower()]
result = {
    "project": d.get("project_name", ""),
    "stack": d.get("languages", []),
    "totals": {"source_files": len(files),
               "source_loc": sum(sizes.values())},
    "signals": {
        "size_outliers": [{"file": f, "loc": n} for n, f in outliers],
        "hotspots": hotspots,
        "test": {"verify_command": test_cmd,
                 "test_files_found": len(test_files),
                 "gap": (test_cmd == "" or len(test_files) == 0)},
        "lint_debt": {"tool": lint_tool or None,
                      "count": (int(lint_count) if lint_count not in ("", "-1") else None),
                      "note": None if lint_tool else "stack linter not installed — skipped"},
        "churn_available": bool(churn),
    },
    "caveats": [
        "One-shot snapshot, not a stored grade. Diff two runs for a trend.",
        "Duplication and dependency-cycle detection are NOT in this version.",
        "No validated universal 'AI-maintainability' metric exists; these are "
        "structural proxies (hotspots have the strongest maintenance-pain evidence).",
    ],
}
if not churn:
    result["caveats"].append("Churn unavailable (not a git repo or empty history) "
                             "— hotspots fall back to size only.")
print(json.dumps(result, indent=2))
sys.stderr.write("assess: %s — %d source files, %d LOC; %d hotspots, %d size-outliers%s\n" % (
    result["project"], result["totals"]["source_files"], result["totals"]["source_loc"],
    len(hotspots), len(outliers),
    (", lint(%s)=%s" % (lint_tool, lint_count)) if lint_tool else ""))
PY
