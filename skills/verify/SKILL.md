---
name: verify
description: "After code changes: run the verification pipeline."
metadata:
  status: stub
---

# verify (stub)

After code changes, execute the verification pipeline in strict order:

1. **Typecheck**: Run project typecheck. After 2 failures, fix surgically with no architectural drift.
2. **Lint / Format**: Run project linter/formatter auto-fix.
3. **Reachability**: Grep for callers from production entry points or routes. Zero callers = unwired, blocked.
4. **Seam Unit Tests**: Run targeted unit tests at public interfaces/seams.
5. **Security & Sweep Escalation**: If Tier 3 or auth/storage/encryption/async error handling is touched, use `invoke_subagent` for security review and sweep.
6. **Gap Declaration**: List every check, boundary, or environment not verified before declaring completion.

*Command discovery*: Read exact commands from `project-commands.md`.
