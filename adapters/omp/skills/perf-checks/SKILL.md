---
name: perf-checks
description: Use when investigating or optimizing performance in a real browser/build/DB before reporting a fix — the omp-native replacement for the chrome-devtools LCP/memory-leak plugins. Ordered MEASURE-before-and-after methodology (Core Web Vitals → LCP breakdown → bundle → render → DB query → caching → memory leaks) driven by the omp `browser` (`tab.evaluate` + CDP), `bash`, and `lsp` builtins. Every claim carries a before/after NUMBER — "should be faster" is banned. Load before claiming any perf improvement. Triggers on performance, LCP, bundle, query optimization, slow, memory leak, render optimization, profiling, CWV.
---

# Performance — measure-before-and-after methodology (omp-native)

A performance change is NOT done until a **before number and an after number** prove it. Prediction ("this should be faster") is not evidence. This skill runs on omp builtins only: `browser` (puppeteer `page`/`tab`, incl. CDP session), `bash`, `lsp`. No external MCP.

**Iron rule:** every claim = a measured delta. `LCP 3.9s → 1.6s (-59%)`, `bundle 842KB → 410KB`, `retained heap +38MB over 3 iterations → +0.4MB`. A verdict with no number = INVALID.

## Setup

1. Start the dev/prod-preview server on its own port; wait for a stable anchor before measuring. Measure a **production build** where possible — dev bundles distort LCP/bundle numbers.
2. `browser` open the target route. Warm once (discard first load), then measure — cold-compile noise is not the signal.
3. Take **3 runs** of any browser metric; report the median, not a lucky min.

## The ordered checks (measure at each; record the number)

1. **Core Web Vitals** — in the live page via `tab.evaluate`, read real entries, not guesses:
   - LCP: `new PerformanceObserver` on `{type:'largest-contentful-paint',buffered:true}` → last entry `.renderTime||.loadTime` and `.element`.
   - CLS: observe `layout-shift`, sum `value` where `!hadRecentInput`.
   - INP/interaction: observe `event`/`first-input` durations; or `performance.getEntriesByType('event')`.
   - Paint: `performance.getEntriesByType('paint')` (FP/FCP). Navigation timing: `getEntriesByType('navigation')[0]`.
   Record: `LCP _ms, CLS _, INP _ms, FCP _ms`. Targets: LCP <2.5s, CLS <0.1, INP <200ms.

2. **LCP breakdown** — split the LCP into TTFB / resource-load / render-delay from `navigation` + the LCP element's `resource` entry (`responseStart`, `requestStart`, `responseEnd`). Attribute the dominant slice, then fix ONLY it: TTFB→server/edge; resource-load→`preload`/priority hints, correctly-sized/`webp` image, no lazy-load on the LCP image; render-delay→critical CSS inline, unblock render-blocking JS/font. Re-measure; cite `render-delay 2.1s → 0.5s`.

3. **Bundle** — inspect the real build output via `bash` (`du -sh dist/**/*.js`, the framework's build report, or `npx source-map-explorer`/`vite build --report`). Record total + largest chunks + top offending deps. Fix: dynamic `import()` code-split at route boundaries, tree-shake (kill barrel/`import *`, side-effectful imports), swap heavy deps. Re-run build; cite `entry chunk 842KB → 410KB gzip`.

4. **Render perf** — count re-renders and wasted work from profiling data, not intuition. Instrument with the React Profiler API / a render-count ref, or read a captured profile; identify components re-rendering with unchanged props. Fix: `memo`/`useMemo`/`useCallback`, stable keys, lift state, split context. Cite `list re-renders 47 → 6 per keystroke`.

5. **DB query perf** — for a slow endpoint, capture the actual SQL and run `EXPLAIN (ANALYZE, BUFFERS)` via the `bash` DB client (`psql`/`sqlite3`/`mysql`). Detect N+1 (same query shape × N in the trace/log), missing index (Seq Scan on a filtered column), bad plan. Fix: add index, eager-load/batch, rewrite. Re-run `EXPLAIN`; cite the plan change `Seq Scan (cost 8400, 1.2s) → Index Scan (cost 12, 3ms)` and total endpoint time.

6. **Caching layers** — verify each layer actually hits: HTTP (`Cache-Control`/`ETag`/304 via response headers), query/data cache (hit-rate log), and in-app memo. Measure cache-cold vs cache-warm latency; a cache with 0 measured hit-rate is dead. Cite `cold 480ms → warm 12ms, hit-rate 94%`.

7. **Memory leaks** — take **2 heap snapshots** and diff retained size, not "looks stable". Via `browser` CDP: `const c = await page.target().createCDPSession(); await c.send('HeapProfiler.enableSampling')` — or `page.metrics()` (`JSHeapUsedSize`) around a repeated action. Protocol: snapshot → run the suspect action N times (navigate/open-close/mount-unmount) → force GC (`c.send('HeapProfiler.collectGarbage')`) → snapshot → diff. Growing = leak; classify detached DOM nodes, un-removed listeners, retained closures/timers. Cite `JSHeapUsedSize +38MB over 10 cycles → +0.4MB after fix (listeners removed on unmount)`.

## Verdict rules — pick exactly 1 of 3

- **IMPROVED** — a before AND after number for the targeted metric shows a real delta, measured on a prod-like build (median of 3).
- **NO-EFFECT/REGRESSION** — the after number did not improve (or regressed elsewhere). Report both numbers honestly; do NOT relabel a null result as a win.
- **CANT-MEASURE** — the metric could not be measured (no prod build, no DB access, unstable env). First-class verdict; NOT "would have improved".

## Output (BLUF first)

- **Conclusion**: one of the 3 above.
- **Measurement table** — table: metric / before / after / delta(%) / measurement method (command·probe). A row with no number is "CANT-MEASURE".
- **Bottleneck**: the dominant slice you attributed the cost to + the evidence (LCP breakdown, EXPLAIN plan, heap diff, bundle report).
- **Applied fix**: what changed and why, tied to the measured slice.

## Constraints

- **"Should be faster" BANNED** — no number, no claim. Prediction without a measured delta is not allowed (measure-first discipline).
- **Static ≠ dynamic** — "the code is changed" is static. "It got faster" is GREEN only on a before/after measurement.
- **Prod-like only** — dev-build numbers for bundle/LCP are misleading; measure a production build or say "CANT-MEASURE".
- **Median of 3** — a single run is noise; report the median and note variance.
- **Fix the dominant slice** — never micro-optimize a 5% slice while a 60% slice is untouched; attribute the cost first, then fix.
- **Citation-truth** — cited plans/headers/probes must come from real `bash`/`tab.evaluate`/CDP output, pasted, not paraphrased.
