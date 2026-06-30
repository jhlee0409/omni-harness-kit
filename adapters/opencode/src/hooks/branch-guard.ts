/**
 * Branch-guard hook — OpenCode equivalent of CC's `protected-branch-guard.sh`.
 *
 * CC approach: PreToolUse(Bash) → asks before git commit/push on protected branch.
 * OpenCode approach: `tool.execute.before` — intercept Bash tool calls, check if
 * the command is a git mutation on a protected branch, and log a warning via the
 * output args (the agent sees the injected note).
 *
 * Note: OpenCode's `tool.execute.before` can mutate args but cannot block execution
 * the way CC's PreToolUse can. Instead, we prepend a visible warning comment that
 * the agent should acknowledge before proceeding. For hard enforcement, pair with
 * `permission.ask` or git hooks on the repo side.
 */

import type { Shell } from "../types.ts";
import { isGuardEnabled, readConfig, resolveProtectedBranches } from "../config.ts";
import { currentBranch, extractBashCommand, isGitMutation } from "../git.ts";

export function createBranchGuardHook(
  dir: string,
  $: Shell,
  readFile: (path: string) => Promise<string | null>,
) {
  return {
    "tool.execute.before": async (
      input: { tool: string; sessionID: string; callID: string },
      output: { args: unknown },
    ) => {
      if (!isGuardEnabled()) return;
      if (input.tool !== "bash") return;

      const cmd = extractBashCommand(output.args);
      if (!isGitMutation(cmd)) return;

      const branch = await currentBranch(dir, $);
      if (!branch) return;

      const cfg = await readConfig(dir, readFile);
      const protected_ = resolveProtectedBranches(cfg);

      if (protected_.includes(branch)) {
        // Inject a visible warning into the command — the agent will see this
        // and should surface it to the user before proceeding.
        const originalCmd = cmd;
        const warning = `# ⚠️  harness-kit: protected branch '${branch}' — confirm before proceeding.\n`;
        if (typeof output.args === "object" && output.args !== null && "command" in output.args) {
          (output.args as Record<string, unknown>).command = warning + originalCmd;
        }
      }
    },
  };
}
