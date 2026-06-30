/**
 * harness-kit config reader — loads `.opencode/harness-kit.json` (or
 * `.claude/harness-kit.json` for shared configs) with the same schema as
 * the Claude Code adapter.
 *
 * Schema (all fields optional):
 *   verify_command:     string   — e.g. "tsc --noEmit && vitest run"
 *   blocking:           boolean  — enforce verify (block) vs remind (default false)
 *   protected_branches: string[] — e.g. ["main", "release"]
 */

export interface HarnessKitConfig {
  verify_command?: string;
  blocking?: boolean;
  protected_branches?: string[];
}

const DEFAULT_PROTECTED = ["main", "master", "develop", "release"];

/** Read config from the project directory. Fail-open: bad/missing = defaults. */
export async function readConfig(
  dir: string,
  read: (path: string) => Promise<string | null>,
): Promise<HarnessKitConfig> {
  // Try .opencode/ first, then .claude/ (shared config between runtimes)
  for (const sub of [".opencode", ".claude"]) {
    const raw = await read(`${dir}/${sub}/harness-kit.json`);
    if (raw) {
      try {
        return JSON.parse(raw) as HarnessKitConfig;
      } catch {
        // malformed — fall through to defaults
      }
    }
  }
  return {};
}

/** Env overrides take precedence (same as CC adapter). */
export function resolveProtectedBranches(cfg: HarnessKitConfig): string[] {
  const env = process.env.HARNESS_PROTECTED_BRANCHES;
  if (env) return env.split(/\s+/).filter(Boolean);
  return cfg.protected_branches?.length ? cfg.protected_branches : DEFAULT_PROTECTED;
}

export function isVerifyEnabled(): boolean {
  return process.env.HARNESS_VERIFY_OFF !== "1";
}

export function isGuardEnabled(): boolean {
  return process.env.HARNESS_GUARD_OFF !== "1";
}
