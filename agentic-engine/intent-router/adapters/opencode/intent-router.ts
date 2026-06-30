/**
 * Intent router — OpenCode adapter.
 *
 * Uses `experimental.chat.system.transform` to inject a skill suggestion
 * when the user's message strongly matches a skill above threshold.
 *
 * Known limitation: system.transform fires per-LLM-call, not per-user-message,
 * and does not expose the latest user message. For now, this adapter is
 * stubbed — proper implementation requires a chat.prompt.before hook.
 *
 * Fail-open: any error → no injection.
 */

import type { Shell } from "../../../../adapters/opencode/src/types.ts";

export function createIntentRouterHook(
  _projectDir: string,
  _$: Shell,
  _readFile: (path: string) => Promise<string | null>,
) {
  return {
    "experimental.chat.system.transform": async (
      _input: { sessionID?: string; model: unknown },
      _output: { system: string[] },
    ) => {
      if (process.env.HARNESS_INTENT_OFF === "1") return;
      // TODO: requires chat.prompt.before hook to access user message.
      // system.transform doesn't have the user's latest message available.
    },
  };
}
