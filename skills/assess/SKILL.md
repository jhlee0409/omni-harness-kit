---
name: assess
description: >-
  Read-only maintainability audit of a whole codebase — ranks the files most
  likely to cause maintenance pain (size × churn hotspots, test gaps, lint debt)
  and proposes discrete fixes, each as its own PR. Use before a cleanup/refactor
  pass, when inheriting a codebase, or when the user says "유지보수성 점검",
  "어디부터 리팩토링", "코드베이스 상태 봐줘", "where is the tech debt?", "what
  should we clean up first?". Produces a findings table + top-3 fix proposals; it
  edits nothing and stores no grade.
argument-hint: "[target-dir]"
allowed-tools: Read, Grep, Glob, Bash
---

# assess — rank maintenance risk, propose discrete fixes

Give a codebase a **stack-parameterized maintainability snapshot** so the next
change (by a human or an agent) lands where it hurts least. This is deliberately
NOT a quality daemon: it is a one-shot, on-demand, read-only audit that outputs a
**ranked fix list**, not a stored score, grade, dashboard, or trend line.

## Scope boundary (read this first)

The kit ships no measurement / self-evolving subsystem by design (`introspect`
SKILL §3, Tier 3). This skill is compatible with that decision because it is a
**human-invoked one-shot assessment**, not a generated runtime metrics layer: it
persists nothing, runs only when asked, and its output is discrete PRs a person
chooses — never an automatic remediation loop or a number the harness optimizes.
If you find yourself wanting to *store* the score or run this on every commit,
stop: that is the rejected metrics layer.

Honest limit: **there is no validated universal "AI-maintainability" metric.** The
signals below are structural proxies; hotspots (churn × size) have the strongest
maintenance-pain evidence in the literature, static-analysis smells the weakest
(they need size/churn controls). Report proxies, not verdicts.

## 1. Run the engine

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/assess/assess.sh" <target>
```

It reuses `introspect/detect.sh` for the stack, then emits JSON:
- `signals.hotspots` — files ranked by size × 90-day churn (the primary signal).
- `signals.size_outliers` — files ≥ 400 lines (hard to change safely).
- `signals.test` — is there a runnable verify command + any test files? `gap: true`
  means an agent can't cheaply prove a change here.
- `signals.lint_debt` — the stack linter's finding count, only if it's installed.
- `signals.duplication` — candidate clone blocks (8+ identical normalized lines seen
  in ≥2 places), with locations; conservative, so treat as leads not verdicts.
- `caveats` — always surface these to the reader.

The engine is deterministic and cheap (git + `wc` + a rolling-hash clone scan +
optional installed linter). It does NOT cover dependency cycles or cognitive
complexity yet — say so; don't imply it did.

## 2. Render the findings (human-decidable)

Turn the JSON into a table a person can act on — severity × effort, each row with
its evidence and the concrete fix:

| Finding | Evidence (`file:line` / count) | Severity | Effort | Fix |
|---|---|---|---|---|

Severity from the signal (a high-churn 400+ line file with no tests = high). Keep
labels in words, not jargon — a reader must decide from each row (route to
`readability-critic` if unsure).

## 3. Propose the top 3 — as discrete PRs

Pick the 3 highest severity×(low effort) findings. For each: the file, why it's a
risk (the signal), and the concrete change (split the god-file, add a
characterization test before refactoring the hotspot, fix the lint debt). Hand the
chosen one to `/harness-kit:new-spec` — one fix, one PR, one human gate. Do NOT
auto-apply.

## Constraints

- Read-only. Enumerate + rank + propose; never edit, never open a PR.
- No stored grade / dashboard / trend. A caller who wants a trend diffs two runs
  themselves.
- Cite every finding with a `file:line` or a count from the engine — no "feels
  messy". Surface the engine's caveats verbatim.
- Stack-parameterized, degrade gracefully: no git → hotspots fall back to size; no
  linter installed → skip lint debt and say so.
