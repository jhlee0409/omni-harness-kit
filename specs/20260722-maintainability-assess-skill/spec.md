# Spec: maintainability assess skill

- Status: Implemented (2026-07-22) — `skills/assess/{SKILL.md,assess.sh}` + `tests/assess_test.sh`
- Created: 2026-07-22
- Gate 0 resolved: (1) Tier-3 boundary ACCEPTED — a human-invoked one-shot skill
  that persists nothing is distinct from the rejected runtime metrics layer; the
  boundary is documented in `skills/assess/SKILL.md`. (2) deletion-bias — motivation
  = the research pass (`docs/roadmap.md`) + the maintenance thesis; the skill reuses
  `introspect/detect.sh` (no parallel detection) rather than adding a second engine.

## Problem / goal

Original ask (verbatim): *"코드베이스를 기준으로 LLM, AI, 사람이 더 관리하고 유지보수
하고 확장 하기 쉽도록 loop를 돌면서 퀄리티를 높히는거지. 퀄리티는 기술 스택과
아키텍쳐에 따라 다르지만."*

Reframed goal: give a codebase a **read-only, stack-parameterized maintainability
audit** that ranks concrete fixes so an LLM/agent/human can safely change, extend,
and maintain the code — where "quality" is measured by cheap structural signals,
not model taste, and the improvement *loop lives outside the machine* as a
human-gated cadence (audit → pick top finding → one spec → one PR → re-audit).

### Why the naive version is explicitly OUT (grounded)
- `skills/introspect/SKILL.md` §3 Tier 3: the kit ships **NO measurement /
  self-evolving / memory subsystem** — reliability comes from discipline + critics,
  not metrics. A stored score / dashboard / self-tuning daemon reintroduces exactly
  this and is rejected.
- `AGENTS.md`: *"큰 자율루프(다중 세대 자동진화) 대신 스펙 하나·PR 하나·사람 게이트로
  끊어서 간다 — Ouroboros류 다세대 자율루프 기각 (2026-07-21 실측)"* and error
  compounding (*"스텝당 95%도 10스텝 누적 시 ~60%"*). An autonomous quality loop
  is the rejected pattern; the human gate between audit and PR is what caps it.

## What "done" looks like

A human runs `/harness-kit:assess` in any supported-stack repo and gets, in one
pass, a **findings table** (each row: signal, `file:line` evidence, severity,
effort, the concrete fix) plus a **top-3 proposed PRs**. No score is stored, no
edit is applied, no state persists between runs. Re-running after a fix shows the
finding gone.

## Scope

- **In:**
  - New read-only skill (working name `assess`) that reuses `detect.sh` for stack.
  - A stack-parameterized rubric of **cheap, measurable** maintainability signals
    (not LLM vibes): shellcheck/lint/vet debt count, exported-symbol callsite
    fan-out (`lsp references`), dead exports, missing/failing verify command,
    untyped/undocumented public API, per-module test presence, oversized files,
    dependency cycles.
  - Output: findings table (severity × effort) + top-3 discrete fixes, each framed
    as its own PR; hand off to `new-spec` for the chosen one.
  - Stack matrix covering at least the stacks `detect.sh` already knows
    (shell / TS-Next / Python / Go / Rust / Ruby / JVM), degrading gracefully.
- **Out:**
  - Any stored score, dashboard, trend, or grade.
  - Any auto-fix / auto-edit / auto-PR. Findings are proposals; a human picks.
  - Any persistent/self-evolving/metrics subsystem or background loop (Tier-3).
  - Per-diff review — that is already `architecture-reviewer` / `readability-critic`
    / `change-verifier`. This is the codebase-WIDE, pre-work entrypoint they lack.

## Acceptance

- Running the skill on THIS repo (shell stack) surfaces real findings with
  `file:line` evidence (e.g. any shellcheck-warning debt, scripts with no
  `*_test.sh`, oversized scripts) and proposes 3 concrete PRs — verified by a real
  run, not a fixture.
- Running on a TS repo and a Python repo yields stack-appropriate signals (typed
  export / mypy debt), proving parameterization — verified by real runs.
- No file is written/edited by the skill except an optional findings report the
  user asked for; re-run is idempotent (no stored state).
- `readability-critic` verdict on the findings table = PROCEED (a human can decide
  from each row).

## Risks / open questions

- `[NEEDS CLARIFICATION: Tier-3 boundary]` — this is a human-invoked one-shot
  *assessment skill*, not a generated/promised runtime metrics layer, so it is
  technically distinct from the §3 Tier-3 prohibition. But it is ADJACENT. Decide:
  accept the distinction explicitly (document it in the skill + SKILL §3), or judge
  it too close and drop the feature. **Blocks leaving Draft.**
- `[NEEDS CLARIFICATION: deletion-bias gate]` — `AGENTS.md` requires a new
  machine to cite (a) a real maintenance-pain incident as motivation and (b) an
  equivalent deletion/merge. Candidate: fold overlapping checks so `assess` reuses
  `architecture-reviewer`'s taxonomy rather than duplicating it, and/or retire any
  redundant prose. **Blocks leaving Draft.**
- Signal quality: cheap structural signals can false-positive (a legitimately large
  generated file, a cache/broker dep). Each signal needs a documented false-positive
  escape, mirroring `detect.sh`'s existing 0.x heuristic caveats.
- Naming/entrypoint collision with `introspect` (both stack-aware, read the repo) —
  confirm `assess` is a distinct verb (assess existing quality vs. tailor a harness).
