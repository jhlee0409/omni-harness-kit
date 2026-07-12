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
  <b>Most AI coding harnesses ship the same config to every repo.<br>Harness Kit reads yours first.</b>
</p>

<p align="center">
  Built for <b>Claude Code</b>, with experimental <b>Codex</b> and <b>OpenCode</b> adapters.
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
| `hooks/scripts/verify-loop.sh` | A `Stop` hook — the **feedback** half of the loop. When code changed and a verify command is configured (the generated `.claude/harness-kit.json`), it surfaces that command so work is verified before "done". Claude Code is non-blocking by default; Codex creates one continuation because its UI-only warning channel cannot reach the model. |
| `skills/new-spec/`, `skills/adr/`, `skills/worktree/` | Workflow skills — `/harness-kit:new-spec` scaffolds a spec triplet (spec / plan / context), `/harness-kit:adr` records the next numbered ADR, `/harness-kit:worktree` creates an isolated per-task worktree (only if you opt into that workflow). Structured work is where reliable output comes from (no measurement system needed). |
| `skills/handoff/`, `skills/pickup/` | Resume loop — `/harness-kit:handoff` writes a resume block at a stopping point; `/harness-kit:pickup` continues from it in a fresh session. Validated with a discriminating eval: a fresh session reliably picked up a non-obvious decision a control (no handoff) missed 3/3. |
| `skills/tdd/`, `skills/diagnose/`, `skills/coding-guidelines/` | Build discipline — `/harness-kit:tdd` (red → green → refactor, test first), `/harness-kit:diagnose` (reproduce → minimize → hypothesize → fix the cause → regression-test), and coding guidelines that counter common LLM mistakes (surgical changes, no overcomplication, verifiable success). |
| **Stack-conditional critics** (generated) | `introspect` generates a `db-verify` critic **only when it detects a data layer** (tailored to the real store — MongoDB `$exists` / Postgres `information_schema` / MySQL / SQLite / Redis) and a `ui-verify` critic **only when it detects a frontend** (tailored to the real dev command). They need an external DB client / browser driver — the kit does **not** bundle those; introspect tells you the one command to add them, you install them. This is the introspect-first thesis applied to verification: ship the check tailored to *your* stack, not a generic one to every repo. |
| `skills/introspect/render.sh` | **Deterministic renderer** for the three generated agent files (architect + the two conditional critics). Their slots are pure-data / table-lookup, so a script fills them — no LLM, no slot leak, fully tested. Shrinks the probabilistic surface to just the spine's judgment prose. |
| `templates/` | The spine, architect, conditional-critic (db-verify / ui-verify), spec-triplet, and ADR templates the skills fill. |

## Install

### Claude Code

```bash
# add this repo as a marketplace, then install the plugin
/plugin marketplace add jhlee0409/claude-harness-kit
/plugin install harness-kit@harness-kit-marketplace
```

Local development (no install step):

```bash
claude --plugin-dir /path/to/claude-harness-kit
```

### Codex (experimental tracer)

Codex currently loads the shared skills and the runtime-aware `Stop` verify loop
through `.codex-plugin/plugin.json`. The Codex manifest explicitly selects
`adapters/codex/hooks.json`, so it does **not** load the Claude Code-only
protected-branch `PreToolUse` guard.

Add this repository as a Codex marketplace, then install the plugin:

```bash
codex plugin marketplace add jhlee0409/claude-harness-kit --ref main
codex plugin add harness-kit@harness-kit-codex
```

Start a new task after installation. Codex will ask you to review and trust the
plugin's Stop hook before it runs; use `/hooks` to inspect that exact definition.

This is intentionally a tracer, not a full migration: `introspect` still emits
Claude Code-oriented `CLAUDE.md` / `.claude/agents` output, and Codex custom
agents are not generated yet. Use Claude Code to run `introspect` until that
adapter exists.

### OpenCode

Add to your project's `.opencode/` config or global `~/.config/opencode/opencode.json`:

```json
{
  "plugin": ["./path/to/claude-harness-kit/adapters/opencode/src/index.ts"]
}
```

See [`adapters/opencode/README.md`](adapters/opencode/README.md) for details.

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

`introspect` generates `.claude/harness-kit.json` in the target repo — the shared
config read by the Claude Code hooks and the Codex Stop adapter (precedence: env
override > this file > built-in default):

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

**Stack coverage & language.** The deterministic detector covers Node / TypeScript /
Python / Go / Rust / Ruby / JVM (Maven & Gradle); any other stack (PHP, Elixir, .NET,
Deno, …) degrades gracefully — introspect reads its manifest and still tailors a basic
architect. A **blank/greenfield** repo with no manifest gets the universal discipline
spine plus a "re-run once you add a stack" note. The **generated harness is in English**
(no localization of the rules/structure).

## Status

Early PoC (0.x — expect breaking changes). What is actually proven, stated honestly:

- **Codex tracer** (`.codex-plugin/`, `adapters/codex/`) — shared skills plus the
  Stop verify loop. Contract tests cover authoritative Codex `cwd`,
  `decision: block` continuation, `stop_hook_active` loop prevention, and preservation
  of Claude Code's `additionalContext` output. A live
  Codex CLI 0.144 run installed the plugin, continued once, ran the configured
  verify command, and then stopped without looping. Protected-branch `PreToolUse`
  and Codex custom-agent generation remain deferred.
- **OpenCode adapter** (`adapters/opencode/`) — plugin entry point with verify-loop,
  branch-guard, and compaction hooks. 13 unit tests pass (dogfood suite with mock shell).
  Not yet dogfooded in a live OpenCode session.
- **Agentic engine** (`agentic-engine/`) — all 4 modules implemented and tested (83 tests,
  all pass): cross-vendor verification (21 tests), rag-feedback retrieval (20 tests),
  intent-router classification (12 tests), verify-evidence capture (17 tests). CC adapters
  work fully; OC adapters for rag-feedback and intent-router are stubbed (system.transform
  doesn't expose the user's latest message — known OpenCode limitation).

- **Detection + the deterministic engine** (`detect.sh`, the two hooks, the
  scaffolders, the template contracts) is covered by an extensive shell test suite,
  run in CI on every push.
- **`introspect` has been dogfooded against real public repos** across the matrix —
  Go (`cobra`), Rust (`ripgrep`), a TS/JS monorepo (`create-t3-turbo`), Python+Postgres
  + React monorepo (`full-stack-fastapi-template`), a Python library (`flask`), and a
  Next.js + Prisma(MySQL) frontend (`taxonomy`). Conditional-critic gating, the
  store-verify idioms, and reference integrity validated clean on every stack; the
  plumbing defects it surfaced are fixed (see [`docs/dogfood-log.md`](docs/dogfood-log.md)).
- **Generation is mostly deterministic.** The three generated agent files (the
  `<stack>-architect` and the conditional `db-verify` / `ui-verify` critics) are
  rendered by a script (`render.sh`) — same input, same output, fully tested
  (including the per-store verify idioms), so they can't leak a slot or pick the wrong
  store query. The **only** LLM-filled, *probabilistic* part left is the spine's
  judgment prose (the architecture note, the stack summary). Review that before
  committing — it's the irreducible residue.

License: MIT.

---

> **Not affiliated with Anthropic.** Harness Kit is an independent, community
> project — not affiliated with, endorsed by, or sponsored by Anthropic. "Claude"
> and "Claude Code" are trademarks of Anthropic, PBC, used here descriptively to
> indicate compatibility.
