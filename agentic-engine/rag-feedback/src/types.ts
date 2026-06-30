export interface FeedbackMemory {
  id: string;
  content: string;
  similarity: number;
}

export interface VectorEntry {
  id: string;
  content: string;
  embedding: number[];
  hash: string;
}

export interface FeedbackRetriever {
  index(dir: string): Promise<void>;
  retrieve(query: string, k?: number): Promise<FeedbackMemory[]>;
}

export interface EmbeddingProvider {
  name: string;
  dim: number;
  embed(text: string): Promise<number[]>;
  embedBatch(texts: string[]): Promise<number[][]>;
}
