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
import sys, os, tempfile
file, start, end, new = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
try:
    txt = open(file).read()
    mode = os.stat(file).st_mode & 0o7777          # preserve the file's existing mode
except FileNotFoundError:
    txt = ""
    _u = os.umask(0); os.umask(_u)
    mode = 0o666 & ~_u                              # umask default for a brand-new file
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
# Atomic write — temp in the same dir + os.replace so an interruption can never leave
# the user's file (often CLAUDE.md) truncated. os.replace is atomic on POSIX.
d = os.path.dirname(os.path.abspath(file)) or "."
fd, tmp = tempfile.mkstemp(dir=d, prefix=".update-block.")
try:
    with os.fdopen(fd, "w") as f:
        f.write(txt)
    os.chmod(tmp, mode)   # mkstemp forces 0600; restore the intended mode before swap
    os.replace(tmp, file)
except BaseException:
    try: os.unlink(tmp)
    except OSError: pass
    raise
PY
