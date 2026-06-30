/**
 * Dogfood test — exercises each OpenCode adapter hook with mock input/output,
 * proving the hook LOGIC works before any runtime integration.
 *
 * Run: cd adapters/opencode && bun test test/dogfood.test.ts
 */

import { describe, expect, it, beforeEach, afterEach } from "bun:test";
import { rm, mkdir, mkdtemp } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { Shell, ShellPromise, ShellOutput } from "../src/types.ts";

// ─── Mock helpers ────────────────────────────────────────────────

/**
 * Create a mock `$` shell that executes real git commands in `dir`.
 * This proves the hooks call git correctly, without needing OpenCode runtime.
 */
function createMockShell(realDir: string): Shell {
  const shell = ((strings: TemplateStringsArray, ...exprs: unknown[]): ShellPromise => {
    // Reconstruct the command string (template literal → plain string)
    let cmd = strings[0];
    for (let i = 0; i < exprs.length; i++) {
      cmd += String(exprs[i]) + (strings[i + 1] ?? "");
    }

    const proc = Bun.spawn(["bash", "-c", cmd], {
      cwd: realDir,
      stdout: "pipe",
      stderr: "pipe",
    });

    const promise = new Promise<ShellOutput>(async (resolve) => {
      const exitCode = await proc.exited;
      const stdout_data = await new Response(proc.stdout).text();
      resolve({
        text: () => stdout_data,
        exitCode,
      });
    });

    (promise as ShellPromise).quiet = () => promise as ShellPromise;
    return promise as ShellPromise;
  }) as Shell;

  return shell;
}

/** Mock file reader backed by a Map. */
function createMockFileReader(files: Map<string, string>) {
  return async (path: string): Promise<string | null> => files.get(path) ?? null;
}

// ─── Test state ──────────────────────────────────────────────────

let tempDir: string;

beforeEach(async () => {
  tempDir = await mkdtemp(join(tmpdir(), "hk-dogfood-"));
  // Init a real git repo with an initial commit (needed for branch operations)
  await Bun.spawn(["bash", "-c", `git init -q && git config user.email test@test && git config user.name test && echo init > .init && git add .init && git commit -q -m init`], {
    cwd: tempDir,
  }).exited;
});

afterEach(async () => {
  await rm(tempDir, { recursive: true, force: true });
});

// ─── Tests ───────────────────────────────────────────────────────

describe("verify-loop hook", () => {
  it("injects reminder when code is dirty and verify_command is set", async () => {
    delete process.env.HARNESS_VERIFY_OFF;

    const { createVerifyLoopHook } = await import("../src/hooks/verify-loop.ts");
    const $ = createMockShell(tempDir);
    const files = new Map([
      [`${tempDir}/.opencode/harness-kit.json`, JSON.stringify({ verify_command: "tsc --noEmit" })],
    ]);
    const readFile = createMockFileReader(files);

    const hook = createVerifyLoopHook(tempDir, $, readFile);
    const systemTransform = hook["experimental.chat.system.transform"]!;

    // Make repo dirty
    await Bun.write(join(tempDir, "test.txt"), "dirty");
    await Bun.spawn(["bash", "-c", "git add -A"], { cwd: tempDir }).exited;

    const output = { system: [] as string[] };
    await systemTransform({ model: "test-model" }, output);

    expect(output.system.length).toBe(1);
    expect(output.system[0]).toContain("harness-kit");
    expect(output.system[0]).toContain("tsc --noEmit");
    expect(output.system[0]).toContain("Uncommitted changes detected");
  });

  it("does NOT inject when repo is clean", async () => {
    delete process.env.HARNESS_VERIFY_OFF;

    const { createVerifyLoopHook } = await import("../src/hooks/verify-loop.ts");
    const $ = createMockShell(tempDir);
    const files = new Map([
      [`${tempDir}/.opencode/harness-kit.json`, JSON.stringify({ verify_command: "tsc --noEmit" })],
    ]);
    const readFile = createMockFileReader(files);

    const hook = createVerifyLoopHook(tempDir, $, readFile);
    const systemTransform = hook["experimental.chat.system.transform"]!;

    // Repo is clean (no changes)
    const output = { system: [] as string[] };
    await systemTransform({ model: "test-model" }, output);

    expect(output.system.length).toBe(0);
  });

  it("does NOT inject when HARNESS_VERIFY_OFF=1", async () => {
    process.env.HARNESS_VERIFY_OFF = "1";

    const { createVerifyLoopHook } = await import("../src/hooks/verify-loop.ts");
    const $ = createMockShell(tempDir);
    const readFile = createMockFileReader(new Map());

    const hook = createVerifyLoopHook(tempDir, $, readFile);
    const systemTransform = hook["experimental.chat.system.transform"]!;

    // Make repo dirty
    await Bun.write(join(tempDir, "test.txt"), "dirty");
    await Bun.spawn(["bash", "-c", "git add -A"], { cwd: tempDir }).exited;

    const output = { system: [] as string[] };
    await systemTransform({ model: "test-model" }, output);

    expect(output.system.length).toBe(0);
    delete process.env.HARNESS_VERIFY_OFF;
  });

  it("injects BLOCKING tone when config.blocking=true", async () => {
    delete process.env.HARNESS_VERIFY_OFF;

    const { createVerifyLoopHook } = await import("../src/hooks/verify-loop.ts");
    const $ = createMockShell(tempDir);
    const files = new Map([
      [`${tempDir}/.opencode/harness-kit.json`, JSON.stringify({ verify_command: "pytest", blocking: true })],
    ]);
    const readFile = createMockFileReader(files);

    const hook = createVerifyLoopHook(tempDir, $, readFile);
    const systemTransform = hook["experimental.chat.system.transform"]!;

    await Bun.write(join(tempDir, "test.txt"), "dirty");
    await Bun.spawn(["bash", "-c", "git add -A"], { cwd: tempDir }).exited;

    const output = { system: [] as string[] };
    await systemTransform({ model: "test-model" }, output);

    expect(output.system.length).toBe(1);
    expect(output.system[0]).toContain("BLOCKING");
  });
});

describe("branch-guard hook", () => {
  it("injects warning when committing on protected branch 'main'", async () => {
    delete process.env.HARNESS_GUARD_OFF;

    const { createBranchGuardHook } = await import("../src/hooks/branch-guard.ts");
    const $ = createMockShell(tempDir);
    const readFile = createMockFileReader(new Map());

    const hook = createBranchGuardHook(tempDir, $, readFile);
    const toolBefore = hook["tool.execute.before"]!;

    // Ensure we're on main (git init defaults to master, rename to main)
    await Bun.spawn(["bash", "-c", "git branch -m main"], { cwd: tempDir }).exited;

    const output = { args: { command: "git commit -m test" } };
    await toolBefore(
      { tool: "bash", sessionID: "s1", callID: "c1" },
      output,
    );

    const cmd = (output.args as Record<string, unknown>).command as string;
    expect(cmd).toContain("⚠️");
    expect(cmd).toContain("protected branch 'main'");
    expect(cmd).toContain("git commit -m test"); // original command preserved
  });

  it("does NOT inject when not a git mutation command", async () => {
    delete process.env.HARNESS_GUARD_OFF;

    const { createBranchGuardHook } = await import("../src/hooks/branch-guard.ts");
    const $ = createMockShell(tempDir);
    const readFile = createMockFileReader(new Map());

    const hook = createBranchGuardHook(tempDir, $, readFile);
    const toolBefore = hook["tool.execute.before"]!;

    await Bun.spawn(["bash", "-c", "git branch -m main"], { cwd: tempDir }).exited;

    const output = { args: { command: "ls -la" } };
    await toolBefore(
      { tool: "bash", sessionID: "s1", callID: "c1" },
      output,
    );

    expect((output.args as Record<string, unknown>).command).toBe("ls -la"); // unchanged
  });

  it("does NOT inject when on a non-protected branch", async () => {
    delete process.env.HARNESS_GUARD_OFF;

    const { createBranchGuardHook } = await import("../src/hooks/branch-guard.ts");
    const $ = createMockShell(tempDir);
    const readFile = createMockFileReader(new Map());

    const hook = createBranchGuardHook(tempDir, $, readFile);
    const toolBefore = hook["tool.execute.before"]!;

    // Create and checkout a feature branch
    await Bun.spawn(["bash", "-c", "git checkout -b feat/test"], { cwd: tempDir }).exited;

    const output = { args: { command: "git commit -m test" } };
    await toolBefore(
      { tool: "bash", sessionID: "s1", callID: "c1" },
      output,
    );

    expect((output.args as Record<string, unknown>).command).toBe("git commit -m test"); // unchanged
  });

  it("does NOT inject when HARNESS_GUARD_OFF=1", async () => {
    process.env.HARNESS_GUARD_OFF = "1";

    const { createBranchGuardHook } = await import("../src/hooks/branch-guard.ts");
    const $ = createMockShell(tempDir);
    const readFile = createMockFileReader(new Map());

    const hook = createBranchGuardHook(tempDir, $, readFile);
    const toolBefore = hook["tool.execute.before"]!;

    await Bun.spawn(["bash", "-c", "git branch -m main"], { cwd: tempDir }).exited;

    const output = { args: { command: "git commit -m test" } };
    await toolBefore(
      { tool: "bash", sessionID: "s1", callID: "c1" },
      output,
    );

    expect((output.args as Record<string, unknown>).command).toBe("git commit -m test"); // unchanged
    delete process.env.HARNESS_GUARD_OFF;
  });
});

describe("compaction hook", () => {
  it("injects verify command + dirty state + protected branches", async () => {
    const { createCompactionHook } = await import("../src/hooks/compaction.ts");
    const $ = createMockShell(tempDir);
    const files = new Map([
      [`${tempDir}/.opencode/harness-kit.json`, JSON.stringify({
        verify_command: "tsc --noEmit",
        protected_branches: ["main", "release"],
      })],
    ]);
    const readFile = createMockFileReader(files);

    const hook = createCompactionHook(tempDir, $, readFile);
    const compacting = hook["experimental.session.compacting"]!;

    // Make repo dirty
    await Bun.write(join(tempDir, "test.txt"), "dirty");
    await Bun.spawn(["bash", "-c", "git add -A"], { cwd: tempDir }).exited;

    const output = { context: [] as string[] };
    await compacting({ sessionID: "s1" }, output);

    expect(output.context.length).toBe(1);
    const text = output.context[0];
    expect(text).toContain("tsc --noEmit");
    expect(text).toContain("uncommitted changes");
    expect(text).toContain("main, release");
  });

  it("injects nothing when config is empty and repo is clean", async () => {
    const { createCompactionHook } = await import("../src/hooks/compaction.ts");
    const $ = createMockShell(tempDir);
    const readFile = createMockFileReader(new Map());

    const hook = createCompactionHook(tempDir, $, readFile);
    const compacting = hook["experimental.session.compacting"]!;

    const output = { context: [] as string[] };
    await compacting({ sessionID: "s1" }, output);

    expect(output.context.length).toBe(0);
  });
});

describe("config reader", () => {
  it("reads .opencode/harness-kit.json first", async () => {
    const { readConfig } = await import("../src/config.ts");
    const files = new Map([
      ["/repo/.opencode/harness-kit.json", JSON.stringify({ verify_command: "from-opencode" })],
      ["/repo/.claude/harness-kit.json", JSON.stringify({ verify_command: "from-claude" })],
    ]);
    const readFile = createMockFileReader(files);

    const cfg = await readConfig("/repo", readFile);
    expect(cfg.verify_command).toBe("from-opencode");
  });

  it("falls back to .claude/harness-kit.json", async () => {
    const { readConfig } = await import("../src/config.ts");
    const files = new Map([
      ["/repo/.claude/harness-kit.json", JSON.stringify({ verify_command: "from-claude" })],
    ]);
    const readFile = createMockFileReader(files);

    const cfg = await readConfig("/repo", readFile);
    expect(cfg.verify_command).toBe("from-claude");
  });

  it("returns empty config when no file exists", async () => {
    const { readConfig } = await import("../src/config.ts");
    const readFile = createMockFileReader(new Map());

    const cfg = await readConfig("/repo", readFile);
    expect(cfg).toEqual({});
  });
});
