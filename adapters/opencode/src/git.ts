/**
 * Git helpers — thin wrappers around the BunShell `$` for the hooks.
 * All fail-open: any error returns a safe default.
 */

import type { Shell } from "./types.ts";

/** Returns true if the repo has uncommitted changes. */
export async function isDirty(
  dir: string,
  $: Shell,
): Promise<boolean> {
  try {
    const result = await $`git -C ${dir} status --porcelain`.quiet();
    const text = result.text().trim();
    return text.length > 0;
  } catch {
    return false;
  }
}

/** Returns the current git branch name, or null. */
export async function currentBranch(
  dir: string,
  $: Shell,
): Promise<string | null> {
  try {
    const result = await $`git -C ${dir} branch --show-current`.quiet();
    return result.text().trim() || null;
  } catch {
    return null;
  }
}

/** Extracts the command string from a Bash tool call's args. */
export function extractBashCommand(args: unknown): string {
  if (typeof args === "object" && args !== null && "command" in args) {
    return String((args as Record<string, unknown>).command ?? "");
  }
  return "";
}

/** Returns true if the command is a git commit or push. */
export function isGitMutation(cmd: string): boolean {
  return cmd.includes("git commit") || cmd.includes("git push");
}
