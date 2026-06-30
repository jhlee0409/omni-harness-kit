/**
 * Intent router tests — mock embedding provider, no API calls.
 *
 * Run: cd agentic-engine/intent-router && bun test test/intent-router.test.ts
 */

import { describe, expect, it, beforeEach, afterEach } from "bun:test";
import { rm, mkdtemp, mkdir, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { EmbeddingProvider } from "../src/types.ts";
import { cosineSimilarity, contentHash } from "../src/similarity.ts";
import { readCache, writeCache } from "../src/store.ts";
import { createRouter } from "../src/index.ts";

function createMockProvider(dim: number = 16): EmbeddingProvider {
  return {
    name: "mock",
    dim,
    async embed(text: string): Promise<number[]> {
      const vec = new Array(dim).fill(0);
      for (let i = 0; i < text.length; i++) {
        vec[i % dim] += text.charCodeAt(i) / 1000;
      }
      const norm = Math.sqrt(vec.reduce((s, v) => s + v * v, 0));
      if (norm > 0) for (let i = 0; i < dim; i++) vec[i] /= norm;
      return vec;
    },
    async embedBatch(texts: string[]): Promise<number[][]> {
      const out: number[][] = [];
      for (const t of texts) out.push(await this.embed(t));
      return out;
    },
  };
}

function makeSkillMd(name: string, description: string): string {
  return `---\nname: ${name}\ndescription: ${description}\n---\n\n# ${name}\n\nBody.\n`;
}

let projectDir: string;
let skillsDir: string;

beforeEach(async () => {
  projectDir = await mkdtemp(join(tmpdir(), "hk-intent-"));
  skillsDir = join(projectDir, "skills");
  await mkdir(skillsDir, { recursive: true });
});

afterEach(async () => {
  await rm(projectDir, { recursive: true, force: true });
});

describe("similarity + hash", () => {
  it("cosineSimilarity basics", () => {
    expect(cosineSimilarity([1, 0], [1, 0])).toBeCloseTo(1, 5);
    expect(cosineSimilarity([1, 0], [0, 1])).toBeCloseTo(0, 5);
    expect(cosineSimilarity([], [])).toBe(0);
  });

  it("contentHash stability", () => {
    expect(contentHash("x")).toBe(contentHash("x"));
    expect(contentHash("x")).not.toBe(contentHash("y"));
  });
});

describe("store", () => {
  it("readCache returns [] for missing file", async () => {
    expect(await readCache(join(projectDir, "nope.json"))).toEqual([]);
  });

  it("writeCache + readCache round-trip", async () => {
    const path = join(projectDir, "c.json");
    const entries = [{ skill: "a", description: "alpha", embedding: [1], hash: "aa" }];
    await writeCache(path, entries);
    const result = await readCache(path);
    expect(result).toEqual(entries);
  });
});

describe("IntentRouter", () => {
  it("index() reads SKILL.md frontmatter and caches embeddings", async () => {
    await mkdir(join(skillsDir, "diagnose"), { recursive: true });
    await mkdir(join(skillsDir, "tdd"), { recursive: true });
    await writeFile(join(skillsDir, "diagnose", "SKILL.md"), makeSkillMd("diagnose", "Debug and diagnose bugs systematically"));
    await writeFile(join(skillsDir, "tdd", "SKILL.md"), makeSkillMd("tdd", "Test driven development red green refactor"));

    const r = createRouter(projectDir, createMockProvider());
    await r.index(skillsDir);

    const cache = await readCache(join(projectDir, ".harness-cache/intent-vectors.json"));
    expect(cache.length).toBe(2);
    expect(cache.find((e) => e.skill === "diagnose")).toBeDefined();
    expect(cache.find((e) => e.skill === "tdd")).toBeDefined();
  });

  it("index() skips unchanged skills (hash check)", async () => {
    await mkdir(join(skillsDir, "x"), { recursive: true });
    await writeFile(join(skillsDir, "x", "SKILL.md"), makeSkillMd("x", "original desc"));

    const provider = createMockProvider();
    let calls = 0;
    const orig = provider.embedBatch.bind(provider);
    provider.embedBatch = async (t: string[]) => { calls += t.length; return orig(t); };

    const r = createRouter(projectDir, provider);
    await r.index(skillsDir);
    expect(calls).toBe(1);
    await r.index(skillsDir);
    expect(calls).toBe(1);
  });

  it("index() re-embeds changed descriptions", async () => {
    await mkdir(join(skillsDir, "x"), { recursive: true });
    await writeFile(join(skillsDir, "x", "SKILL.md"), makeSkillMd("x", "original desc"));

    const provider = createMockProvider();
    let calls = 0;
    const orig = provider.embedBatch.bind(provider);
    provider.embedBatch = async (t: string[]) => { calls += t.length; return orig(t); };

    const r = createRouter(projectDir, provider);
    await r.index(skillsDir);
    expect(calls).toBe(1);

    await writeFile(join(skillsDir, "x", "SKILL.md"), makeSkillMd("x", "changed desc"));
    await r.index(skillsDir);
    expect(calls).toBe(2);
  });

  it("classify() returns best match above threshold", async () => {
    await mkdir(join(skillsDir, "diagnose"), { recursive: true });
    await mkdir(join(skillsDir, "deploy"), { recursive: true });
    await writeFile(join(skillsDir, "diagnose", "SKILL.md"), makeSkillMd("diagnose", "debug diagnose bug systematic root cause"));
    await writeFile(join(skillsDir, "deploy", "SKILL.md"), makeSkillMd("deploy", "deploy production release CI CD"));

    const r = createRouter(projectDir, createMockProvider(), 0.0);
    await r.index(skillsDir);

    const match = await r.classify("debug diagnose bug");
    expect(match).not.toBeNull();
    expect(match!.skill).toBe("diagnose");
  });

  it("classify() returns null when below threshold", async () => {
    await mkdir(join(skillsDir, "diagnose"), { recursive: true });
    await writeFile(join(skillsDir, "diagnose", "SKILL.md"), makeSkillMd("diagnose", "debug diagnose bug"));

    const r = createRouter(projectDir, createMockProvider(), 0.99);
    await r.index(skillsDir);

    const match = await r.classify("something totally different xyzzy");
    expect(match).toBeNull();
  });

  it("classify() returns null when cache is empty", async () => {
    const r = createRouter(projectDir, createMockProvider());
    const match = await r.classify("anything");
    expect(match).toBeNull();
  });

  it("index() handles dir with no SKILL.md files", async () => {
    await mkdir(join(skillsDir, "empty"), { recursive: true });
    await writeFile(join(skillsDir, "empty", "README.md"), "no frontmatter here");

    const r = createRouter(projectDir, createMockProvider());
    await r.index(skillsDir);

    const cache = await readCache(join(projectDir, ".harness-cache/intent-vectors.json"));
    expect(cache).toEqual([]);
  });

  it("index() skips SKILL.md without name/description in frontmatter", async () => {
    await mkdir(join(skillsDir, "bad"), { recursive: true });
    await writeFile(join(skillsDir, "bad", "SKILL.md"), "---\ncategories: misc\n---\n\nNo name/desc.");

    const r = createRouter(projectDir, createMockProvider());
    await r.index(skillsDir);

    const cache = await readCache(join(projectDir, ".harness-cache/intent-vectors.json"));
    expect(cache).toEqual([]);
  });
});
