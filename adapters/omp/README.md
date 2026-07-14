# Harness Kit — omp (oh-my-pi) target

The omp-native target for Harness Kit. Where the root plugin ships the
cross-runtime critic fleet + workflow skills, this adapter adds an **omp-native
role/verify agent fleet**, verification **skills**, **TTSR** render/backend
guards, a deterministic **harness-check** audit device, a **project-onboarder**
that tailors `<repo>/.omp/` to a repo's stack, and per-project **templates**.

Everything here is omp-native (lowercase `tools:` + `autoloadSkills:`), kept
separate from the root `agents/` so the Claude Code / Codex / OpenCode experience
is unchanged.

## Install (omp)

```bash
omp plugin marketplace add jhlee0409/omni-harness-kit
omp plugin install harness-kit-omp@harness-kit-marketplace
```

## What's inside

### Agents (`agents/`)
An omp-native fleet the delivery-lead / main agent routes to:

- **Engine** — `project-onboarder` (detects a repo's stack and writes a tailored
  `<repo>/.omp/`: LSP rootMarkers, WATCHDOG, mcp, config), `harness-doctor` (runs
  the deterministic health check and fixes what's broken), `delivery-lead` (runs a
  whole feature A→Z across the roster in parallel waves).
- **Roles** — `ai-engineer`, `security-engineer`, `infra-engineer`,
  `qa-strategist`, `analytics-engineer`, `product-manager`, `product-designer`,
  `ux-writer`, `technical-writer`.
- **Verifiers** — `ui-verify`, `db-verify`, `chrome-verify`,
  `accessibility-auditor`, `performance-engineer`, `design-critic`. Each is
  evidence-first: a real browser probe, a real API round-trip, or a real store
  query — never "looks fine".

### Skills (`skills/`)
Methodology packs several agents auto-load: `accessibility-checks` (WCAG 2.2 AA in
a real browser), `perf-checks` (Core Web Vitals → bundle → render → DB → memory),
`llm-eng-checks` (prompt / RAG / eval / guardrails, real round-trip),
`ui-verify-checks`, `chrome-verify-checks`, `db-verify-checks`.

### Rules (`rules/`) — TTSR
Fire automatically on file edits: `verify-ui-render` (editing `*.tsx/jsx/vue/svelte`
→ demand a real render probe), `verify-backend-trace` (editing adapters / services /
api / `*.py` → demand a real API/DB trace).

### Engine (`scripts/harness-check.py`)
A deterministic, dependency-light audit device. In one pass it validates every
agent parses, tools are valid, `autoloadSkills` resolve (classifying omp-native vs
vendor-plugin), no duplicate/bundled name collisions, config.yml + model roles,
JSON configs, `.env` key presence, per-repo context-file discoverability, and MCP
command resolvability.

```bash
python3 scripts/harness-check.py [repo_path ...]   # exit 1 on any RED
```

`harness-doctor` wraps this and closes the RED findings.

### Templates (`templates/`)
Skeletons the onboarder (or you) copy into place: `RULES.md` (the team operating
model), `WATCHDOG.md` (the advisor false-completion charter), `config.yml` (model
roles + advisor/memory/lsp toggles), `lsp.json` (monorepo rootMarkers), `mcp.json`
(per-repo servers).

## Notes
- The agent fleet is omp-flavored (lowercase tool schema + `autoloadSkills`). It is
  intentionally isolated from the root `agents/` so it does not change the Claude
  Code / Codex / OpenCode surface.
- No secrets, model IDs, or private paths ship here — set your own in `config.yml`
  (`omp models` lists what your account can serve).
