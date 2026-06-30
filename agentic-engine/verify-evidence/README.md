# Verify-Evidence Capture

Captures what was verified, how, and when — prevents false "done" claims by
persisting verification evidence from critic agents.

## Status: IMPLEMENTED (v0.1.0)

Core capture + parser + JSONL storage + CC/OC adapters + 17 unit tests, all pass.

## How it works

1. When a critic agent (change-verifier, db-verify, ui-verify, etc.) completes,
   its output is parsed for verification claims
2. Claims matching patterns like `Verified:`, `Test result:`, `✓`, `typecheck:`
   are extracted with surrounding context
3. Claims are persisted as structured JSONL records (`.harness-kit/evidence.jsonl`)
4. `hasEvidence()` checks if evidence exists for a given claim

## Usage (programmatic)

```typescript
import { createEvidenceCapture } from "./src/index.ts";

const cap = createEvidenceCapture(process.cwd());

// Called by adapter when a sub-agent finishes
const record = await cap.capture("change-verifier", "All callsites checked.\nVerified: no stale refs");
// → { agent: "change-verifier", claim: "no stale refs", evidence: "...", timestamp: ... }

// Check before claiming "done"
if (!await cap.hasEvidence("callsites updated")) {
  console.log("WARNING: no evidence for callsites update");
}
```

## Interface

```typescript
interface EvidenceCapture {
  capture(agentName: string, output: string): Promise<EvidenceRecord | null>;
  hasEvidence(claim: string): Promise<boolean>;
  getAll(): Promise<EvidenceRecord[]>;
}

interface EvidenceRecord {
  agent: string;
  claim: string;
  evidence: string;
  timestamp: number;
}
```

## Claim Patterns

| Pattern | Example match |
|---|---|
| `Verified: ...` / `Confirmed: ...` | `Verified: all callsites updated` |
| `Test result: ...` / `Tests: ...` | `Tests: 20 pass, 0 fail` |
| `Pass: ...` / `Passed: ...` | `Pass: schema matches` |
| `✓ ...` / `✅ ...` / `PASS ...` | `✓ All tests pass` |
| `typecheck: ...` / `lint: ...` / `build: ...` | `typecheck: exit 0` |

Non-colon patterns (`tests?`, `pass`) require a colon to avoid false positives
(e.g., "All tests pass" should NOT match the test-result pattern).

## Recognized Agents

`change-verifier`, `db-verify`, `ui-verify`, `chrome-verify`, `spec-reviewer`,
`harness-auditor`, `tdd-runner`, `oracle`.

## Storage

JSONL (append-only): `.harness-kit/evidence.jsonl` — one JSON record per line.

## Test

```bash
cd agentic-engine/verify-evidence && bun test test/verify-evidence.test.ts
# 17 pass, 0 fail
```

Covers: agent recognition, claim parsing (6 patterns + null + context), store round-trip, capture (recognized/non-recognized/no-match), hasEvidence (match/miss/case-insensitive), getAll empty.
