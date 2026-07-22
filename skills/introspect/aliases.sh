#!/usr/bin/env bash
# Wire CLAUDE.md to import the canonical AGENTS.md via Claude Code's @-import, so the
# generated harness has ONE source of truth: AGENTS.md (the cross-vendor standard that
# Codex / Cursor / others read directly) holds the content, and CLAUDE.md just imports
# it. No duplication, no drift, no symlink. See docs/adr/0001-*. Idempotent: re-running
# replaces its own marked block and preserves any other content in the user's CLAUDE.md.
# Usage: aliases.sh <target-dir>
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:?usage: aliases.sh <target-dir>}"
[ -d "$TARGET" ] || { echo "aliases: target not found: $TARGET" >&2; exit 1; }
# AGENTS.md is the source of truth; refuse to wire an import to a file that isn't there
# (introspect §4 step 1 writes AGENTS.md first). Fail loud rather than create a dangling
# @import that Claude Code would silently expand to nothing.
[ -f "$TARGET/AGENTS.md" ] || {
  echo "aliases: $TARGET/AGENTS.md not found — write the spine to AGENTS.md first" >&2
  exit 1
}

S='<!-- harness-kit:import:start -->'
E='<!-- harness-kit:import:end -->'
# The @import line is plain (not fenced) so Claude Code expands it; the HTML-comment
# markers make the block idempotently replaceable and visible as generated.
block="$(printf '%s\n@AGENTS.md\n%s\n' "$S" "$E")"
printf '%s' "$block" | bash "$HERE/update-block.sh" "$TARGET/CLAUDE.md" "$S" "$E"
echo "aliases: CLAUDE.md imports AGENTS.md (harness-kit:import block)"
