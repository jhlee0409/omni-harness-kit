# Agentic Engine

The layer that makes the harness a **self-correcting system**, not just a static
config bundle. Each module is a generic, domain-agnostic capability that any
project benefits from.

## Architecture

```
agentic-engine/
├── rag-feedback/      Cross-session learning (semantic feedback retrieval)
├── intent-router/     Semantic skill/agent routing (embedding-based)
├── cross-vendor/      Independent verification from different AI vendors
└── verify-evidence/   Verification evidence capture & persistence
```

## Design Principles

1. **Platform-neutral core, platform-specific adapter.**
   Each module has a `core/` (Python or TypeScript — pure logic) and a
   `adapters/{claude-code,opencode}/` (the hook/glue for each runtime).

2. **No heavy dependencies by default.**
   The RAG feedback and intent router use API-based embeddings by default
   (OpenAI text-embedding-3-small). Local embeddings (ollama bge-m3) are opt-in
   for privacy-conscious users.

3. **Graceful degradation.**
   If ollama isn't installed, or no API key is set, modules fail open — the
   harness still works, just without that module's enhancement.

## Module Status

| Module | Status | CC Adapter | OpenCode Adapter |
|---|---|---|---|
| `rag-feedback/` | 📋 Specification only | Planned | Planned |
| `intent-router/` | 📋 Specification only | Planned | Planned |
| `cross-vendor/` | 📋 Specification only | Planned | Planned |
| `verify-evidence/` | 📋 Specification only | Planned | Planned |

## Relationship to the Source (ai-showhost)

These modules are generalized versions of the systems proven in the
`ai-showhost` monorepo. The source systems are tightly coupled to that
project's measurement infrastructure (18 jsonl files, ~50MB). This engine
extracts the *agentic capability* without the measurement overhead.

### What's NOT here (deliberately excluded)

- **Measurement/audit pipeline** (tools.jsonl, turns.jsonl, audit-log.jsonl) —
  too heavy for an open-source project. The user's own thesis: "측정 시스템가
  없더라도 안정적이고 신뢰성있는 산출물을 제공했으면 좋겠다."
- **Domain-specific gates** (PR automation, slice drift alerts, design routing) —
  these are ai-showhost-specific operational needs, not generic agentic capabilities.
