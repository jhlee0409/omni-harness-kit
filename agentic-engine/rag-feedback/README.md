# RAG Feedback Retrieval

Cross-session learning — semantically retrieves relevant past feedback/lessons
and injects them into the current context.

## How it works

1. Feedback memories are stored as markdown files (`feedback/*.md`)
2. On first run, each file is embedded (API or local) and cached as JSON
3. On each user message, the message is embedded and the top-k matching
   feedback memories are retrieved (cosine similarity)
4. Retrieved memories are injected into the system prompt

## Interface

```typescript
interface FeedbackRetriever {
  /** Index feedback files from a directory. */
  index(dir: string): Promise<void>;

  /** Retrieve top-k relevant feedback for a query. */
  retrieve(query: string, k?: number): Promise<FeedbackMemory[]>;
}

interface FeedbackMemory {
  id: string;          // filename stem
  content: string;     // markdown body
  similarity: number;  // cosine score
}
```

## Adapters

- **Claude Code**: `UserPromptSubmit` hook → `additionalContext`
- **OpenCode**: `chat.message` hook → `experimental.chat.system.transform`

## Embedding Providers (configurable)

| Provider | Type | Key needed | Privacy |
|---|---|---|---|
| OpenAI text-embedding-3-small | API | `OPENAI_API_KEY` | Cloud |
| Google text-embedding-004 | API | `GOOGLE_API_KEY` | Cloud |
| ollama bge-m3 | Local | None | Local |

Default: OpenAI. Override via `HARNESS_EMBEDDING_PROVIDER=ollama`.
