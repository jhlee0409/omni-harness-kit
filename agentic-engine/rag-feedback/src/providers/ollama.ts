import type { EmbeddingProvider } from "../types.ts";

const MODEL = "bge-m3";
const DIM = 1024;
const URL = "http://localhost:11434/api/embeddings";

export const ollamaProvider: EmbeddingProvider = {
  name: "ollama",
  dim: DIM,

  async embed(text: string): Promise<number[]> {
    const res = await fetch(URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ model: MODEL, prompt: text }),
    });

    if (!res.ok) {
      throw new Error(`ollama embeddings ${res.status}: ${await res.text()}`);
    }

    const json = (await res.json()) as { embedding: number[] };
    return json.embedding;
  },

  async embedBatch(texts: string[]): Promise<number[][]> {
    // ollama's API is single-text; batch sequentially
    const results: number[][] = [];
    for (const text of texts) {
      results.push(await this.embed(text));
    }
    return results;
  },
};
