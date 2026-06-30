import type { EvidenceRecord } from "./types.ts";

/** Patterns that indicate a verification claim in agent output. */
const CLAIM_PATTERNS: RegExp[] = [
  /(?:verified|confirmed|proven)[:\s]+(.+)/gi,
  /(?:test result|tests?):\s*(.+)/gi,
  /(?:pass(?:ed|ing)?):\s*(.+)/gi,
  /(?:✓|✅|PASS)\s+(.+)/g,
  /(?:evidence)[:\s]+(.+)/gi,
  /(?:typecheck|lint|build)[:\s]+(.+)/gi,
];

/** Agents whose output is worth capturing evidence from. */
const EVIDENCE_AGENTS = new Set([
  "change-verifier",
  "db-verify",
  "ui-verify",
  "chrome-verify",
  "spec-reviewer",
  "harness-auditor",
  "tdd-runner",
  "oracle",
]);

export function isEvidenceAgent(agentName: string): boolean {
  return EVIDENCE_AGENTS.has(agentName);
}

/** Extract the strongest verification claim from agent output. */
export function parseClaim(output: string): { claim: string; evidence: string } | null {
  const lines = output.split("\n");

  for (const pattern of CLAIM_PATTERNS) {
    for (const line of lines) {
      const match = new RegExp(pattern.source, pattern.flags).exec(line);
      if (match && match[1]) {
        const claim = match[1].trim().slice(0, 200);
        // Evidence = the matched line + 2 lines of context after
        const lineIdx = lines.indexOf(line);
        const contextEnd = Math.min(lineIdx + 3, lines.length);
        const evidence = lines.slice(lineIdx, contextEnd).join("\n").trim();
        return { claim, evidence };
      }
    }
  }

  return null;
}

export function createRecord(
  agent: string,
  claim: string,
  evidence: string,
): EvidenceRecord {
  return { agent, claim, evidence, timestamp: Date.now() };
}
