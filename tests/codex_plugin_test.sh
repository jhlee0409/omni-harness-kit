#!/usr/bin/env bash
# Contract test for the Codex plugin entry point. It deliberately verifies the
# runtime adapter rather than accepting the Claude Code default hooks file.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0; FAIL=0
ok(){ echo "  PASS: $1"; PASS=$((PASS+1)); }
no(){ echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

echo "[1] Codex manifest selects a Stop-only adapter backed by the shared hook"
python3 - "$ROOT" <<'PY' \
  && ok "Codex plugin contract is explicit and runtime-safe" \
  || no "Codex plugin contract is missing or unsafe"
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
claude = json.loads((root / ".claude-plugin/plugin.json").read_text())
codex = json.loads((root / ".codex-plugin/plugin.json").read_text())
hooks_path = root / codex["hooks"].removeprefix("./")
hooks = json.loads(hooks_path.read_text())

assert codex["name"] == claude["name"] == "harness-kit"
assert codex["version"] == claude["version"]
assert codex["skills"] == "./skills/"
assert codex["hooks"] == "./adapters/codex/hooks.json"
assert set(hooks["hooks"]) == {"Stop"}

stop = hooks["hooks"]["Stop"]
assert len(stop) == 1 and "matcher" not in stop[0]
handlers = stop[0]["hooks"]
assert len(handlers) == 1 and handlers[0]["type"] == "command"
command = handlers[0]["command"]
assert "HARNESS_RUNTIME=codex" in command
assert "${PLUGIN_ROOT}" in command
assert "/hooks/scripts/verify-loop.sh" in command
assert (root / "hooks/scripts/verify-loop.sh").is_file()
PY

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
