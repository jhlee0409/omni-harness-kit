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

- **D5 — FIXED (2026-07-22).** `detect.sh` now parses the Cargo `[workspace]`
  `members` (glob-expanded, must have a `Cargo.toml`) and `exclude` arrays, so an
  excluded crate is dropped and glob members are included. Regression: `detect_test.sh`
  [18]. (Deep glob edge cases beyond one level remain best-effort.)
- A dependency used only as a **cache / broker / queue** (e.g. redis) can false-positive
  as a verifiable store.
- A script *body* (not its npm name) is captured for `dev`/`build`, so a `concurrently …`
  dev script renders verbatim rather than as `<pm> dev`.
- **The agent files are now rendered deterministically** by `render.sh` (the
  `<stack>-architect` + the conditional `db-verify` / `ui-verify`) — fully tested, no
  slot leak possible, the store idioms are a table in the script. The **only**
  probabilistic residue left is the spine's judgment prose (architecture note, stack
  summary), filled by the LLM; review that before committing.

## 2026-07-22 — agent-maintainability wave: live dogfood + honest-limit closure

The new capabilities (blast-radius / localize / assess / repo-map / shell detection)
were exercised live against THIS repo and the load-bearing research was spot-checked
against primary sources. What was actually run, and the residual limit stated plainly.

### Gap 3 (research soundness) — spot-verified against primary source
Two load-bearing claims re-read directly (not via the scout summary):
- **Agentless** (arXiv 2407.01489, abstract): *"32.00%, 96 correct fixes … low cost
  ($0.70) … highest performance compared with all existing open-source software
  agents"* — matches the synthesis verbatim. Backs the `localize` skill's staged
  localize→repair→validate over broad autonomy.
- **Lost in the Middle** (arXiv 2307.03172, abstract): *"performance is often highest
  when relevant information occurs at the beginning or end … significantly degrades …
  in the middle … even for explicitly long-context models"* — matches. Backs spine
  rule `0.7` (keep constraints at the context edges).
- Result: the scouts did not fabricate the two claims checked. Other citations remain
  spot-checkable via their URLs (each carries a date + confidence in the brief).

### Gap 2 (live skill behavior) — run on this repo
- **`blast-radius`** on the `detect.sh` output schema: enumerated its real impact set
  — callers (`render.sh`, `repomap.sh`, `assess.sh`, and 3 test files) plus the
  JSON-key consumers (`render.sh`/`repomap.sh`/`assess.sh` read `languages` /
  `frameworks` / `data_layer` / `project_name` / `test_cmd` / `members`). Bash has no
  LSP, so the protocol degraded to AST/ripgrep exactly as the skill specifies, and
  correctly labels that as reduced-confidence (no false completeness claim).
- **`assess`** on this repo: real hotspots ranked (`detect.sh` score 2088, `render.sh`
  1463, `tests/detect_test.sh` 1379 …), `test gap: false`, `shellcheck` debt `0`, no
  size outliers. Valid JSON, human-decidable ranking — the skill's actual deliverable.
- **`localize`**: this wave's changes were themselves made localize-disciplined —
  each change localized before editing, then gated by `tests/*_test.sh` + the new
  `install_smoke` e2e (the validate step). The session is the dogfood.

### Gap 1 (LLM-filled spine prose) — bounded, not eliminated (honest)
This is irreducible by design: the spine's judgment slots (architecture note, stack
summary, agent-routing prose) are LLM-filled, so they cannot be made deterministic
without removing the judgment. It is BOUNDED, not solved: (a) the agent files are
rendered deterministically (above), shrinking the residue to prose only; (b) the
slot contract is test-enforced (`generation_contract_test`); (c) `introspect` was
dogfooded on 6 real repos (above); (d) the SKILL mandates a critic review of the
generated spine before commit. Claiming this gap is "closed" would itself be the
overclaim the kit's `0.6` rule forbids — it is managed, and the management is tested.
