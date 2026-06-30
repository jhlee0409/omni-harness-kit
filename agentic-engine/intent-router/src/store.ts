import type { SkillVector } from "./types.ts";
import { rename, mkdir } from "node:fs/promises";
import { dirname } from "node:path";

export async function readCache(path: string): Promise<SkillVector[]> {
  try {
    const file = Bun.file(path);
    if (!(await file.exists())) return [];
    return (await file.json()) as SkillVector[];
  } catch {
    return [];
  }
}

export async function writeCache(path: string, entries: SkillVector[]): Promise<void> {
  try {
    const dir = dirname(path);
    await mkdir(dir, { recursive: true });
    const tmp = path + ".tmp";
    await Bun.write(tmp, JSON.stringify(entries));
    await rename(tmp, path);
  } catch {
    // fail-open
  }
}

export function indexBySkill(entries: SkillVector[]): Map<string, SkillVector> {
  const m = new Map<string, SkillVector>();
  for (const e of entries) m.set(e.skill, e);
  return m;
}
