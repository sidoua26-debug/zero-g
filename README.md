# zero-g

A lightweight, reproducible Antigravity operating standard, custom skill set, and pinned dependency lockfile.

## Quick Start

1. Clone zero-g to your local machine:
   ```bash
   git clone https://github.com/sidoua26-debug/zero-g.git ~/.zero-g
   cd ~/.zero-g
   ```

2. Run the installer (dry-run by default):
   ```bash
   ./install.sh
   ```

3. Review the planned changes and apply:
   ```bash
   ./install.sh --apply
   ```
   To keep your existing `~/.gemini/GEMINI.md` and only install skills, pass `--no-rules`:
   ```bash
   ./install.sh --apply --no-rules
   ```

4. Restart your Antigravity IDE or start a new conversation turn.

On Windows PowerShell:
```powershell
.\install.ps1 -Apply
# Or without updating rules:
.\install.ps1 -Apply -NoRules
```

## Safety & No Silent Overwrites

- **Marker Files**: Every skill installed by zero-g contains a `.zero-g-managed` marker file.
- **Automatic Backups**: Before writing a skill over an existing folder lacking this marker, the installer moves the unmanaged folder safely to `~/.gemini/antigravity/skills-archive/backups/<name>.bak-<date>` (outside of discovery paths).
- **Rule Backups**: `~/.gemini/GEMINI.md` is backed up with timestamp suffix `.bak-<date>` before being updated (unless `--no-rules` is passed).

## What's Inside

- **Operating Rules (`rules/GEMINI.md`)**: A compact, single-source CORE operating rule set enforcing verification gates, proportional effort tiers, and safe tool use.
- **Custom Skills (`skills/`)**:
  - `plan` (*stub, written from a description*): Structured planning and design interview. Relies on `brainstorming` / `interview-me` and `writing-plans`.
  - `fix` (*stub, written from a description*): Root-cause isolation and minimal-diff fixes. Relies on `systematic-debugging` and `impact-map`.
  - `audit` (*stub, written from a description*): Subagent code and security reviews. Relies on `code-review-and-quality`, `security-and-hardening`, and `sweep`.
  - `ship` (*stub, written from a description*): Automated release gating and gap declarations. Relies on `verify` and `audit`.
  - `verify` (*stub, written from a description*): Six-step verification pipeline (typecheck, lint, reachability, seams). Relies on `invoke_subagent` and `grep_search`.
  - `impact-map` (*stub, written from a description*): Blast-radius and caller-tracing gate.
  - `sweep` (*stub, written from a description*): Codebase-wide scanner for swallowed exceptions and bug classes.
  - `session-handoff` (*stub, written by the repo author*): Structured multi-session context distillation into `handoff.md`.
  - `sync` (*stub, written by the repo author*): Repository synchronization skill invocable via `/sync`.
- **Templates (`templates/`)**: Baseline `.antigravityignore`, `project-commands.md` placeholder, and `MISTAKES.md` learning log template.
- **Third-Party Dependency Lockfile (`skills.lock.json`)**: Pins 50 external skills to exact, immutable git commit SHAs.

## Updating

Update zero-g at any time from within an Antigravity chat:
```text
/sync
```
Or run from the terminal:
```bash
./sync.sh pull
```

To sync local improvements back upstream:
```bash
./sync.sh push
```

> [!NOTE]
> On each new machine, set the repo-local noreply email before running `sync push`:
> ```bash
> git config user.email "<id>+<username>@users.noreply.github.com"
> ```
> *(Find your GitHub account id with `gh api user --jq .id`)*


## Uninstalling

Every modified or replaced file is backed up before installation with the pattern `<name>.bak-<date>`. To uninstall or revert, restore the respective `.bak-*` files from `~/.gemini/` and remove symlinks in `~/.gemini/config/skills/`.

## Credits & Upstream Repositories

- [obra/superpowers](https://github.com/obra/superpowers)
- [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail)
- [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills)
- [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill)
- [Egonex-AI/Understand-Anything](https://github.com/Egonex-AI/Understand-Anything)
- [ayghri/i-have-adhd](https://github.com/ayghri/i-have-adhd)


## License

MIT License. See [LICENSE](LICENSE) for details.
