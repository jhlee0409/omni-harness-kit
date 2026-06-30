import type { EmbeddingProvider } from "../types.ts";

const MODEL = "text-embedding-3-small";
const DIM = 1536;
const URL = "https://api.openai.com/v1/embeddings";

export const openaiProvider: EmbeddingProvider = {
  name: "openai",
  dim: DIM,

  async embed(text: string): Promise<number[]> {
    const [vec] = await this.embedBatch([text]);
    return vec;
  },

  async embedBatch(texts: string[]): Promise<number[][]> {
    const key = process.env.OPENAI_API_KEY;
    if (!key) throw new Error("OPENAI_API_KEY not set");

    const res = await fetch(URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${key}`,
      },
      body: JSON.stringify({ model: MODEL, input: texts }),
    });

    if (!res.ok) {
      throw new Error(`OpenAI embeddings ${res.status}: ${await res.text()}`);
    }

    const json = (await res.json()) as {
      data: { embedding: number[] }[];
    };

    return json.data.map((d) => d.embedding);
  },
};
