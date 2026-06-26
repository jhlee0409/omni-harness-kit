<p align="center">
  <img src="docs/logo.svg" width="112" alt="Harness Kit logo">
</p>

<h1 align="center">Harness Kit</h1>

<p align="center">
  <a href="https://github.com/jhlee0409/claude-harness-kit/actions/workflows/ci.yml"><img src="https://github.com/jhlee0409/claude-harness-kit/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="./LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License: MIT"></a>
  <a href="https://github.com/jhlee0409/claude-harness-kit/releases"><img src="https://img.shields.io/github/v/release/jhlee0409/claude-harness-kit?sort=semver" alt="Release"></a>
</p>

<p align="center">
  <b>Most Claude Code harnesses ship the same config to every repo.<br>Harness Kit reads yours first.</b>
</p>

It introspects your repo's tech stack and generates a harness tailored to it — a
`CLAUDE.md` spine, a stack-specific architect agent, and a verify hook wired to
your repo's *real* test/lint commands.

![Running /harness-kit:introspect in Claude Code](docs/demo.gif)

A focused engine, not a kitchen sink: it detects your stack (reading configs
statically, never executing them) and fits a `plan → work → verify → feedback`
discipline to *your* real commands.

## What's inside

| Component | What it does |
|---|---|
| `skills/introspect/` | **The core.** Scans a target repo (language / framework / test-runner / package-manager / monorepo / data-layer), then generates a tailored harness: a thin `CLAUDE.md` spine + an explicit agent-routing block (so the main agent auto-delegates) + a stack-specific `*-architect` agent. |
| `agents/` (critic fleet) | Eight read-only critics the main agent routes to on demand — an independent check at each boundary: `instruction-critic` (is this the right ask?), `requirement-fidelity-critic` (spec drift from the original ask?), `change-verifier` (is the change complete?), `claim-checker` (is a terminal claim measured or asserted?), `spec-reviewer` (did the PR deliver its spec?), `readability-critic` (can a human decide from this output?), `pr-shepherd` (is the PR mergeable?), `architecture-reviewer` (is a structural change sound?). Independent verification is the reliability lever — no measurement system needed. (Critics share one limit: invocation-gated + same model class, so marginal-but-real, not a guarantee; the only proven 100% check is a human.) |
| `agents/tdd-runner.md` | A delegate runner for one red → green → refactor cycle — writes the failing test first, confirms red, implements the minimum, refactors, returns green-with-evidence. |
| `hooks/scripts/protected-branch-guard.sh` | A `PreToolUse` guard that asks before a `git commit`/`git push` on a protected branch. Fires in every repo the plugin is installed into. |
| `hooks/scripts/verify-loop.sh` | A `Stop` hook — the **feedback** half of the loop. When code changed and a verify command is configured (the generated `.claude/harness-kit.json`), it surfaces that command so work is verified before "done". Non-blocking by default; opt into enforcement with `"blocking": true`. |
| `skills/new-spec/`, `skills/adr/`, `skills/worktree/` | Workflow skills — `/harness-kit:new-spec` scaffolds a spec triplet (spec / plan / context), `/harness-kit:adr` records the next numbered ADR, `/harness-kit:worktree` creates an isolated per-task worktree (only if you opt into that workflow). Structured work is where reliable output comes from (no measurement system needed). |
| `skills/handoff/`, `skills/pickup/` | Resume loop — `/harness-kit:handoff` writes a resume block at a stopping point; `/harness-kit:pickup` continues from it in a fresh session. Validated with a discriminating eval: a fresh session reliably picked up a non-obvious decision a control (no handoff) missed 3/3. |
| `skills/tdd/`, `skills/diagnose/`, `skills/karpathy-guidelines/` | Build discipline — `/harness-kit:tdd` (red → green → refactor, test first), `/harness-kit:diagnose` (reproduce → minimize → hypothesize → fix the cause → regression-test), and coding guidelines that counter common LLM mistakes (surgical changes, no overcomplication, verifiable success). |
| **Stack-conditional critics** (generated) | `introspect` generates a `db-verify` critic **only when it detects a data layer** (tailored to the real store — MongoDB `$exists` / Postgres `information_schema` / Redis) and a `ui-verify` critic **only when it detects a frontend** (tailored to the real dev command). They need an external DB client / browser driver — the kit does **not** bundle those; introspect tells you the one command to add them, you install them. This is the introspect-first thesis applied to verification: ship the check tailored to *your* stack, not a generic one to every repo. |
| `templates/` | The spine, architect, conditional-critic (db-verify / ui-verify), spec-triplet, and ADR templates the skills fill. |

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

## Configuration

`introspect` generates `.claude/harness-kit.json` in the target repo — the single
config both hooks read (precedence: env override > this file > built-in default):

```json
{
  "verify_command": "tsc --noEmit && vitest run",
  "blocking": false,
  "protected_branches": ["main", "master", "develop", "release"]
}
```

`introspect` also seeds two keys read outside the hooks: `worktree_workflow` (the
worktree skill) and `pr_workflow` (`pr-shepherd`) — five keys in all; see the
introspect skill for the full schema.

Quick env toggles: `HARNESS_GUARD_OFF=1`, `HARNESS_VERIFY_OFF=1`,
`HARNESS_PROTECTED_BRANCHES="main release"`.

Re-running `introspect` is safe — it replaces its own marked block in `CLAUDE.md`
(via `update-block.sh`) instead of stacking copies.

## Requirements

`bash` + `python3` (the detection engine and the hooks); `git` for the guard hook.
Node/npm only when the target stack is Node (auto-detected, not a hard dependency).
macOS and Linux are supported; on Windows use WSL or Git-Bash. Without `python3` the
hooks **fail open silently** — they never block your work, but the guard you expect
is simply absent.

## Status

Early PoC (0.x — expect breaking changes). What is actually proven, stated honestly:

- **Detection + the deterministic engine** (`detect.sh`, the two hooks, the
  scaffolders, the template contracts) is covered by **71 tests**, and `introspect`
  has been run end-to-end on TypeScript/MCP and Python/Gradio repos.
- **Harness generation is LLM-driven** from those tested templates — it is
  *probabilistic, not guaranteed*: a mis-filled slot is not caught by a test. Only
  TS + Python are generation-validated end-to-end; Go / Rust / monorepo-per-member /
  the Python-DB path are detection-verified only (the first user on those is the
  integration test).
- The generated `db-verify` / `ui-verify` critics are template- and signal-tested,
  not yet generated-and-run in CI.

License: MIT.
