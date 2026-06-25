# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres
to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `introspect` skill: scans a target repo's stack and generates a tailored harness
  (root `CLAUDE.md` spine + stack `*-architect` agent + specs/ADR scaffolding).
- `detect.sh` detection engine with a 14-case test suite — layered-precedence
  detection of language / framework / test-runner / package-manager / monorepo /
  data-layer; reads configs statically, upward-crawl + per-subtree for monorepos.
- `change-verifier` read-only critic agent.
- `protected-branch-guard` PreToolUse hook (asks before commit/push on a protected branch).
- Plugin + marketplace manifests, MIT license, community-profile files, CI.

[Unreleased]: https://github.com/jhlee0409/claude-harness-kit/commits/main
