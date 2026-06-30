import type { VectorEntry } from "./types.ts";
import { rename, mkdir } from "node:fs/promises";
import { dirname } from "node:path";

/** Read the vector cache. Returns [] if missing/corrupt (fail-open). */
export async function readCache(path: string): Promise<VectorEntry[]> {
  try {
    const file = Bun.file(path);
    if (!(await file.exists())) return [];
    return (await file.json()) as VectorEntry[];
  } catch {
    return [];
  }
}

/** Write the vector cache atomically (temp + rename). */
export async function writeCache(path: string, entries: VectorEntry[]): Promise<void> {
  try {
    const dir = dirname(path);
    await mkdir(dir, { recursive: true });
    const tmp = path + ".tmp";
    await Bun.write(tmp, JSON.stringify(entries));
    await rename(tmp, path);
  } catch {
    // fail-open: cache write is best-effort
  }
}

/** Return cache entries keyed by id for O(1) lookup. */
export function indexById(entries: VectorEntry[]): Map<string, VectorEntry> {
  const m = new Map<string, VectorEntry>();
  for (const e of entries) m.set(e.id, e);
  return m;
}
