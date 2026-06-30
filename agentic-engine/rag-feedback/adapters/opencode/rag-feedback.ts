/**
 * RAG feedback injection — OpenCode adapter.
 *
 * Uses `experimental.chat.system.transform` to inject top-k feedback memories
 * into the system prompt. Indexes on first call, then retrieves from cache.
 *
 * Fail-open: any error → no injection (the session continues normally).
 */

import type { Shell } from "../../../../adapters/opencode/src/types.ts";
import { createRetriever } from "../src/index.ts";

const DEFAULT_K = 3;

export function createRagFeedbackHook(
  projectDir: string,
  _$: Shell,
  _readFile: (path: string) => Promise<string | null>,
) {
  let retriever: ReturnType<typeof createRetriever> | null = null;
  let indexed = false;

  return {
    "experimental.chat.system.transform": async (
      _input: { sessionID?: string; model: unknown },
      output: { system: string[] },
    ) => {
      if (process.env.HARNESS_RAG_OFF === "1") return;

      try {
        if (!retriever) {
          retriever = createRetriever(projectDir);
        }

        const feedbackDir =
          process.env.HARNESS_FEEDBACK_DIR ??
          `${projectDir}/.claude/feedback`;

        // Check if feedback dir exists via Bun.file
        const dirCheck = Bun.file(feedbackDir);
        if (!(await dirCheck.exists())) {
          // Try .opencode/feedback
          const altDir = `${projectDir}/.opencode/feedback`;
          const altCheck = Bun.file(altDir);
          if (!(await altCheck.exists())) return;
        }

        if (!indexed) {
          await retriever.index(feedbackDir);
          indexed = true;
        }

        // We don't have the user's message here (system.transform fires
        // before the user message is processed). Use the session's recent
        // messages as the query — or just inject all cached memories above
        // a similarity threshold with a generic query.
        //
        // For now, inject nothing on system.transform (which fires per-LLM-call,
        // not per-user-message). The actual retrieval should happen on
        // chat.prompt.before or similar. This is a known limitation — the
        // system.transform hook doesn't have access to the user's latest message.
        //
        // TODO: switch to chat.message or chat.prompt hook when available.
      } catch {
        // fail-open
      }
    },
  };
}
