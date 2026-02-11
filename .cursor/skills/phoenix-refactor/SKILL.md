---
name: phoenix-refactor
description: Refactoring Phoenix and Elixir code while preserving behaviour. Use when simplifying code, applying context boundaries, or improving structure without changing behaviour.
user-invocable: false
---

# Phoenix Refactor

## When to Use

- Moving logic from controllers or LiveView into context functions.
- Simplifying functions or replacing conditionals with pattern matching or `with`.
- Applying style or idiom rules (pipe, naming, module structure).
- Extracting components or context functions to reduce complexity.
- Improving error handling or boundaries without changing observable behaviour.

## Principles

1. **Preserve behaviour**: Do not change inputs/outputs or side effects. Rely on existing tests; run `mix test` after each logical step.
2. **Context boundaries**: When refactoring, ensure business logic ends up in contexts and web layer stays thin. Do not push web concerns (conn, socket, flash) into context.
3. **Small steps**: Prefer a sequence of small, testable refactors over one large change. Commit or checkpoint when tests pass.
4. **Idioms**: Prefer pipe where data flows through transformations; use `with` for multi-step success/failure; replace nested `if`/`case` with pattern matching in function heads where appropriate.
5. **Verification**: After refactor, run `mix test` and `mix credo` and confirm no new failures or warnings. Do not suppress Credo without justification.
