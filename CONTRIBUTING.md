# Contributing to Harness Kit

Thanks for your interest! This is a small, opinionated kit — contributions that
keep it small and sharp are the most welcome.

## Develop locally

Load the plugin into a Claude Code session without publishing:

```bash
claude --plugin-dir /path/to/claude-harness-kit
# then, in a target repo:
/harness-kit:introspect
```

## Run the checks before a PR

```bash
bash tests/detect_test.sh            # detection-engine unit tests (must be green)
bash -n skills/introspect/detect.sh  # shell syntax
claude plugin validate . --strict    # manifest + frontmatter + hooks schema
```

CI runs the same three. A PR is mergeable only when all are green.

## Conventions

- **Keep it minimal.** A new agent/skill/hook must earn its place — prefer
  improving an existing one over adding machinery. We deliberately do NOT compete
  on breadth; the value is the introspect/auto-tailoring layer.
- **Detection logic is tested.** Any change to `detect.sh` adds or updates a case
  in `tests/detect_test.sh`. Read configs statically — never execute a target's
  config files.
- **Conventional commits** (`feat:`, `fix:`, `docs:`, `chore:`) for the changelog.
- Match the surrounding style; no unrelated reformatting in a feature PR.

## Reporting issues

Use the issue templates. For security, see [SECURITY.md](./SECURITY.md) — do not
open a public issue for a vulnerability.
