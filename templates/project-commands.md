TEMPLATE - commands below are placeholders, not discovered.

# Project Commands

Discovered standard project commands:

| Task | Command | Notes |
| :--- | :--- | :--- |
| **Typecheck** | `npx tsc --noEmit` / `mypy .` / `cargo check` | Run project-specific typechecker |
| **Lint / Format** | `npm run lint -- --fix` / `ruff check --fix .` | Run auto-formatting and linting |
| **Seam Tests** | `npm test` / `pytest` / `cargo test` | Target public interfaces and seams |
| **Build** | `npm run build` / `cargo build` | Full production build check |
| **Reachability** | `git grep "<symbol>"` | Grep entry points and routes |
