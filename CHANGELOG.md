# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres
to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2026-06-26

The introspect-first thesis extended to verification + build discipline, plus a
full cross-file coherence audit (identity / version / detection-gap fixes).

### Added
- **Stack-conditional critics** — `introspect` now generates a `db-verify` critic
  **only when a data layer is detected** (tailored to the real store: MongoDB
  `$exists` counts / Postgres `information_schema` / Redis) and a `ui-verify` critic
  **only when a frontend framework is detected** (tailored to the real dev command).
  Generated like the architect (not shipped static) because their commands are
  stack-specific — the introspect-first thesis applied to verification. The kit does
  **not** bundle the DB client or browser driver these need; introspect surfaces the
  one command to add them as guidance (§5 "External setup you may need") and never
  copies an external tool into the repo. New spine slot `{{CONDITIONAL_CRITICS}}`;
  replaces the old dead references to non-existent UI skills. +20 tests (→ 69).
- **Build-discipline layer** — `/harness-kit:tdd` + the `tdd-runner` agent
  (red → green → refactor, test-first), `/harness-kit:diagnose` (reproduce →
  minimize → hypothesize → fix the cause → regression-test),
  `/harness-kit:karpathy-guidelines` (surgical changes, no overcomplication,
  verifiable success), and the `architecture-reviewer` critic (layers / smells /
  invariants — the review pair of the generated `<stack>-architect`). Closes the
  build-discipline gap: the kit had verification + artifacts but not the
  test-first / debug discipline. The spine `## Workflow` gains a Build bullet and
  `## Critics` gains `architecture-reviewer` (eight critics).

### Fixed
- **Coherence audit remediation** (a full cross-file / per-stack-generation sweep):
  - **Identity** — `plugin.json` author, `marketplace.json` owner, and `LICENSE`
    copyright now use the publishing identity (`Jack Lee` / `github.com/jhlee0409`);
    the prior placeholder leaked an unrelated account onto the distribution surface.
  - **Python data layer detected** — `detect.sh` now recognizes a Python DB client
    (`pymongo` / `motor` / `sqlalchemy` / `psycopg` / `redis`), so a FastAPI + Mongo
    backend correctly gets a `db-verify` critic (previously DB detection was
    Node-only — the canonical backend stack silently shipped no `db-verify`).
  - **Measurement vapor removed** — `introspect` no longer mentions a Tier-3
    measurement subsystem or an `--enable-measurement` flag (neither exists); this
    matches the "no measurement system" thesis the README/CHANGELOG state.
  - **No dash sentinel** — an absent `dev`/`build`/`test` script now yields an empty
    field, not a literal `-` that could leak into a generated `{{DEV_COMMAND}}`.
  - **Monorepo** — `introspect` re-runs `detect.sh` per member (the root scan only
    names members); doc/comment honesty fixed to match.
  - Doc/template fixes: README hook paths (`hooks/scripts/…`), the five-key config
    schema noted, the resume-block fields moved inside the `resume:*` markers, the
    guard's default branches de-personalized, and a CI identity/version guard added.

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

[0.3.0]: https://github.com/jhlee0409/claude-harness-kit/releases/tag/v0.3.0
[0.2.0]: https://github.com/jhlee0409/claude-harness-kit/releases/tag/v0.2.0
[0.1.0]: https://github.com/jhlee0409/claude-harness-kit/releases/tag/v0.1.0
