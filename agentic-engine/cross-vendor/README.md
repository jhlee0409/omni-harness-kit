# Cross-Vendor Verification

Independent verification from different AI vendors — sends the same prompt to
multiple AI systems and surfaces disagreements.

## How it works

1. On key decision points (architecture changes, critical fixes), the prompt +
   output are sent to a second vendor (Codex, Gemini, etc.)
2. The second vendor independently evaluates the output
3. Disagreements are surfaced to the user

## Interface

```bash
# Core is a bash script (most portable)
outside-voices.sh \
  --prompt-file <path> \
  --output-file <path> \
  --vendors codex,gemini \
  --mode review
```

## Adapters

- **Claude Code**: `Stop` / `SubagentStop` hook → runs `outside-voices.sh`
- **OpenCode**: `tool.execute.after` (on task tool) + `event` (session.idle)

## Vendors

| Vendor | CLI/API | Key needed |
|---|---|---|
| Codex (OpenAI) | `codex` CLI | `OPENAI_API_KEY` |
| Gemini (Google) | `gemini` CLI or API | `GOOGLE_API_KEY` |
| Antigravity | API | Provider-specific |

This is the most portable module — the core is pure bash, only the trigger
mechanism differs per platform.
