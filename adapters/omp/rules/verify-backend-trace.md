---
description: Force a real trace when editing backend/adapter/service code — auto-fires
condition: ["**/adapters/**", "**/services/**", "**/api/**", "**/*.py"]
interruptMode: prose-only
---
Backend / adapter / service code was edited. Before claiming "works / done"
(strong-guard):
- LLM / external-API adapter = one real API round-trip (quote the real request →
  real response body). A stubbed/synthetic response = "static OK, dynamic
  unverified".
- DB change = a real query (existence / type / count), never inferred from code.
- Dev-server claim = `curl` 200 + body / confirm the port is bound.
- "200 OK" / a fake fixture is not evidence. Route deep verification to `db-verify`
  / `security-engineer` / `change-verifier`.
