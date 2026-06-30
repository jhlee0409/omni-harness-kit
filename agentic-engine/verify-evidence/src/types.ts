export interface EvidenceRecord {
  agent: string;
  claim: string;
  evidence: string;
  timestamp: number;
}

export interface EvidenceCapture {
  capture(agentName: string, output: string): Promise<EvidenceRecord | null>;
  hasEvidence(claim: string): Promise<boolean>;
  getAll(): Promise<EvidenceRecord[]>;
}
