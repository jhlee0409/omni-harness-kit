# Intent Router

Semantic skill/agent routing — replaces keyword matching with embedding-based
intent classification for more accurate routing.

## Status: IMPLEMENTED (v0.1.0)

Core router + CC adapter + 12 unit tests, all pass. OC adapter stubbed
(same system.transform limitation as rag-feedback).

## How it works

1. Each skill's `description` from SKILL.md YAML frontmatter is embedded and cached
2. On each user message, the message is embedded
3. Cosine similarity finds the best-matching skill
4. If similarity ≥ threshold (default 0.75), the skill is suggested

## Usage (programmatic)

```typescript
import { createRouter } from "./src/index.ts";

const router = createRouter(process.cwd());
await router.index("./.claude/skills");

const match = await router.classify("why is this throwing an error?");
// → { skill: "diagnose", description: "...", similarity: 0.82 } | null
```

## Usage (Claude Code hook)

```bash
# .claude/settings.json — UserPromptSubmit hook
{
  "hooks": {
    "UserPromptSubmit": [
      { "command": "bash ./agentic-engine/intent-router/adapters/claude-code/submit.sh" }
    ]
  }
}
```

Kill switch: `HARNESS_INTENT_OFF=1`
Threshold: `HARNESS_INTENT_THRESHOLD=0.75`

## Interface

```typescript
interface IntentRouter {
  index(skillsDir: string): Promise<void>;
  classify(message: string): Promise<IntentMatch | null>;
}

interface IntentMatch {
  skill: string;
  description: string;
  similarity: number;
}
```

## Relationship to oh-my-openagent

oh-my-openagent already has `keyword-detector` (regex-based). This module
upgrades it to embedding-based matching for better accuracy on ambiguous
phrases ("이거 왜 안 돼?" → diagnose, not "fix").

## Test

```bash
cd agentic-engine/intent-router && bun test test/intent-router.test.ts
# 12 pass, 0 fail
```

Covers: similarity/hash basics, store round-trip, index (create/skip-unchanged/re-embed/no-skill-md/missing-frontmatter), classify (match/no-match-empty-cache/threshold-gate).
