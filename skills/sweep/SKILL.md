---
name: sweep
description: "Whole-codebase sweep for bug classes and silent failures."
metadata:
  status: stub
---

# sweep (stub)

Whole-codebase sweep for bug classes and silent failures using `grep_search`:

1. **Bug Classes**:
   - Swallowed errors and empty catch/except blocks.
   - Swallowed `CancellationException`.
   - Unsafe silent fallbacks (e.g. `catch { return null; }`).
   - Resource and connection leaks (unclosed streams, sockets, handles).
   - Null-safety violations and unhandled nullable access.
   - Stale references and dead code.
2. **Reporting**: Report only filtered, actionable hits with `file:line` citations and remediation advice.
