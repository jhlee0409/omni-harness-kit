---
name: pickup
description: >-
  Re-enter in-flight work in a fresh session by reading a resume block a previous
  session left (the read half of the handoff/pickup loop). Use at the start of a
  fresh session, or when the user says "pickup", "resume", "이어서", "재개",
  "어디까지 했지", "continue where we left off".
argument-hint: "[spec-slug]"
allowed-tools: Read, Bash, Grep, Glob
---

# pickup

Re-establish where the work left off — from the resume block ALONE, without asking
the user to re-narrate.

1. **Find the resume block.** Look for `.claude/handoff.md`, then any
   `specs/*/context.md` with a `## 0. Resume here` block (use the `[spec-slug]`
   arg to disambiguate when several exist). If none is found, say so plainly —
   don't guess.
2. **Read it fully**, then re-ground in the repo: `git status --short`,
   `git log --oneline -5`, and read the files it lists. Confirm the stated state
   matches reality (files actually changed, the next command still makes sense).
3. **Restate** the original ask + where you are (phase / N of M) + the single next
   action — then DO that next action. Do NOT redo the "Don't redo" items.
4. If the block contradicts the repo (says a file was changed but it wasn't),
   surface the conflict instead of trusting the block blindly.
