---
name: ship
description: "/ship - verify pipeline, audit gates, SHIP/NO-SHIP verdict, gap declaration."
metadata:
  status: stub
---

# ship (stub)

1. Run full `verify` pipeline (typecheck, lint, reachability, unit tests).
2. Run the `audit` skill for security and quality gates.
3. Output release verdict: SHIP or NO-SHIP.
4. Provide verification gate table: Gate | Pass/Fail | Evidence.
5. Declare the Gap Round (list everything NOT verified).
