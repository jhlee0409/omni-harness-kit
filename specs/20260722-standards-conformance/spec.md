# Spec: standards conformance

- Status: Partial — AGENTS.md conformance shipped; MCP + SCIP deferred
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

- **In (shipped this PR):**
  - `AGENTS.md` canonical + `CLAUDE.md` `@import` wiring
    (`skills/introspect/aliases.sh`, `tests/aliases_test.sh`), decided in
    `docs/adr/0001-agentsmd-canonical-claudemd-imports-it.md`.
  - `introspect` SKILL §4 step 1 + spine header updated to the AGENTS.md-canonical model.
- **Out (deferred, with rationale — NOT shipped, not stubbed):**
  - **MCP tool manifests.** The MCP spec (2025-06-18) makes user consent
    **host-enforced**, not protocol-enforced — a portable kit can only ship a config
    template + allowlist, not enforce consent. Needs its own design (which servers,
    what allowlist shape) before code; deferring avoids shipping a security-theater
    "consent" the kit cannot actually guarantee.
  - **SCIP/LSIF consumption.** Requires a language indexer (heavy) — per the roadmap's
    rejected-list, this belongs in an enterprise adapter, not the portable core.

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
- `[NEEDS CLARIFICATION: MCP scope]` and `[NEEDS CLARIFICATION: SCIP scope]` block the
  MCP/SCIP sub-items leaving Draft; AGENTS.md conformance is independently complete.
