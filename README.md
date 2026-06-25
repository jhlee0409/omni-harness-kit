# Harness Kit

A small, opinionated Claude Code plugin that gives any repository a
**plan → work → verify → feedback** engineering discipline — and an `introspect`
skill that scans the repo's tech stack and **tailors the setup to it**.

Most Claude Code harnesses are either kitchen-sink collections (hundreds of
agents/skills) or one-size-fits-all discipline frameworks. Harness Kit is the
opposite: a focused engine plus a generator that fits the engine to *your* repo's
real test-runner, build, and lint commands.

## What's inside

| Component | What it does |
|---|---|
| `skills/introspect/` | **The core.** Scans a target repo (language / framework / test-runner / package-manager / monorepo / data-layer), then generates a tailored harness: a thin `CLAUDE.md` spine + a stack-specific `*-architect` agent. |
| `agents/change-verifier.md` | A read-only critic that independently proves a change is complete (callsites, wiring, tests, real-run evidence) before it's reported done. |
| `hooks/protected-branch-guard.sh` | A `PreToolUse` guard that asks before a `git commit`/`git push` on a protected branch. Fires in every repo the plugin is installed into. |
| `hooks/verify-loop.sh` | A `Stop` hook — the **feedback** half of the loop. When code changed and a verify command is configured (the generated `.claude/harness-kit.json`), it surfaces that command so work is verified before "done". Non-blocking by default; opt into enforcement with `"blocking": true`. |
| `templates/` | The spine + architect templates `introspect` fills. |

## Install

```bash
# add this repo as a marketplace, then install the plugin
/plugin marketplace add jhlee0409/claude-harness-kit
/plugin install harness-kit@harness-kit-marketplace
```

Local development (no install step):

```bash
claude --plugin-dir /path/to/claude-harness-kit
```

## Use

In a target repo:

```
/harness-kit:introspect            # scan the current repo and generate its harness
/harness-kit:introspect ../other   # or point at another directory
```

`introspect` detects the stack with a layered-precedence engine
(`skills/introspect/detect.sh`) — lockfile/manifest/config presence first,
configs read statically (never executed), upward-crawl + per-subtree for
monorepos — then writes a marked, idempotent harness block into the repo's
root `CLAUDE.md` plus a stack-specific architect agent under `.claude/agents/`.

## Detection design

The detector follows the proven scaffolding/introspection playbook
(github-linguist, antfu's package-manager-detector, Nx Project Crystal):

1. Layered precedence — declared files beat content guessing.
2. Detect at the declaration layer; read configs statically, never execute them.
3. Monorepos → upward-crawl + per-subtree detection (a single root probe
   mislabels polyglot repos).
4. Separate "what the repo declares" from "what is installed on the machine".
5. Detect the declared (meta-)framework; mark generated files for safe re-runs.

## Status

Early PoC. Validated end-to-end against a TypeScript MCP-server repo. License: MIT.
