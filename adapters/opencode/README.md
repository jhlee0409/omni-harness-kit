# Harness Kit — OpenCode Adapter

OpenCode plugin adapter for Harness Kit. Provides the same `plan → work → verify →
feedback` discipline as the Claude Code adapter, using OpenCode's mutation-based
hook system.

## Install

### From local directory (development)

Add to your project's `.opencode/` config or global `~/.config/opencode/opencode.json`:

```json
{
  "plugin": ["~/client/omni-harness-kit/adapters/opencode/src/index.ts"]
}
```

### From published package (when available)

```json
{
  "plugin": ["@harness-kit/opencode"]
}
```

## Configure

Create `.opencode/harness-kit.json` in your project root (same schema as CC):

```json
{
  "verify_command": "tsc --noEmit && vitest run",
  "blocking": false,
  "protected_branches": ["main", "release"]
}
```

Or reuse `.claude/harness-kit.json` if you run both adapters on the same repo —
the plugin checks both locations (.opencode/ first, .claude/ second).

## What it does

| Hook | CC Equivalent | OpenCode Hook | Behavior |
|---|---|---|---|
| **Verify-loop** | `verify-loop.sh` (Stop) | `experimental.chat.system.transform` | When code is dirty + verify_command configured, injects a reminder into the system prompt on every LLM call. More effective than CC's end-of-turn nudge. |
| **Branch-guard** | `protected-branch-guard.sh` (PreToolUse/Bash) | `tool.execute.before` | Intercepts `git commit`/`git push` on protected branches, injects a visible warning into the command. |
| **Compaction-context** | `PreCompact` hook | `experimental.session.compacting` | Preserves verify command + git state through compaction. |

## Env overrides (same as CC)

```bash
HARNESS_VERIFY_OFF=1           # disable verify-loop
HARNESS_GUARD_OFF=1            # disable branch-guard
HARNESS_PROTECTED_BRANCHES="main release"  # override protected branches
```

## Type-check

```bash
cd adapters/opencode
npm install   # installs @opencode-ai/plugin types
npx tsc --noEmit
```

## Differences from CC adapter

| Aspect | Claude Code | OpenCode |
|---|---|---|
| Hook pattern | stdin/stdout JSON (observe + block) | input/output mutation (modify in-place) |
| Verify timing | Stop event (end of turn) | System prompt transform (every LLM call) |
| Block capability | Can block execution | Can't block — injects warning comment |
| Config location | `.claude/harness-kit.json` | `.opencode/harness-kit.json` (or shared `.claude/`) |

## Skills & Agents

The skill markdown files (`../../skills/*/SKILL.md`) are runtime-neutral. To use
them with OpenCode, symlink or copy to `.opencode/skills/`:

```bash
ln -s ~/client/omni-harness-kit/skills/* .opencode/skills/
```

Agent definitions (critic fleet) differ per runtime:
- **CC**: `../../agents/*.md` (Claude Code agent format)
- **OpenCode**: use `task()` with `subagent_type` (built-in) — the agent prompt
  content is shared, only the invocation mechanism differs
