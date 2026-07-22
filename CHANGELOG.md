# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres
to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **`assess` now detects duplication.** A cheap, language-agnostic rolling-hash clone
  scan (8+ identical normalized lines seen in ≥2 places, overlap-deduped) — GitClear's
  top AI-code smell — added to `assess.sh` signals; conservative (leads, not verdicts).

### Fixed
- **D5: Cargo `[workspace]` members/exclude are now parsed.** `detect.sh` glob-expands
  `members` (keeping dirs that have a `Cargo.toml`) and drops `exclude`d crates, so a
  Cargo workspace's member list is no longer polluted by excluded crates. Regression:
  `tests/detect_test.sh` [18].

## [0.9.1] - 2026-07-22

### Added
- **MCP + SCIP conformance completed (portable scope).** `introspect`'s report (§5)
  now gives coherent MCP guidance — which server each generated critic benefits from
  (Playwright MCP → `ui-verify`; store client / DB MCP → `db-verify`; LSP/SCIP
  code-intelligence → `blast-radius` / `change-verifier`) — under a least-privilege +
  host-enforced-consent model; `blast-radius` documents consuming an existing LSP/SCIP
  index if present. Auto-writing `.mcp.json` (consent theater) and shipping a SCIP
  indexer (too heavy → enterprise adapter) are explicitly rejected. Completes roadmap
  item 6; spec `specs/20260722-standards-conformance/`.

## [0.9.0] - 2026-07-22

### Added
- **`introspect` now detects shell-tooling repos.** `detect.sh` gained a `shell`
  fallback stack, recognized ONLY when no packaged-language manifest (package.json /
  pyproject / go.mod / Cargo.toml / Gemfile / pom.xml) is present, so a Node/Python
  repo with a `scripts/` dir is never mislabeled. The marker is a shell test suite
  (`tests/*_test.sh`, `tests/test_*.sh`, or `*.bats`), which fills a runnable
  `test_cmd` — so the verify-loop hook is no longer a no-op on bash-only repos (the
  kit's own repo included), and `render.sh` emits a `shell-architect`.
- **`blast-radius` impact-enumeration skill.** Given a target/changed symbol, it
  enumerates the impact set layered strongest-signal-first (LSP references /
  implementations / call hierarchy → tree-sitter AST → ripgrep both-names sweep),
  deduped with provenance, and — the point of the skill — surfaces an explicit
  UNKNOWN section (dynamic dispatch / reflection / generated code) plus an
  "enumeration complete?" checklist. It never claims completeness, only "all
  discovered edges + listed unresolved regions". `change-verifier` (stale-reference
  sweep) and `architecture-reviewer` (blast-radius/centrality check) now route to
  this one protocol instead of each restating ad-hoc callsite hunting. First item
  of the agent-maintainability roadmap (`docs/roadmap.md`).
- **`localize` skill — the localize → edit → validate loop.** Requires a written
  localization artifact (target `file:line`s + the evidence that put them there +
  remaining uncertainty) BEFORE any edit, uses `blast-radius` for the impact set,
  then gates the edit on a focused test (failing → passing) plus the stack
  regression run. Encodes the empirical finding that staged localization beats
  broad autonomous exploration at a fraction of the cost (Agentless, arXiv
  2407.01489); bounded to one change → one validation → the human gate, no blind
  retry loops. Roadmap item 2 (`docs/roadmap.md`).
- **`introspect` now generates `.claude/repo-map.md`.** A deterministic navigation
  map (stack / entry points / top-level layout / monorepo members / where tests
  live) via `skills/introspect/repomap.sh`, so an agent orients on a whole codebase
  by progressive disclosure — read the map, drill into the exact subtree — rather
  than blind-globbing. Facts only (dir roles are name-based heuristics; module
  responsibilities are left for a human to fill); refreshed by re-running
  introspect, not a stored metric. Roadmap item 3 (`docs/roadmap.md`).
- **Spine gained a `0.7 Context discipline` rule.** Generated `CLAUDE.md` spines
  now instruct: orient via `.claude/repo-map.md` then read the exact subtree
  (progressive disclosure); keep the ask/acceptance/invariants at the context edges
  because models attend to the start/end, not the middle (lost-in-the-middle,
  arXiv 2307.03172; NoLiMa, arXiv 2502.05167); keep a NOTES scratch and resume via
  handoff/pickup; delegate deep exploration to a scoped subagent returning a
  distilled summary. Roadmap item 4 (`docs/roadmap.md`).
- **`assess` skill — read-only maintainability audit.** `skills/assess/assess.sh`
  emits deterministic, stack-parameterized structural signals — size × 90-day-churn
  hotspots (primary), ≥400-line size outliers, test-discoverability gaps, and lint
  debt (only if the stack linter is already installed) — as JSON; the skill renders
  a severity × effort findings table and proposes the top-3 fixes, each handed to
  `new-spec` as its own PR. It stores no grade/dashboard (one-shot snapshot; diff
  two runs for a trend), edits nothing, and documents that no validated universal
  "AI-maintainability" metric exists. Compatible with the no-metrics Tier-3 stance
  because it is human-invoked and persists nothing. Roadmap item 5; spec
  `specs/20260722-maintainability-assess-skill/`.
- **Fresh-install end-to-end smoke test** (`tests/install_smoke_test.sh`). Packages
  the tree as a plugin is installed, points `CLAUDE_PLUGIN_ROOT` at that isolated
  copy, and runs the introspect engine against throwaway node + shell targets as a
  brand-new user would — proving the harness applies from an INSTALLED location
  (not just the dev checkout), the new skills ship, and every generated-spine route
  resolves to a shipped file (no dangling link a fresh install would hit).
- **AGENTS.md conformance — the generated harness is now vendor-neutral.**
  `introspect` writes the canonical spine to `AGENTS.md` (the cross-vendor standard
  Codex / Cursor / others read directly) and wires `CLAUDE.md` to `@AGENTS.md`-import
  it (`skills/introspect/aliases.sh`, idempotent, preserves user content) — one
  source of truth, no duplication/drift, no symlink. Decided in
  `docs/adr/0001-agentsmd-canonical-claudemd-imports-it.md`; tested by
  `tests/aliases_test.sh` + a fresh-install check. Roadmap item 6 (AGENTS.md part);
  MCP + SCIP conformance deferred with rationale (`specs/20260722-standards-conformance/`).

## [0.8.0] - 2026-07-21

### Fixed
- **`db-verify` covered only the first detected data store.** Detection is additive
  (a repo can report `mongodb` + `postgres` + `redis`), but the renderer used
  `data_layer[0]`, silently dropping guidance for every other store. `render.sh` now
  emits per-store verification idioms for all detected stores (deduped, so a store
  detected twice is not repeated); single-store output is unchanged.
- **The `agentic-engine` Claude Code hook adapters were broken two ways.** (1)
  rag-feedback and intent-router imported the engine from `$PROJECT_DIR`, which does
  not exist when the kit is installed as a plugin in another repo — the same silent
  no-op fixed for verify-evidence in 761c26e; all three now resolve the module via
  `CLAUDE_PLUGIN_ROOT` and stand down when it is unset. (2) All three interpolated
  `${JSON.stringify(...)}` into a double-quoted `bun -e` string, which bash parses as a
  fatal "bad substitution" that killed the hook under `set -euo pipefail` before it
  could run. Values now pass through the environment into a single-quoted bun script
  (engine path resolved by dynamic import), so the adapters run to completion.
- **Spec/ADR/worktree slugs collapsed non-ASCII names to a generic fallback.**
  `tr -cd 'a-z0-9-'` stripped Korean (and other non-ASCII) entirely, so `라이브 스케줄러`
  became `spec`/`decision`/empty and collided across tasks. Slugification now runs in
  `python3`, preserving unicode word characters (a pure-underscore input still falls
  back).
- **The protected-branch guard matched `git commit`/`git push` as bare substrings**, so
  it fired on mentions like `legit commit` and `git pushed`. It now parses the command
  with `shlex` and fires only when git's actual *subcommand* is `commit`/`push` —
  ignoring look-alikes, quoted mentions (`echo 'git commit'`), and argument-position
  matches (`git log --grep push`, `git stash push`, `git diff commit.txt`), while still
  catching git-level-flag forms (`git -c k=v commit`, `git -C dir push`,
  `git --no-pager commit`).
- **The OpenCode branch guard carried the identical substring bug.**
  `adapters/opencode/src/git.ts` `isGitMutation` used `cmd.includes("git commit")`; it
  now uses the same subcommand-aware match as the CC guard.
- **`update-block.sh` wrote `CLAUDE.md` non-atomically.** An interruption mid-write
  could truncate the user's file. It now writes to a temp file in the same directory
  and `os.replace`s it into place (atomic on POSIX).

### Added
- Regression tests for the fixes above: multi-store and duplicate-store `db-verify`
  (`render_test.sh`) and a non-ASCII slug (`spec_test.sh`). (The guard look-alike and
  `isGitMutation` classification cases live in the cross-runtime conformance matrix
  below — one shared table, not per-runtime duplicates.)
- **Deterministic offline embedding provider (`local`, alias `hash`).** Feature-hashing
  over unicode tokens — no API key, no network — selectable with
  `HARNESS_EMBEDDING_PROVIDER=local`. An opt-in, zero-dependency offline provider for
  rag-feedback / intent-router (not an automatic fallback — the default is still
  `openai`), it also makes their retrieval/routing pipeline self-testable in CI without
  a live model.
- **CI now runs the engine and adapter test suites it previously skipped.** The
  `agentic-engine` bun suites (rag-feedback, intent-router, verify-evidence),
  cross-vendor's shell test, and the OpenCode adapter tests + typecheck existed but CI
  ran only the top-level `tests/*_test.sh`. A Bun toolchain step plus a new integration
  test (`tests/agentic_adapters_test.sh`, skips where Bun is absent) exercise the three
  Claude Code hook adapters end-to-end with the deterministic `local` provider — the
  layer the bun unit suites (which cover `src/` only) never touched.
- **`detect.sh` surfaces a `warnings[]` channel.** Partial/failed detection was silent
  (a `set -u` but not `-e` script fails soft to empty), so a malformed `package.json`,
  a monorepo whose member list hit the depth-3/20 cap, or a stackless repo produced a
  quietly degraded harness that looked fully detected. Those now emit a warning in the
  JSON summary and on stderr (surfaced by `render.sh`).
- **The verify→feedback loop is now closed.** verify-evidence has always written a
  `.harness-kit/evidence.jsonl` log of what critics proved/refuted, but nothing consumed
  it. rag-feedback now ingests that log as retrievable memory (alongside curated
  `feedback/*.md`), so past verification outcomes surface in future sessions. Decoupled —
  it reads the JSONL by its public shape, no import of the verify-evidence module; bounded
  to the 50 most recent entries; opt out with `HARNESS_RAG_EVIDENCE_OFF=1`. The CC
  rag adapter now also runs when only the evidence log exists (no curated feedback dir).
- **Cross-runtime conformance matrix (`tests/runtime_conformance_test.sh`).** The
  git-commit/push classification that gates the protected-branch guard is implemented
  separately per runtime (CC shell parser vs OpenCode `isGitMutation`), and drifted
  before — the CC guard was hardened while OpenCode kept a substring match. One shared
  case table is now asserted against every runtime's real implementation and fails on
  any disagreement (Codex is asserted as a deliberate no-guard non-participant). The
  previously duplicated per-runtime classification cases (in `guard_test.sh` and the
  OpenCode `dogfood.test.ts`) were folded into this single source of truth.
- **Monorepo per-member harness generation (`render.sh <target> --members`).** The root
  scan already NAMED a monorepo's members, but only the root stack was rendered — a
  polyglot repo left every sub-package without a tailored architect/critics. `--members`
  now renders each member's OWN `<stack>-architect` and conditional `db-verify`/`ui-verify`
  into its `<member>/.claude/agents`, driven by that member's own detection (one level
  deep, deterministic). The introspect skill invokes it for monorepos; a member's agents
  load when that member is opened as the working root (the norm for per-package work).

### Documentation
- Corrected the `harness-kit.json` precedence claim: `env override > file > default`
  holds for `protected_branches` only. `verify_command` is read from the file alone —
  its sole env control is the `HARNESS_VERIFY_OFF=1` off switch (no env override, no
  built-in default command).
- `pickup` now searches the active spec's `context.md` resume block before
  `.claude/handoff.md` (mirroring where `handoff` writes) and prefers the most
  recently modified when both exist; the spec `context.md` template gained the
  `Don't redo:` field that `handoff` already required.

## [0.7.0] - 2026-07-13

**Codex tracer + runtime-safe Stop feedback.** Harness Kit can now be installed as
a Codex plugin without loading the Claude Code-only protected-branch guard. The
shared verification loop understands both runtimes while keeping their output
contracts separate.

### Added
- `.codex-plugin/plugin.json` with shared skill discovery and an explicit Codex
  lifecycle-hook path.
- `adapters/codex/hooks.json` with a Stop-only adapter. It sets
  `HARNESS_RUNTIME=codex` instead of guessing the runtime from overlapping payload
  fields.
- `.agents/plugins/marketplace.json` with a Git-backed repository-root source for
  direct Codex marketplace installation.
- Contract tests for Codex `cwd`, Stop continuation, `stop_hook_active` loop
  prevention, marketplace wiring, and CC output
  preservation.
- A model-free CI smoke that uses the real Codex CLI to ingest and install the
  packaged plugin into an isolated `CODEX_HOME`.

### Fixed
- `tests/detect_test.sh` no longer reports green when the blank-repository assertion
  calls missing helpers; unexpected shell failures now stop the suite.
- **The shared Stop hook looped until the runtime's block cap.** Claude Code and
  Codex re-fire Stop after a continuation with `stop_hook_active: true`; the hook
  now stands down on that re-fire for both blocking and non-blocking paths.
- **The Stop hook could hang on an unclosed stdin.** Input is now read only when a
  payload can arrive and is bounded to two seconds. A TTY, malformed payload, or
  inherited pipe that never closes degrades safely instead of hanging.
- **Codex non-blocking reminders were UI-only and did not re-enter the model loop.**
  Codex now uses the documented Stop `decision: block` continuation contract;
  Claude Code keeps its non-blocking `additionalContext` contract.
- **Sessions launched from a monorepo subdirectory missed the root Harness Kit
  configuration and dirty state.** The shared Stop hook now resolves the git root
  from the runtime-selected directory and reports a root-anchored verification
  command for both Claude Code and Codex.

### Verified scope
- Live Codex CLI plugin installation and one Stop continuation completed
  successfully, including the configured verification command and loop termination.
- Codex protected-branch `PreToolUse`, Codex custom-agent generation, and Codex-native
  `introspect` output remain deferred.

## [0.6.1] - 2026-07-09

**Version-manifest alignment.** The `v0.6.0` release tag was cut with
`.claude-plugin/plugin.json` still reporting `0.5.2`, so installers of `harness-kit@0.6.0`
saw a manifest that mis-reported its own version. This patch bumps the manifest to match
the release and closes the drift.

### Fixed
- `plugin.json` `version` bumped `0.5.2` → `0.6.1` to align the plugin manifest with the
  published release tag and CHANGELOG (the CI version-coherence gate now passes).

## [0.6.0] - 2026-06-30

**Dual-runtime support + agentic engine.** The kit now works with both Claude Code
and OpenCode — same skills, same discipline, your runtime. This release also adds the
first four modules of the agentic engine layer: cross-vendor verification, RAG-based
feedback retrieval, intent routing, and verify-evidence capture.

### Added — OpenCode adapter (`adapters/opencode/`)
- **Plugin entry point** with three hooks: verify-loop (feedback), branch-guard (protected
  branch), and compaction (resume). Config resolved from `.opencode/harness-kit.json`,
  falling back to `.claude/harness-kit.json`. 13 dogfood tests (mock shell, all pass).

### Added — Agentic engine (`agentic-engine/`)
Four modules, 83 tests total, all passing:

- **cross-vendor** (`outside-voices.sh`) — N-vendor parallel verification core. Pure bash
  for portability; vendor registry pattern (`_vendor_<name>_cmd`); 3-state exit
  (ok/timeout/timeout-unanimous); durable capture to `.harness-kit/outside-voices/`.
  CC Stop hook + OC `tool.execute.after` adapter. 21 shell tests.
- **rag-feedback** — embedding-based retrieval of past feedback memory. Three providers
  (OpenAI / Google / ollama opt-in); cosine similarity; hash-based cache invalidation
  with atomic write. CC `UserPromptSubmit` adapter works fully; OC adapter stubbed
  (`system.transform` doesn't expose the user's latest message). 20 unit tests.
- **intent-router** — embedding-based SKILL.md classification. Cosine similarity
  threshold; reuses rag-feedback's provider abstraction. CC `UserPromptSubmit` adapter
  works fully; OC adapter stubbed (same limitation). 12 unit tests.
- **verify-evidence** — JSONL evidence capture from critic agents. Regex parser
  (`Verified:` / `Tests:` / `✓` / `typecheck:`); append-only `.harness-kit/evidence.jsonl`.
  CC `SubagentStop` + OC `tool.execute.after` adapters. 17 unit tests.

### Changed
- README updated with dual-runtime install instructions and honest status for the new
  modules (what's proven vs stubbed).

### Known limitations
- OC adapters for rag-feedback and intent-router are stubbed — `experimental.chat.system.transform`
  fires per-LLM-call, not per-user-message, and doesn't expose the user's latest message.
  Full OC adapters wait for a `chat.prompt.before` or equivalent hook.
- OpenCode adapter tested with mock shell only; not yet dogfooded in a live OC session.

## [0.5.2] - 2026-06-28

Security hardening — the kit's whole job is scanning an UNTRUSTED target repo, so the
last audit angle was content flowing FROM that repo's manifest INTO a generated agent a
user later loads. The RCE execution vector was already closed (v0.4.x, `detect.sh` `add()`
dropped `eval`); this closes the content-injection sibling.

### Security
- **Untrusted manifest content is now sanitized before it is embedded in a generated
  agent.** A target repo's `package.json` `name` (or a `Cargo.toml` / `pyproject.toml`
  field, or a script command) flowed VERBATIM into the rendered `<stack>-architect`
  body — so a crafted `name` like `app](http://evil) **SYSTEM: …**` landed as live
  markdown / a link / a prompt-injection string inside an agent definition. `render.sh`
  now strips control chars + newlines (no multi-line / YAML-key breakout) and the
  markdown-structural chars (`` ` `` `[]()<>{}|*#`) from these untrusted scalars and caps
  their length. YAML frontmatter structure was already safe (the `name` key uses a fixed
  stack slug, never the untrusted string); this neutralizes the agent *body* content too.
  Languages / frameworks / store come from `detect.sh`'s fixed vocabulary and were never
  a vector. New `render_test.sh` case [12] proves the payload is neutralized and the
  frontmatter stays single-key-per-line valid YAML.

## [0.5.1] - 2026-06-28

Final end-to-end gap sweep — the install→introspect→render→hooks→workflow spine was
confirmed clean, but running the WHOLE kit once on ordinary input surfaced scaffolder
bugs. All fixed.

### Fixed
- **ADR / spec title with `/` or `&` crashed or corrupted the scaffolder.**
  `new-adr.sh` / `new-spec.sh` filled the template with `sed`, so a perfectly ordinary
  title — `CI/CD`, `A/B test`, `Q&A` — hit `sed: bad flag` (crash + a 0-byte ADR
  occupying the number) or silently mangled the `&`. Now filled with `python3`
  `str.replace` (metacharacter-safe). The most likely first-run failure, gone.
- **`new-adr.sh` used `ls | grep`** (SC2010, fragile on odd filenames) → replaced with a
  glob loop. **CI shellcheck now covers ALL scripts** (the scaffolders were unchecked)
  and is **blocking** (was `|| true`).
- **`render.sh` orphaned a stale `<old-stack>-architect.md`** when the stack slug changed
  on re-run (e.g. typescript → node) — now reaped, like db-verify/ui-verify.
- **`detect.sh` silently failed (empty stdout, exit 0) when `python3` was missing** — now
  emits `{"error":"python3 not found"}` and exits non-zero.
- README test-count claim made version-agnostic (was a stale "83").

### Added
- `tests/resume_loop_test.sh` pins the handoff ↔ context.md ↔ pickup marker contract (a
  1-char drift in any of the three now fails CI instead of silently breaking resume).
- Regression tests for the metacharacter titles + the architect reap. → 172 tests.

## [0.5.0] - 2026-06-26

User-diversity coverage — handle the tails of the real-user distribution
(greenfield / unknown stack / non-Node-Python) that the detector previously left
silently under-served.

### Added
- **Ruby + JVM detection** — `detect.sh` now implements the `Gemfile` (Ruby: rspec /
  minitest, rails / sinatra, bundler) and `pom.xml` / `build.gradle[.kts]` (Java /
  Kotlin: Maven / Gradle test+build commands, name from `<artifactId>`) markers that
  SKILL §2 already promised — closing a doc-over-promise where a Ruby/JVM repo was
  silently treated as stackless. `render.sh` renders their architects unchanged (it's
  stack-agnostic). Added to the monorepo member markers too.
- **Edge-of-distribution guidance** (SKILL §3): a **blank/greenfield** repo (no
  manifest) now gets only the universal §0 discipline spine + a "re-run once you add a
  stack" note (no fabricated stack); a manifest `detect.sh` doesn't cover
  (composer.json / mix.exs / *.csproj / deno.json …) gets a documented LLM fallback —
  read the manifest, hand-write a basic architect from the template — so an uncovered
  stack degrades gracefully instead of getting nothing.
- README documents stack coverage + that the generated harness is **English** (no
  localization of rules/structure).
- +9 tests (→ 159): Ruby, JVM, blank-slate detection + blank-slate render.

## [0.4.1] - 2026-06-26

Integration-audit fixes — close the connection-point holes between the plugin and
Claude Code's hook runtime (verdict was otherwise solid: manifest, discovery,
frontmatter, both enforcing hook paths, and config wiring all verified against the CC
spec).

### Fixed
- **verify-loop's default (non-blocking) reminder was silently discarded.** It wrote
  the "verify before done" reminder to stderr on exit 0 — which Claude Code drops for a
  Stop hook (confirmed against the CC hooks docs: only
  `hookSpecificOutput.additionalContext` continues the turn). So the kit's headline
  feedback half was a runtime no-op in the default mode. Now emitted as
  `hookSpecificOutput.additionalContext` on stdout, the channel CC honors. The contract
  test was updated too — it had captured stderr, masking the hole with a green test.
- **`render.sh` leak-guard scanned the whole agents dir** — a user's own agent carrying
  a `{{TOKEN}}`-shaped string would trip a false leak abort and block generation. Now it
  scans only the files render wrote this run.
- **`render.sh` left orphan critics on re-run** — on the supported UPDATE path, dropping
  a data layer / frontend left a stale `db-verify.md` / `ui-verify.md` the spine no
  longer routes to. render now reaps those two render-owned files when no longer
  applicable (never touching user-authored agents).
- +4 tests (→ 150).

## [0.4.0] - 2026-06-26

Hybrid renderer — shrink the probabilistic (LLM) surface of `introspect` to just the
spine's judgment prose.

### Added
- **`render.sh` — a deterministic renderer for the three generated agent files** (the
  `<stack>-architect` and the conditional `db-verify` / `ui-verify` critics). Those
  files have only pure-data / table-lookup slots, so a script fills them instead of the
  LLM. This makes the whole class of slot-fill defects the dogfood pass found
  (wrong store idiom, empty `()` / backticks, dir-name project_name, a leaked
  `{{SLOT}}`) **deterministically impossible** — `render.sh` exits non-zero if any slot
  would leak — and **fully testable** (`tests/render_test.sh`, 21 cases across the
  stack matrix). The store-verify idiom table now lives in `render.sh` as the single
  source of truth.
- +23 tests (→ 146).

### Changed
- **`introspect` (SKILL §4)** now runs `render.sh` for the agent files instead of
  hand-filling templates; the **only** LLM-filled, probabilistic part left is the
  spine's judgment slots (`{{ARCHITECTURE_NOTE}}` / `{{STACK_LINES}}` /
  `{{TEST_DISCIPLINE}}` / `{{AGENT_ROUTING}}`) — the irreducible residue, which the
  README/dogfood-log now scope precisely.
- `generation_contract_test` slot-contract split: spine slots are checked against the
  SKILL (LLM fills them), agent slots against `render.sh` (the renderer fills them).

## [0.3.4] - 2026-06-26

Test-hardening — deterministic guards for the contract around the (probabilistic)
generation step. No product behavior change beyond one generation-guidance fix.

### Added
- **Generation-contract tests** (`tests/generation_contract_test.sh`): **referential
  integrity** — every critic / `tdd-runner` / `/harness-kit:<skill>` the spine routes
  to must resolve to a real file (catches rename/delete drift, which this kit's
  deletion-bias invites); **slot contract** — every `{{SLOT}}` in the generated
  templates must be documented as fillable in the SKILL (catches a slot that would
  render literally, incl. digit slots like `{{E2E_NOTE}}`).
- **Store idiom coverage** — `conditional_critics_test` now asserts each store row
  carries its signature verify idiom (`$exists` / `information_schema` / the MySQL
  no-`FILTER` warning / `PRAGMA table_info` / `HEXISTS`), so a row can't silently
  degrade to a wrong/empty howto.
- +40 tests (→ 123).

### Changed
- **`verify_command` join (C2 dogfood fix)** — `SKILL.md §4.4` now says to join with
  `&&` only the non-empty checks (no dangling `tsc --noEmit && `) and notes the hook
  runs inside the repo so a workspace-local bin resolves.

## [0.3.3] - 2026-06-26

Maturation from a dogfood pass — `introspect` was run against real public repos
across the unvalidated matrix (Go/Rust/monorepo/Python+DB/frontend); the kit's
judgment held everywhere and the plumbing defects it surfaced are fixed. See
[`docs/dogfood-log.md`](docs/dogfood-log.md).

### Fixed
- **Go / Rust / Python verify commands** — these branches set a test *runner* but no
  runnable command, so the verify-loop hook silently no-op'd on those ecosystems. Now
  `go test ./...` / `cargo test` / `pytest` (+ build/typecheck/lint defaults) are
  emitted, lighting up the verify loop. (D1)
- **`project_name` for Go/Rust** — now read from the Go module path / Cargo
  `[package].name`, not the clone-dir basename (`# CLAUDE.md — go` → `cobra`). (D6)
- **Prisma datasource** — was hardcoded to Postgres, so a MySQL/SQLite repo got a
  `db-verify` with Postgres-only `FILTER(WHERE)` queries that *error*. `detect.sh` now
  reads `schema.prisma` `provider`; the SKILL store table gained MySQL + SQLite rows. (D4)
- **Monorepo member detection (REL-5)** — `requirements.txt` / `setup.py` / `setup.cfg`
  are now member markers, so Python sub-packages are no longer invisible. (D3)
- **Duplicate members** — a dir with two manifests is now listed once. (D7)
- **Python package manager** — `uv.lock` / `poetry.lock` / `Pipfile.lock` detected. (C3)

### Changed
- **Empty-slot rendering** — `SKILL.md §4.2` now instructs the generator to omit empty
  slots (no empty `()` / inline-code / dangling `Build:` lines) and gives a
  no-test-runner fallback, so a frameworkless Go/Rust harness renders cleanly. (D2)
- README Status narrowed to the dogfood evidence; +12 tests (→ 83).

### Known limitations (0.x)
- Cargo `[workspace]` `members`/`exclude` not parsed (find-based member scan can
  include an excluded crate or miss a no-manifest binary crate) — tracked. (D5)

## [0.3.2] - 2026-06-26

### Changed
- **IP / attribution hygiene** (from an adversarial copyright audit — verdict was
  CLEAN, these are norm nits, no obligation existed): added a "not affiliated with
  Anthropic" disclaimer to the README ("Claude" / "Claude Code" used descriptively);
  renamed the `karpathy-guidelines` skill → `coding-guidelines` to drop a person's
  name from the public slug (content unchanged); fixed the `marketplace.json`
  `$schema` to the resolvable community URL (`json.schemastore.org/claude-code-marketplace.json`)
  — the previous `anthropic.com` URL 404'd and implied false provenance. The audit
  confirmed: no third-party code is vendored, no copied license headers, and no
  internal/proprietary content leaked (the engine is original bash; references like
  github-linguist / package-manager-detector are credited ideas, not copied code).

## [0.3.1] - 2026-06-26

A security + honesty patch from an adversarial OSS-readiness audit.

### Security
- **Critical RCE in `detect.sh` fixed.** The `add()` helper used `eval` to build its
  comma-lists; the `members` list is fed attacker-controlled directory names from a
  scanned (untrusted) target repo, so a crafted dir name like
  `a$(…)b/package.json` executed arbitrary shell when `introspect` scanned the repo —
  a drive-by RCE in a tool whose whole job is scanning untrusted repos. Replaced
  `eval` with a `printf -v` / `${!var}` form that stores values as inert data (no
  re-evaluation), portable to bash 3.2. Added a regression test (`detect_test.sh` [8])
  that feeds a `$(touch MARKER)`-named member dir and asserts nothing executes.

### Changed
- **Honest status / caveats** (the audit flagged overclaim): README now states that
  harness *generation* is LLM-driven and probabilistic (only *detection* is e2e-
  validated), that only TS + Python are generation-validated end-to-end, and adds a
  Requirements section (bash + python3; Windows via WSL; hooks fail open without
  python3). Test count corrected to 71.

## [0.3.0] - 2026-06-26

The introspect-first thesis extended to verification + build discipline, plus a
full cross-file coherence audit (identity / version / detection-gap fixes).

### Added
- **Stack-conditional critics** — `introspect` now generates a `db-verify` critic
  **only when a data layer is detected** (tailored to the real store: MongoDB
  `$exists` counts / Postgres `information_schema` / Redis) and a `ui-verify` critic
  **only when a frontend framework is detected** (tailored to the real dev command).
  Generated like the architect (not shipped static) because their commands are
  stack-specific — the introspect-first thesis applied to verification. The kit does
  **not** bundle the DB client or browser driver these need; introspect surfaces the
  one command to add them as guidance (§5 "External setup you may need") and never
  copies an external tool into the repo. New spine slot `{{CONDITIONAL_CRITICS}}`;
  replaces the old dead references to non-existent UI skills. +20 tests (→ 69).
- **Build-discipline layer** — `/harness-kit:tdd` + the `tdd-runner` agent
  (red → green → refactor, test-first), `/harness-kit:diagnose` (reproduce →
  minimize → hypothesize → fix the cause → regression-test),
  `/harness-kit:karpathy-guidelines` (surgical changes, no overcomplication,
  verifiable success), and the `architecture-reviewer` critic (layers / smells /
  invariants — the review pair of the generated `<stack>-architect`). Closes the
  build-discipline gap: the kit had verification + artifacts but not the
  test-first / debug discipline. The spine `## Workflow` gains a Build bullet and
  `## Critics` gains `architecture-reviewer` (eight critics).

### Fixed
- **Coherence audit remediation** (a full cross-file / per-stack-generation sweep):
  - **Identity** — `plugin.json` author, `marketplace.json` owner, and `LICENSE`
    copyright now use the publishing identity (`Jack Lee` / `github.com/jhlee0409`);
    the prior placeholder leaked an unrelated account onto the distribution surface.
  - **Python data layer detected** — `detect.sh` now recognizes a Python DB client
    (`pymongo` / `motor` / `sqlalchemy` / `psycopg` / `redis`), so a FastAPI + Mongo
    backend correctly gets a `db-verify` critic (previously DB detection was
    Node-only — the canonical backend stack silently shipped no `db-verify`).
  - **Measurement vapor removed** — `introspect` no longer mentions a Tier-3
    measurement subsystem or an `--enable-measurement` flag (neither exists); this
    matches the "no measurement system" thesis the README/CHANGELOG state.
  - **No dash sentinel** — an absent `dev`/`build`/`test` script now yields an empty
    field, not a literal `-` that could leak into a generated `{{DEV_COMMAND}}`.
  - **Monorepo** — `introspect` re-runs `detect.sh` per member (the root scan only
    names members); doc/comment honesty fixed to match.
  - Doc/template fixes: README hook paths (`hooks/scripts/…`), the five-key config
    schema noted, the resume-block fields moved inside the `resume:*` markers, the
    guard's default branches de-personalized, and a CI identity/version guard added.

## [0.2.0] - 2026-06-26

The workflow + verification layer: structured artifact management, a seven-critic
verification spine, the introspect routing block, a validated resume loop, and
brand assets. Reliability comes from discipline + independent checks — no
measurement system (deliberately cut as too heavy).

### Added
- **Agent routing** — introspect generates an explicit `## Agents` block in the
  spine so the main agent delegates to the right `<stack>-architect` without being
  named (auto-orchestration by explicit guidance, not description-matching luck).
- **Artifact-management skills** — `/harness-kit:new-spec` (spec / plan / context
  triplet), `/harness-kit:adr` (auto-numbered ADR), plus a spine `## Workflow`
  section (spec discipline / ADR / scratch).
- **Worktree workflow (ask-gated)** — introspect ASKS whether to enable a
  worktree-per-task workflow; `/harness-kit:worktree <slug>` isolates a task.
  Opinionated choices are asked, not assumed.
- **Resume loop** — `/harness-kit:handoff` writes a resume block;
  `/harness-kit:pickup` continues in a fresh session. Shipped only after a
  discriminating validation: a fresh session respected a non-obvious decision a
  no-handoff control missed 3/3.
- **Verification spine — seven read-only critics** routed on demand at each
  boundary: `instruction-critic` (is this the right ask?),
  `requirement-fidelity-critic` (spec drift from the original ask?),
  `change-verifier` (is the change complete?), `claim-checker` (overclaim? — with
  spine `§0.6 No overclaim`), `spec-reviewer` (PR vs its spec), `readability-critic`
  (can a human decide from this output?), `pr-shepherd` (is the PR mergeable?).
  Independent verification is the reliability lever; effect is marginal-but-real,
  not a guarantee — the only proven 100% check is a human.
- **`pr-shepherd` discovers the PR workflow** instead of assuming one — host / CI /
  bots are read at runtime, intent is pinned via a `pr_workflow` config
  (host / ci / merge_gate), it degrades gracefully when CI or a host CLI is absent,
  and never fabricates a MERGEABLE verdict without a defined gate.
- **Brand** — SVG logo, 1280×640 social-preview card, README hero, and an honest
  demo GIF (the real `/harness-kit:introspect` trigger, not a fabricated CLI).
- Tests: +spec (4) +adr (4) +worktree (4) → **49** across all suites.

### Changed
- The spine grew `§0.6 No overclaim` and `## Workflow` / `## Critics` sections;
  introspect seeds `worktree_workflow` and `pr_workflow` in `.claude/harness-kit.json`.

## [0.1.0] - 2026-06-26

First public release.

### Added
- `introspect` skill: scans a target repo's stack and generates a tailored harness
  (root `CLAUDE.md` spine + stack `*-architect` agent + `.claude/harness-kit.json`
  verify config + specs / ADR scaffolding).
- `detect.sh` detection engine (23-case suite) — layered-precedence detection of
  language / framework / test-runner / package-manager / monorepo / data-layer,
  plus typecheck/lint commands and polyglot per-subtree detection. Reads configs
  statically.
- `verify-loop` Stop hook — the feedback half of plan→work→verify→feedback, wired
  to the repo's real verify command. Non-blocking by default.
- `change-verifier` read-only critic agent.
- `protected-branch-guard` PreToolUse hook — configurable protected branches
  (env override > repo config > built-in default).
- `update-block.sh` — idempotent marked-block updater for safe introspect re-runs.
- `.claude/harness-kit.json` per-repo config; plugin + marketplace manifests, MIT
  license, community-profile files, CI. 37 tests.

[0.9.1]: https://github.com/jhlee0409/omni-harness-kit/releases/tag/v0.9.1
[0.9.0]: https://github.com/jhlee0409/omni-harness-kit/releases/tag/v0.9.0
[0.8.0]: https://github.com/jhlee0409/omni-harness-kit/releases/tag/v0.8.0
[0.5.2]: https://github.com/jhlee0409/omni-harness-kit/releases/tag/v0.5.2
[0.5.1]: https://github.com/jhlee0409/omni-harness-kit/releases/tag/v0.5.1
[0.5.0]: https://github.com/jhlee0409/omni-harness-kit/releases/tag/v0.5.0
[0.4.1]: https://github.com/jhlee0409/omni-harness-kit/releases/tag/v0.4.1
[0.4.0]: https://github.com/jhlee0409/omni-harness-kit/releases/tag/v0.4.0
[0.3.4]: https://github.com/jhlee0409/omni-harness-kit/releases/tag/v0.3.4
[0.3.3]: https://github.com/jhlee0409/omni-harness-kit/releases/tag/v0.3.3
[0.3.2]: https://github.com/jhlee0409/omni-harness-kit/releases/tag/v0.3.2
[0.3.1]: https://github.com/jhlee0409/omni-harness-kit/releases/tag/v0.3.1
[0.3.0]: https://github.com/jhlee0409/omni-harness-kit/releases/tag/v0.3.0
[0.2.0]: https://github.com/jhlee0409/omni-harness-kit/releases/tag/v0.2.0
[0.1.0]: https://github.com/jhlee0409/omni-harness-kit/releases/tag/v0.1.0
