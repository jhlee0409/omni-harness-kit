#!/usr/bin/env bash
# Deterministic renderer for the GENERATED AGENT files (the <stack>-architect and the
# conditional db-verify / ui-verify critics). Those three files have only pure-data /
# table-lookup slots, so rendering them deterministically removes a whole class of
# LLM slot-fill error the dogfood pass found (wrong store idiom, empty `()`/backticks,
# dir-name project_name) and makes them unit-testable. The SPINE (root CLAUDE.md) keeps
# its judgment slots (architecture note, stack prose) for the LLM — that is the
# irreducible probabilistic residue; this shrinks the residue to it.
#
# Usage: render.sh <target-dir> [--out <dir>]   (default out: <target>/.claude/agents)
# Reads configs statically via detect.sh (no eval, no target-code execution).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$HERE/../.." && pwd)}"
TARGET="${1:?usage: render.sh <target-dir> [--out <dir>]}"
OUT="$TARGET/.claude/agents"
[ "${2:-}" = "--out" ] && OUT="${3:?--out needs a dir}"

# Pass the detect JSON via a temp file, not stdin — stdin is the python heredoc script.
json_file="$(mktemp)"
trap 'rm -f "$json_file"' EXIT
bash "$HERE/detect.sh" "$TARGET" 2>/dev/null > "$json_file"
[ -s "$json_file" ] || { echo "render: detection failed for $TARGET" >&2; exit 1; }
mkdir -p "$OUT"

python3 - "$ROOT/templates/agents" "$OUT" "$TARGET" "$json_file" <<'PY'
import json, sys, os, re

tpl_dir, out_dir, target, json_file = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
detect = json.load(open(json_file))

langs = detect.get("languages", []) or []
fws   = detect.get("frameworks", []) or []
dl    = detect.get("data_layer", []) or []

# Sanitize UNTRUSTED scalars before embedding them in a generated agent. The target
# repo is untrusted (the kit's whole job is scanning it); a manifest `name` / script
# can carry prompt-injection text or markdown that would otherwise land verbatim in the
# agent a user later loads. Strip control chars + newlines (no multi-line breakout) and,
# for free text, the markdown-structural chars that enable link/heading/code injection;
# cap length. (languages/frameworks/store come from detect.sh's FIXED vocab — safe.)
def clean(s, n=64, cmd=False):
    s = re.sub(r'[\x00-\x1f\x7f]+', ' ', str(s))
    if not cmd:
        s = re.sub(r'[`\[\]()<>{}|*#]', '', s)
    return re.sub(r'[ \t]+', ' ', s).strip()[:n]

name  = clean(detect.get("project_name", "") or "project") or "project"
tr  = clean(detect.get("test_runner", "") or "")
tc  = clean(detect.get("test_cmd", "")  or "", n=120, cmd=True)
bc  = clean(detect.get("build_cmd", "") or "", n=120, cmd=True)
dev = clean(detect.get("dev_cmd", "")   or "", n=120, cmd=True)

# STACK slug from the LANGUAGE (not a framework) → always a clean slug, never a dot.
stack = "typescript" if "typescript" in langs else (langs[0] if langs else "code")
language = ", ".join(langs) or stack
frameworks = ", ".join(fws)
FRONTEND = {"next.js", "react", "vue", "svelte", "nuxt", "remix", "astro"}
is_frontend = any(f in FRONTEND for f in fws)
test_mandate = "Add or extend tests for the change." if is_frontend else "Write the failing test first."

# Store table — single source of truth (moved out of the SKILL prose).
STORES = {
  "mongodb":   ("MongoDB", "Count with `$exists`: `db.<coll>.countDocuments({ <field>: { $exists: true } })` vs total; sample with `db.<coll>.find({}, { <field>: 1 }).limit(10)`; check the type of sampled values. Use `mongosh` or the repo's driver."),
  "postgres":  ("PostgreSQL", "Confirm the column in `information_schema.columns`; count population with `SELECT count(*) FILTER (WHERE <col> IS NOT NULL), count(*) FROM <table>;`; read the declared type from `information_schema.columns.data_type`. Use `psql` or the repo's client."),
  "mysql":     ("MySQL", "Confirm the column in `information_schema.columns`; count population with `SELECT COUNT(*), SUM(<col> IS NOT NULL) FROM <table>;` (NO `FILTER (WHERE …)` — that is Postgres-only syntax and errors on MySQL); read the type from `information_schema.columns`. Use the `mysql` client."),
  "sqlite":    ("SQLite", "Confirm the column via `PRAGMA table_info(<table>)`; count population with `SELECT count(*), count(<col>) FROM <table>;`; sample rows. Use `sqlite3 <db-file>`."),
  "redis":     ("Redis", "Confirm a key/field with `EXISTS` / `HEXISTS`; check `TYPE <key>`; sample with a scoped `SCAN` (never `KEYS *` on a shared instance). Use `redis-cli`. If this store is only a cache/broker/queue, this critic may not apply."),
  "sqlserver": ("SQL Server", "Confirm the column in `information_schema.columns`; count population with `SELECT COUNT(*), COUNT(<col>) FROM <table>;`. Use `sqlcmd` or the repo's client."),
}

def slot(t, k, v):
    return t.replace("{{%s}}" % k, v)

written = []  # only the files THIS run produced — never touch user-authored agents.
def write(fn, content):
    with open(os.path.join(out_dir, fn), "w") as f:
        f.write(content)
    written.append(fn)

def reap(fn):
    # Remove a render-OWNED file that no longer applies (re-run/UPDATE path); a
    # user-authored agent is never named here, so it is never removed.
    try:
        os.remove(os.path.join(out_dir, fn))
    except FileNotFoundError:
        pass

generated = []

# --- <stack>-architect.md (always, when a language was detected) ---
if langs:
    t = open(os.path.join(tpl_dir, "stack-architect.md")).read()
    # Frameworks: omit the parenthetical + the bullet entirely when empty (D2).
    if frameworks:
        t = t.replace("({{FRAMEWORKS}})", "(%s)" % frameworks)
        t = t.replace("Frameworks: {{FRAMEWORKS}}", "Frameworks: %s" % frameworks)
    else:
        t = t.replace("\n  ({{FRAMEWORKS}}).", ".")          # description folded scalar
        t = re.sub(r"\n- Frameworks: \{\{FRAMEWORKS\}\}", "", t)
    # Test runner / command / mandate — no-runner fallback (D2).
    if tr or tc:
        t = slot(t, "TEST_RUNNER", tr)
        t = t.replace("`{{TEST_COMMAND}}`", ("`%s`" % tc) if tc else "the configured test command")
        t = slot(t, "TEST_MANDATE", test_mandate)
    else:
        t = re.sub(r"- Test runner: \{\{TEST_RUNNER\}\} — `\{\{TEST_COMMAND\}\}`",
                   "- Test runner: none configured — verify behavior end-to-end against the real app", t)
        # Replace the inline `{{TEST_COMMAND}}` span (the IMPLEMENT line wraps, so a
        # full-sentence match would miss it and leak the slot).
        t = t.replace("Run `{{TEST_COMMAND}}`", "Verify the change against the real app")
        t = slot(t, "TEST_MANDATE",
                 "No test runner is configured — add one before claiming a behavior change works.")
    # Build line — drop when empty.
    if bc:
        t = t.replace("`{{BUILD_COMMAND}}`", "`%s`" % bc)
    else:
        t = re.sub(r"\n- Build: `\{\{BUILD_COMMAND\}\}`", "", t)
    t = slot(t, "STACK", stack)
    t = slot(t, "PROJECT_NAME", name)
    t = slot(t, "LANGUAGE", language)
    write("%s-architect.md" % stack, t)
    generated.append("%s-architect.md" % stack)
    # Reap a stale architect from a previous run whose slug changed (e.g. typescript →
    # node when the TS dep was dropped). Only render-OWNED slugs — never a user's agent.
    RENDER_SLUGS = ("node", "typescript", "python", "go", "rust", "ruby", "java", "kotlin", "code")
    for s in RENDER_SLUGS:
        if s != stack:
            reap("%s-architect.md" % s)

# --- db-verify.md (only when a data layer is present) ---
if dl:
    store_key = dl[0]
    human, howto = STORES.get(store_key, (store_key, "Verify existence + population + type against the real %s store; name the client to install." % store_key))
    t = open(os.path.join(tpl_dir, "db-verify.md")).read()
    t = slot(t, "PROJECT_NAME", name)
    t = slot(t, "STORE_VERIFY_HOWTO", howto)
    t = slot(t, "STORE", human)
    write("db-verify.md", t)
    generated.append("db-verify.md (%s)" % human)

# --- ui-verify.md (only when a frontend framework is present) ---
if is_frontend:
    fw = next((f for f in fws if f in FRONTEND), fws[0] if fws else "frontend")
    # E2E driver note from the target's declared deps (no execution — static read).
    deps = ""
    pj = os.path.join(target, "package.json")
    if os.path.isfile(pj):
        try:
            d = json.load(open(pj))
            deps = " ".join(list((d.get("dependencies") or {}).keys()) + list((d.get("devDependencies") or {}).keys()))
        except Exception:
            deps = ""
    if "@playwright/test" in deps:
        e2e = "Drive the browser with the repo's Playwright (`npx playwright …`)."
    elif "cypress" in deps:
        e2e = "Drive with the repo's Cypress (`npx cypress run`)."
    else:
        e2e = ("If the Playwright MCP is connected, use its `browser_*` tools; otherwise open the dev server "
               "(`%s`) and capture a real-browser screenshot of the flow. The kit bundles no browser driver." % (dev or "the dev command"))
    t = open(os.path.join(tpl_dir, "ui-verify.md")).read()
    t = slot(t, "PROJECT_NAME", name)
    t = slot(t, "FRAMEWORK", fw)
    t = slot(t, "DEV_COMMAND", dev or "the dev command")
    t = slot(t, "E2E_NOTE", e2e)
    write("ui-verify.md", t)
    generated.append("ui-verify.md (%s)" % fw)

# Reap render-OWNED conditional critics that no longer apply (the re-run / UPDATE path):
# a dropped data layer / frontend must not leave an orphan agent the spine no longer routes to.
if not dl:
    reap("db-verify.md")
if not is_frontend:
    reap("ui-verify.md")

# Fail loudly if any slot leaked — scan ONLY the files this run wrote, so a user's own
# agent in .claude/agents/ carrying a {{TOKEN}}-shaped string can't trip a false abort.
leaks = []
for fn in written:
    body = open(os.path.join(out_dir, fn)).read()
    if re.search(r"\{\{[A-Z0-9_]+\}\}", body):
        leaks.append(fn)
if leaks:
    sys.stderr.write("render: ERROR — unfilled slot(s) in: %s\n" % ", ".join(leaks))
    sys.exit(2)

print("render: wrote %s to %s" % (", ".join(generated) or "(nothing)", out_dir))
PY
