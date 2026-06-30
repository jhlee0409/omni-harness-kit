import type { EmbeddingProvider } from "../types.ts";

const MODEL = "text-embedding-004";
const DIM = 768;
const URL = "https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent";

export const googleProvider: EmbeddingProvider = {
  name: "google",
  dim: DIM,

  async embed(text: string): Promise<number[]> {
    const key = process.env.GOOGLE_API_KEY;
    if (!key) throw new Error("GOOGLE_API_KEY not set");

    const res = await fetch(`${URL}?key=${key}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        model: `models/${MODEL}`,
        content: { parts: [{ text }] },
      }),
    });

    if (!res.ok) {
      throw new Error(`Google embeddings ${res.status}: ${await res.text()}`);
    }

    const json = (await res.json()) as {
      embedding: { values: number[] };
    };

    return json.embedding.values;
  },

  async embedBatch(texts: string[]): Promise<number[][]> {
    // Google's API is single-text; batch sequentially
    const results: number[][] = [];
    for (const text of texts) {
      results.push(await this.embed(text));
    }
    return results;
  },
};
