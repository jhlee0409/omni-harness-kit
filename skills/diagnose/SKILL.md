---
name: diagnose
description: >-
  Disciplined diagnosis loop for a hard bug or performance regression —
  reproduce → minimize → hypothesize → instrument → fix the cause → regression-test.
  Use when something is broken / throwing / failing or regressed, or when the user
  says "diagnose this", "debug this", "버그 진단", "왜 안 되지", "디버깅".
argument-hint: "[the symptom]"
allowed-tools: Read, Grep, Glob, Bash, Edit, Write
---

# diagnose

Don't guess-and-patch. Find the real cause, then fix it.

## Loop
1. **Reproduce** — get a reliable, minimal repro. A bug you can't reproduce, you
   can't confirm you fixed. Capture the exact failing command + output.
2. **Minimize** — strip the repro to the smallest input / path that still fails.
   The minimal case usually names the cause.
3. **Hypothesize** — state ONE falsifiable hypothesis ("X is null because Y returns
   early when Z"), not a vibe — a claim a check can disprove.
4. **Instrument** — add the cheapest probe (a log, an assert, a breakpoint) that
   confirms or kills the hypothesis. Let evidence decide, not intuition. Killed →
   back to step 3.
5. **Fix the cause**, not the symptom. A narrow patch that hides the symptom while
   the cause remains is a stopgap — label it as one if you must ship it.
6. **Regression-test** — write a test that fails before the fix and passes after,
   so the bug can't silently return.

## Discipline
- Verify against the REAL system (a real query / real run), never inferred from
  code alone.
- One hypothesis at a time; record what you ruled out.
- "Looks fixed" is not fixed — the regression test (red → green) is the proof.
