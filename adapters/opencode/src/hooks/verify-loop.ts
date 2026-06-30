/**
 * Verify-loop hook — OpenCode equivalent of CC's `verify-loop.sh` (Stop hook).
 *
 * CC approach: fires at Stop event, injects additionalContext with the verify command.
 * OpenCode approach: `experimental.chat.system.transform` — appends the verify
 * reminder to the system prompt on every LLM call when code is dirty. This is
 * actually MORE effective than CC's approach because the reminder stays
 * top-of-mind throughout, not just at the end.
 */

import type { Shell } from "../types.ts";
import { type HarnessKitConfig, isVerifyEnabled, readConfig } from "../config.ts";
import { isDirty } from "../git.ts";

export function createVerifyLoopHook(
  dir: string,
  $: Shell,
  readFile: (path: string) => Promise<string | null>,
) {
  // Cache config + dirty state to avoid re-reading on every LLM call
  let cachedCfg: HarnessKitConfig | null = null;
  let lastDirtyCheck = 0;
  let cachedDirty = false;
  const DIRTY_CACHE_MS = 5000; // re-check git status at most every 5s

  return {
    "experimental.chat.system.transform": async (
      _input: { sessionID?: string; model: unknown },
      output: { system: string[] },
    ) => {
      if (!isVerifyEnabled()) return;

      // Lazy-load config (once)
      if (cachedCfg === null) {
        cachedCfg = await readConfig(dir, readFile);
      }
      if (!cachedCfg.verify_command) return;

      // Throttled dirty check
      const now = Date.now();
      if (now - lastDirtyCheck > DIRTY_CACHE_MS) {
        cachedDirty = await isDirty(dir, $);
        lastDirtyCheck = now;
      }
      if (!cachedDirty) return;

      // Inject the reminder — non-blocking nudge
      const cmd = cachedCfg.verify_command;
      const tone = cachedCfg.blocking
        ? "BLOCKING: verify must pass before claiming done."
        : "Remind the user to verify before claiming done.";
      output.system.push(
        `[harness-kit] Uncommitted changes detected. ${tone} Verify command: \`${cmd}\``,
      );
    },
  };
}
