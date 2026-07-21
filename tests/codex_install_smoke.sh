#!/usr/bin/env bash
# Model-free release smoke: package the repository as a marketplace plugin and
# make the real Codex CLI ingest/install it into an isolated CODEX_HOME.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/.agents/plugins" "$TMP/plugins/harness-kit" "$TMP/codex-home"
git -C "$ROOT" archive HEAD | tar -x -C "$TMP/plugins/harness-kit"

python3 - "$TMP/.agents/plugins/marketplace.json" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
path.write_text(json.dumps({
    "name": "harness-kit-ci",
    "plugins": [{
        "name": "harness-kit",
        "source": {"source": "local", "path": "./plugins/harness-kit"},
        "policy": {"installation": "AVAILABLE", "authentication": "ON_INSTALL"},
        "category": "Productivity",
    }],
}, indent=2) + "\n")
PY

CODEX_HOME="$TMP/codex-home" codex plugin marketplace add "$TMP" --json \
  > "$TMP/marketplace-result.json"
CODEX_HOME="$TMP/codex-home" codex plugin add harness-kit@harness-kit-ci --json \
  > "$TMP/install-result.json"

python3 - "$TMP/install-result.json" <<'PY'
import json
import pathlib
import sys

result = json.loads(pathlib.Path(sys.argv[1]).read_text())
installed = pathlib.Path(result["installedPath"])
manifest = installed / ".codex-plugin/plugin.json"
# Release-agnostic: assert the installed version matches the manifest (no hardcoded
# number to edit every bump), and the Stop-adapter files are present.
assert result["pluginId"] == "harness-kit@harness-kit-ci"
assert manifest.is_file()
expected = json.loads(manifest.read_text())["version"]
assert result["version"] == expected, f"install reported {result['version']} != manifest {expected}"
assert (installed / "adapters/codex/hooks.json").is_file()
assert (installed / "hooks/scripts/verify-loop.sh").is_file()
print(f"Codex install smoke: harness-kit@{expected} installed with Stop adapter")
PY
