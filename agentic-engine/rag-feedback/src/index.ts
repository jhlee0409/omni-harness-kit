import type { FeedbackMemory, FeedbackRetriever, VectorEntry, EmbeddingProvider } from "./types.ts";
import { cosineSimilarity, contentHash } from "./similarity.ts";
import { readCache, writeCache, indexById } from "./store.ts";
import { openaiProvider } from "./providers/openai.ts";
import { googleProvider } from "./providers/google.ts";
import { ollamaProvider } from "./providers/ollama.ts";
import { localProvider } from "./providers/local.ts";

const DEFAULT_K = 3;
const CACHE_FILE = ".harness-cache/feedback-vectors.json";

export function createProvider(): EmbeddingProvider {
  const choice = process.env.HARNESS_EMBEDDING_PROVIDER ?? "openai";
  switch (choice) {
    case "openai":  return openaiProvider;
    case "google":  return googleProvider;
    case "ollama":  return ollamaProvider;
    case "local":
    case "hash":    return localProvider;
    default:
      throw new Error(`Unknown embedding provider: ${choice}`);
  }
}

export function createRetriever(
  projectDir: string,
  provider?: EmbeddingProvider,
): FeedbackRetriever {
  const embed = provider ?? createProvider();
  const cachePath = `${projectDir}/${CACHE_FILE}`;

  return {
    async index(feedbackDir: string): Promise<void> {
      const cached = indexById(await readCache(cachePath));
      const next: VectorEntry[] = [];

      // Read all .md files from feedback dir
      const dir = await Bun.file(feedbackDir);
      // Bun.file doesn't list dirs — use the glob API via a workaround
      const proc = Bun.spawn(["bash", "-c", `find "${feedbackDir}" -name '*.md' -type f | sort`], {
        stdout: "pipe",
        stderr: "pipe",
      });
      const exitCode = await proc.exited;
      if (exitCode !== 0) return;

      const stdout = await new Response(proc.stdout).text();
      const files = stdout.trim().split("\n").filter(Boolean);
      if (files.length === 0) return;

      // Determine which need (re-)embedding
      const toEmbed: { id: string; content: string; path: string }[] = [];
      for (const f of files) {
        const content = await Bun.file(f).text();
        const id = f.replace(/\.md$/, "").split("/").pop()!;
        const hash = contentHash(content);
        const existing = cached.get(id);

        if (existing && existing.hash === hash) {
          next.push(existing);
        } else {
          toEmbed.push({ id, content, path: f });
        }
      }

      // Batch-embed new/changed entries
      if (toEmbed.length > 0) {
        const embeddings = await embed.embedBatch(toEmbed.map((e) => e.content));
        for (let i = 0; i < toEmbed.length; i++) {
          next.push({
            id: toEmbed[i].id,
            content: toEmbed[i].content,
            embedding: embeddings[i],
            hash: contentHash(toEmbed[i].content),
          });
        }
      }

      await writeCache(cachePath, next);
    },

    async retrieve(query: string, k: number = DEFAULT_K): Promise<FeedbackMemory[]> {
      const entries = await readCache(cachePath);
      if (entries.length === 0) return [];

      const qVec = await embed.embed(query);
      const scored = entries
        .map((e) => ({
          id: e.id,
          content: e.content,
          similarity: cosineSimilarity(qVec, e.embedding),
        }))
        .sort((a, b) => b.similarity - a.similarity)
        .slice(0, k);

      return scored;
    },
  };
}
