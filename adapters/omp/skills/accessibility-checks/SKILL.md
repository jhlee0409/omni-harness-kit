---
name: accessibility-checks
description: Use when verifying accessibility (WCAG 2.2 AA) of a rendered UI in a real browser before reporting done — the omp-native replacement for the chrome-devtools a11y plugin. Runs a concrete ordered checklist with omp's builtin `browser` tool (open tab → `tab.evaluate` DOM query / `elementFromPoint` / `getComputedStyle` / `getBoundingClientRect` / `tab.screenshot`), NOT chrome-devtools MCP or axe-in-CI self-report. Every criterion gets PASS/FAIL WITH the measured value (contrast ratio, px size, tabindex order); computed-style/rect is the evidence, source-reading alone is INVALID. Load when auditing a11y, before claiming a UI is accessible. Triggers on accessibility, a11y, WCAG, keyboard navigation, contrast, screen reader, focus, tap target.
---

# Accessibility checks — WCAG 2.2 AA, measured in a real browser

Accessibility is a MEASURED property of the rendered DOM, never a source-reading guess. `aria-label` in JSX proves nothing if the runtime node is `display:none`, the contrast ratio is 3.9:1, or the tap target renders at 32px. This skill runs the audit against the LIVE page with omp's native `browser` tool and cites the number for every verdict. "looks accessible" is BANNED — every row carries a measured value or it is CANT-VERIFY.

## Setup

1. `git diff --name-only` → identify the changed route/component. Read its `DESIGN.md` (tokens/tone) if present.
2. Start the dev server on its own port; wait for a stable anchor before probing (a cold compile is not "down").
3. `browser` action `open` the changed route. Then drive every check with action `run` + `tab.evaluate`.
4. All snippets below run inside `tab.evaluate(() => { ... })` and RETURN a JSON value — that returned value is the evidence you cite.

## 1. Semantic structure — landmarks + heading order (WCAG 1.3.1, 2.4.6)

```js
tab.evaluate(() => {
  const landmarks = [...document.querySelectorAll('header,nav,main,aside,footer,[role="banner"],[role="navigation"],[role="main"],[role="contentinfo"]')].map(e => e.tagName+ (e.getAttribute('role')?`[${e.getAttribute('role')}]`:''));
  const headings = [...document.querySelectorAll('h1,h2,h3,h4,h5,h6')].map(h => ({ lvl:+h.tagName[1], text:h.textContent.trim().slice(0,40) }));
  return { mainCount: document.querySelectorAll('main,[role=main]').length, landmarks, headings };
})
```
FAIL if: `mainCount !== 1`; no h1; heading levels skip (h2→h4). Cite the actual level sequence.

## 2. Keyboard nav + focus order + visible focus ring (WCAG 2.1.1, 2.4.3, 2.4.7)

- Enumerate the tab order and confirm it follows DOM/visual order (no positive `tabindex` reordering surprises):
```js
tab.evaluate(() => [...document.querySelectorAll('a[href],button,input,select,textarea,[tabindex]')]
  .filter(e => !e.disabled && e.offsetParent !== null)
  .map(e => ({ tag:e.tagName, ti:e.tabIndex, label:(e.textContent||e.value||e.ariaLabel||'').trim().slice(0,30) })))
```
FAIL if any positive `tabIndex > 0` (manual reorder trap), or a control is reachable by mouse but absent from this list.
- Visible focus ring — focus each interactive node and read `:focus-visible` computed style; a ring is only real if `outline-width`/`box-shadow` actually changes on focus:
```js
tab.evaluate(() => {
  const el = document.querySelector('button');           // repeat per control class
  el.focus();
  const s = getComputedStyle(el);
  return { outlineWidth:s.outlineWidth, outlineStyle:s.outlineStyle, boxShadow:s.boxShadow };
})
```
FAIL if focused control shows `outline-style:none` AND no distinguishing `box-shadow` (invisible focus). `outline:0` with no replacement = FAIL.

## 3. Color contrast — compute the REAL ratio (WCAG 1.4.3, 1.4.11)

NEVER eyeball. Read `color` + effective background from `getComputedStyle`, compute the WCAG ratio, cite the number.
```js
tab.evaluate(() => {
  const lum = ([r,g,b]) => { const f=v=>{v/=255; return v<=0.03928?v/12.92:((v+0.055)/1.055)**2.4;}; return 0.2126*f(r)+0.7152*f(g)+0.0722*f(b); };
  const rgb = s => s.match(/\d+(\.\d+)?/g).map(Number).slice(0,3);
  const bgOf = el => { for(let n=el; n; n=n.parentElement){ const b=getComputedStyle(n).backgroundColor; if(b && !/rgba?\(0, 0, 0, 0\)|transparent/.test(b)) return b; } return 'rgb(255,255,255)'; };
  const ratio = el => { const s=getComputedStyle(el); const L1=lum(rgb(s.color)), L2=lum(rgb(bgOf(el))); return ((Math.max(L1,L2)+0.05)/(Math.min(L1,L2)+0.05)); };
  return [...document.querySelectorAll('p,span,a,button,label,h1,h2,h3,li')]
    .filter(e => e.textContent.trim() && e.offsetParent)
    .map(e => { const s=getComputedStyle(e); const px=parseFloat(s.fontSize); const large = px>=24 || (px>=18.66 && +s.fontWeight>=700);
      return { text:e.textContent.trim().slice(0,25), ratio:+ratio(e).toFixed(2), px, large, need: large?3:4.5 }; })
    .filter(r => r.ratio < r.need);
})
```
Threshold: 4.5:1 normal text, 3:1 large text (≥24px, or ≥18.66px bold) and UI components/graphics. Any returned row = FAIL, cite `ratio` vs `need`. (This is opacity-blind — for `rgba`/overlay text also `tab.screenshot` and note it as a caveat.)

## 4. Tap-target size ≥44px (WCAG 2.5.8 AA)

```js
tab.evaluate(() => [...document.querySelectorAll('a[href],button,input,select,[role=button],[onclick]')]
  .filter(e => e.offsetParent !== null)
  .map(e => { const r=e.getBoundingClientRect(); return { label:(e.textContent||e.ariaLabel||'').trim().slice(0,25), w:Math.round(r.width), h:Math.round(r.height) }; })
  .filter(r => r.w < 44 || r.h < 44))
```
FAIL for each returned control (cite w×h) unless it qualifies for the WCAG spacing/inline exception. Verify with `elementFromPoint(cx, cy)` that the visible hit area actually resolves to that control, not an overlay.

## 5. ARIA roles/states/names + form labels + errors (WCAG 1.3.1, 3.3.1, 3.3.2, 4.1.2)

```js
tab.evaluate(() => {
  const nameOf = e => e.getAttribute('aria-label') || (e.getAttribute('aria-labelledby') && document.getElementById(e.getAttribute('aria-labelledby'))?.textContent?.trim()) || (e.labels && e.labels[0]?.textContent?.trim()) || e.textContent.trim();
  const iconBtns = [...document.querySelectorAll('button,[role=button]')].filter(b => !nameOf(b)).map(b => b.outerHTML.slice(0,60));
  const inputs = [...document.querySelectorAll('input,select,textarea')].filter(i => i.type!=='hidden').map(i => ({ type:i.type, hasLabel:!!nameOf(i), required:i.required, invalid:i.getAttribute('aria-invalid'), describedby:i.getAttribute('aria-describedby') }));
  return { unnamedControls: iconBtns, inputsMissingLabel: inputs.filter(i=>!i.hasLabel) };
})
```
FAIL if: any interactive control has no accessible name (icon-only button); any form field lacks a programmatic label; an error state sets no `aria-invalid`/`aria-describedby` pointing at the message. Also sanity-check `tab.ariaSnapshot()` — roles must match intent (a `div onclick` with no role = FAIL). Trigger a validation error and re-run to confirm the error is announced.

## 6. Images alt + reduced-motion + reflow at 320px (WCAG 1.1.1, 2.3.3/1.4.4, 1.4.10)

```js
tab.evaluate(() => ({
  imgsNoAlt: [...document.images].filter(i => !i.hasAttribute('alt')).map(i => i.src.slice(-40)),
  decorativeOk: [...document.images].filter(i => i.alt==='' ).length,
  reducedMotionHonored: matchMedia('(prefers-reduced-motion: reduce)').matches
}))
```
- Alt: FAIL for any `<img>` missing an `alt` attribute (decorative = `alt=""` is correct, informative empty = FAIL).
- Reduced motion: set the browser open with reduced-motion emulation (or check the CSS has a `@media (prefers-reduced-motion: reduce)` block that stops animation) — infinite auto-animation with no reduce guard = FAIL.
- Reflow: re-`open`/resize the tab to 320px width, then `tab.evaluate(() => ({ hScroll: document.documentElement.scrollWidth > window.innerWidth + 1, overflow: [...document.querySelectorAll('*')].filter(e=>e.scrollWidth>window.innerWidth+1).length }))`. Horizontal scroll at 320px = FAIL. Screenshot at 320px as artifact.

## 7. Interactive-state sweep — audit the OPEN state too

A closed-state-only audit is INVALID — a common failure mode is checking an accordion/menu/modal/dropdown only while CLOSED and calling it done. For each stateful component, drive it through **closed → open → hover → disabled** and re-run checks 2/3/4/5 in EACH state:
- Open the menu/modal (`tab.click`), then re-check contrast, tap-target, focus trap (focus must move into and stay within an open modal), and `aria-expanded`/`aria-modal`.
- `elementFromPoint()` on all 4 corners of the opened surface to confirm it is actually visible and not clipped by an `overflow:hidden` parent (rect-normal ≠ visible).
- Disabled controls: confirm `aria-disabled`/`disabled` present AND not focus-reachable.
Contrast/size measured only in the closed state does NOT cover the open state — state it explicitly.

## Verdict rules — pick exactly 1 of 3 per criterion (all first-class)

- **PASS** — measured value meets the WCAG threshold. Cite the number (ratio 5.8:1, 48×48px, tabindex 0…n in order).
- **FAIL** — measured value violates the threshold. Cite the number + the offending selector/text.
- **CANT-VERIFY** — could not measure (control not rendered, state not reachable, opacity/overlay defeats the compute). NOT "PASS with caveats".

## Output (BLUF first)

- **Conclusion**: overall PASS / FAIL / CANT-VERIFY (FAIL if any criterion failed).
- **Check results**: table — criterion (1–7), PASS/FAIL/CANT-VERIFY, **measured value** (ratio, px, order, name), evidence (the `tab.evaluate` JSON return or screenshot path). A row with no measured value is CANT-VERIFY, never PASS.
- **Defects**: per failure — selector + measured value vs required threshold + which WCAG SC + a screenshot of the state.
- Attach screenshots of key states (default + open state + 320px reflow).

## Constraints

- **Source-reading alone is INVALID.** `aria-label` in JSX / a Tailwind class in the file is NOT evidence. The evidence is the runtime `getComputedStyle` / `getBoundingClientRect` / `elementFromPoint` return from the live DOM.
- **Cite the number, never eyeball.** No "contrast looks fine" — write "contrast 4.9:1 (threshold 4.5:1) PASS" or it is CANT-VERIFY.
- **Closed-state-only audit = CANT-VERIFY for the open state.** Sweep every interactive state (check 7).
- **This is not the axe CI gate.** axe-core in CI is a deterministic floor; this skill is the human-judgment layer (focus-order intent, label semantics, open-state coverage) on top of it — do not just re-report axe output.
- **rect-normal ≠ visible.** Always confirm with `elementFromPoint` that the measured node is the one actually rendered at that point.
