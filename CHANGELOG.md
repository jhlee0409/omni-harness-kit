# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres
to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-06-26

First public release.

### Added
- `introspect` skill: scans a target repo's stack and generates a tailored harness
  (root `CLAUDE.md` spine — including an explicit `## Agents` routing block so the
  main agent delegates to the right agent without being named — + stack `*-architect`
  agent + `.claude/harness-kit.json` verify config + specs/ADR scaffolding).
- `detect.sh` detection engine with a 23-case test suite — layered-precedence
  detection of language / framework / test-runner / package-manager / monorepo /
  data-layer, plus **typecheck/lint command** detection and **polyglot per-subtree**
  detection (a python root with a node subtree is no longer mislabelled). Reads
  configs statically.
- `verify-loop` Stop hook — the feedback half of plan→work→verify→feedback, wired
  to the repo's real verify command via the generated `.claude/harness-kit.json`.
  Non-blocking by default (reminds, does not auto-run); opt into enforcement with
  `"blocking": true`. 4-case isolation test suite.
- `new-spec` + `adr` workflow skills — `/harness-kit:new-spec <name>` scaffolds a
  spec triplet (`specs/<date>-<name>/{spec,plan,context}.md`); `/harness-kit:adr
  <title>` records the next numbered ADR (`docs/adr/NNNN-*.md`). The generated
  spine gains a `## Workflow` section (spec discipline / ADR / scratch). Reliable
  output comes from this structured discipline, not a measurement system.
- `worktree` skill + **ask-gated** workflow — introspect now ASKS (via
  AskUserQuestion) whether the repo wants a worktree-per-task workflow; if yes the
  spine gets a worktree rule and `.claude/harness-kit.json` records
  `worktree_workflow: true`. `/harness-kit:worktree <slug>` creates
  `../<repo>-<slug>` on its own branch. Opinionated choices are asked, not assumed.
- `change-verifier` read-only critic agent.
- `protected-branch-guard` PreToolUse hook (asks before commit/push on a protected
  branch). Branches are configurable per repo via `.claude/harness-kit.json`
  `protected_branches` — precedence: env override > repo config > built-in default.
  Now reads the branch from `CLAUDE_PROJECT_DIR` (not the hook's cwd).
- `.claude/harness-kit.json` is the single per-repo config for both hooks
  (`verify_command`, `blocking`, `protected_branches`).
- `update-block.sh` — idempotent marked-block updater so an introspect re-run
  replaces its own `CLAUDE.md` block instead of stacking copies.
- Test suites: detection (23) + verify-loop (4) + guard (6) + update-block (4); CI
  runs every `tests/*_test.sh`.
- Plugin + marketplace manifests, MIT license, community-profile files, CI.

[0.1.0]: https://github.com/jhlee0409/claude-harness-kit/releases/tag/v0.1.0
