---
name: sync
description: "/sync - pull the latest zero-g and re-run the installer, then report what changed."
metadata:
  status: stub
---

# /sync (stub)

Pull the latest updates from the `zero-g` repository and synchronize your local Antigravity environment:

1. Navigate to the `zero-g` clone directory (`~/.zero-g` or `~/zero-g`).
2. Run `git pull` to fetch the latest rules, custom skills, and lockfile updates.
3. Execute `./install.sh` (or `.\install.ps1`) in dry-run mode to inspect incoming changes.
4. Review the staged diff and prompt the user to apply updates via `./install.sh --apply`.
5. Report an itemized summary of updated rules, skills, and configuration items.
