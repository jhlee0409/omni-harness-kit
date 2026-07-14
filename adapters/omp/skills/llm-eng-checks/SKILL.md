---
name: llm-eng-checks
description: Use when building or hardening an LLM feature — prompt design, RAG, eval harness, model/provider selection, guardrails, and token/cost budgeting — with omp-native tools (bash for real API round-trips, read/grep for the repo's own client, no vendor-plugin dependency, provider-agnostic). PRIME RULE — no LLM feature is "working" until ONE real API round-trip is shown (real prompt in, real output quoted, provider+model named); a stubbed/synthetic response is "static OK, dynamic unverified", never done. Load when writing an LLM call, adding retrieval, standing up an eval, choosing a model, or reporting an LLM change done. Triggers on LLM, prompt design, RAG, eval harness, hallucination, model selection, structured output, prompt optimization, token cost.
---

# LLM engineering — design → round-trip → measure → verdict

The dominant failure pattern is **claiming an LLM feature works from the code path alone**. Code shows the prompt is assembled and the SDK is called; only a real round-trip shows the model actually returns what the contract promises. This skill is provider-agnostic — detect the repo's own client (a hosted provider SDK / a local inference server / an internal gateway) and drive *that*, never a vendor CLI you assume exists.

## PRIME RULE — one real round-trip or it is not done

Before reporting any LLM change done you MUST show ONE real call:
- Real prompt in (quote the actual assembled prompt, not a paraphrase).
- Real output out (quote the model's actual response, not a mock).
- Provider + model named (`<provider>/<model>`) + token counts.

Drive it with the repo's own client via `bash` (its Python/JS entrypoint) — read config from the repo env, never hardcode a key. A stub / fixture / synthetic response = **"static OK, dynamic unverified"**, never "done". "200 OK" is not proof — the *content* must satisfy the output contract.

## 1. Prompt design

- **Contract, not vibes.** Every prompt names: role, task, hard constraints (negative ones too), and an explicit output contract. If the output is consumed by code, the contract is a **schema**, not prose.
- **Few-shot earns its tokens or it is cut.** Add exemplars only when a zero-shot round-trip fails the contract; measure the delta (pass-rate before/after). Never carry examples "just in case" — they inflate every request forever.
- **Structured output.** Prefer provider JSON-schema / tool-calling for machine-consumed output. Then **validate every response against the schema** (jsonschema / pydantic / zod — the repo's own). An unvalidated `json.loads()` is a latent crash: quote a round-trip where the model returns malformed/extra fields and show the validator catching it.
- **Determinism where it matters.** Pin `temperature=0` (or the provider's floor) for extraction/classification; reserve higher temp for generative surfaces. State which and why.

## 2. RAG

- **Chunking is a decision, not a default.** State size + overlap + boundary (semantic / heading / fixed-token) and why it fits the corpus. Dumping 512-token fixed windows over structured docs is a finding.
- **Embedding choice is measured.** Name the model + dimension; justify against cost and the domain (code vs prose vs multilingual — multilingual corpora need a multilingual-capable embedder).
- **Retrieval eval is mandatory.** Build a labeled set (query → known-relevant chunk ids) and report **recall@k** (and MRR/nDCG if ranking matters). "retrieval works" without recall@k on a labeled set = unmeasured.
- **Rerank when recall@k is high but precision@1 is low** — a cross-encoder reranker over the top-N. Show the metric moving, not just that a reranker was added.
- **Context assembly + citation.** Assemble retrieved chunks with source ids; require the model to cite which chunk grounds each claim. An answer with no traceable source chunk is treated as ungrounded (see §3).

## 3. Eval harness

- **Golden set first.** A fixed set of (input → expected/acceptable output) pairs, committed. Every prompt or model change re-runs it → **regression gate**. No golden set = every change is a guess.
- **LLM-as-judge with an explicit rubric.** When output is open-ended, judge with a *written* rubric (per-criterion pass/fail), not a bare 1–10. Use a **different/stronger model** as judge than the one under test where possible; spot-check judge calls against human labels so the judge itself is calibrated.
- **Hallucination = claim-grounding check.** Decompose the answer into atomic claims; for each, verify it is entailed by the provided context (RAG chunks) or a trusted source. Report the ungrounded-claim rate. A generative feature with no grounding check is unverified.
- **Report deltas, not absolutes.** On any prompt/model swap: golden-set pass-rate before → after, plus token/cost delta. A quality win that doubles cost is a tradeoff to surface, not hide.

## 4. Model / provider selection

Decide on a **cost × latency × quality** table, not habit:

| axis | small model | large model |
|---|---|---|
| cost/req | low | high (often 10–30×) |
| latency (p50/p95) | low | high |
| quality on task | measure on golden set | measure on golden set |
| when | extraction, classification, routing, high-volume, tight latency | reasoning, long-context synthesis, judge role, low-volume high-stakes |

- Fill the quality column with **golden-set numbers**, not reputation. A small model that passes the golden set is the right choice — do not reach for the large model by default.
- Consider a **router / cascade**: small model first, escalate to large only on low confidence or validation failure. Measure the escalation rate.

## 5. Guardrails

- **Injection defense.** Untrusted input (user text, retrieved docs, tool output) is data, never instructions — keep it in a clearly delimited channel, and never let retrieved content override the system contract. Probe with an injection attempt in a real round-trip and show it held.
- **Output validation.** Everything §1's schema said — enforced at runtime with a reject/repair/retry path. Never ship raw model output straight into a downstream system.
- **Refusal handling.** Distinguish a legitimate refusal from a failure; have a defined fallback (retry, escalate, degrade) rather than surfacing a raw refusal to the user.
- **PII.** Do not send PII to a provider without approval; redact on the way in, and scan output for leaked PII on the way out. In fixtures/logs, redact — real PII in a test payload is BANNED.

## 6. Cost / token budgeting

- **Measure per request.** Report input+output tokens/req and $/req from the provider's real usage fields (not an estimate). Multiply by expected volume for a monthly figure before shipping.
- **Cache where safe.** Provider prompt-caching for a stable system prefix; an app-level cache for idempotent (prompt → output) pairs. Never cache anything with per-user PII in the key/value. State the expected hit-rate and the invalidation trigger.
- **Trim the prompt.** The cheapest token is the one not sent — cut dead few-shot, oversized retrieved context, and redundant instructions; re-run the golden set to prove quality held after trimming.

## Verdict rules — pick exactly 1 (no hedging)

- **WORKING** — a real round-trip shown (§PRIME RULE: prompt + output quoted, provider/model + tokens named) AND the output satisfies its contract/schema AND, for a change, the golden set did not regress.
- **NOT-WORKING** — round-trip failed the contract (malformed output, ungrounded claims, regression). Give the quoted output + the failing check + `file:line` of the prompt/assembly at fault.
- **static OK, dynamic unverified** — code is correct by inspection but no real round-trip was run (no key, no approval, provider down). First-class; say so plainly. NEVER upgrade to "WORKING" on inspection alone.

## Constraints

- Real API only for the WORKING verdict — no mock/fixture/synthetic response counts as dynamic proof.
- Provider-agnostic: detect and drive the repo's own client + config; never assume a specific vendor CLI or hardcode a model/key.
- Cost-aware: estimate $/req before a batch/eval run; "just once" means one call.
- Every metric claim (recall@k, pass-rate, tokens, $) is a measured number with the command that produced it, or it is "unmeasured".
- Do not silently swap the model/provider a change was specified against — that changes the contract.
- Keep user-facing copy in the product's language; internal surfaces (code/prompts/schemas) in English.

## Output (BLUF header first)

- **Conclusion**: WORKING / NOT-WORKING / static OK·dynamic unverified — exactly one.
- **Round-trip** — provider/model, actual prompt (gist + key lines), actual output (quoted), input/output tokens.
- **Contract check** — schema/contract pass/fail + validator output. (For RAG: recall@k, hallucination rate.)
- **Cost** — tokens/req, $/req, projected monthly cost at expected volume.
- **Mismatches / unverified** — each finding with `file:line` + the failing check result.
- **Next actions** — a concrete fix per finding.
