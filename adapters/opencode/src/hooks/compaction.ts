/**
 * Compaction-context hook — OpenCode equivalent of CC's PreCompact hook.
 *
 * Uses `experimental.session.compacting` to inject context that should survive
 * compaction: the active task, key decisions, and the harness-kit config.
 */

import type { Shell } from "../types.ts";
import { readConfig } from "../config.ts";
import { isDirty } from "../git.ts";

export function createCompactionHook(
  dir: string,
  $: Shell,
  readFile: (path: string) => Promise<string | null>,
) {
  return {
    "experimental.session.compacting": async (
      _input: { sessionID: string },
      output: { context: string[]; prompt?: string },
    ) => {
      const parts: string[] = [];

      // Preserve verify command
      const cfg = await readConfig(dir, readFile);
      if (cfg.verify_command) {
        parts.push(`[harness-kit] Verify command for this repo: \`${cfg.verify_command}\``);
      }

      // Preserve git state
      if (await isDirty(dir, $)) {
        parts.push("[harness-kit] There are uncommitted changes — verify before claiming done.");
      }

      // Preserve protected branch info
      const branches = cfg.protected_branches;
      if (branches?.length) {
        parts.push(`[harness-kit] Protected branches: ${branches.join(", ")}`);
      }

      if (parts.length > 0) {
        output.context.push(parts.join("\n"));
      }
    },
  };
}
