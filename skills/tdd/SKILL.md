---
name: tdd
description: >-
  Drive a single behavior change with Kent Beck's red → green → refactor loop —
  write the failing test FIRST, confirm it fails for the right reason, implement
  the minimum to pass, then refactor. Use when building a feature or fixing a bug
  test-first, or when the user says "TDD", "red-green-refactor", "테스트 먼저",
  "실패 테스트부터". For a hands-off loop that owns the whole cycle, delegate to
  the `tdd-runner` agent instead.
argument-hint: "[behavior to build]"
allowed-tools: Read, Grep, Glob, Bash, Edit, Write
---

# tdd

One behavior at a time. Never write implementation before a failing test for it.

## The loop
1. **🔴 Red** — write the smallest test that expresses the next behavior. Run it
   with the repo's runner (the `verify_command` / test command from
   `.claude/harness-kit.json`). Confirm it FAILS, and fails for the RIGHT reason
   (asserting the missing behavior — not a typo / import error). A test that
   passes immediately, or fails for the wrong reason, tells you nothing.
2. **🟢 Green** — write the MINIMUM implementation to make it pass. No extra
   features, no speculative generality. Run the test; confirm green.
3. **🔵 Refactor** — with the test green, clean up (names, duplication, shape)
   without changing behavior. Re-run; stay green.

## Discipline
- **Structural and behavioral changes never mix in one commit** (Tidy First).
- Keep the red→green step small — minutes, not an hour. If it's big, the test is
  too coarse; split it.
- A real run is the evidence: show the runner output (red, then green), not a claim.
- Mandatory for library / backend / CLI code, where there's no UI to eyeball.
