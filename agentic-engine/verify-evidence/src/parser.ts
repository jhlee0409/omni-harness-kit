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

/** Agents whose output is worth capturing evidence from.
 * Matches agents/*.md `name:` + adapters/omp/agents/{db,ui,chrome}-verify.md.
 * `harness-auditor` and `oracle` were removed from the repo — dropped from
 * this list rather than left stale. */
const EVIDENCE_AGENTS: Record<string, true> = {
  "change-verifier": true,
  "pr-shepherd": true,
  "claim-checker": true,
  "instruction-critic": true,
  "requirement-fidelity-critic": true,
  "readability-critic": true,
  "architecture-reviewer": true,
  "spec-reviewer": true,
  "tdd-runner": true,
  "db-verify": true,
  "ui-verify": true,
  "chrome-verify": true,
};

export function isEvidenceAgent(agentName: string): boolean {
  return EVIDENCE_AGENTS[agentName] === true;
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
