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
| 6 | standards conformance (AGENTS.md / MCP / SCIP) | 3 | adapters | **AGENTS.md done; MCP/SCIP deferred** |

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

**5. `assess` maintainability audit.** Read-only, stack-parameterized. **v1 shipped:**
size × 90-day-churn hotspot concentration (strongest predictor), size outliers,
test-gap, and lint debt (when the stack linter is installed). **Deferred** (stated in
the skill's caveats + `assess.sh`): duplication, cognitive complexity, dependency
cycles, LSP symbol-resolution rate. Baseline/delta snapshots, never an absolute grade
or dashboard. Backing: DORA 2024, GitClear 2024, Sonar Cognitive Complexity. No
validated universal "AI-maintainability" metric exists → measure operationally and
say so. Spec: `specs/20260722-maintainability-assess-skill/`.

**6. standards conformance.** One canonical rules file → generate AGENTS.md +
vendor aliases; MCP tool manifests with allowlist + explicit consent; optional
SCIP/LSIF consumption for navigation adapters. Backing: MCP spec (2025-06-18),
AGENTS.md, SCIP (sourcegraph/scip).

**Note (2026-07-22): AGENTS.md conformance shipped; MCP + SCIP deferred (honestly).**
Decided in `docs/adr/0001-agentsmd-canonical-claudemd-imports-it.md`: `AGENTS.md` is
canonical (cross-vendor standard), `CLAUDE.md` `@import`s it — one source of truth, no
drift, no symlink (`skills/introspect/aliases.sh`, `tests/aliases_test.sh`). MCP and
SCIP are NOT shipped and NOT stubbed: MCP consent is host-enforced by spec (a kit can
only ship a config template + allowlist), and SCIP needs a heavy indexer
(enterprise-adapter only). Both tracked in `specs/20260722-standards-conformance/` as
deferred sub-items needing their own design before code.

## Explicitly rejected (research-backed)

Hosted vector DB in the core; LLM-generated code graphs as "no-omission proof"
(GraphRAG is global-QFS, not impact enumeration); stored quality grades/dashboards
(Tier-3 violation; DORA/GitClear are observational, not causal); multi-generation
autonomous loops / blind retries (error compounding; Agentless beats them cheaply);
Glean/CodeQL as a default dependency (heavy) — enterprise adapters only.
