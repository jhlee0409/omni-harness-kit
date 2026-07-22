# Roadmap — agent-maintainability capabilities

Prioritized enhancement plan for making the kit a world-class, enterprise-grade
harness for AI/agent codebase comprehension, navigation, and maintenance under
context limits. Derived from a cross-verified web research pass (2026-07-22); the
governing finding is that **no technique guarantees omission-free understanding**,
so reliability comes from *deterministic enumeration + explicit unknowns + test
gates + human gates* — which is the kit's existing philosophy, now externally
validated. See the research citations in the wave notes below.

Executed one wave at a time, each item completed and gated (a human reviews the
PR) before the next — per the kit's "one spec, one PR, one human gate" rule and
the measured error-compounding argument in `AGENTS.md`. This roadmap fixes the
ORDER; it does not authorize an autonomous multi-feature chain.

## Priority order

| # | Item | Wave | Form | Status |
|---|---|---|---|---|
| 1 | `blast-radius` impact-enumeration protocol | 1 | skill | **done** |
| 2 | `localize → edit → validate` discipline | 1 | skill | **done** |
| 3 | deterministic repo-map spine | 2 | render extension | **done** |
| 4 | context-engineering discipline in the spine | 2 | spine/skill prose | **done** |
| 5 | `assess` maintainability audit | 3 | skill + engine | **done** |
| 6 | standards conformance (AGENTS.md / MCP / SCIP) | 3 | adapters | **needs own spec** |

## Wave 1 — discipline skills (highest leverage, near-zero new machinery)

**1. `blast-radius` impact enumeration.** Given a target/changed symbol, enumerate
its impact set (LSP `references` / `implementations` / call- & type-hierarchy →
tree-sitter AST inventory → ripgrep both-names sweep), deduped with provenance,
plus an explicit **unknowns** section (dynamic dispatch / reflection / generated
code) and an "enumeration complete?" checklist. Directly answers the "누락없이"
requirement by being honest: it guarantees *all discovered edges + surfaced
unknowns*, never "completeness". Backing: LSP relation set = the agent's impact
surface (LSP 3.17 spec); Agentless-style targeted localization beats broad
autonomy (arXiv 2407.01489). Deletion pair: `change-verifier` step 2 and
`architecture-reviewer` check 7 stop restating ad-hoc callsite hunting and route
to this one protocol.

**2. `localize → edit → validate`.** Require a `localize` artifact (target files/
symbols + evidence + uncertainty) before editing; gate on a focused test then a
stack regression run. Backing: Agentless 32%@$0.70 on SWE-bench Lite beating
elaborate agent loops (arXiv 2407.01489); SWE-bench success = test-passing patch
(arXiv 2310.06770).

## Wave 2 — deterministic context

**3. repo-map spine.** Extend `introspect`/`render.sh` to emit a hierarchical,
deterministic map (root overview + per-subtree responsibilities / entrypoints /
tests / invariants), refreshed on demand — NOT a stored metric. Backing: hybrid
inventory+map over vector-only (RepoRetrieval synthesis); progressive disclosure
and just-in-time retrieval (Anthropic Effective Context Engineering, 2025-09-29).

**4. context-engineering discipline.** Put acceptance/invariants at prompt edges
(lost-in-the-middle, arXiv 2307.03172; NoLiMa, arXiv 2502.05167); per-task
NOTES.md (extend handoff/pickup); recall-first compaction; subagent scoping.

## Wave 3 — diagnosis & standards (enterprise / omni positioning)

**5. `assess` maintainability audit.** Read-only, stack-parameterized. Cheap
signals: churn×complexity hotspot concentration (strongest predictor), duplication,
p95 cognitive complexity, dependency cycles, LSP symbol-resolution rate (AI-usability
proxy), verify/test command discoverability. Baseline/delta snapshots, never an
absolute grade or dashboard. Backing: DORA 2024, GitClear 2024, Sonar Cognitive
Complexity. No validated universal "AI-maintainability" metric exists → measure
operationally and say so. Spec: `specs/20260722-maintainability-assess-skill/`.

**6. standards conformance.** One canonical rules file → generate AGENTS.md +
vendor aliases; MCP tool manifests with allowlist + explicit consent; optional
SCIP/LSIF consumption for navigation adapters. Backing: MCP spec (2025-06-18),
AGENTS.md, SCIP (sourcegraph/scip).

**Note (2026-07-22): item 6 is deliberately NOT rushed.** It is a design decision,
not a quick wiring: the canonical-file choice (AGENTS.md vs CLAUDE.md, symlink vs
duplicate — a real drift risk), the fact that MCP consent is host-enforced by the
spec (a kit can only ship a config template + allowlist, not enforce consent), and
SCIP needing a heavy indexer (enterprise-adapter only, per the rejected-list above)
all warrant an ADR + spec before code. Rushing it would create the duplication the
kit warns against. Next action for item 6: `/harness-kit:new-spec standards-conformance`.

## Explicitly rejected (research-backed)

Hosted vector DB in the core; LLM-generated code graphs as "no-omission proof"
(GraphRAG is global-QFS, not impact enumeration); stored quality grades/dashboards
(Tier-3 violation; DORA/GitClear are observational, not causal); multi-generation
autonomous loops / blind retries (error compounding; Agentless beats them cheaply);
Glean/CodeQL as a default dependency (heavy) — enterprise adapters only.
