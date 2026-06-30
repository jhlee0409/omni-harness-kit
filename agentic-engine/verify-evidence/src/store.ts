import type { EvidenceRecord } from "./types.ts";
import { appendFile, mkdir } from "node:fs/promises";
import { dirname } from "node:path";

export async function readEvidence(path: string): Promise<EvidenceRecord[]> {
  try {
    const file = Bun.file(path);
    if (!(await file.exists())) return [];
    const text = await file.text();
    return text
      .trim()
      .split("\n")
      .filter(Boolean)
      .map((line) => JSON.parse(line) as EvidenceRecord)
      .filter((r) => r && typeof r.agent === "string");
  } catch {
    return [];
  }
}

export async function appendEvidence(path: string, record: EvidenceRecord): Promise<void> {
  try {
    const dir = dirname(path);
    await mkdir(dir, { recursive: true });
    await appendFile(path, JSON.stringify(record) + "\n", "utf-8");
  } catch {
    // fail-open
  }
}
