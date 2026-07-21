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

/**
 * Returns true only when git's SUBCOMMAND is commit or push — mirroring the CC guard
 * (hooks/scripts/protected-branch-guard.sh). A bare substring match fired on look-alikes
 * ("legit commit", "git pushed") and on commit/push appearing as an argument value
 * ("git log --grep push"); tracking the subcommand position avoids both.
 */
const GIT_VALUE_FLAGS: Record<string, true> = {
  "-C": true, "-c": true, "--git-dir": true, "--work-tree": true,
  "--exec-path": true, "--namespace": true, "--super-prefix": true, "--config-env": true,
};
export function isGitMutation(cmd: string): boolean {
  const toks = cmd.split(/\s+/).filter(Boolean);
  for (let i = 0; i < toks.length; i++) {
    const t = toks[i];
    if (t === undefined || (t !== "git" && !t.endsWith("/git"))) continue;
    let j = i + 1;
    while (j < toks.length) {
      const a = toks[j];
      if (a === undefined) break;
      if (GIT_VALUE_FLAGS[a]) { j += 2; continue; }
      if (a.startsWith("-")) { j += 1; continue; }
      break;
    }
    const sub = toks[j];
    if (sub === "commit" || sub === "push") return true;
  }
  return false;
}
