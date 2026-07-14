---
name: db-verify-checks
description: Use when verifying data-shape claims against a real store — MongoDB or a SQL store (SQLAlchemy / SQLite / Postgres) — before reporting any data-touching change done. Detects the store from repo config, then runs the canonical checks (existence count, type distribution, 10-row/doc sample, index or owner crosscheck) and emits a CONFIRMED / REFUTED / CANT-VERIFY verdict. Default target = local store; prod only on schema-change + explicit approval. Load when invoking db-verify, backend-architect Phase 2, change-verifier on backend changes, or any time a field/column shape claim must be proven. Triggers on DB check, $exists check, schema match, is it really in prod, field existence check.
---

# DB verification — detect store → measure → verdict

The largest failure pattern is **inferring DB shape from code**. Code says what SHOULD be there; only a query says what IS. This skill is the canonical replacement: prove or disprove a data-shape claim with a real query against the real store, **before** any data-touching change is reported done.

You are a fresh-context critic when you load this: you did NOT design the schema and you do NOT assume the code's shape is correct. **Falsify; do not edit.**

## Step 0 — DETECT the store first

Read the repo's own config / env to determine which store backs the change:

- `DATABASE_URL` (or equivalent) with `sqlite:///...` or `postgresql://...` / `postgres://...` ⇒ **SQL store**. A `mongodb://...` / `mongodb+srv://...` URI (often `MONGO_URI` / `MONGODB_URL`) ⇒ **Mongo store**.
- If absent, grep the backend for the actual client (`sqlalchemy` / `create_engine` / `pymongo` / `motor`) and its config module.
- Prefer the repository's own DB dependency over assuming a system CLI exists. Read the connection target from config — never hard-code a production host.

## Setup

1. From the invocation prompt, extract: (collection/table, field/column name(s), expected type, expected presence — required / optional / migrated).
2. If the repo defines an ownership SSOT (e.g. a collections/tables ownership doc), confirm the caller owns this collection/table. Wrong owner = a finding.
3. Load DB credentials from the repo env (read only — never write `.env` directly).
4. Test the connection with the repo's own client. Real prod hostnames in fixtures BANNED — use the env's actual host, never hardcode.
5. Default target = local store (dev default, e.g. `sqlite:///./*.db` or `mongodb://localhost:27017`). Touch a shared / production store only on schema-change + explicit approval, and only to READ.

## The checks (run every one — do not skip)

For each claimed field/column:

### Mongo idiom

1. **`$exists: true` count** — `db.<coll>.countDocuments({"<field>": {"$exists": true}})`. State the number and compare to total doc count. "every document has X" with `$exists` ratio <1.0 is a finding.
2. **`$type` distribution** — `db.<coll>.aggregate([{$group: {_id: {$type: "$<field>"}, count: {$sum: 1}}}])`. State each type + count. A "string" field with a `null` / `missing` bucket is a finding — code must use `doc.get("<field>")`, never `doc["<field>"]`.
3. **Sample 10 real documents** — `db.<coll>.find({"<field>": {"$exists": true}}).limit(10)`. Dump them; confirm the value shape matches what the code expects.
4. **Index coverage** (write-path changes only) — `db.<coll>.getIndexes()`. A new filter on `<field>` that no index covers = perf-risk finding.
5. **Owner crosscheck** — confirm the changed code lives in the owner defined by the ownership SSOT. Wrong-owner write is a blocking finding.

### SQL idiom (SQLAlchemy / SQLite / Postgres)

1. **Column existence** — SQLite: `PRAGMA table_info(<table>)`; Postgres: `SELECT column_name, data_type, is_nullable FROM information_schema.columns WHERE table_name='<table>'`. The column must actually exist on the table. Absent = REFUTED.
2. **Population** — `SELECT COUNT(*) AS total, COUNT(<column>) AS populated FROM <table>`. Of N total rows, how many have it set (vs NULL)? A column present on 0 rows is not "present".
3. **Type** — from the info-schema / PRAGMA row, confirm the stored type matches what the code assumes (string vs number, array/JSON vs scalar, date vs string).
4. **Sample 10 real rows** — `SELECT * FROM <table> WHERE <column> IS NOT NULL LIMIT 10`. Confirm the value shape matches code expectations.
5. **Index / owner crosscheck** — for a new filter on `<column>` with no covering index, flag perf risk; if the repo defines table ownership, confirm the change lives in the owner.

Prefer the repository's SQLAlchemy inspection (`sqlalchemy.inspect(engine)`) or its own read-only client over assuming a system `psql` / `sqlite3` CLI exists.

## Verdict rules — pick exactly 1 (no hedging)

- **CONFIRMED** — the claim holds. Back it with the real counts (existence ratio, populated/total) and, where the store is local read/measure, a sample of ≥ 5% of the row/doc count AND N ≥ 30 (provisional floor: `5%` alone is broken at both poles, so combine an absolute `N ≥ 30` floor).
- **REFUTED** — a code/schema mismatch found. Give `file:line` + the failing query result + the counts.
- **CANT-VERIFY** — cannot connect / no access / prod not approved. First-class; say so plainly, do NOT guess and do NOT report "CONFIRMED (conditional)".

**Scope caution**: read/measure default target is local and local results are first-class "CONFIRMED" for read/measure. BUT **generalizing local shape to prod structure** is a different claim — dev/local N rows vs prod's millions of rows may have different distributions. "concluding prod structure from local-only results" is the failure mode this skill exists to prevent. local is sufficient for read/measure, NOT for prod-structure generalization → CANT-VERIFY for the prod claim.

## Constraints

- Real DB only — no fixtures, no mocks. Cannot connect → "CANT-VERIFY", not "CONFIRMED".
- "200 OK on a test call" is not proof — only existence counts / type distribution / real-row (or -doc) samples count.
- Do not edit code or schema. Verify and report only.
- Unsafe key access is a finding — Mongo `doc["key"]` → propose `doc.get("key")`; a SQL column assumed present without a NULL/absence guard → flag it.
- Never report "fake key limitation, 0 feature errors" — that is "CANT-VERIFY", not "CONFIRMED".
- Inferring shape from code instead of from the store is the failure mode this skill exists to prevent — never do it.
- **Citation-truth**: any file/contract you cite must be confirmed to exist via grep/read before it grounds a claim; a green test alone ≠ a verdict.

## Output (BLUF header first)

- **Conclusion**: CONFIRMED / REFUTED / CANT-VERIFY — exactly one.
- **Count table** — collection·table / field·column / existence(count·ratio) / total / type distribution. Every row has the real query output, not a summary.
- **Sample** — 3–10 real docs/rows (PII redacted if any).
- **Mismatches / not connected** — every finding with `file:line` of the code that contradicts the data + the failing query result.
- **Next actions** — a concrete fix per finding.
