import type { FeedbackMemory, FeedbackRetriever, VectorEntry, EmbeddingProvider } from "./types.ts";
import { cosineSimilarity, contentHash } from "./similarity.ts";
import { readCache, writeCache, indexById } from "./store.ts";
import { openaiProvider } from "./providers/openai.ts";
import { googleProvider } from "./providers/google.ts";
import { ollamaProvider } from "./providers/ollama.ts";
import { localProvider } from "./providers/local.ts";

const DEFAULT_K = 3;
const CACHE_FILE = ".harness-cache/feedback-vectors.json";
const EVIDENCE_FILE = ".harness-kit/evidence.jsonl";
const EVIDENCE_LIMIT = 50;

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

/**
 * Read past-session verification evidence (the verify-evidence SubagentStop log) as
 * retrievable memories — closing the verify→feedback loop so what a critic already
 * proved or refuted informs future sessions. Decoupled: reads the JSONL artifact by its
 * public shape, with NO import of the verify-evidence module. Bounded to the most recent
 * entries so a long log cannot dominate the cache or the top-k. Opt out with
 * HARNESS_RAG_EVIDENCE_OFF=1.
 */
async function readEvidenceMemories(path: string): Promise<{ id: string; content: string }[]> {
  if (process.env.HARNESS_RAG_EVIDENCE_OFF === "1") return [];
  const file = Bun.file(path);
  if (!(await file.exists())) return [];
  const lines = (await file.text()).split("\n").filter(Boolean).slice(-EVIDENCE_LIMIT);
  const out: { id: string; content: string }[] = [];
  for (const line of lines) {
    try {
      const r = JSON.parse(line) as { agent?: string; claim?: string; evidence?: string; timestamp?: number };
      if (!r.claim) continue;
      const agent = r.agent ?? "critic";
      const id = `evidence:${agent}:${r.timestamp ?? contentHash(r.claim)}`;
      const detail = r.evidence ? `\n${r.evidence}` : "";
      out.push({ id, content: `[verification evidence — ${agent}] ${r.claim}${detail}` });
    } catch {
      // skip a malformed line — one bad record must never break retrieval
    }
  }
  return out;
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
      const toEmbed: { id: string; content: string }[] = [];

      const stage = (id: string, content: string): void => {
        const hash = contentHash(content);
        const existing = cached.get(id);
        if (existing && existing.hash === hash) next.push(existing);
        else toEmbed.push({ id, content });
      };

      // Curated feedback memories — every .md under the feedback dir (may be absent).
      const proc = Bun.spawn(
        ["bash", "-c", `find "${feedbackDir}" -name '*.md' -type f 2>/dev/null | sort`],
        { stdout: "pipe", stderr: "pipe" },
      );
      await proc.exited;
      const files = (await new Response(proc.stdout).text()).trim().split("\n").filter(Boolean);
      for (const f of files) {
        stage(f.replace(/\.md$/, "").split("/").pop()!, await Bun.file(f).text());
      }

      // Past-session verification evidence — closes the verify→feedback loop.
      for (const mem of await readEvidenceMemories(`${projectDir}/${EVIDENCE_FILE}`)) {
        stage(mem.id, mem.content);
      }

      // Batch-embed only the new/changed entries.
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
