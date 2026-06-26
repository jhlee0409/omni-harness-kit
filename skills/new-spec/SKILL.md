---
name: new-spec
description: >-
  Scaffold a spec triplet (spec.md / plan.md / context.md) under
  specs/YYYYMMDD-<name>/ before starting a non-trivial piece of work. Use when a
  task spans multiple modules / several commits / a new ADR, or when the user
  says "new spec", "스펙 만들어", "plan this out", "spec this", "기획부터".
argument-hint: "<name>"
allowed-tools: Bash, Read, Edit
---

# new-spec

Structure non-trivial work before coding — the spec is what keeps the work
grounded on the original ask (this is where reliability comes from, not from a
measurement system).

1. **Decide if a spec is warranted.** Yes if the task touches ≥2 modules / areas,
   needs ≥3 commits, introduces a new ADR, or is forward-only. **Skip it** for
   small work (single file, doc-only, a follow-up) — spec ceremony on tiny tasks
   is net-negative.
2. **Scaffold:** run
   `bash "${CLAUDE_PLUGIN_ROOT}/skills/new-spec/new-spec.sh" "<name>"` from the
   repo root. It creates `specs/<date>-<slug>/{spec,plan,context}.md` and prints
   the directory.
3. **Fill, in order:** `spec.md` (the original ask verbatim + acceptance),
   `plan.md` (dependency-ordered tasks), then load the tasks and surface **N/M**
   as you work. A "done" tone before all plan tasks are consumed is not allowed.
4. **`context.md` `## 0. Resume here`** — write it with `/harness-kit:handoff` at
   a stopping point; a fresh session resumes from it with `/harness-kit:pickup`.
