---
name: ui-verify-checks
description: Use when verifying a frontend UI change in a real browser before reporting done. The canonical 7-check list (real auth → render≠behavior → scroll containment → primary-button reachability → selection-state sync → responsive → console) + environment fail-fast rule (transport-unreachable vs HTTP error distinction) + verdict rules. Load when invoking ui-verify, after any UI change in the frontend app, before claiming any user-visible feature works. Triggers on UI check, design broken, scroll check, button not visible, preview not updating.
---

# UI verification — 7 real-browser checks

A UI change is NOT done until it renders correctly in a real browser. The recurring failure modes: broken scroll, off-screen buttons, selection state that does not propagate, render passing while behavior is broken. This skill catches them before work is reported complete.

## Setup

1. Identify which sub-context changed from `git diff --name-only`.
2. Read that sub-context's `DESIGN.md` first. Separate stacks may have separate tones and tokens; verify against the right one.
3. Identify the changed route/page from the diff.
4. Start the dev server if it is not running (`npm run dev` / `vite` on the app's own port). Wait for it to be ready before navigating.

## Environment fail-fast rule (CRITICAL — distinguishes "environment" from "UI defect")

The trigger is the server being UNREACHABLE at the **TRANSPORT layer**: the dev server won't start, or a probe of the backend base URL returns connection-refused / ECONNREFUSED / DNS-fail / timeout — the process is not up, there is NO HTTP response at all.

An HTTP error is **NOT** environment failure: a 4xx/5xx (even a blanket one) means the server IS up and RESPONDING — a 500 can be a genuine backend bug, and a blanket 401/403 is usually fake-auth / wrong-cred → CANT-VERIFY (see Checks), NOT environment.

**Before declaring "environment", PROBE the transport**:
```
curl -sS -o /dev/null -w '%{http_code}' <backend base URL>
```
- No HTTP code (refused / timeout) = environment fail-fast.
- ANY code (even 500) = server is up, stay on the §Checks verdict (FAILURE / CANT-VERIFY).

On a genuine transport-unreachable signal STOP: report `environment problem — server/backend process not running (transport-unreachable), environment must be fixed first` in ONE line and end. Do NOT retry endlessly, re-screenshot, or fall into a long static-analysis fallback — one fail-fast verdict, then stop.

A cold `next dev` / `vite` compile is NOT "down": `browser_wait_for` a stable anchor first; only a refused transport AFTER that is environment.

## Scope boundary — accessibility is NOT your job

a11y for operator surfaces is enforced DETERMINISTICALLY by the CI a11y gate (axe-core runs in CI, not by you, and the merge gate reads its conclusion). Do NOT run axe and self-report it here — stay focused on render + behavior. Design-intent a11y (focus-order intent, label semantics) is `design-critic`'s human layer on top of the axe CI signal.

## The 7 checks (run every one — do not skip)

1. **Real auth, not fake fixtures** — log in with a real seed account against a real backend. Fake JWT / fake storage keys / synthetic silent audio → verdict for any feature behavior is CANT-VERIFY, NOT "PASS". A test environment that makes failure unfalsifiable is no test at all.

2. **Render is not behavior** — "the page renders, the button is in the viewport, the console is clean" only proves the UI was drawn. It is NOT evidence the feature works. The feature works only when real input → real output is demonstrated (e.g. real inputs → click the primary action → a real artifact lands in the result page). Without that artifact, the verdict for "the feature works" is CANT-VERIFY.

3. **Scroll containment** — is scroll applied at the right level? A page-wide scroll that should have been a panel-level scroll is a defect. Confirm the intended scroll region scrolls and the rest stays fixed.

4. **Primary-button reachability** — the save / submit / primary action button must be reachable and clickable without being pushed off-screen. Scroll to it and confirm it is in the viewport and clickable.

5. **Selection-state sync** — when a selection is made in a sub-component (e.g. a bottom strip), confirm it is reflected in the parent (e.g. the top preview). This is a recurring defect — test it explicitly.

6. **Responsive** — resize to a desktop width and a narrow width; confirm nothing overflows or becomes unreachable.

7. **Console** — `browser_console_messages` — report any error. A 401 / 403 / 5xx on a real backend call is a FAILURE, not "environment limitation".

## Verdict rules — pick exactly 1 of 3 (all first-class)

- **PASS** — all 7 checks passed AND a real execution artifact was produced (real output file, real HTTP response body, real authenticated screenshot).
- **FAIL** — specific check(s) failed. List each with selector + screenshot.
- **CANT-VERIFY** — real-run evidence absent OR environment prevents exercising the real path. NOT "PASS with caveats".

## Output (BLUF header first)

- **Conclusion**: one of the 3 above.
- **Check results**: table — check name, PASS/FAIL/CANT-VERIFY, evidence (file path, screenshot path, real HTTP response body, real artifact produced). Evidence is required — a row with no evidence is CANT-VERIFY.
- **Defects**: for each failure, the concrete problem + selector + a screenshot.
- Attach screenshots of the key states + the actual artifact produced.

## Constraints

- Do NOT report "PASS" if any check fails or could not be run.
- **Evidence-based verdict only** — your own narration ("looks good", "should work", "expected to render") is NOT evidence. No artifact = CANT-VERIFY.
- **"Environment limitation" excuse BANNED** — never report "fake auth / fake key / synthetic silent audio limitation, 0 feature errors". If the environment is fake and prevents exercising the real path, the verdict is CANT-VERIFY — not "PASS (conditional)".
- **Render ≠ works** — a passing scroll/viewport/console checklist with no real input→output demonstration means the verdict for *the feature* is CANT-VERIFY.
- **Citation-truth**: any file/contract you cite must be confirmed to exist via grep/read before it grounds a claim.
