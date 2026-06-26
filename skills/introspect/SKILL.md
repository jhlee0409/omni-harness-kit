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

- **Tier 1 — always.** The CLAUDE.md §0 spine + the generic critics from the
  plugin. Every repo gets this.
- **Tier 2 — conditional, you generate it:**
  - any compiled/typed language or framework → a `<stack>-architect` agent (§4.2).
  - **frontend framework** (React / Next / Vue / Svelte) → generate a `ui-verify`
    critic (§4.3) tailored to the dev command + framework, and list it in the spine
    `## Critics`. It needs a browser driver, which the kit does NOT bundle — surface
    the setup as guidance in §5, never copy a tool in.
  - **data layer present** (mongodb / postgres / redis / …) → generate a `db-verify`
    critic (§4.3) tailored to the detected store, and list it in the spine
    `## Critics`. It needs the store's client, which the kit does NOT bundle —
    surface the setup as guidance in §5.
  - monorepo → **re-run `detect.sh` against each `members[]` dir** (the root scan
    only NAMES members, it does not detect their stacks), then generate one
    sub-context `CLAUDE.md` stub + the per-member conditional critics from each
    member's OWN detection, plus a note that sub-context CLAUDE.md wins on conflict.
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

1. **Root `<target>/CLAUDE.md`** — the spine MUST live at the repo ROOT (only
   `./CLAUDE.md` is auto-loaded; a `.claude/CLAUDE.md` is NOT). Two modes:
   - **No CLAUDE.md exists** → write the full `templates/CLAUDE.md.spine`.
   - **A CLAUDE.md already exists** → do NOT clobber it. Write a marked block
     `<!-- harness-kit:start ... -->` … `<!-- harness-kit:end -->` (a condensed
     spine under a `## Engineering harness` heading) using the idempotent updater
     so a re-run replaces its own block instead of stacking a second copy:
     ```bash
     printf '%s' "$BLOCK" | bash "${CLAUDE_PLUGIN_ROOT}/skills/introspect/update-block.sh" \
       <target>/CLAUDE.md '<!-- harness-kit:start' '<!-- harness-kit:end -->'
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
     run (§4.3): a `db-verify` row if the data layer was present, a `ui-verify` row
     if a frontend framework was present. Generated neither → remove the placeholder
     line entirely. Format each like the static critic rows, e.g.:
     `` - `db-verify` — is a data claim true against the real {{STORE}} store? — before a data-touching change. ``
     `` - `ui-verify` — does the UI actually render and work? — after a frontend change. ``

2. **`.claude/agents/<stack>-architect.md`** — one per primary stack, from
   `templates/agents/stack-architect.md`. Fill `{{STACK}}`, `{{FRAMEWORKS}}`,
   `{{LANGUAGE}}`, `{{TEST_RUNNER}}`, `{{TEST_COMMAND}}`, `{{BUILD_COMMAND}}`, and
   `{{TEST_MANDATE}}` ("Write the failing test first." for backend/library;
   "Add/extend tests for the change." for frontend).

3. **`.claude/agents/db-verify.md` and/or `.claude/agents/ui-verify.md`** — the
   stack-conditional critics, generated ONLY when the matching signal is present.
   Templated like the architect (the eight static critics stay in the plugin; these
   are generated because their commands are stack-specific).
   - **data layer detected** → from `templates/agents/db-verify.md`. Fill
     `{{PROJECT_NAME}}`, `{{STORE}}` (the human name), and `{{STORE_VERIFY_HOWTO}}`:

     | Detected store | `{{STORE}}` | `{{STORE_VERIFY_HOWTO}}` |
     |---|---|---|
     | mongodb / mongoose / motor | MongoDB | Count with `$exists`: `db.<coll>.countDocuments({ <field>: { $exists: true } })` vs total; sample with `db.<coll>.find({}, { <field>: 1 }).limit(10)`; check the type of sampled values. Use `mongosh` or the repo's driver. |
     | postgres / pg / prisma / drizzle / sqlalchemy | PostgreSQL | Confirm the column in `information_schema.columns`; count population with `SELECT count(*) FILTER (WHERE <col> IS NOT NULL), count(*) FROM <table>;`; read the declared type from `information_schema.columns.data_type`. Use `psql` or the repo's client. |
     | redis / ioredis | Redis | Confirm a key/field with `EXISTS` / `HEXISTS`; check `TYPE <key>`; sample with a scoped `SCAN` (never `KEYS *` on a shared instance). Use `redis-cli`. |

     For any other store, fill the generic equivalent (existence + population + type
     against the real store) and name the client to install.
   - **frontend framework detected** → from `templates/agents/ui-verify.md`. Fill
     `{{PROJECT_NAME}}`, `{{FRAMEWORK}}`, `{{DEV_COMMAND}}` (the repo's real dev
     command), and `{{E2E_NOTE}}`:
     - repo has `@playwright/test` → "Drive the browser with the repo's Playwright (`npx playwright …`)."
     - repo has Cypress → "Drive with the repo's Cypress."
     - neither → "If the Playwright MCP is connected, use its `browser_*` tools;
       otherwise open `{{DEV_COMMAND}}` and capture a real-browser screenshot of the
       flow." (Surface the browser-driver setup in §5 — the kit bundles none.)
   - List each generated critic in the spine `{{CONDITIONAL_CRITICS}}` slot (step 1).

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
   - `verify_command` — the detected fast check (prefer `typecheck_cmd && test_cmd`,
     else whichever exists: `"tsc --noEmit && vitest run"`, `"mypy . && pytest"`,
     `"pytest"`). The verify-loop Stop hook surfaces it when code changed. Omit if
     no check was detected.
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
- **External setup you may need** (the kit does NOT bundle or copy these — it
  tells you how to add them, you install them): if you generated `ui-verify`, the
  browser driver it needs (the Playwright MCP — `claude mcp add playwright …` — or a
  repo e2e tool); if you generated `db-verify`, the store's client CLI / driver
  (`mongosh` / `psql` / `redis-cli`). List only what's actually missing, with the
  one command to add it. Never silently embed an external tool / skill in the repo.
- **Refine**: 2–3 concrete next edits the user may want (e.g. "fill the Architecture
  note", "flip `blocking: true` once the verify command is trusted", "add a
  sub-context CLAUDE.md for the new package").
