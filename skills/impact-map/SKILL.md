---
name: impact-map
description: "Before changing a shared type, signature or symbol: trace callers (depth 1; core schemas depth 2) and tests, state the blast radius. More than 8 files = escalate to Tier 3."
metadata:
  status: stub
---

# impact-map (stub)

Before changing a shared type, signature, or symbol:

1. **Caller Tracing**:
   - General symbols: trace callers at depth 1.
   - Core schemas & data contracts: trace callers at depth 2.
2. **Test Tracing**: Identify all test files and assertions exercising this symbol.
3. **Blast Radius Statement**: State the exact blast radius: files affected, public API impact, risk level.
4. **Escalation Gate**: If blast radius exceeds 8 files, escalate task to Tier 3 immediately.
