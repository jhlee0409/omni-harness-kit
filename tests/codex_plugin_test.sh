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

echo "[2] Codex marketplace exposes the repository-root plugin via Git URL"
python3 - "$ROOT" <<'PY' \
  && ok "Codex marketplace uses the repository-root URL contract" \
  || no "Codex marketplace URL contract is missing or malformed"
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
marketplace = json.loads((root / ".agents/plugins/marketplace.json").read_text())
assert marketplace["name"] == "harness-kit-codex"
assert marketplace["interface"]["displayName"] == "Harness Kit for Codex"
assert len(marketplace["plugins"]) == 1
entry = marketplace["plugins"][0]
assert entry["name"] == "harness-kit"
assert entry["source"] == {
    "source": "url",
    "url": "https://github.com/jhlee0409/omni-harness-kit.git",
    "ref": "main",
}
assert entry["policy"] == {
    "installation": "AVAILABLE",
    "authentication": "ON_INSTALL",
}
assert entry["category"] == "Productivity"
PY

echo "[3] Claude and Codex manifests publish the same 0.7.0 release"
python3 - "$ROOT" <<'PY' \
  && ok "runtime manifests and CHANGELOG share one release version" \
  || no "runtime manifest release versions drifted"
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
claude = json.loads((root / ".claude-plugin/plugin.json").read_text())
codex = json.loads((root / ".codex-plugin/plugin.json").read_text())
changelog = (root / "CHANGELOG.md").read_text()
assert claude["version"] == codex["version"] == "0.7.0"
assert f"## [{claude['version']}] - " in changelog
PY

echo "[4] README install commands target the shipped Codex marketplace"
python3 - "$ROOT" <<'PY' \
  && ok "README installs from harness-kit-codex" \
  || no "README Codex installation path drifted"
import pathlib
import sys

readme = (pathlib.Path(sys.argv[1]) / "README.md").read_text()
assert "codex plugin marketplace add jhlee0409/omni-harness-kit --ref main" in readme
assert "codex plugin add harness-kit@harness-kit-codex" in readme
assert "expose this checkout as `plugins/harness-kit`" not in readme
PY

echo "[5] CI runs a model-free Codex plugin installation smoke"
python3 - "$ROOT" <<'PY' \
  && ok "CI installs the Codex plugin without an agent turn" \
  || no "CI Codex installation smoke is not wired"
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
workflow = (root / ".github/workflows/ci.yml").read_text()
smoke = root / "tests/codex_install_smoke.sh"
assert smoke.is_file()
assert "npm install -g @openai/codex" in workflow
assert "bash tests/codex_install_smoke.sh" in workflow
PY

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
