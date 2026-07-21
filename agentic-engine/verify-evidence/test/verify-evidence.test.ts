/**
 * Verify-evidence module tests.
 *
 * Run: cd agentic-engine/verify-evidence && bun test test/verify-evidence.test.ts
 */

import { describe, expect, it, beforeEach, afterEach } from "bun:test";
import { rm, mkdtemp, mkdir } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { readEvidence, appendEvidence } from "../src/store.ts";
import { parseClaim, isEvidenceAgent, createRecord } from "../src/parser.ts";
import { createEvidenceCapture } from "../src/index.ts";
import type { EvidenceRecord } from "../src/types.ts";

let projectDir: string;

beforeEach(async () => {
  projectDir = await mkdtemp(join(tmpdir(), "hk-evidence-"));
});

afterEach(async () => {
  await rm(projectDir, { recursive: true, force: true });
});

describe("parser", () => {
  it("isEvidenceAgent recognizes critic agents", () => {
    expect(isEvidenceAgent("change-verifier")).toBe(true);
    expect(isEvidenceAgent("db-verify")).toBe(true);
    expect(isEvidenceAgent("ui-verify")).toBe(true);
    expect(isEvidenceAgent("pr-shepherd")).toBe(true);
    expect(isEvidenceAgent("tdd-runner")).toBe(true);
  });

  it("isEvidenceAgent rejects non-critic agents", () => {
    expect(isEvidenceAgent("build")).toBe(false);
    expect(isEvidenceAgent("explore")).toBe(false);
    expect(isEvidenceAgent("random-agent")).toBe(false);
  });

  it("parseClaim extracts 'verified:' pattern", () => {
    const result = parseClaim("Verified: all callsites updated to new signature");
    expect(result).not.toBeNull();
    expect(result!.claim).toContain("all callsites updated");
  });

  it("parseClaim extracts 'test result:' pattern", () => {
    const result = parseClaim("Test result: 20 pass, 0 fail");
    expect(result).not.toBeNull();
    expect(result!.claim).toContain("20 pass");
  });

  it("parseClaim extracts ✓ pattern", () => {
    const result = parseClaim("✓ All tests pass");
    expect(result).not.toBeNull();
    expect(result!.claim).toContain("All tests pass");
  });

  it("parseClaim extracts 'typecheck:' pattern", () => {
    const result = parseClaim("typecheck: exit 0, no errors");
    expect(result).not.toBeNull();
    expect(result!.claim).toContain("exit 0");
  });

  it("parseClaim returns null for no match", () => {
    expect(parseClaim("I looked at the code and it seems fine")).toBeNull();
  });

  it("parseClaim includes evidence context", () => {
    const output = "Some preamble\nVerified: schema matches\nLine 3 detail\nLine 4";
    const result = parseClaim(output);
    expect(result).not.toBeNull();
    expect(result!.evidence).toContain("Verified: schema matches");
    expect(result!.evidence).toContain("Line 3");
  });

  it("createRecord builds a well-formed record", () => {
    const r = createRecord("db-verify", "schema ok", "evidence text");
    expect(r.agent).toBe("db-verify");
    expect(r.claim).toBe("schema ok");
    expect(r.evidence).toBe("evidence text");
    expect(typeof r.timestamp).toBe("number");
  });
});

describe("store", () => {
  it("readEvidence returns [] for missing file", async () => {
    expect(await readEvidence(join(projectDir, "nope.jsonl"))).toEqual([]);
  });

  it("appendEvidence + readEvidence round-trip", async () => {
    const path = join(projectDir, "evidence.jsonl");
    const r1: EvidenceRecord = { agent: "a", claim: "x", evidence: "y", timestamp: 1 };
    const r2: EvidenceRecord = { agent: "b", claim: "z", evidence: "w", timestamp: 2 };
    await appendEvidence(path, r1);
    await appendEvidence(path, r2);
    const result = await readEvidence(path);
    expect(result.length).toBe(2);
    expect(result[0]).toEqual(r1);
    expect(result[1]).toEqual(r2);
  });
});

describe("EvidenceCapture", () => {
  it("capture() persists evidence from recognized agents", async () => {
    const cap = createEvidenceCapture(projectDir);
    const record = await cap.capture(
      "change-verifier",
      "All callsites checked.\nVerified: no stale references found\nDone.",
    );
    expect(record).not.toBeNull();
    expect(record!.agent).toBe("change-verifier");
    expect(record!.claim).toContain("no stale references");

    const all = await cap.getAll();
    expect(all.length).toBe(1);
  });

  it("capture() returns null for non-evidence agents", async () => {
    const cap = createEvidenceCapture(projectDir);
    const record = await cap.capture("explore", "Verified: something");
    expect(record).toBeNull();

    const all = await cap.getAll();
    expect(all.length).toBe(0);
  });

  it("capture() returns null when no claim pattern matches", async () => {
    const cap = createEvidenceCapture(projectDir);
    const record = await cap.capture("db-verify", "looked at the data, seems ok");
    expect(record).toBeNull();
  });

  it("hasEvidence() finds matching records", async () => {
    const cap = createEvidenceCapture(projectDir);
    await cap.capture("ui-verify", "Verified: button is reachable in viewport");

    expect(await cap.hasEvidence("button is reachable")).toBe(true);
    expect(await cap.hasEvidence("something completely different")).toBe(false);
  });

  it("hasEvidence() is case-insensitive", async () => {
    const cap = createEvidenceCapture(projectDir);
    await cap.capture("db-verify", "Verified: SCHEMA matches");

    expect(await cap.hasEvidence("schema matches")).toBe(true);
  });

  it("getAll() returns empty when no evidence file exists", async () => {
    const cap = createEvidenceCapture(projectDir);
    expect(await cap.getAll()).toEqual([]);
  });
});
