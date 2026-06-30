import type { EvidenceCapture, EvidenceRecord } from "./types.ts";
import { readEvidence, appendEvidence } from "./store.ts";
import { parseClaim, createRecord, isEvidenceAgent } from "./parser.ts";

const EVIDENCE_FILE = ".harness-kit/evidence.jsonl";

export function createEvidenceCapture(projectDir: string): EvidenceCapture {
  const path = `${projectDir}/${EVIDENCE_FILE}`;

  return {
    async capture(agentName: string, output: string): Promise<EvidenceRecord | null> {
      if (!isEvidenceAgent(agentName)) return null;

      const parsed = parseClaim(output);
      if (!parsed) return null;

      const record = createRecord(agentName, parsed.claim, parsed.evidence);
      await appendEvidence(path, record);
      return record;
    },

    async hasEvidence(claim: string): Promise<boolean> {
      const records = await readEvidence(path);
      const lower = claim.toLowerCase();
      return records.some(
        (r) =>
          r.claim.toLowerCase().includes(lower) ||
          lower.includes(r.claim.toLowerCase()),
      );
    },

    async getAll(): Promise<EvidenceRecord[]> {
      return readEvidence(path);
    },
  };
}
