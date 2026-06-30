import type { IntentRouter, IntentMatch, SkillVector, EmbeddingProvider } from "./types.ts";
import { cosineSimilarity, contentHash } from "./similarity.ts";
import { readCache, writeCache, indexBySkill } from "./store.ts";
import { createProvider as createEmbedProvider } from "../../rag-feedback/src/index.ts";

const CACHE_FILE = ".harness-cache/intent-vectors.json";
const DEFAULT_THRESHOLD = 0.75;

export function createRouter(
  projectDir: string,
  provider?: EmbeddingProvider,
  threshold: number = DEFAULT_THRESHOLD,
): IntentRouter {
  const embed = provider ?? createEmbedProvider();
  const cachePath = `${projectDir}/${CACHE_FILE}`;

  async function extractSkillMeta(
    filePath: string,
  ): Promise<{ name: string; description: string } | null> {
    const text = await Bun.file(filePath).text();

    // Extract YAML frontmatter (between --- markers)
    const fmMatch = text.match(/^---\n([\s\S]*?)\n---/);
    if (!fmMatch) return null;
    const fm = fmMatch[1];

    // Parse name and description from frontmatter (simple regex, not full YAML)
    const nameMatch = fm.match(/^name:\s*(.+)$/m);
    const descMatch = fm.match(/^description:\s*(.+)$/m);
    // Description might be multi-line (| or >) — for simplicity, take first line
    const name = nameMatch?.[1]?.trim().replace(/^["']|["']$/g, "");
    const description = descMatch?.[1]?.trim().replace(/^["']|["']$/g, "");

    if (!name || !description) return null;
    return { name, description };
  }

  return {
    async index(skillsDir: string): Promise<void> {
      const cached = indexBySkill(await readCache(cachePath));
      const next: SkillVector[] = [];

      // Find all SKILL.md files in subdirectories
      const proc = Bun.spawn(
        ["bash", "-c", `find "${skillsDir}" -name 'SKILL.md' -o -name 'skill.md' -type f | sort`],
        { stdout: "pipe", stderr: "pipe" },
      );
      const exitCode = await proc.exited;
      if (exitCode !== 0) return;

      const stdout = await new Response(proc.stdout).text();
      const files = stdout.trim().split("\n").filter(Boolean);
      if (files.length === 0) return;

      const toEmbed: { skill: string; description: string }[] = [];
      for (const f of files) {
        const meta = await extractSkillMeta(f);
        if (!meta) continue;

        const hash = contentHash(meta.description);
        const existing = cached.get(meta.name);

        if (existing && existing.hash === hash) {
          next.push(existing);
        } else {
          toEmbed.push({ skill: meta.name, description: meta.description });
        }
      }

      if (toEmbed.length > 0) {
        const embeddings = await embed.embedBatch(toEmbed.map((e) => e.description));
        for (let i = 0; i < toEmbed.length; i++) {
          next.push({
            skill: toEmbed[i].skill,
            description: toEmbed[i].description,
            embedding: embeddings[i],
            hash: contentHash(toEmbed[i].description),
          });
        }
      }

      await writeCache(cachePath, next);
    },

    async classify(message: string): Promise<IntentMatch | null> {
      const entries = await readCache(cachePath);
      if (entries.length === 0) return null;

      const qVec = await embed.embed(message);
      let best: IntentMatch | null = null;

      for (const e of entries) {
        const sim = cosineSimilarity(qVec, e.embedding);
        if (sim >= threshold && (!best || sim > best.similarity)) {
          best = { skill: e.skill, description: e.description, similarity: sim };
        }
      }

      return best;
    },
  };
}

export { createEmbedProvider as createProvider };
