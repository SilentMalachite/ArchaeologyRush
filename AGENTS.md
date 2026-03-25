# ArchaeologyRush - AGENTS.md

## Project Overview

Archaeological excavation simulation game built with Elixir, Phoenix LiveView, and Elixir Desktop.
The user is an archaeology expert with decades of field experience. All domain-specific logic must come from the user — never invent archaeological specifications.

## Tech Stack

- **Language:** Elixir ~> 1.19
- **Web Framework:** Phoenix ~> 1.8 (Verified Routes, HEEx templates)
- **UI:** Phoenix LiveView ~> 1.1
- **Desktop:** Elixir Desktop ~> 1.5
- **Database:** Ecto + SQLite3 (ecto_sqlite3)
- **HTTP Server:** Bandit ~> 1.8
- **Image Processing:** vix ~> 0.34 (libvips bindings)
- **Frontend:** Tailwind CSS, ESBuild, Heroicons

## Commands

```bash
# Install dependencies + setup DB
mix setup

# Run tests
mix test

# Quality check (format + compile strict + test)
mix quality

# CLI demo
mix run scripts/demo_excavation.exs

# LiveView demo
mix run --no-halt

# Database
mix ecto.setup    # create + migrate
mix ecto.reset    # drop + recreate

# Static analysis (dev only)
mix credo
mix dialyzer
```

## Project Structure

```
lib/archaeology_rush/
  application.ex      # Supervision tree (:one_for_one)
  demo.ex             # CLI / LiveView demo output builder
  excavation.ex       # Use-case API and game_status/1
  repo.ex             # Ecto SQLite3 repository
  site_state.ex       # Core state transitions (dig/catalog/recover/end_turn)
  artifact.ex         # Artifact schema (name, layer, notes)
  archaeology_rush.ex # Main application module

lib/archaeology_rush_web.ex
  Endpoint            # Bandit-backed Phoenix endpoint
  Router              # Minimal router with DemoLive
  DemoLive            # LiveView demo screen

test/
  support/
    repo_case.ex      # DB test helpers (reset_table!, insert_row!, etc.)
  *_test.exs

priv/repo/migrations/ # Ecto migrations
config/
  config.exs          # Base config
  dev.exs             # Dev: debug logging, live reload
  test.exs            # Test: warning-level logging, repo manual start
  runtime.exs         # Repo/Endpoint runtime config
```

## AI Agent Directives (from AGENT.md)

1. **Conclusion first:** State the logical conclusion / implementation overview at the top of every response.
2. **Max 3 files per chunk:** Never modify or create more than 3 files in a single proposal. Break larger changes into incremental steps and wait for approval.
3. **No Mermaid:** Use ASCII art or Unicode box-drawing characters for diagrams — Mermaid is strictly forbidden.
4. **Respect domain expertise:** Never guess or invent archaeological logic (stratigraphy, artifact classification, excavation processes). Always ask the user for specifications.
5. **Reply in Japanese.**

## Quality Standards

- All code must pass `mix credo` and `mix dialyxir` without warnings.
- Write ExUnit tests alongside every logic implementation (TDD).
- Add regression tests when fixing bugs.
- Use typespecs (`@spec`) on all public functions.
- Use changeset validation; never trust raw input.
- SQL helpers must use placeholders, not string interpolation.

## Testing Patterns

- `ArchaeologyRush.RepoCase` provides: `reset_table!/2`, `insert_row!/3`, `insert_rows!/3`, `clear_table!/1`, `fetch_all!/1`, `fetch_one!/1`, `count!/1`, `table_exists?/1`
- Test config sets `pool_size: 1` and disables repo auto-start; `RepoCase` starts it manually.
- `elixirc_paths` includes `test/support` in `:test` env.

## Key Constraints

- Archaeological domain specifications must come from the user — never invented by the AI.
- Staged development: implement infrastructure first, then domain logic only after receiving user specs.
- Keep supervision tree minimal; add children incrementally as features are built.
- Current web UI is intentionally minimal and read-only; interactive controls are the next UI step.
