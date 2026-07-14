#!/usr/bin/env python3
# ruff: noqa: E701,E702,E401,E741,E703,E402  (compact audit script — style noise silenced; logic verified)
"""omp harness health check — deterministic audit device.

Finds harness holes in one pass: agent parse/tools/dupes/collisions,
autoloadSkills resolution WITH source classification (omp-native vs vendor-plugin),
skills, TTSR rules, config validity, model-role resolvability, JSON configs,
per-repo context-file discoverability.

Usage: python3 harness-check.py [repo_path ...]
  repo_path  one or more repo roots to audit for per-project config + context
             files. Defaults to the current working directory when omitted.
Exit 0 = no RED issues; exit 1 = RED issues found.
"""
import os, re, glob, json, subprocess, sys
H = os.path.expanduser
RED, YEL, GRN = [], [], []
# Repos to audit for per-project config + context files (default = cwd).
REPOS = [ (r[:-5] if r.rstrip("/").endswith("/.omp") else r).rstrip("/") for r in (sys.argv[1:] or [os.getcwd()]) ]

def sh(cmd):
    try: return subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=30).stdout
    except Exception: return ""

def fm(path):
    try: t = open(path, encoding="utf-8").read()
    except Exception: return None, ""
    m = re.match(r"^---\n(.*?)\n---\n?(.*)$", t, re.S)
    if not m: return None, t
    d = {}
    for ln in m.group(1).splitlines():
        mm = re.match(r"^([\w-]+):\s*(.*)$", ln)
        if mm: d[mm.group(1)] = mm.group(2).strip()
    return d, m.group(2)

# ---------- 1. skill inventory (ALL sources) with source class ----------
SKILL_ROOTS = [
    ("omp-native", H("~/.agents/skills/*/SKILL.md")),
    ("omp-native", H("~/.agent/skills/*/SKILL.md")),
    ("omp-native", H("~/.omp/agent/skills/*/SKILL.md")),
    ("omp-managed", H("~/.omp/agent/managed-skills/*/SKILL.md")),
    ("claude-user", H("~/.claude/skills/*/SKILL.md")),
]
skills = {}   # name -> source class
for src, pat in SKILL_ROOTS:
    for f in glob.glob(pat):
        skills.setdefault(os.path.basename(os.path.dirname(f)), src)
# omp-installed plugins (the omp plugin system, independent of ~/.claude) — scanned first so they win dedup
for f in glob.glob(H("~/.omp/plugins/**/skills/*/SKILL.md"), recursive=True):
    if "/node_modules/" in f: continue
    skills.setdefault(os.path.basename(os.path.dirname(f)), "omp-plugin")
# every plugin skill root (this is what a shallow audit misses)
for f in glob.glob(H("~/.claude/plugins/**/skills/*/SKILL.md"), recursive=True):
    if "/node_modules/" in f: continue
    plug = re.search(r"/plugins/(?:cache|marketplaces)/([^/]+)/", f)
    skills.setdefault(os.path.basename(os.path.dirname(f)), f"plugin:{plug.group(1) if plug else '?'}")

# ---------- 2. agents ----------
VALID_TOOLS = {"read","write","edit","bash","grep","glob","lsp","web_search","browser","task","todo","ast_grep","ast_edit","eval","debug","launch","ask","irc","job","resolve","generate_image","search_tool_bm25","yield"}
BUNDLED = {"scout","designer","reviewer","librarian","task","sonic"}

def audit_agents(scope, pat, repo_skill_names):
    names = []
    for f in sorted(glob.glob(pat)):
        d, body = fm(f); base = os.path.basename(f)
        if d is None: RED.append(f"agent [{scope}] {base}: no valid frontmatter"); continue
        nm = d.get("name") or base[:-3]
        if not d.get("name"): RED.append(f"agent [{scope}] {base}: missing name")
        if not d.get("description"): RED.append(f"agent [{scope}] {nm}: missing description")
        if len(body.strip()) < 40: RED.append(f"agent [{scope}] {nm}: body too short")
        toks = [x for x in re.split(r"[,\s]+", d.get("tools","")) if x]
        bad = [x for x in toks if x not in VALID_TOOLS]
        if bad: RED.append(f"agent [{scope}] {nm}: invalid tools {bad}")
        al = re.findall(r"[\w-]+", d.get("autoloadSkills","")) if d.get("autoloadSkills","") not in ("","[]") else []
        for s in al:
            src = skills.get(s) or (repo_skill_names.get(s) if repo_skill_names else None)
            if not src: RED.append(f"agent [{scope}] {nm}: autoloadSkills '{s}' NOT FOUND")
            elif src.startswith("plugin:"): YEL.append(f"agent [{scope}] {nm}: autoloadSkills '{s}' depends on {src} (not omp-native)")
        for sk, sksrc in list(skills.items()) + list((repo_skill_names or {}).items()):
            # a body reference to a vendor-plugin skill is a portability risk; the kit's own skills are fine
            if str(sksrc).startswith("plugin:") and "harness-kit" not in str(sksrc) and re.search(r"[`\"']" + re.escape(sk) + r"[`\"']", body):
                YEL.append(f"agent [{scope}] {nm}: body references vendor-plugin skill '{sk}' ({sksrc}) — repoint to an omp-native skill")
        names.append(nm)
    dupes = {n for n in names if names.count(n) > 1}
    if dupes: RED.append(f"agent [{scope}]: duplicate names {dupes}")
    return names

gl = audit_agents("global", H("~/.omp/agent/agents/*.md"), None)
if set(gl) & BUNDLED: RED.append(f"global agents collide with bundled: {set(gl)&BUNDLED}")
GRN.append(f"agents: global={len(gl)}")

# ---------- 3. rules (TTSR) ----------
for f in glob.glob(H("~/.omp/agent/rules/*.md")) + glob.glob(H("~/.agents/rules/*.md")):
    d, b = fm(f); base = os.path.basename(f)
    if d is None: RED.append(f"rule {base}: no frontmatter")
    elif "condition" not in d and "astCondition" not in d and d.get("alwaysApply","")!="true":
        YEL.append(f"rule {base}: no condition/astCondition/alwaysApply — may not register as TTSR")
GRN.append(f"rules: {len(glob.glob(H('~/.omp/agent/rules/*.md')))}")

# ---------- 4. config + model resolvability ----------
cfg = H("~/.omp/agent/config.yml")
if os.path.exists(cfg):
    try: import yaml
    except Exception: YEL.append("config.yml: PyYAML not installed — YAML validation skipped")
    else:
        try: yaml.safe_load(open(cfg)); GRN.append("config.yml: valid YAML")
        except Exception as e: RED.append(f"config.yml invalid: {e}")
models_out = sh("omp models")
avail = set(re.findall(r"^\s*│?\s*([a-z0-9][a-z0-9.\-]+)\s*│", models_out, re.M))
prov = set(re.findall(r"^([a-z0-9\-]+) \(\d+\)", models_out, re.M))
def check_models(jsonstr, label):
    try: obj = json.loads(jsonstr)
    except Exception: return
    ids = []
    for v in obj.values(): ids += (v if isinstance(v, list) else [v])
    for mid in ids:
        base = mid.split(":")[0]; short = base.split("/")[-1]
        if short not in avail and base not in avail and not any(base.startswith(p+"/") and p in prov for p in prov):
            YEL.append(f"{label}: model '{mid}' not found in `omp models` (check auth/id)")
if avail:
    check_models(sh("omp config get modelRoles"), "modelRoles")
    check_models(sh("omp config get retry.fallbackChains"), "fallbackChains")
    GRN.append(f"models available: {len(avail)}")

# ---------- 5. JSON configs ----------
for f in [H("~/.omp/agent/mcp.json")] + [os.path.join(r, ".omp", "lsp.json") for r in REPOS] + [os.path.join(r, ".omp", "mcp.json") for r in REPOS]:
    if os.path.exists(f):
        try: json.load(open(f)); 
        except Exception as e: RED.append(f"{f}: invalid JSON: {e}")

# ---------- 6. .env keys (names only) ----------
env = H("~/.omp/agent/.env")
if os.path.exists(env):
    keys = [l.split("=")[0] for l in open(env) if "=" in l and not l.startswith("#")]
    GRN.append(f".env keys: {', '.join(keys)}")

# ---------- 7. per-repo: context-file discoverability + repo agents ----------
for root in REPOS:
    name = os.path.basename(root) or root
    # repo skills (for repo-agent autoloadSkills)
    rsk = {os.path.basename(os.path.dirname(f)): "repo" for f in glob.glob(root+"/.agents/skills/*/SKILL.md")}
    ra = audit_agents(name, root+"/.omp/agents/*.md", rsk)
    if ra: GRN.append(f"agents: {name}={len(ra)}")
    # bare CLAUDE.md omp would miss
    for d in [root] + [os.path.dirname(p) for p in glob.glob(root+"/*/") ]:
        cl, ag = os.path.join(d,"CLAUDE.md"), os.path.join(d,"AGENTS.md")
        if os.path.isfile(cl) and not os.path.exists(ag) and not os.path.isfile(os.path.join(d,".claude/CLAUDE.md")):
            YEL.append(f"context [{name}]: bare CLAUDE.md at {d} — omp won't load it (add AGENTS.md symlink or .omp/AGENTS.md @import)")

# ---------- 8. MCP: server command resolvability across discovered sources ----------
import shutil
_disabled = set(); _mcp_src = {}
_omp_mcp = H("~/.omp/agent/mcp.json")
if os.path.exists(_omp_mcp):
    try:
        _j = json.load(open(_omp_mcp)); _disabled = set(_j.get("disabledServers", [])); _mcp_src["omp"] = _j.get("mcpServers", {})
    except Exception: pass
try:
    import tomllib
    _cx = H("~/.codex/config.toml")
    if os.path.exists(_cx):
        with open(_cx, "rb") as _fh: _mcp_src["codex"] = (tomllib.load(_fh).get("mcp_servers", {}) or {})
except Exception: pass
for _lbl, _p in [("claude", "~/.claude.json"), ("cursor", "~/.cursor/mcp.json"), ("windsurf", "~/.codeium/windsurf/mcp_config.json")]:
    _fp = H(_p)
    if os.path.exists(_fp):
        try: _mcp_src[_lbl] = (json.load(open(_fp)).get("mcpServers", {}) or {})
        except Exception: pass
_mcp_ok = 0
for _lbl, _servers in _mcp_src.items():
    for _name, _cfg in (_servers or {}).items():
        if _name in _disabled or not isinstance(_cfg, dict): continue
        if _cfg.get("url") or _cfg.get("type") in ("http", "sse"): _mcp_ok += 1; continue
        _cmd = _cfg.get("command")
        if not _cmd: continue
        if _cmd.startswith("/"): _ok = os.path.exists(_cmd)
        elif "/" in _cmd: _ok = False
        else: _ok = shutil.which(_cmd) is not None
        if _ok: _mcp_ok += 1
        else: YEL.append(f"mcp [{_lbl}] {_name}: command '{_cmd[:48]}' not resolvable (relative/missing) — will ENOENT; add to disabledServers or fix path")
GRN.append(f"mcp: {_mcp_ok} resolvable, disabled: {sorted(_disabled) or 'none'}")

# ---------- report ----------
print("="*60); print("omp HARNESS HEALTH CHECK"); print("="*60)
for g in GRN: print(f"  GREEN  {g}")
for w in YEL: print(f"  YELLOW {w}")
for r in RED: print(f"  RED    {r}")
print("-"*60)
print(f"verdict: {'RED — fix required' if RED else ('YELLOW — review' if YEL else 'GREEN — all clear')}  ({len(RED)} red, {len(YEL)} yellow)")
sys.exit(1 if RED else 0)
