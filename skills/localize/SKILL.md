---
name: localize
description: >-
  Resolve a change request into an EXACT edit target before touching code, then
  gate the edit on tests — the localize → edit → validate loop. Use for a bug fix,
  an issue, or a feature change where the right files/symbols are not already
  obvious, or when the user says "이거 고쳐줘", "어디를 고쳐야 해?", "fix this
  issue", "where does this live?". Produces a localization artifact (targets +
  evidence + uncertainty) first; edits only after it, validates with a focused
  test then a regression run.
argument-hint: "<issue / change description>"
allowed-tools: Read, Grep, Glob, Bash, Edit, Write
---

# localize — localize → edit → validate

Do NOT start editing from the first plausible file. Empirically, a staged
**localize → repair → validate** loop resolves real repository issues at a
fraction of the cost of broad autonomous exploration (Agentless, arXiv
2407.01489), and the benchmark contract for "resolved" is a change whose tests
pass (SWE-bench, arXiv 2310.06770). This skill enforces that discipline: name the
target with evidence, make the minimal edit, then prove it with tests.

## 1. LOCALIZE — produce the target before editing

From the request, find the exact edit site(s). Do NOT edit in this phase.

- Extract the concrete signals from the request: error text, stack trace,
  symptom, endpoint / field / component name, the file it mentions.
- Search from those signals: `grep` the error string / symbol; `glob` the module;
  read the suspected files. For a symbol you will change, run
  `/harness-kit:blast-radius <symbol>` to enumerate everything that depends on it,
  so the edit scope is known up front (not discovered after a half-fix).
- If tests exist, use the failing test (or write one that reproduces the symptom)
  to point at the fault — a failing test IS localization evidence.

**Localization artifact (write it down, BLUF):**
- **Targets**: each `file:line` + symbol you intend to change, with the evidence
  that put it there (the grep hit / the failing test / the reference).
- **Impact**: the blast-radius set for any changed signature (callsites that must
  move together).
- **Uncertainty**: what you are NOT sure about + the candidate you'd check next.
  Non-empty is honest; a confident-but-wrong target is the failure mode here.

## 2. EDIT — minimal, scoped to the target

Make the smallest change that addresses the request at the localized site. Update
every callsite the blast-radius set named — do not leave a half-migrated signature.
Match the surrounding idioms.

## 3. VALIDATE — tests gate the change

- **Focused first**: run the specific test covering the change (or the reproducer
  from step 1). It must go from failing → passing.
- **Regression next**: run the stack's test command (the repo's detected
  `test_cmd`). Report pass/fail counts.
- **Real-run evidence** for a "feature works" claim: a real input → real output,
  not just green unit tests (per the kit's `0.3 No premature done`).
- Record the commands run + outcomes in the handoff / verify artifact.

## Constraints

- The localization artifact (step 1) is REQUIRED before any edit — no "edit first,
  find the rest later".
- A change is not done until its focused test passes AND the regression run is
  green (or the failures are pre-existing and named). "Compiles" / "200 OK" is not
  validation.
- No blind retries: if two edits don't pass, re-localize (the target was wrong),
  don't loop on the same site — broad retry loops compound error, they don't fix
  localization.
- Bounded autonomy: this is one change → one validation → the human gate, not an
  open-ended fix loop.
