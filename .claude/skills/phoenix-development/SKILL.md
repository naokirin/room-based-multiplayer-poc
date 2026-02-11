---
name: phoenix-development
description: General Phoenix and Elixir development following context boundaries, style, and best practices. Use when writing or modifying Phoenix apps, contexts, controllers, LiveView, or Ecto.
user-invocable: false
---

# Phoenix Development

## When to Use

- Writing new Phoenix features (contexts, controllers, LiveView, components).
- Adding or changing Ecto schemas, changesets, or context functions.
- Adding routes, pipelines, or plugs.
- Designing or evolving public APIs (context functions, assigns, options).

## Principles

1. **Context boundaries**: Business logic in `lib/my_app/` (contexts); web layer in `lib/my_app_web/` thin and delegating to contexts. Controllers and LiveViews call context functions and handle HTTP/LiveView concerns only.
2. **Idioms**: Prefer pipe `|>`, pattern matching, and `with` for multi-step flows. Return `{:ok, result}` / `{:error, reason}` from context functions; use `raise` only for exceptional cases.
3. **Style**: Follow the project's Phoenix and Elixir rules (CLAUDE.md or `.cursor/rules/`). Use snake_case for functions and variables; PascalCase for modules. Follow phoenix-style, ecto-style, and liveview-style as applicable.
4. **Ecto**: Use schemas and changesets for data; keep queries in context or dedicated query modules. Do not edit migrations after they have been run in production.
5. **LiveView**: Keep state in assigns; delegate logic to context; use `send(self(), ...)` and `handle_info` for async work.

## Verification

- `mix compile` and `mix test`.
- `mix credo` when available (fix or allow with justification).
- `mix format` (or rely on the format hook).
