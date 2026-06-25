#!/usr/bin/env bash
# Idempotently write a marked block into a file. If the start+end markers already
# exist, the region between them (inclusive) is REPLACED; otherwise the block is
# APPENDED. Re-running with the same block is a no-op — this is what makes an
# introspect re-run safe (it updates its own block instead of stacking copies).
#
# usage: update-block.sh <file> <start-marker> <end-marker>   # new block on stdin
# The new block passed on stdin should itself include the start and end markers.
set -uo pipefail
file="$1"; start="$2"; end="$3"
new="$(cat)"

python3 - "$file" "$start" "$end" "$new" <<'PY'
import sys
file, start, end, new = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
try:
    txt = open(file).read()
except FileNotFoundError:
    txt = ""
si = txt.find(start)
if si != -1:
    ei = txt.find(end, si)
    if ei != -1:
        ei += len(end)
        txt = txt[:si] + new + txt[ei:]      # replace existing block
    else:
        txt = txt[:si] + new                 # dangling start: replace to EOF
else:
    if txt and not txt.endswith("\n"):
        txt += "\n"
    if txt and not txt.endswith("\n\n"):
        txt += "\n"
    txt += new                                # append new block
if not txt.endswith("\n"):
    txt += "\n"
open(file, "w").write(txt)
PY
