---
name: introspect
description: >-
  Scan a repository's tech stack and generate a tailored Claude Code harness for
  it — a thin .claude/CLAUDE.md spine, stack-specific architect agent(s), and
  specs/ADR scaffolding — fitting the generic harness-kit engine to this repo.
  Use when setting up the harness in a new or existing repo, or when the user
  says "set up the harness here", "introspect this repo", "tailor claude config",
  "scaffold .claude for this project".
argument-hint: "[target-dir]"
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# introspect — fit the harness to this repo

You generate the **repo-specific layer** of the harness. The **generic engine**
(change-verifier and other critic agents, portable skills, the protected-branch
guard hook) already ships in the installed `harness-kit` plugin and fires
everywhere — do NOT regenerate or duplicate it. Your job is only what is specific
to THIS repository: the CLAUDE.md spine, the stack architect(s), and scaffolding.

Templates live at `${CLAUDE_PLUGIN_ROOT}/templates/`. Read them, fill the slots,
write the result into the target repo. Never invent a stack you did not observe.

## 1. Resolve the target

Target dir = the skill argument if given, else the current working directory.
Confirm it is a git repo or at least a project root (has a manifest). If a
`.claude/CLAUDE.md` already exists, read it first and treat this as an UPDATE
(merge, don't clobber the user's edits) — report what you would change before
overwriting.

## 2. Detect the stack (observe, never assume)

Run a detection sweep and read what you find. Markers and what they imply:

| Marker file | Implies |
|---|---|
| `package.json` | Node. Read `dependencies`/`devDependencies` + `scripts`. |
| `pyproject.toml` / `requirements.txt` / `setup.py` | Python. |
| `go.mod` | Go. |
| `Cargo.toml` | Rust. |
| `pom.xml` / `build.gradle` | JVM. |
| `Gemfile` | Ruby. |
| shell test suite (`tests/*_test.sh` / `*.bats`) + no other manifest | Shell tooling repo (fallback — only when no packaged-language manifest exists). |

From `package.json` dependencies, classify the **framework**:
`next`→Next.js · `react`(no next)→React SPA · `vue`/`nuxt`→Vue ·
`@modelcontextprotocol/sdk`→MCP server · `express`/`fastify`/`koa`→Node API ·
`electron`→Electron · none of these + `bin`→CLI/library.
From Python: `fastapi`/`flask`/`django`→web API; `mcp`→MCP server.

**Test runner** (from scripts/deps): `vitest` · `jest` · `mocha` · `pytest` ·
`go test` · `cargo test`. Capture the actual command (prefer the repo's own
`test` script, e.g. `npm test`).

**Build / dev commands**: read the repo's `scripts` (Node) or documented commands
(`tsc`, `uvicorn`, `go build`, …). Use the repo's real commands, not guesses.

**Monorepo**: `workspaces` in package.json, `apps/`+`packages/`, `pnpm-workspace.yaml`,
`turbo.json`, or `lerna.json` → multiple sub-contexts.

**Data layer**: a DB client in deps (`mongodb`/`mongoose`/`motor` · `pg`/`prisma`/
`drizzle` · `sqlalchemy` · `redis`) → the project touches a store.

A ready-made detection helper: run
`bash "${CLAUDE_PLUGIN_ROOT}/skills/introspect/detect.sh" <target-dir>` and read
its JSON-ish summary, then verify anything ambiguous by reading the manifest
directly.

## 3. Classify into tiers

**First, the edge of the distribution** (the kit serves greenfield → legacy, any stack,
any locale — handle these before the normal path):
- **No manifest at all (blank / greenfield repo)** → there is no stack to tailor.
  Generate ONLY the generic §0 discipline spine; keep the stack-specific slots minimal
  or empty (no architect, no critics — `render.sh` correctly writes nothing), and add one
  line: *"No stack detected yet — re-run `/harness-kit:introspect` once you add a manifest
  (package.json / pyproject.toml / go.mod / Cargo.toml / Gemfile / pom.xml) to tailor the
  architect + critics."* Don't fabricate a stack.
- **A manifest `detect.sh` doesn't cover** (composer.json / mix.exs / *.csproj /
  pubspec.yaml / deno.json …) → `detect.sh` returns empty `languages`, so `render.sh`
  writes no architect. READ that manifest yourself and hand-write a `<stack>-architect`
  from `templates/agents/stack-architect.md` using its REAL test/build commands (the
  deterministic renderer only covers the detected stacks node/python/go/rust/ruby/jvm;
  for any other, fill the template manually and cite the manifest you read).
- **Output language**: the generated harness is **English** (the kit's lingua franca);
  do not localize the rules or structure.

- **Tier 1 — always.** The CLAUDE.md §0 spine + the generic critics from the
  plugin. Every repo gets this.
- **Tier 2 — conditional, you generate it:**
  - any compiled/typed language or framework → a `<stack>-architect` agent (§4 step 2).
  - **frontend framework** (React / Next / Vue / Svelte) → generate a `ui-verify`
    critic (§4 step 2) tailored to the dev command + framework, and list it in the spine
    `## Critics`. It needs a browser driver, which the kit does NOT bundle — surface
    the setup as guidance in §5, never copy a tool in.
  - **data layer present** (mongodb / postgres / redis / …) → generate a `db-verify`
    critic (§4 step 2) tailored to the detected store, and list it in the spine
    `## Critics`. It needs the store's client, which the kit does NOT bundle —
    surface the setup as guidance in §5.
  - monorepo → run **`render.sh <target> --members`**: the root scan only NAMES members
    and the default render covers only the root stack, so `--members` renders each
    member's OWN `<stack>-architect` + conditional critics into its
    `<member>/.claude/agents` (deterministic, driven by that member's own detection).
    Then hand-write one sub-context `CLAUDE.md` stub per active member with a note that
    the sub-context wins on conflict. (A member's `.claude/agents` is auto-loaded only
    when that member is opened as the working root — the norm for per-package monorepo
    work; the root harness still covers the root stack.)
- **Tier 3 — none.** Harness Kit ships NO measurement / self-evolving / memory
  subsystem (deliberately cut as too heavy). Reliability comes from the discipline
  + independent critics above, not metrics. Do NOT generate, mention, or promise a
  measurement layer — it does not exist, and offering one would be a dead reference.

## 3.5 Ask the user (opinionated choices)

Universal discipline is generated unconditionally. But some workflow choices are
opinionated — not every team wants them — so ASK rather than assume. You run
inside Claude Code, so use `AskUserQuestion`:

- **Worktree-per-task?** "Isolate each code-change task in its own git worktree
  (`../<repo>-<slug>`), keeping the main checkout clean? Good for parallel work;
  skip if you prefer one checkout." — yes / no.

Record the answer; it drives the `worktree_workflow` flag and the
`{{WORKTREE_RULE}}` slot below. (If the skill is run non-interactively, default to
**no** — don't impose an opinionated workflow silently.)

## 4. Generate the files

1. **Root harness — `AGENTS.md` (canonical) + `CLAUDE.md` (imports it).** Write the
   spine to **`<target>/AGENTS.md`** — the cross-vendor standard file that Codex /
   Cursor / other agents read directly — and wire `CLAUDE.md` to `@AGENTS.md`-import
   it (Claude Code expands @-imports), so there is ONE source of truth: no
   duplication, no drift, no symlink. See `docs/adr/0001-agentsmd-canonical-*`. The
   files MUST live at the repo ROOT (only `./AGENTS.md` / `./CLAUDE.md` are
   auto-loaded; nested copies are NOT). Two modes for AGENTS.md:
   - **No AGENTS.md exists** → write the full `templates/CLAUDE.md.spine` to it.
   - **An AGENTS.md already exists** → do NOT clobber it. Write a marked block
     `<!-- harness-kit:start ... -->` … `<!-- harness-kit:end -->` (a condensed spine
     under a `## Engineering harness` heading) via the idempotent updater so a re-run
     replaces its own block instead of stacking a copy:
     ```bash
     printf '%s' "$BLOCK" | bash "${CLAUDE_PLUGIN_ROOT}/skills/introspect/update-block.sh" \
       <target>/AGENTS.md '<!-- harness-kit:start' '<!-- harness-kit:end -->'
     ```
   Then wire CLAUDE.md to import it (idempotent; preserves any other CLAUDE.md content):
     ```bash
     bash "${CLAUDE_PLUGIN_ROOT}/skills/introspect/aliases.sh" <target>
     ```
     (`$BLOCK` includes both markers. Lesson 5 generated-file marking.)
   Fill in either case:
   - `{{PROJECT_NAME}}` — from the manifest `name`.
   - `{{STACK_LINES}}` — one bullet per detected language/framework, citing the
     declaring file (`package.json`, `tsconfig.json`).
   - `{{ENTRY_POINTS}}` — the real dev / build / test commands from detect.sh.
   - `{{TEST_DISCIPLINE}}` — the runner + command + a "tests-first for non-trivial
     changes" line (mandatory-TDD wording for backend/library code).
   - `{{AGENT_ROUTING}}` — list the `<stack>-architect`(s) you generated THIS run,
     each with a *when*, so the main agent delegates architecture work without
     being told. **List ONLY architects that exist** — don't invent agents; a
     detected concern with no agent (a database) becomes a `§0.2` verify rule. The
     verification critics are already in the static `## Critics` section — do NOT
     duplicate them here. Example:
     ```
     - `typescript-architect` — structural / refactoring / deepening architecture work.
     ```
   - `{{ARCHITECTURE_NOTE}}` — name the `<stack>-architect` agent(s) you created
     and, for a monorepo, the sub-context map.
   - `{{WORKTREE_RULE}}` — from the §3.5 answer. If **yes**, emit a bullet:
     `` - **Worktrees.** Each code-change task gets its own worktree via ``
     `` `/harness-kit:worktree <slug>` (`../<repo>-<slug>`); the main checkout stays read-only for edits. ``
     If **no**, leave it empty (remove the placeholder line entirely).
   - `{{CONDITIONAL_CRITICS}}` — the stack-conditional critics you generated THIS
     run (§4 step 2): a `db-verify` row if the data layer was present, a `ui-verify` row
     if a frontend framework was present. Generated neither → remove the placeholder
     line entirely. Format each like the static critic rows, e.g.:
     `` - `db-verify` — is a data claim true against the real {{STORE}} store? — before a data-touching change. ``
     `` - `ui-verify` — does the UI actually render and work? — after a frontend change. ``

2. **The generated agents — `render.sh` writes these DETERMINISTICALLY; do NOT
   hand-fill them.** The `<stack>-architect` and the conditional `db-verify` /
   `ui-verify` critics have only pure-data / table-lookup slots, so a script fills
   them — which removes the LLM slot-fill error class (a wrong store idiom, an empty
   `()` / backtick, a dir-name project_name) and makes the output testable. Run:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/skills/introspect/render.sh" <target>
   ```
   It runs detection, then writes into `<target>/.claude/agents/`:
   - `<stack>-architect.md` — always (when a language was detected); `{{STACK}}` is the
     clean language slug, empty slots are omitted, a no-test-runner repo gets a
     fallback instead of empty backticks.
   - `db-verify.md` — ONLY when a data layer is detected, tailored to the store
     (MongoDB / PostgreSQL / MySQL / SQLite / Redis — `render.sh` owns the idiom table
     and reads the Prisma `schema.prisma` provider, so a MySQL repo is never given
     Postgres-only queries).
   - `ui-verify.md` — ONLY when a frontend framework is detected (the real dev command
     + the e2e driver note from the repo's own Playwright / Cypress deps).
   `render.sh` exits non-zero if any slot would leak. Then **list each critic it
   generated in the spine's `{{CONDITIONAL_CRITICS}}` slot (step 1).** The ONLY slots
   the LLM fills are the spine's judgment ones in step 1 (`{{STACK_LINES}}` /
   `{{TEST_DISCIPLINE}}` / `{{AGENT_ROUTING}}` / `{{ARCHITECTURE_NOTE}}`) — that is the
   irreducible probabilistic residue; review it.

3. **`.claude/repo-map.md`** — a DETERMINISTIC navigation map (stack / entry
   points / top-level layout / monorepo members / where tests live) so an agent
   orients on the whole codebase by progressive disclosure: read the map, then
   drill into the exact subtree. Run:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/skills/introspect/repomap.sh" <target>
   ```
   Facts only — it never fabricates what a module *does* (that judgment is left for
   a human to fill in); dir roles are name-based heuristics. It is a navigation doc
   refreshed by re-running introspect, NOT a stored metric.

4. **`.claude/harness-kit.json`** — the single per-repo config both plugin hooks
   read (precedence for the hooks: env override > this file > built-in default).
   ```json
   {
     "verify_command": "<typecheck && test>",
     "blocking": false,
     "protected_branches": ["main", "master", "develop", "release"],
     "worktree_workflow": false,
     "pr_workflow": { "host": "github", "ci": "github-actions", "merge_gate": null }
   }
   ```
   - `verify_command` — the detected fast check. Join with `&&` ONLY the checks that
     are non-empty (C2 dogfood fix: a missing typecheck must not leave a dangling
     `tsc --noEmit && ` or a leading `&& test`); a single check stands alone. E.g.
     `"tsc --noEmit && vitest run"`, `"mypy . && pytest"`, just `"go test ./..."`, or
     `"cargo test"`. The command runs inside the repo (deps installed), so a
     workspace-local bin like `vitest` resolves. The verify-loop Stop hook surfaces it
     when code changed. Omit the key entirely if no check was detected.
   - `blocking` — leave `false` (reminds, non-intrusive); the user flips it to enforce.
   - `protected_branches` — seed from the repo's real long-lived branches; the
     protected-branch guard asks before commit/push on these.
   - `worktree_workflow` — the §3.5 answer (`true`/`false`); records whether this
     repo uses the worktree-per-task workflow.
   - `pr_workflow` — seeds what `pr-shepherd` can't safely assume (PR workflows
     vary wildly). Detect: `host` from `git remote` (github / gitlab / bitbucket /
     none), `ci` from config presence (`.github/workflows/` → github-actions,
     `.gitlab-ci.yml` → gitlab-ci, `.circleci/` → circleci, `Jenkinsfile` →
     jenkins, none). Leave `merge_gate: null` unless the user states one (then
     pr-shepherd reports state + "you decide" rather than fabricating MERGEABLE).
     Omit the whole block if there's no PR host (a local-only repo).

5. **Scaffolding** (only if absent): ensure `scratch/` is gitignored (append it
   to `.gitignore`); create `<target>/specs/.gitkeep` and
   `<target>/docs/adr/0000-record-architecture-decisions.md` (a one-paragraph ADR
   starter). The `/harness-kit:new-spec` and `/harness-kit:adr` skills (from the
   plugin) create specs and ADRs on demand — don't pre-build them here. Skip
   anything the repo already has.

Never write secrets, never touch `.env`, never overwrite a file you did not
generate without showing the diff first.

## 5. Report

Print a BLUF summary:
- **Detected**: stacks / frameworks / test runner / monorepo? / data layer? —
  each with the evidence (the manifest line you read).
- **Generated**: every file written, with its path.
- **From the plugin (not duplicated)**: the generic agents/skills/hooks now
  active in this repo.
- **MCP + external tools your critics need** (the kit does NOT bundle, copy, or
  auto-write these — MCP consent is **host-enforced by the spec**, so a kit that
  auto-generated a `.mcp.json` would be consent theater; the user adds only what they
  consent to, least-privilege). Surface, for what you generated THIS run:
  - `ui-verify` → the Playwright MCP (`claude mcp add playwright …`) or the repo's e2e tool.
  - `db-verify` → the store's client / MCP (`mongosh` / `psql` / `redis-cli`, or a DB MCP).
  - `blast-radius` / `change-verifier` → a code-intelligence source (the repo's LSP, or
    an LSP/SCIP MCP) sharpens enumeration; they degrade to ripgrep + AST without it.
  List only what's actually missing, with the one command to add it. Never silently
  embed an external tool / server in the repo, and never auto-write `.mcp.json`.
- **Refine**: 2–3 concrete next edits the user may want (e.g. "fill the Architecture
  note", "flip `blocking: true` once the verify command is trusted", "add a
  sub-context CLAUDE.md for the new package").
