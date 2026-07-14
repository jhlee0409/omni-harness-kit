---
description: Force render verification when editing UI files — auto-fires (no skill naming needed)
condition: ["*.tsx", "*.jsx", "*.vue", "*.svelte"]
interruptMode: prose-only
---
A UI component was edited. Before claiming "fixed / it renders / not broken":
- Probe the real browser: `elementFromPoint()` at 4 corners + an interactive-state
  sweep (closed/open/hover/disabled). `getBoundingClientRect()` alone is banned — a
  fine rect can still be clipped by a parent `overflow:hidden`.
- `tsc` / build passing = static OK ≠ render OK.
- Route visual/runtime verification to `ui-verify`, accessibility to
  `accessibility-auditor`, craft judgment to `design-critic`.
