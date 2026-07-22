---
name: blast-radius
description: >-
  Enumerate the full impact set of a symbol before or during a change — every
  reference, caller, implementation/subtype, and reverse import — plus an explicit
  list of what could NOT be resolved (dynamic dispatch, reflection, generated
  code). Use before touching a shared / exported / widely-imported symbol, before
  an interface or signature change, or when the user asks "what breaks if I change
  this?", "어디까지 영향 가?", "누락 없이 찾아줘", "전부 찾았어?". Produces an
  evidence table + an "enumeration complete?" checklist; read-only.
argument-hint: "<symbol or file:symbol>"
allowed-tools: Read, Grep, Glob, Bash
---

# blast-radius — enumerate impact, surface the unknowns

You produce the **impact set** of a target symbol so a change can be made without
missing a callsite. The honest contract of this skill: **no tool guarantees
omission-free discovery.** LSP misses dynamic dispatch; grep misses renames;
generated code and reflection defeat both. So you do NOT claim "completeness" — you
guarantee **all *discovered* edges, deduped with provenance, plus an explicit list
of what you could not resolve.** The unknowns section is the point, not an
afterthought — it tells the human exactly where to look by hand.

## 1. Scope the target

Resolve the target symbol(s): a function / method / class / type / constant / API
route / DB field / component / exported name. For a signature or rename change,
capture BOTH the old and the new name. Note the declaring `file:line`.

## 2. Enumerate — layered, strongest signal first

Run every layer available; do not stop at the first. Cross-check the counts
between layers — a divergence is itself a finding (a match one layer sees and
another misses is a candidate omission).

1. **Code-intelligence (LSP / SCIP), if available** — the strongest signal,
   because it resolves bindings, not text:
   - `references` — every use of the symbol.
   - `implementations` / type hierarchy — every impl / subtype (for an interface
     or base type).
   - call hierarchy — incoming callers and outgoing callees; traverse recursively
     with a depth cap and a cycle guard.
   Record the provider and that support was present. If no LSP/index is available,
   say so explicitly (it changes the confidence of the result).
2. **AST inventory (tree-sitter), if available** — enumerate declarations,
   imports/exports, class inheritance, and call-shaped expressions. Use it to
   catch structural uses and to sanity-check the LSP count.
3. **Text sweep (ripgrep) — always** — grep both the old and new names across the
   repo, excluding `node_modules`, `.venv`, `dist`, `build`, `.next`, `coverage`,
   and vendored dirs. This catches string/symbol refs the import graph misses
   (config keys, DI tokens, dynamic route strings, docs). Treat lexical matches as
   *candidates*, never as resolved references — never present a grep hit as a
   precise call edge.

## 3. Categorize the impact

Bucket every discovered edge so the human can reason about coverage:

- **Direct references** — uses of the symbol.
- **Callers** — incoming call sites (who breaks if the signature changes).
- **Implementations / subtypes** — every type that must change together.
- **Reverse imports / dependents** — modules that import the declaring module.
- **Tests / config / docs** — test files, fixtures, config keys, and docs that
  name the symbol (often missed, often where a change actually breaks).
- **UNKNOWN / unresolved** — dynamic dispatch, reflection, `eval`/metaprogramming,
  generated or macro-expanded code, framework-convention wiring, cross-language
  boundaries, and monorepo edges an unconfigured LSP can't cross. List each with
  why it's unresolved. THIS is where the human verifies by hand.

## 4. Report contract (BLUF)

- **Target**: the symbol(s) + declaring `file:line`.
- **Searched scope**: which layers ran (LSP? which provider / AST? / ripgrep) and
  the exclusion set — so the reader knows what was and wasn't covered.
- **Impact table**: one row per edge — `file:line` · category · provider
  (lsp/ast/grep) · confidence (resolved / candidate).
- **Unknowns**: every unresolved region + why. Non-empty is normal and expected.
- **Enumeration complete?** checklist — answer each:
  - LSP available and used? (if no, recall is reduced — say so)
  - Old AND new name swept (for a rename)?
  - Tests / config / docs scanned?
  - Any layer-count divergence investigated?
  - Dynamic / generated / reflective code present and listed as unknown?

## Constraints

- **Never claim completeness.** State "all discovered edges + N unresolved regions
  (listed)", never "all callsites" / "nothing else uses it". A terminal claim of
  completeness on a symbol with unresolved dynamic edges is the failure mode this
  skill exists to prevent.
- Degrade gracefully: no LSP → run AST + ripgrep and lower the stated confidence.
- **Consume a code-intelligence index if present; never ship one.** Use the host's
  LSP or an existing SCIP/LSIF index when available — generating/maintaining an index
  is heavy and out of scope (an enterprise-adapter concern, not the portable kit).
- Read-only — enumerate and report; make no edits.
- Cite every edge with a `file:line` confirmed by Read/grep; a count with no rows
  is not evidence.
