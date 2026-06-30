/**
 * Verify-evidence capture — OpenCode adapter.
 *
 * `tool.execute.after` on task tool — when a sub-agent finishes, its output
 * is parsed for verification claims and persisted as evidence.
 *
 * Fail-open: any error → no capture.
 */

import type { Shell } from "../../../../adapters/opencode/src/types.ts";
import { createEvidenceCapture } from "../src/index.ts";
import { isEvidenceAgent } from "../src/parser.ts";

export function createVerifyEvidenceHook(
  projectDir: string,
  _$: Shell,
  _readFile: (path: string) => Promise<string | null>,
) {
  const capture = createEvidenceCapture(projectDir);

  return {
    "tool.execute.after": async (
      input: { tool: string; sessionID: string; callID: string },
      output: { output?: string; result?: string; args?: unknown },
    ) => {
      if (process.env.HARNESS_EVIDENCE_OFF === "1") return;
      if (input.tool !== "task") return;

      // Extract agent name from task args and output text
      const args = output.args as Record<string, unknown> | undefined;
      const subagent = (args?.subagent_type as string) ?? "";
      if (!isEvidenceAgent(subagent)) return;

      const outputText = output.output ?? output.result ?? "";
      if (!outputText) return;

      try {
        await capture.capture(subagent, String(outputText));
      } catch {
        // fail-open
      }
    },
  };
}
