---
name: chrome-verify-checks
description: Use when verifying a chrome-extension/ change before reporting done. The canonical 7-check list (build → Service Worker vm.createContext compat → manifest sanity → per-site content-script DOM contract → message-passing trace → test suite → manual-load checklist) + verdict rules. chrome-extension/ is a strong-guard sub-context the maintainer cannot easily verify (MV3 SW quirks, per-site content-script breakage). Load when invoking chrome-verify or after any change in chrome-extension/. Triggers on chrome extension check, SW compatibility, MV3 check, content script behavior, extension load check.
---

# Chrome extension verification — 7 checks + manual-load checklist

`chrome-extension/` is a **strong-guard** sub-context — a frontend maintainer cannot easily catch MV3 service-worker quirks or per-site content-script breakage. This skill is the canonical verification: prove or disprove that the extension still loads, still talks across its boundaries, and still works on each target site — with real evidence.

You are a **fresh-context critic** when you load this: you did NOT make the change and you do NOT assume it works. **Falsify.**

## Setup

1. From `git diff --name-only`, confirm the change is in `chrome-extension/`.
2. Read the sub-context's own guide (TDD entry) and the manifest `chrome-extension/manifest.json` for the current permissions / matches / background entry.
3. Read `chrome-extension/shared/` for the message-passing protocol shape.

## The 7 checks (run every one — do not skip)

1. **Build the extension** — `cd chrome-extension && npm run build:dev`. Capture build output. Any error / warning = finding.

2. **Service Worker compat (`vm.createContext`)** — there is no dedicated sw-compat script in this repo. Inspect the SW entry from `chrome-extension/manifest.json` `background.service_worker`, then grep the entry file + its transitive imports for DOM-tied refs (`window.`, `document.`, `XMLHttpRequest`, `localStorage`) and for modules known to break under MV3 SW (axios with default adapter, any `node:*` import, anything pulling in `jsdom`). Any DOM-tied ref in the SW transitive closure = blocking finding. A `ReferenceError: window is not defined` at SW boot (visible from `chrome://extensions` on manual load) is the runtime symptom.

3. **Manifest sanity** — verify `manifest_version: 3`, `background.service_worker` path resolves to a real built file in `dist/`, every `host_permissions` entry is actually used by code (grep), every `matches` URL pattern resolves to an existing content-script file.

4. **Per-site content-script DOM contract** — for each target site the extension supports, grep the selector strings the content script depends on. If a selector is missing in the live DOM, the script silently no-ops on that site. List each selector + the file:line that owns it + the last-verified date if recorded. If a selector cannot be verified, flag it as CANT-VERIFY — manual browser load required by the maintainer.

5. **Message-passing trace** — for any new or changed `chrome.runtime.sendMessage` / `chrome.tabs.sendMessage` / `chrome.runtime.onMessage` handler, confirm both ends exist: a `sendMessage` without an `onMessage` listener for that type is broken; same for the reverse. Trace each message type end to end.

6. **Test suite** — `npm test` from `chrome-extension/`. Pass/fail counts.

7. **Manual-load checklist** — produce the exact step list the maintainer must run in Chrome (`chrome://extensions` → load unpacked from `dist/` → open each target site → confirm content script ran). The maintainer has to do this themselves; your job is to leave them a checklist they can run in <2 min, not a vague "test it in browser".

## Verdict rules — pick exactly 1 of 3 (all first-class)

- **PASS** — all 7 checks passed including the maintainer-confirmed manual-load checklist.
- **FAIL** — specific check(s) failed. List each with `file:line` and the failing evidence.
- **CANT-VERIFY** — manual-load is the only path to confirm a check and the maintainer has not run it yet. First-class verdict; do NOT default to "PASS (conditional)".

## Output (BLUF header first)

- **Conclusion**: one of the 3 above (+ one-line reason for CANT-VERIFY).
- **Check results** — table: item / PASS/FAIL/CANT-VERIFY / evidence (build output, selector match count, message-trace file:line, manual-load step result).
- **Defects** — every gap with `file:line`. Per-site silent no-ops are blocking.
- **Manual verification checklist** — concrete steps in `chrome://extensions`, exact URLs to open, exact DOM signals to look for. ≤ 2 min for the maintainer to run.

## Constraints (strong guard)

- Do NOT report "PASS" if any check could not be run.
- Build green is necessary but not sufficient — per-site content-script behavior requires either a real DOM snapshot or the maintainer's manual load.
- "Render ≠ works" — a passing build + clean console without a real selector match on the target site = CANT-VERIFY, not "PASS".
- Real prod hostnames in fixtures BANNED — use mock fixtures.
- **Citation-truth**: any file/contract you cite must be confirmed to exist via grep/read before it grounds a claim; a green test alone ≠ a verdict.
