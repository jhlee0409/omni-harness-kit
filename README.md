<p align="center">
  <img src="docs/logo.svg" width="120" alt="Harness Kit logo">
</p>

<h1 align="center">Harness Kit</h1>

<p align="center">
  <b>Most AI coding harnesses ship the same config to every repo.<br>Harness Kit reads yours first.</b>
</p>

<p align="center">
  <a href="https://github.com/jhlee0409/omni-harness-kit/actions/workflows/ci.yml"><img src="https://github.com/jhlee0409/omni-harness-kit/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="./LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License: MIT"></a>
  <a href="https://github.com/jhlee0409/omni-harness-kit/releases"><img src="https://img.shields.io/github/v/release/jhlee0409/omni-harness-kit?sort=semver" alt="Release"></a>
  <img src="https://img.shields.io/badge/runtimes-Claude_Code_%C2%B7_Codex_%C2%B7_OpenCode_%C2%B7_omp-6366f1" alt="Runtimes: Claude Code, Codex, OpenCode, omp">
</p>

<p align="center">
  It introspects your repo's tech stack and generates a harness tailored to it —<br>
  a <code>CLAUDE.md</code> spine, a stack-specific architect agent, and a verify hook<br>
  wired to your repo's <i>real</i> test/lint commands.
</p>

<p align="center">
  <img src="docs/demo.gif" alt="Running /harness-kit:introspect in Claude Code" width="760">
</p>

---

## Why

A focused engine, not a kitchen sink. Most harnesses hand every repo the same
generic rules. Harness Kit detects your stack — reading configs statically, never
executing them — and fits a `plan → work → verify → feedback` discipline to *your*
real commands, then gets out of the way.

## Runtimes

One kit, four runtimes. Pick yours:

| Runtime | Install | What you get |
|---|---|---|
| **Claude Code** | `/plugin marketplace add jhlee0409/omni-harness-kit` | The full kit — `introspect`, the critic fleet, the guard + verify hooks, all skills. |
| **Codex** | `codex plugin marketplace add jhlee0409/omni-harness-kit --ref main` | Shared skills + the runtime-aware `Stop` verify loop (tracer). |
| **OpenCode** | plugin entry in `opencode.json` | Verify-loop, branch-guard, and compaction hooks. |
| **omp** (oh-my-pi) | `omp plugin marketplace add jhlee0409/omni-harness-kit` | An omp-native agent fleet, verify skills, TTSR guards, a `harness-check` audit device + `project-onboarder`. |

Full install steps + caveats are in [Install](#install).

## What's inside

### The engine

- **`introspect`** — the core. Scans a target repo (language / framework /
  test-runner / package-manager / monorepo / data-layer), then generates a tailored
  harness: a thin `CLAUDE.md` spine + an explicit agent-routing block (so the main
  agent auto-delegates) + a stack-specific `*-architect` agent.
- **Deterministic renderer** (`render.sh`) — the three generated agent files
  (architect + the two conditional critics) are filled by a script from pure-data
  slots: same input, same output, no LLM, no slot leak. The only probabilistic part
  left is the spine's judgment prose.
- **`.claude/repo-map.md`** — `introspect` also emits a deterministic navigation
  map (stack / entry points / top-level layout / monorepo members / where tests
  live) so an agent orients on the whole codebase by progressive disclosure — read
  the map, then drill into the exact subtree — instead of blind-globbing.

### The critic fleet (`agents/`)

Eight read-only critics the main agent routes to on demand — one independent check
per boundary:

| Critic | Asks |
|---|---|
| `instruction-critic` | Is this the right ask? |
| `requirement-fidelity-critic` | Has it drifted from the original spec? |
| `change-verifier` | Is the change actually complete? |
| `claim-checker` | Is a terminal claim measured, or asserted? |
| `spec-reviewer` | Did the PR deliver its spec? |
| `readability-critic` | Can a human decide from this output? |
| `pr-shepherd` | Is the PR mergeable? |
| `architecture-reviewer` | Is a structural change sound? |

Plus `tdd-runner`, a delegate for one red → green → refactor cycle. Independent
verification is the reliability lever — no measurement system required.

**Stack-conditional critics** (generated): `introspect` emits a `db-verify` critic
**only when it detects a data layer** (tailored to the real store — Mongo
`$exists` / Postgres `information_schema` / MySQL / SQLite / Redis) and a
`ui-verify` critic **only when it detects a frontend**. Ship the check tailored to
*your* stack, not a generic one to every repo.

### Workflow skills (`skills/`)

- **`new-spec` · `adr` · `worktree`** — scaffold a spec triplet (spec / plan /
  context), record the next numbered ADR, or create an isolated per-task worktree.
- **`handoff` · `pickup`** — write a resume block at a stopping point; continue from
  it in a fresh session.
- **`tdd` · `diagnose` · `coding-guidelines`** — red → green → refactor, root-cause
  debugging, and guidelines that counter common LLM mistakes.
- **`localize` · `blast-radius` · `assess`** — resolve a change to an exact edit
  target then test-gate it (localize → edit → validate); enumerate a symbol's full
  impact set (references / callers / implementations, with unresolved dynamic
  regions surfaced, never a false "completeness" claim); and audit maintainability
  read-only (size × churn hotspots → a ranked list of discrete fix PRs).

### The hooks (`hooks/`)

- **`protected-branch-guard.sh`** — a `PreToolUse` guard that asks before a
  `git commit` / `git push` on a protected branch.
- **`verify-loop.sh`** — a `Stop` hook (the feedback half of the loop) that surfaces
  your configured verify command so work is checked before "done".

### Runtime adapters (`adapters/`)

- **[`adapters/omp/`](adapters/omp/)** — the omp (oh-my-pi) target: an omp-native
  role/verify agent fleet (18 agents), verification skills, TTSR render/backend
  guards, a deterministic `harness-check.py` audit device, and a `project-onboarder`
  that tailors `<repo>/.omp/` to a stack.
- **`adapters/codex/` · `adapters/opencode/`** — the Codex and OpenCode adapters.

## Install

### Claude Code

```bash
# add this repo as a marketplace, then install the plugin
/plugin marketplace add jhlee0409/omni-harness-kit
/plugin install harness-kit@harness-kit-marketplace
```

Local development (no install step):

```bash
claude --plugin-dir /path/to/omni-harness-kit
```

### omp (oh-my-pi)

```bash
omp plugin marketplace add jhlee0409/omni-harness-kit
omp plugin install harness-kit@harness-kit-marketplace       # base: workflow skills the fleet autoloads
omp plugin install harness-kit-omp@harness-kit-marketplace
```

omp gets its own native target — an agent fleet, verify skills, TTSR guards, a
deterministic `harness-check` audit device, and a `project-onboarder` that tailors
`<repo>/.omp/` to your stack. See [`adapters/omp/README.md`](adapters/omp/README.md).

<details>
<summary><b>Codex</b> (experimental tracer)</summary>

Codex loads the shared skills and the runtime-aware `Stop` verify loop through
`.codex-plugin/plugin.json`. The Codex manifest explicitly selects
`adapters/codex/hooks.json`, so it does **not** load the Claude Code-only
protected-branch `PreToolUse` guard.

```bash
codex plugin marketplace add jhlee0409/omni-harness-kit --ref main
codex plugin add harness-kit@harness-kit-codex
```

Start a new task after installation. Codex will ask you to review and trust the
plugin's Stop hook before it runs; use `/hooks` to inspect that exact definition.

This is intentionally a tracer, not a full migration: `introspect` still emits
Claude Code-oriented `CLAUDE.md` / `.claude/agents` output, and Codex custom agents
are not generated yet. Use Claude Code to run `introspect` until that adapter exists.
</details>

<details>
<summary><b>OpenCode</b></summary>

Add to your project's `.opencode/` config or global
`~/.config/opencode/opencode.json`:

```json
{
  "plugin": ["./path/to/omni-harness-kit/adapters/opencode/src/index.ts"]
}
```

See [`adapters/opencode/README.md`](adapters/opencode/README.md) for details.
</details>

## Use

In a target repo:

```
/harness-kit:introspect            # scan the current repo and generate its harness
/harness-kit:introspect ../other   # or point at another directory
```

`introspect` detects the stack with a layered-precedence engine
(`skills/introspect/detect.sh`) — lockfile/manifest/config presence first, configs
read statically (never executed), upward-crawl + per-subtree for monorepos — then
writes a marked, idempotent harness block into the repo's root `AGENTS.md` (the
canonical cross-vendor file) and wires `CLAUDE.md` to `@AGENTS.md`-import it, plus a
deterministic `.claude/repo-map.md` and a stack-specific architect agent under
`.claude/agents/`.

## Detection design

The detector follows the proven scaffolding/introspection playbook
(github-linguist, antfu's package-manager-detector, Nx Project Crystal):

1. Layered precedence — declared files beat content guessing.
2. Detect at the declaration layer; read configs statically, never execute them.
3. Monorepos → upward-crawl + per-subtree detection (a single root probe mislabels
   polyglot repos).
4. Separate "what the repo declares" from "what is installed on the machine".
5. Detect the declared (meta-)framework; mark generated files for safe re-runs.

## Configuration

`introspect` generates `.claude/harness-kit.json` in the target repo — the shared
config read by the Claude Code hooks and the Codex Stop adapter. `protected_branches`
follows env override > this file > built-in default; `verify_command` is read from
this file only (its sole env control is the `HARNESS_VERIFY_OFF=1` off switch — there
is no env override and no built-in default command), and `blocking` defaults to false:

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
Python / Go / Rust / Ruby / JVM (Maven & Gradle) / Shell (a bash-tooling repo,
detected only when no packaged manifest exists); any other stack (PHP, Elixir, .NET,
Deno, …) degrades gracefully — introspect reads its manifest and still tailors a basic
architect. A **blank/greenfield** repo with no manifest gets the universal discipline
spine plus a "re-run once you add a stack" note. The **generated harness is in English**
(no localization of the rules/structure).

## Status

Early PoC (0.x — expect breaking changes). What is actually proven, stated honestly:

- **omp target** (`adapters/omp/`) — an omp-native fleet of 18 agents, 6 verify
  skills, 2 TTSR rules, and the `harness-check.py` audit device. Static validation
  is clean: every agent parses, tools are valid, `autoloadSkills` resolve, and all
  JSON/YAML/script parse. Live-session dogfooding of the full fleet is ongoing.
- **Codex tracer** (`.codex-plugin/`, `adapters/codex/`) — shared skills plus the
  Stop verify loop. Contract tests cover authoritative Codex `cwd`,
  `decision: block` continuation, `stop_hook_active` loop prevention, and preservation
  of Claude Code's `additionalContext` output. A live Codex CLI 0.144 run installed
  the plugin, continued once, ran the configured verify command, and then stopped
  without looping. Protected-branch `PreToolUse` and Codex custom-agent generation
  remain deferred.
- **OpenCode adapter** (`adapters/opencode/`) — plugin entry point with verify-loop,
  branch-guard, and compaction hooks. 13 unit tests pass (dogfood suite with mock shell).
  Not yet dogfooded in a live OpenCode session.
- **Agentic engine** (`agentic-engine/`) — all 4 modules implemented and tested (83 tests,
  all pass): cross-vendor verification (21 tests), rag-feedback retrieval (20 tests),
  intent-router classification (12 tests), verify-evidence capture (17 tests). CC adapters
  build and pass their unit tests; OC adapters for rag-feedback and intent-router are
  stubbed (system.transform doesn't expose the user's latest message — known OpenCode
  limitation). **verify-evidence's CC adapter is not registered in `hooks/hooks.json` by
  design** — it is a `SubagentStop` hook that appends a JSONL log entry whenever a critic
  agent's output matches a claim pattern (no blocking, no context injection back to the
  model). To opt in, add it to your own `.claude/settings.json` `hooks.SubagentStop`
  pointing at `agentic-engine/verify-evidence/adapters/claude-code/subagent-stop.sh`.
  Pilot it before trusting the log: any always-on hook accumulates entries nobody reviews
  unless something actually consumes `.harness-kit/evidence.jsonl` downstream.
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
