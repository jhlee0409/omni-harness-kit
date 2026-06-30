# Cross-Vendor Verification

Independent verification from different AI vendors — sends the same prompt to
multiple AI systems in parallel and surfaces a 3-state verdict.

## Status: IMPLEMENTED (v0.1.0)

Core script + both runtime adapters are written and tested (21 shell tests, all pass).

## How it works

1. A trigger fires (CC Stop hook / OC tool.execute.after hook) with the session's last user prompt + assistant output
2. `outside-voices.sh` sends the prompt to N vendors in parallel (each with a per-vendor timeout)
3. Common framing is prepended identically to all vendors
4. Each vendor's output is captured to a durable per-vendor file + a merged `result.md`
5. Exit code signals the aggregate verdict:
   - `0` = all-green (every vendor returned exit 0 with non-empty output)
   - `2` = degraded (at least one green, at least one dead)
   - `1` = all-dead (no vendor succeeded)

## Usage

```bash
# Direct invocation
echo "Review this code: ..." | ./outside-voices.sh --vendors codex,gemini

# With a prompt file
./outside-voices.sh \
  --prompt-file ./prompt.txt \
  --vendors codex,gemini,agy \
  --mode review

# Environment-based config
OUTSIDE_VOICES_VENDORS=codex,gemini ./outside-voices.sh < prompt.txt
```

### Kill switch

```bash
OUTSIDE_VOICES_OFF=1  # disables entirely (fail-open)
```

### Output

All output goes to `$OUTSIDE_VOICES_OUT_DIR` (default: `/tmp/outside-voices-<timestamp>/`):

```
/tmp/outside-voices-1234567/
├── result.md          # merged output (all vendors)
├── codex.out          # per-vendor raw output
├── gemini.out
└── agy.out
```

## Vendors

| Vendor | CLI | Env var | Registry function |
|---|---|---|---|
| Codex (OpenAI) | `codex` | `OPENAI_API_KEY` | `_vendor_codex_cmd` |
| Gemini (Google) | `gemini` | `GEMINI_API_KEY` | `_vendor_gemini_cmd` |
| Antigravity | `agy` | Provider-specific | `_vendor_agy_cmd` |

Adding a new vendor: define `_vendor_<name>_cmd` and `_vendor_<name>_label` functions in `outside-voices.sh`, then pass `--vendors <name>` or set `OUTSIDE_VOICES_VENDORS`.

## Adapters

### Claude Code (`adapters/claude-code/stop.sh`)

Stop hook — extracts the last user prompt via `jq`, runs `outside-voices.sh` detached via `nohup` (fail-open, non-blocking).

### OpenCode (`adapters/opencode/cross-vendor.ts`)

`tool.execute.after` hook on the `task` tool — runs `outside-voices.sh` detached via BunShell (fail-open, non-blocking).

## Test

```bash
bash agentic-engine/cross-vendor/test/outside-voices.test.sh
# 21 pass, 0 fail
```

Covers: kill switch, missing CLI, unknown vendor, all-green, degraded, all-dead, empty output = dead, stdin input, --prompt-file, durable output files.
