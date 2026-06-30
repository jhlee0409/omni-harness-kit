# Intent Router

Semantic skill/agent routing — replaces keyword matching with embedding-based
intent classification for more accurate routing.

## How it works

1. Each skill's description is embedded once and cached
2. On each user message, the message is embedded
3. Cosine similarity finds the best-matching skill
4. If similarity > threshold, the skill is surfaced/routed

## Interface

```typescript
interface IntentRouter {
  /** Index skill descriptions from a directory. */
  index(skillsDir: string): Promise<void>;

  /** Classify user intent → best matching skill. */
  classify(message: string): Promise<IntentMatch | null>;
}

interface IntentMatch {
  skill: string;       // skill name
  similarity: number;  // cosine score
}
```

## Adapters

- **Claude Code**: `UserPromptSubmit` hook → skill suggestion via additionalContext
- **OpenCode**: `chat.message` hook → `tool.definition` (dynamic skill description boost)

## Relationship to oh-my-openagent

oh-my-openagent already has `keyword-detector` (regex-based). This module
upgrades it to embedding-based matching for better accuracy on ambiguous
phrases ("이거 왜 안 돼?" → diagnose, not "fix").
