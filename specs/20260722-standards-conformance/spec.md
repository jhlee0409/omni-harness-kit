# Spec: standards conformance

- Status: Implemented (2026-07-22) — AGENTS.md + MCP guidance + SCIP consume-if-present; auto `.mcp.json` and shipped indexer rejected
- Created: 2026-07-22

## Problem / goal

Roadmap item 6: make the generated harness vendor-neutral ("omni") by conforming to
the cross-ecosystem standards — `AGENTS.md` (agent instructions), MCP (tool/context
access), and SCIP/LSIF (code navigation) — so a repo tailored by `introspect` works
across Claude Code / Codex / Cursor / others, not just Claude Code.

## What "done" looks like

- **AGENTS.md (this PR):** `introspect` writes the canonical spine to `AGENTS.md` and
  wires `CLAUDE.md` to `@AGENTS.md`-import it — one source of truth, verified by a
  fresh-install run producing both files with the import resolving.
- MCP + SCIP: separate follow-ups (see Out).

## Scope

- **In (shipped):**
  - `AGENTS.md` canonical + `CLAUDE.md` `@import` wiring
    (`skills/introspect/aliases.sh`, `tests/aliases_test.sh`), decided in
    `docs/adr/0001-agentsmd-canonical-claudemd-imports-it.md`.
  - `introspect` SKILL §4 step 1 + spine header → AGENTS.md-canonical model.
  - **MCP guidance** (`introspect` SKILL §5): the report tells the user which MCP
    servers each generated critic benefits from (Playwright MCP → `ui-verify`; store
    client / DB MCP → `db-verify`; LSP/SCIP code-intelligence → `blast-radius` /
    `change-verifier`), with the least-privilege + host-enforced-consent model.
  - **SCIP/LSIF consume-if-present** (`blast-radius` SKILL): use an existing LSP/SCIP
    index when the host provides one; degrade to ripgrep + AST otherwise.
- **Rejected (NOT built — would violate the kit's principles):**
  - **Auto-generating `.mcp.json`.** MCP consent is host-enforced by the spec (2025-06-18);
    a kit auto-writing server configs would be consent theater. The kit guides; the
    user adds what they consent to.
  - **Shipping a SCIP/LSIF indexer in the core.** Heavy; an enterprise-adapter concern,
    per the roadmap's rejected-list. The kit consumes an index, never builds one.

## Acceptance

- A fresh-install run (`tests/install_smoke_test.sh`, extended) generates `AGENTS.md`
  with the spine and a `CLAUDE.md` whose `@AGENTS.md` import resolves; re-run is
  idempotent (no duplicate blocks) — verified by real run, not a fixture stub.
- `tests/aliases_test.sh` green (create / preserve-user-content / idempotent /
  fail-loud-on-missing-AGENTS.md).

## Risks / open questions

- Relies on Claude Code `@import` (verified: docs.claude.com/en/docs/claude-code/memory).
  If a runtime drops @import support, fall back to writing the block into CLAUDE.md
  directly — `aliases.sh` is the single place to change.
- Resolved: MCP scope = guidance (not auto-config); SCIP scope = consume-if-present
  (not ship-indexer). Both bounded by the kit's portability + host-consent constraints;
  AGENTS.md conformance remains independently complete.
