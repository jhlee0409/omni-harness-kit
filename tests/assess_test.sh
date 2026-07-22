#!/usr/bin/env bash
# Tests for the maintainability audit engine (skills/assess/assess.sh).
# Throwaway git + non-git fixtures; bash + python3 + git. No network.
# Run: bash tests/assess_test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASSESS="$ROOT/skills/assess/assess.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
ok(){ echo "  PASS: $1"; PASS=$((PASS+1)); }
no(){ echo "  FAIL: $1"; FAIL=$((FAIL+1)); }
gitq(){ git -C "$1" -c user.email=t@t -c user.name=t -c commit.gpgsign=false "${@:2}" >/dev/null 2>&1; }
# jq-free JSON assertion: pipe JSON to a python expr that exits 0/1.
jchk(){ printf '%s' "$1" | python3 -c "import json,sys
d=json.load(sys.stdin)
sys.exit(0 if ($2) else 1)"; }

echo "[1] git repo with a churned source file → hotspot fires + valid JSON"
f="$TMP/g"; mkdir -p "$f"; git -C "$f" init -q
python3 -c "print(chr(10).join('x=%d'%i for i in range(60)))" > "$f/app.py"
gitq "$f" add -A; gitq "$f" commit -m one
printf 'y=1\n' >> "$f/app.py"; gitq "$f" add -A; gitq "$f" commit -m two
printf 'y=2\n' >> "$f/app.py"; gitq "$f" add -A; gitq "$f" commit -m three
j="$(bash "$ASSESS" "$f" 2>/dev/null)"
jchk "$j" "True" && ok "valid JSON emitted" || no "invalid/empty JSON"
jchk "$j" "any(x['file']=='app.py' and x['churn_90d']>=2 for x in d['signals']['hotspots'])" \
  && ok "churned file surfaced as a hotspot" || no "hotspot missed"
jchk "$j" "d['signals']['churn_available'] is True" \
  && ok "churn detected in a git repo" || no "churn not detected in git repo"

echo "[2] test-gap detection — repo with no test files → gap true"
jchk "$j" "d['signals']['test']['gap'] is True" \
  && ok "no-test repo flagged as a test gap" || no "test gap missed"

echo "[3] non-git repo → churn off, still valid JSON, files counted"
b="$TMP/nogit"; mkdir -p "$b"
python3 -c "print(chr(10).join('z=%d'%i for i in range(10)))" > "$b/lib.py"
jb="$(bash "$ASSESS" "$b" 2>/dev/null)"
jchk "$jb" "d['signals']['churn_available'] is False and d['totals']['source_files']>=1" \
  && ok "non-git: churn off, files counted, valid JSON" || no "non-git handling broke"

echo "[4] size-outlier detection (>=400 lines)"
s="$TMP/big"; mkdir -p "$s"
python3 -c "print(chr(10).join('a=%d'%i for i in range(450)))" > "$s/huge.py"
js="$(bash "$ASSESS" "$s" 2>/dev/null)"
jchk "$js" "any(x['file']=='huge.py' for x in d['signals']['size_outliers'])" \
  && ok "450-line file flagged as a size outlier" || no "size outlier missed"

echo "[5] caveats always present (honest-limits contract)"
jchk "$js" "len(d['caveats'])>=3 and any('AI-maintainability' in c for c in d['caveats'])" \
  && ok "caveats surfaced incl. no-universal-metric" || no "caveats missing"

echo "[6] duplication detection — an identical block across two files is flagged"
dp="$TMP/dup"; mkdir -p "$dp"
block="$(python3 -c "print(chr(10).join('    step_%d = compute(%d) + adjust(%d)'%(i,i,i) for i in range(10)))")"
for n in one two; do { echo "def f_$n():"; printf '%s\n' "$block"; } > "$dp/$n.py"; done
jd="$(bash "$ASSESS" "$dp" 2>/dev/null)"
jchk "$jd" "any(b['occurrences']>=2 for b in d['signals']['duplication']['blocks'])" \
  && ok "cross-file duplicated block flagged" || no "duplication missed"

echo "[7] no false duplication on distinct small files"
nd="$TMP/nodup"; mkdir -p "$nd"
python3 -c "print(chr(10).join('x_%d = %d'%(i,i) for i in range(12)))" > "$nd/a.py"
python3 -c "print(chr(10).join('y_%d = %d * 2'%(i,i) for i in range(12)))" > "$nd/b.py"
jn="$(bash "$ASSESS" "$nd" 2>/dev/null)"
jchk "$jn" "len(d['signals']['duplication']['blocks'])==0" \
  && ok "no duplicate blocks on distinct files" || no "false-positive duplication"

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
