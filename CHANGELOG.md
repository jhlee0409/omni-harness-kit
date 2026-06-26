# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres
to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-06-26

The workflow + verification layer: structured artifact management, a seven-critic
verification spine, the introspect routing block, a validated resume loop, and
brand assets. Reliability comes from discipline + independent checks — no
measurement system (deliberately cut as too heavy).

### Added
- **Agent routing** — introspect generates an explicit `## Agents` block in the
  spine so the main agent delegates to the right `<stack>-architect` without being
  named (auto-orchestration by explicit guidance, not description-matching luck).
- **Artifact-management skills** — `/harness-kit:new-spec` (spec / plan / context
  triplet), `/harness-kit:adr` (auto-numbered ADR), plus a spine `## Workflow`
  section (spec discipline / ADR / scratch).
- **Worktree workflow (ask-gated)** — introspect ASKS whether to enable a
  worktree-per-task workflow; `/harness-kit:worktree <slug>` isolates a task.
  Opinionated choices are asked, not assumed.
- **Resume loop** — `/harness-kit:handoff` writes a resume block;
  `/harness-kit:pickup` continues in a fresh session. Shipped only after a
  discriminating validation: a fresh session respected a non-obvious decision a
  no-handoff control missed 3/3.
- **Verification spine — seven read-only critics** routed on demand at each
  boundary: `instruction-critic` (is this the right ask?),
  `requirement-fidelity-critic` (spec drift from the original ask?),
  `change-verifier` (is the change complete?), `claim-checker` (overclaim? — with
  spine `§0.6 No overclaim`), `spec-reviewer` (PR vs its spec), `readability-critic`
  (can a human decide from this output?), `pr-shepherd` (is the PR mergeable?).
  Independent verification is the reliability lever; effect is marginal-but-real,
  not a guarantee — the only proven 100% check is a human.
- **`pr-shepherd` discovers the PR workflow** instead of assuming one — host / CI /
  bots are read at runtime, intent is pinned via a `pr_workflow` config
  (host / ci / merge_gate), it degrades gracefully when CI or a host CLI is absent,
  and never fabricates a MERGEABLE verdict without a defined gate.
- **Brand** — SVG logo, 1280×640 social-preview card, README hero, and an honest
  demo GIF (the real `/harness-kit:introspect` trigger, not a fabricated CLI).
- Tests: +spec (4) +adr (4) +worktree (4) → **49** across all suites.

### Changed
- The spine grew `§0.6 No overclaim` and `## Workflow` / `## Critics` sections;
  introspect seeds `worktree_workflow` and `pr_workflow` in `.claude/harness-kit.json`.

## [0.1.0] - 2026-06-26

First public release.

### Added
- `introspect` skill: scans a target repo's stack and generates a tailored harness
  (root `CLAUDE.md` spine + stack `*-architect` agent + `.claude/harness-kit.json`
  verify config + specs / ADR scaffolding).
- `detect.sh` detection engine (23-case suite) — layered-precedence detection of
  language / framework / test-runner / package-manager / monorepo / data-layer,
  plus typecheck/lint commands and polyglot per-subtree detection. Reads configs
  statically.
- `verify-loop` Stop hook — the feedback half of plan→work→verify→feedback, wired
  to the repo's real verify command. Non-blocking by default.
- `change-verifier` read-only critic agent.
- `protected-branch-guard` PreToolUse hook — configurable protected branches
  (env override > repo config > built-in default).
- `update-block.sh` — idempotent marked-block updater for safe introspect re-runs.
- `.claude/harness-kit.json` per-repo config; plugin + marketplace manifests, MIT
  license, community-profile files, CI. 37 tests.

[0.2.0]: https://github.com/jhlee0409/claude-harness-kit/releases/tag/v0.2.0
[0.1.0]: https://github.com/jhlee0409/claude-harness-kit/releases/tag/v0.1.0
