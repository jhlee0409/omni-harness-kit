# Dogfood log

`introspect` (detection + the generation step it drives) run against real public
repos across the previously-unvalidated stack matrix. This is the evidence behind the
README's narrowed Status claim — what the kit actually produced, and what was wrong.

## What held on every stack (the kit's judgment)

- **Conditional-critic gating** — `db-verify` was generated when (and only when) a data
  layer was present; `ui-verify` when (and only when) a frontend framework was present.
  True-positive / true-negative on all six repos.
- **Store-verify idioms** mapped to the right store wherever the store was correctly
  identified.
- **Reference integrity** — zero generated spines routed to a non-existent agent / skill.

## What was wrong (plumbing) — and the fix

The defects clustered in detection's non-Node/Python branches and in empty-slot
rendering. All fix-now items below are fixed in this release with regression tests in
`tests/detect_test.sh` ([9]–[12]).

| Repo | Stack | Result | Defects found |
|---|---|---|---|
| `spf13/cobra` | Go module (CLI lib, no framework) | minor → fixed | **D1** `test_runner` set but no runnable `test_cmd`/`build`/`typecheck` → verify-loop no-op + empty `` `` in the architect. **D6** `project_name` = dir basename, not the module path. |
| `BurntSushi/ripgrep` | Rust Cargo workspace | minor → mostly fixed | **D1/D6** same as Go (cargo cmds + `[package].name` now filled). **D5** find-based member list includes an `exclude`d crate / misses a no-manifest binary crate — *deferred* (see below). |
| `t3-oss/create-t3-turbo` | TS/JS monorepo (Turbo+pnpm) | clean | Root orchestrator correctly empty; per-member re-run recovered next/react/postgres; both critics fired correctly. |
| `fastapi/full-stack-fastapi-template` | Python+Postgres + React monorepo | minor → fixed | **D3** (REL-5) + **D7** (dup member) confirmed via repro; both fixed. Per-member re-run recovered fastapi+postgres correctly. |
| `pallets/flask` | Python library | minor → fixed | **D1** `pytest` runner but no `test_cmd`; **C3** `uv.lock` not detected. Both fixed. (A redis-broker dep can still false-positive as a store — 0.x heuristic limit.) |
| `shadcn-ui/taxonomy` | Next.js + Prisma(MySQL) + pnpm | real → fixed | **D4** Prisma was hardcoded to Postgres → `db-verify` emitted Postgres-only `FILTER(WHERE)` + `psql` that **errors on MySQL**. Now reads `schema.prisma` `provider`; SKILL gained mysql/sqlite rows. |

## Fixed in this release

- **D1** — Go/Rust/Python branches now emit runnable `test_cmd` (`go test ./...`,
  `cargo test`, `pytest`) + `build`/`typecheck`/`lint` defaults, so the verify-loop hook
  is no longer a no-op on those ecosystems.
- **D2** — `SKILL.md §4.2` now tells the generator to omit empty slots (no empty `()`,
  no empty inline-code, no dangling `Build:`/`Test runner:` line) and gives a
  no-test-runner fallback.
- **D3 (REL-5)** — the monorepo member scan now matches `requirements.txt` / `setup.py`
  / `setup.cfg`, so Python sub-packages are no longer invisible.
- **D4** — Prisma maps to its real datasource provider (mysql/sqlite/postgres/…); SKILL
  store table gained MySQL + SQLite rows.
- **D6** — `project_name` comes from the Go module path / Cargo `[package].name`, not the
  clone-dir basename.
- **D7** — member dirnames are de-duplicated (a dir with two manifests is listed once).
- **C3** — `uv.lock` / `poetry.lock` / `Pipfile.lock` now set the Python package manager.

## Known limitations (acceptable for 0.x)

- **D5** — Cargo `[workspace]` `members`/`exclude` are not parsed; the generic
  find-based member scan can include an excluded crate or miss a binary crate that has
  no own `Cargo.toml`. Narrow (Cargo workspaces with `exclude`); tracked for a follow-up.
- A dependency used only as a **cache / broker / queue** (e.g. redis) can false-positive
  as a verifiable store.
- A script *body* (not its npm name) is captured for `dev`/`build`, so a `concurrently …`
  dev script renders verbatim rather than as `<pm> dev`.
- **The generation step is LLM slot-filling and therefore probabilistic** — the
  irreducible residue. Detection is deterministic and tested; turning it into a
  CLAUDE.md/agents is a model honoring the SKILL prompt. Review the generated harness
  before committing it.
