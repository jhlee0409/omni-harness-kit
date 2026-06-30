/**
 * Harness Kit — OpenCode Adapter
 *
 * Plugin entry point. Implements the same hooks as the Claude Code adapter
 * (verify-loop, branch-guard, compaction-context) using OpenCode's mutation-
 * based hook system.
 *
 * Registration (opencode.json):
 *   { "plugin": ["./adapters/opencode/src/index.ts"] }
 *   — or for a published package —
 *   { "plugin": ["@harness-kit/opencode"] }
 *
 * Config (.opencode/harness-kit.json or .claude/harness-kit.json):
 *   { "verify_command": "tsc --noEmit && vitest run", "blocking": false,
 *     "protected_branches": ["main", "release"] }
 *
 * Env overrides:
 *   HARNESS_VERIFY_OFF=1   — disable verify-loop
 *   HARNESS_GUARD_OFF=1    — disable branch-guard
 *   HARNESS_PROTECTED_BRANCHES="main release" — override protected branches
 */

import type { Plugin, PluginInput, Hooks } from "@opencode-ai/plugin";
import type { Shell } from "./types.ts";
import { createVerifyLoopHook } from "./hooks/verify-loop.ts";
import { createBranchGuardHook } from "./hooks/branch-guard.ts";
import { createCompactionHook } from "./hooks/compaction.ts";

/**
 * Read a file from the filesystem using Bun's API.
 * Returns null if the file doesn't exist (fail-open).
 */
async function fileReader(path: string): Promise<string | null> {
  try {
    const file = Bun.file(path);
    const exists = await file.exists();
    if (!exists) return null;
    return await file.text();
  } catch {
    return null;
  }
}

const harnessKitPlugin: Plugin = async (
  input: PluginInput,
  _options?: Record<string, unknown>,
): Promise<Hooks> => {
  const dir = input.directory;
  // Cast $ to our minimal Shell interface (the real type is BunShell,
  // which is compatible but not exported from the plugin SDK)
  const $ = input.$ as unknown as Shell;

  // Compose hooks from each module
  const verifyLoop = createVerifyLoopHook(dir, $, fileReader);
  const branchGuard = createBranchGuardHook(dir, $, fileReader);
  const compaction = createCompactionHook(dir, $, fileReader);

  return {
    ...verifyLoop,
    ...branchGuard,
    ...compaction,
  };
};

// Export as PluginModule (id + server)
const pluginModule = {
  id: "harness-kit",
  server: harnessKitPlugin,
};

export default pluginModule;
export { harnessKitPlugin };
