import type { EmbeddingProvider } from "../types.ts";

/**
 * Deterministic, offline, zero-dependency embedding via the hashing trick.
 *
 * Tokenizes text (unicode letters/digits, so Korean and Latin both count), hashes
 * each token into a fixed-dimension bucket, and L2-normalizes. It is lexical, not
 * semantic — it captures term overlap, not meaning — but it is stable, needs no API
 * key or network, and yields real cosine similarity (documents sharing terms score
 * higher). Two uses:
 *   1. an offline fallback so a portable kit still works with no provider configured;
 *   2. a deterministic provider that makes the retrieval/routing pipeline self-testable
 *      in CI without a live embedding model.
 *
 * Select with `HARNESS_EMBEDDING_PROVIDER=local` (alias `hash`).
 */
const DIM = 256;

function embedOne(text: string): number[] {
  const vec = new Array(DIM).fill(0);
  const tokens = text.toLowerCase().match(/[\p{L}\p{N}]+/gu) ?? [];
  for (const tok of tokens) {
    // djb2 → bucket; sign from the low bit so unrelated collisions can cancel.
    let h = 5381;
    for (let i = 0; i < tok.length; i++) h = ((h << 5) + h + tok.charCodeAt(i)) | 0;
    const bucket = (h >>> 0) % DIM;
    vec[bucket] += (h & 1) === 0 ? 1 : -1;
  }
  let norm = 0;
  for (let i = 0; i < DIM; i++) norm += vec[i] * vec[i];
  norm = Math.sqrt(norm);
  if (norm > 0) for (let i = 0; i < DIM; i++) vec[i] /= norm;
  return vec;
}

export const localProvider: EmbeddingProvider = {
  name: "local",
  dim: DIM,

  async embed(text: string): Promise<number[]> {
    return embedOne(text);
  },

  async embedBatch(texts: string[]): Promise<number[][]> {
    return texts.map(embedOne);
  },
};
