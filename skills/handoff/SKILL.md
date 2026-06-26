---
name: handoff
description: >-
  Write the live working-set state into a resume block so a FRESH session can
  continue this work without re-narration. Use when stopping mid-task, or when the
  user says "handoff", "핸드오프", "체크포인트", "이어서 할 수 있게", "checkpoint".
  Pairs with `/harness-kit:pickup` (handoff writes, pickup reads).
argument-hint: "[note]"
allowed-tools: Read, Edit, Write, Bash, Grep, Glob
---

# handoff

Capture EVERYTHING a fresh session needs to resume — it has none of your current
context, so be concrete (paths, commands, the original ask verbatim), not vague.

1. **Locate the target.** If there is an active spec (a `specs/<date>-*/context.md`
   matching this work), write into its `## 0. Resume here` block. Otherwise write
   `.claude/handoff.md`.
2. **Fill the resume block** (replace it idempotently — don't stack copies):
   - **Original ask (verbatim):** the user's actual request, not your paraphrase.
   - **Phase / N of M:** where in the plan you are.
   - **Files touched:** the real paths changed so far (`git status --short`).
   - **Next command:** the exact next action (a command, or "edit X to do Y").
   - **In-flight decisions:** anything decided but not yet obvious from the code.
   - **Don't redo:** work already done that a fresh session might wrongly repeat.
3. Use the marked-block updater so a re-handoff replaces the block:
   `printf '%s' "$BLOCK" | bash "${CLAUDE_PLUGIN_ROOT}/skills/introspect/update-block.sh" <file> '<!-- resume:start' '<!-- resume:end -->'`
4. Print the exact `/harness-kit:pickup` command to run in the fresh session.

A handoff is only as good as a fresh session's ability to resume from it ALONE —
write for a reader who saw none of this.
