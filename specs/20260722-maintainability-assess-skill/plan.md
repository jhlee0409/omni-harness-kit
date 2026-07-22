# Plan: maintainability assess skill

Dependency-ordered tasks. Surface progress as **N/M** as you go; a "done" tone
before all tasks are consumed is not allowed.

**Gate 0 blocks everything below** — resolve both `[NEEDS CLARIFICATION]` in
spec.md (Tier-3 boundary + deletion-bias) with the maintainer before any code.

- [ ] 1. **Gate 0 — decisions.** Get maintainer ruling on (a) Tier-3 boundary:
      proceed as one-shot skill vs. drop; (b) deletion-bias: name the motivating
      pain + the equivalent deletion/merge. Record in spec.md, flip Status → Ready.
- [ ] 2. **Rubric contract.** Define the stack matrix: per stack, the exact cheap
      signals + the command/probe that measures each + its false-positive escape.
      One table, single source of truth (mirror `render.sh`'s STORES-table pattern).
- [ ] 3. **Assessment engine.** A read-only script (reuse `detect.sh` for stack)
      that runs the rubric probes (lint/vet debt counts, `lsp references` fan-out,
      dead exports, verify-cmd presence, file-size outliers) and emits findings as
      structured data (JSON-ish, like `detect.sh`) — no edits, no stored state.
- [ ] 4. **Skill + presentation.** `skills/assess/SKILL.md` that runs the engine,
      renders the findings table (severity × effort) + top-3 PR proposals, and
      hands the chosen fix to `new-spec`. Keep the human gate explicit.
- [ ] 5. **Tests.** `tests/assess_test.sh` with throwaway fixtures per stack
      (mirror `detect_test.sh`): assert findings fire on planted debt and stay
      silent on clean fixtures. Idempotent re-run assertion.
- [ ] 6. **Docs + wiring.** SKILL §3 Tier-3 note documenting the accepted
      boundary; CHANGELOG `[Unreleased]`; register the skill in the plugin
      manifests if skills are enumerated there.
- [ ] 7. **Dogfood.** Run on THIS repo + one TS + one Python repo; capture the real
      findings tables in `docs/dogfood-log.md` (evidence, like the existing entries).

## Verification

<!-- The exact command(s) that prove each slice works. -->
- Engine/skill: real run on this repo → findings table with `file:line` evidence +
  3 PR proposals (acceptance criterion 1), not a fixture.
- Parameterization: real runs on a TS and a Python repo show stack-specific signals.
- `bash tests/assess_test.sh` green; full CI loop
  `for t in tests/*_test.sh; do bash "$t"; done` + `shellcheck -S warning` clean.
- `readability-critic` on the findings table returns PROCEED.
