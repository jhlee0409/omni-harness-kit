# Verify-Evidence Capture

Captures what was verified, how, and when — prevents false "done" claims by
persisting verification evidence from critic agents.

## How it works

1. When a critic agent (change-verifier, ui-verify, db-verify) completes,
   its output is parsed for verification claims
2. Claims are persisted as structured evidence records
3. Before a "done" conclusion, the evidence is checked — if missing, the
   agent is reminded

## Interface

```typescript
interface EvidenceCapture {
  /** Capture evidence from a completed sub-agent's output. */
  capture(agentName: string, output: string): Promise<EvidenceRecord | null>;

  /** Check if evidence exists for a given claim. */
  hasEvidence(claim: string): Promise<boolean>;
}

interface EvidenceRecord {
  agent: string;       // e.g. "change-verifier"
  claim: string;       // what was verified
  evidence: string;    // the proof (test output, DB query result, etc.)
  timestamp: number;
}
```

## Adapters

- **Claude Code**: `SubagentStop` hook → parse + persist
- **OpenCode**: `tool.execute.after` (on task tool completion) → parse + persist

## Storage

- **Default**: JSON file (`.harness-kit/evidence.jsonl`) — simple, portable
- **Alternative**: OpenCode session database (future)
