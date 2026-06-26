---
name: worktree
description: >-
  Create an isolated git worktree for a code-change task (../<repo>-<slug> on its
  own branch), keeping the main checkout clean. Use in a repo that opted into the
  worktree-per-task workflow, or when the user says "new worktree", "워크트리 만들어",
  "isolate this task", "task별 worktree".
argument-hint: "<task-slug> [base-branch]"
allowed-tools: Bash, Read
---

# worktree

Each code-change task gets its own worktree, so the main checkout stays clean and
parallel tasks don't collide. (Only relevant if the repo opted into this workflow
at introspect time — `.claude/harness-kit.json` `worktree_workflow: true`.)

1. **Create:** from the repo root, run
   `bash "${CLAUDE_PLUGIN_ROOT}/skills/worktree/new-worktree.sh" "<slug>" [base]`.
   It creates `../<repo>-<slug>` on a new branch `<slug>` (from `base`, default
   `HEAD` — pass your integration branch to branch off it) and prints the path.
2. **Work there:** make the task's edits in that worktree (`cd` into it, or
   `git -C <path> …`). Keep the main checkout read-only for edits.
3. **Finish:** open a PR from the branch, then `git worktree remove <path>`.
