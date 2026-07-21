/**
 * RAG feedback module tests — uses mock embedding provider (no API calls).
 *
 * Run: cd agentic-engine/rag-feedback && bun test test/rag-feedback.test.ts
 */

import { describe, expect, it, beforeEach, afterEach } from "bun:test";
import { rm, mkdtemp } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { mkdir, writeFile } from "node:fs/promises";
import type { EmbeddingProvider, VectorEntry } from "../src/types.ts";
import { cosineSimilarity, contentHash } from "../src/similarity.ts";
import { readCache, writeCache, indexById } from "../src/store.ts";
import { createRetriever } from "../src/index.ts";
import { localProvider } from "../src/providers/local.ts";

// ─── Mock embedding provider ──────────────────────────────

/**
 * Deterministic mock: maps text to a fixed-dim vector via simple hashing.
 * Similar texts get similar vectors (by design — for testing retrieval).
 */
function createMockProvider(dim: number = 16): EmbeddingProvider {
  return {
    name: "mock",
    dim,
    async embed(text: string): Promise<number[]> {
      const vec = new Array(dim).fill(0);
      // Simple: each character contributes to a dimension
      for (let i = 0; i < text.length; i++) {
        vec[i % dim] += text.charCodeAt(i) / 1000;
      }
      // Normalize
      const norm = Math.sqrt(vec.reduce((s, v) => s + v * v, 0));
      if (norm > 0) {
        for (let i = 0; i < dim; i++) vec[i] /= norm;
      }
      return vec;
    },
    async embedBatch(texts: string[]): Promise<number[][]> {
      const results: number[][] = [];
      for (const t of texts) results.push(await this.embed(t));
      return results;
    },
  };
}

// ─── Test state ───────────────────────────────────────────

let projectDir: string;
let feedbackDir: string;

beforeEach(async () => {
  projectDir = await mkdtemp(join(tmpdir(), "hk-rag-"));
  feedbackDir = join(projectDir, "feedback");
  await mkdir(feedbackDir, { recursive: true });
});

afterEach(async () => {
  await rm(projectDir, { recursive: true, force: true });
});

// ─── Tests ────────────────────────────────────────────────

describe("cosineSimilarity", () => {
  it("returns 1 for identical vectors", () => {
    const v = [1, 2, 3];
    expect(cosineSimilarity(v, v)).toBeCloseTo(1, 5);
  });

  it("returns 0 for orthogonal vectors", () => {
    expect(cosineSimilarity([1, 0], [0, 1])).toBeCloseTo(0, 5);
  });

  it("returns -1 for opposite vectors", () => {
    expect(cosineSimilarity([1, 0], [-1, 0])).toBeCloseTo(-1, 5);
  });

  it("returns 0 for empty or mismatched-length vectors", () => {
    expect(cosineSimilarity([], [])).toBe(0);
    expect(cosineSimilarity([1], [1, 2])).toBe(0);
  });
});

describe("contentHash", () => {
  it("returns a stable hex string", () => {
    const h1 = contentHash("hello world");
    const h2 = contentHash("hello world");
    expect(h1).toBe(h2);
    expect(h1).toMatch(/^[0-9a-f]+$/);
  });

  it("returns different hashes for different content", () => {
    expect(contentHash("hello")).not.toBe(contentHash("world"));
  });
});

describe("store", () => {
  it("readCache returns [] for missing file", async () => {
    const result = await readCache(join(projectDir, "nonexistent.json"));
    expect(result).toEqual([]);
  });

  it("writeCache + readCache round-trip", async () => {
    const path = join(projectDir, "cache.json");
    const entries: VectorEntry[] = [
      { id: "a", content: "alpha", embedding: [1, 0], hash: "aa" },
      { id: "b", content: "beta", embedding: [0, 1], hash: "bb" },
    ];
    await writeCache(path, entries);
    const result = await readCache(path);
    expect(result).toEqual(entries);
  });

  it("indexById creates a Map keyed by id", () => {
    const entries: VectorEntry[] = [
      { id: "a", content: "x", embedding: [], hash: "1" },
      { id: "b", content: "y", embedding: [], hash: "2" },
    ];
    const m = indexById(entries);
    expect(m.get("a")?.content).toBe("x");
    expect(m.get("b")?.content).toBe("y");
    expect(m.get("c")).toBeUndefined();
  });
});

describe("FeedbackRetriever", () => {
  it("index() creates cache from feedback files", async () => {
    await writeFile(join(feedbackDir, "auth.md"), "Always verify auth tokens before trusting requests");
    await writeFile(join(feedbackDir, "db.md"), "Check MongoDB indexes before reporting slow queries");

    const provider = createMockProvider();
    const r = createRetriever(projectDir, provider);
    await r.index(feedbackDir);

    const cache = await readCache(join(projectDir, ".harness-cache/feedback-vectors.json"));
    expect(cache.length).toBe(2);
    expect(cache.find((e) => e.id === "auth")).toBeDefined();
    expect(cache.find((e) => e.id === "db")).toBeDefined();
  });

  it("index() skips unchanged files (hash check)", async () => {
    await writeFile(join(feedbackDir, "tip.md"), "original content");

    const provider = createMockProvider();
    let embedCalls = 0;
    const originalBatch = provider.embedBatch.bind(provider);
    provider.embedBatch = async (texts: string[]) => {
      embedCalls += texts.length;
      return originalBatch(texts);
    };

    const r = createRetriever(projectDir, provider);
    await r.index(feedbackDir);
    expect(embedCalls).toBe(1);

    // Second index — file unchanged → should not re-embed
    await r.index(feedbackDir);
    expect(embedCalls).toBe(1); // still 1
  });

  it("index() re-embeds changed files", async () => {
    await writeFile(join(feedbackDir, "tip.md"), "original content");

    const provider = createMockProvider();
    let embedCalls = 0;
    const originalBatch = provider.embedBatch.bind(provider);
    provider.embedBatch = async (texts: string[]) => {
      embedCalls += texts.length;
      return originalBatch(texts);
    };

    const r = createRetriever(projectDir, provider);
    await r.index(feedbackDir);
    expect(embedCalls).toBe(1);

    // Change the file
    await writeFile(join(feedbackDir, "tip.md"), "changed content");
    await r.index(feedbackDir);
    expect(embedCalls).toBe(2); // re-embedded
  });

  it("retrieve() returns top-k by similarity", async () => {
    await writeFile(join(feedbackDir, "auth.md"), "verify auth tokens before trusting requests");
    await writeFile(join(feedbackDir, "db.md"), "check MongoDB indexes for slow queries");
    await writeFile(join(feedbackDir, "ui.md"), "test button reachability in browser viewport");

    const provider = createMockProvider();
    const r = createRetriever(projectDir, provider);
    await r.index(feedbackDir);

    const hits = await r.retrieve("verify auth tokens", 2);
    expect(hits.length).toBe(2);
    // The auth.md entry should be most similar
    expect(hits[0].id).toBe("auth");
    expect(hits[0].similarity).toBeGreaterThan(hits[1].similarity);
  });

  it("retrieve() returns [] when cache is empty", async () => {
    const provider = createMockProvider();
    const r = createRetriever(projectDir, provider);
    const hits = await r.retrieve("anything");
    expect(hits).toEqual([]);
  });

  it("retrieve() respects k parameter", async () => {
    for (let i = 0; i < 5; i++) {
      await writeFile(join(feedbackDir, `f${i}.md`), `feedback item number ${i}`);
    }

    const provider = createMockProvider();
    const r = createRetriever(projectDir, provider);
    await r.index(feedbackDir);

    const hits3 = await r.retrieve("feedback item", 3);
    expect(hits3.length).toBe(3);

    const hits5 = await r.retrieve("feedback item", 5);
    expect(hits5.length).toBe(5);
  });

  it("index() handles empty feedback dir gracefully", async () => {
    const provider = createMockProvider();
    const r = createRetriever(projectDir, provider);
    await r.index(feedbackDir); // no .md files

    const cache = await readCache(join(projectDir, ".harness-cache/feedback-vectors.json"));
    expect(cache).toEqual([]);
  });
});

describe("createProvider", () => {
  it("returns openai by default", () => {
    delete process.env.HARNESS_EMBEDDING_PROVIDER;
    const { createProvider } = require("../src/index.ts");
    expect(createProvider().name).toBe("openai");
  });

  it("returns google when configured", () => {
    process.env.HARNESS_EMBEDDING_PROVIDER = "google";
    const { createProvider } = require("../src/index.ts");
    expect(createProvider().name).toBe("google");
    delete process.env.HARNESS_EMBEDDING_PROVIDER;
  });

  it("returns ollama when configured", () => {
    process.env.HARNESS_EMBEDDING_PROVIDER = "ollama";
    const { createProvider } = require("../src/index.ts");
    expect(createProvider().name).toBe("ollama");
    delete process.env.HARNESS_EMBEDDING_PROVIDER;
  });

  it("throws on unknown provider", () => {
    process.env.HARNESS_EMBEDDING_PROVIDER = "nonexistent";
    const { createProvider } = require("../src/index.ts");
    expect(() => createProvider()).toThrow("Unknown embedding provider");
    delete process.env.HARNESS_EMBEDDING_PROVIDER;
  });
});

describe("localProvider (deterministic offline embedding)", () => {
  it("is deterministic and L2-normalized", async () => {
    const a = await localProvider.embed("verify the live schedule");
    const b = await localProvider.embed("verify the live schedule");
    expect(a).toEqual(b);
    expect(a.length).toBe(localProvider.dim);
    const norm = Math.sqrt(a.reduce((s, x) => s + x * x, 0));
    expect(norm).toBeCloseTo(1, 6);
  });

  it("scores shared terms higher than disjoint terms", async () => {
    const q = await localProvider.embed("verify the live broadcast schedule");
    const near = await localProvider.embed("check the live broadcast schedule now");
    const far = await localProvider.embed("compile rust binaries for release");
    expect(cosineSimilarity(q, near)).toBeGreaterThan(cosineSimilarity(q, far));
  });

  it("handles token-less input without NaN", async () => {
    const v = await localProvider.embed("!!! ??? ...");
    expect(v.every((x) => Number.isFinite(x))).toBe(true);
    expect(cosineSimilarity(v, await localProvider.embed("anything"))).toBe(0);
  });

  it("batch matches single", async () => {
    const [x] = await localProvider.embedBatch(["hello world"]);
    expect(x).toEqual(await localProvider.embed("hello world"));
  });
});
