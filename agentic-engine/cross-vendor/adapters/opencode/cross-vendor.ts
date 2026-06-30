/**
 * OpenCode adapter — triggers cross-vendor verification after task tool completes.
 *
 * Add to the OpenCode plugin's hooks object:
 *
 *   import { createCrossVendorHook } from "./cross-vendor/opencode.ts";
 *   ...
 *   return { ...createCrossVendorHook(engineDir), ...otherHooks };
 *
 * Uses `tool.execute.after` on the task tool to detect when a significant
 * sub-agent result is produced, then runs outside-voices.sh detached.
 * Fail-open: any error is swallowed silently.
 */

import type { Shell } from "../../../adapters/opencode/src/types.ts";

export function createCrossVendorHook(engineDir: string, $: Shell) {
  const script = `${engineDir}/outside-voices.sh`;

  return {
    "tool.execute.after": async (
      input: { tool: string; sessionID: string; callID: string },
      _output: { result?: unknown },
    ) => {
      if (input.tool !== "task") return;

      const envOff = process.env.OUTSIDE_VOICES_OFF;
      if (envOff === "1") return;

      try {
        const result = String(_output.result ?? "").slice(0, 8000);
        if (!result) return;

        await $`nohup bash ${script} ${result} > /dev/null 2>&1 &`.quiet();
      } catch {
        // fail-open
      }
    },
  };
}
