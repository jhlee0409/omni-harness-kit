# RAG Feedback Retrieval

Cross-session learning — semantically retrieves relevant past feedback/lessons
and injects them into the current context.

## Status: IMPLEMENTED (v0.1.0)

Core retriever + 3 embedding providers + CC adapter are written and tested
(20 unit tests, all pass). OC adapter has a known limitation (see below).

## How it works

1. Feedback memories are stored as markdown files (`feedback/*.md`)
2. On first run, each file is embedded (API or local) and cached as JSON
3. On each user message, the message is embedded and the top-k matching
   feedback memories are retrieved (cosine similarity)
4. Retrieved memories are injected into the system prompt

## Usage (programmatic)

```typescript
import { createRetriever } from "./src/index.ts";

const retriever = createRetriever(process.cwd());

// Index feedback files (embeds new/changed, skips cached)
await retriever.index("./feedback");

// Retrieve top-3 relevant memories
const hits = await retriever.retrieve("verify auth before trusting request", 3);
// → [{ id: "auth", content: "...", similarity: 0.87 }, ...]
```

## Usage (Claude Code hook)

```bash
# .claude/settings.json — UserPromptSubmit hook
{
  "hooks": {
    "UserPromptSubmit": [
      { "command": "bash ./agentic-engine/rag-feedback/adapters/claude-code/submit.sh" }
    ]
  }
}
```

Config (`.claude/harness-kit.json`):
```json
{ "feedback_dir": ".claude/feedback", "embedding_provider": "openai" }
```

Kill switch: `HARNESS_RAG_OFF=1`

## Interface

```typescript
interface FeedbackRetriever {
  index(dir: string): Promise<void>;
  retrieve(query: string, k?: number): Promise<FeedbackMemory[]>;
}

interface FeedbackMemory {
  id: string;          // filename stem
  content: string;     // markdown body
  similarity: number;  // cosine score
}
```

## Embedding Providers

| Provider | Model | Dim | Key needed | Privacy |
|---|---|---|---|---|
| OpenAI (default) | text-embedding-3-small | 1536 | `OPENAI_API_KEY` | Cloud |
| Google | text-embedding-004 | 768 | `GOOGLE_API_KEY` | Cloud |
| ollama | bge-m3 | 1024 | None | Local |

Override: `HARNESS_EMBEDDING_PROVIDER=ollama`

## Architecture

```
src/
├── types.ts          — FeedbackRetriever, EmbeddingProvider interfaces
├── index.ts          — createRetriever() + createProvider()
├── similarity.ts     — cosineSimilarity() + contentHash()
├── store.ts          — JSON-based vector cache (read/write/indexById)
└── providers/
    ├── openai.ts     — text-embedding-3-small via fetch
    ├── google.ts     — text-embedding-004 via fetch
    └── ollama.ts     — bge-m3 via fetch
```

Cache: `.harness-cache/feedback-vectors.json` (auto-created, gitignored).

**Hash-based cache invalidation**: files are re-embedded only when content changes (djb2 hash). Unchanged files reuse cached embeddings.

## OpenCode Adapter Limitation

The OC adapter (`adapters/opencode/rag-feedback.ts`) uses `experimental.chat.system.transform`, which fires before the user's message is processed — it cannot access the latest user message for query-based retrieval. A proper implementation requires a `chat.prompt.before` or similar hook that exposes the user's message. The adapter is stubbed with a TODO.

The CC adapter (`adapters/claude-code/submit.sh`) works fully — `UserPromptSubmit` provides the prompt directly.

## Test

```bash
cd agentic-engine/rag-feedback && bun test test/rag-feedback.test.ts
# 20 pass, 0 fail
```

Covers: cosine similarity (identical/orthogonal/opposite/mismatched), content hash stability, store round-trip, index (create/skip-unchanged/re-embed/empty-dir), retrieve (top-k/empty-cache/k-param), provider selection.
