# ADR 0001: AGENTS.md canonical, CLAUDE.md imports it

- Status: Accepted
- Date: 2026-07-22

## Context
The kit generated the harness spine into `CLAUDE.md` only — a Claude Code-specific
filename. To be vendor-neutral ("omni"), the harness must also be readable by Codex,
Cursor, and other agents, which read the emerging cross-vendor standard **`AGENTS.md`**
(agents.md; nearest-file-wins; plain Markdown). Emitting the same content into two
files invites drift (the failure mode the kit's own `architecture-reviewer` flags).
Verified fact: Claude Code's `CLAUDE.md` supports `@path` imports, expanded into
context at launch, relative paths resolved to the importing file
(https://docs.claude.com/en/docs/claude-code/memory).

## Decision
`AGENTS.md` is the **canonical** generated harness file (the vendor-neutral standard
that Codex/Cursor read directly). `CLAUDE.md` is wired to **`@AGENTS.md`-import** it
via a `harness-kit:import` marked block (`skills/introspect/aliases.sh`, idempotent).
`introspect` §4 step 1 writes the spine to `AGENTS.md`, then runs `aliases.sh`. One
source of truth; no duplication, no symlink.

## Consequences
- Easier: one file to edit; Codex/Cursor/Claude Code all see the same rules; re-runs
  stay idempotent (marked blocks in both `AGENTS.md` and `CLAUDE.md`).
- Harder / accepted: relies on Claude Code's `@import` (verified, but a Claude-side
  feature); a user who deletes `AGENTS.md` leaves a dangling import — `aliases.sh`
  fails loud if `AGENTS.md` is absent to prevent writing one. Windows users need the
  same POSIX-ish setup the kit already assumes (WSL/Git-Bash).

## Alternatives considered
- **Duplicate full content into both files** — rejected: drift risk, the exact
  duplication smell the kit warns against.
- **Symlink `CLAUDE.md` → `AGENTS.md`** — rejected: fragile on Windows / some VCS
  checkouts; `@import` is the first-class mechanism.
- **Keep `CLAUDE.md` canonical, `AGENTS.md` a pointer** — rejected: Codex/Cursor do
  NOT expand `@import`, so a pointer `AGENTS.md` would give them empty rules.
