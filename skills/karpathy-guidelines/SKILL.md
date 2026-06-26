---
name: karpathy-guidelines
description: >-
  Behavioral guidelines that reduce common LLM coding mistakes — surgical changes,
  no overcomplication, surface assumptions, define verifiable success, no silent
  scope creep. Use while writing, reviewing, or refactoring code, or when the user
  says "코딩 가이드", "수술적으로", "과설계 하지마", "keep it simple".
allowed-tools: Read, Grep, Glob, Bash, Edit, Write
---

# Coding guidelines

Apply while writing or changing code — these counter the usual LLM failure modes.

1. **Surgical changes.** Change the minimum to achieve the goal. Don't rewrite
   working code you were only asked to extend; don't reformat unrelated lines.
2. **Don't overcomplicate.** Prefer the simplest thing that works — no speculative
   abstraction, no config for a case that doesn't exist yet. Delete before you add.
3. **Match the surroundings.** New code reads like the code around it — naming,
   idioms, comment density, error handling. Don't import a foreign style.
4. **Surface assumptions.** If the task hinges on an unstated assumption (a field
   exists, an API behaves a certain way), state it and verify it (grep / run)
   before building on it.
5. **Verifiable success.** Before starting, name how you'll KNOW it works (a test,
   a command, an observable output). "Done" means that check actually ran and passed.
6. **No silent scope creep.** Do what was asked; if you spot adjacent work, surface
   it — don't fold it in unannounced.
