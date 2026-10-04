---
name: audit
description: "/audit - code review, security review, codebase sweep via invoke_subagent."
metadata:
  status: stub
---

# audit (stub)

1. Invoke subagent for multi-axis code review (`code-review-and-quality`).
2. Invoke subagent for security review (`security-and-hardening`).
3. Run `sweep` for silent failures and bug classes.
4. Produce prioritized findings table (P1/P2/P3 with file:line).
