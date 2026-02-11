---
name: exunit-testing
description: Adding or fixing ExUnit tests (unit, ConnCase, DataCase, LiveView). Use when writing tests, fixing failing tests, or improving test structure and coverage.
user-invocable: false
---

# ExUnit Testing

## When to Use

- Adding tests for contexts, controllers, LiveView, or other modules (unit or integration).
- Fixing failing tests (determine whether the failure is in implementation or test; fix minimally).
- Improving test structure (describe, setup, tags) or readability.

## Principles

1. **Layout**: Mirror source layout: `test/my_app/user_test.exs` for `lib/my_app/user.ex`; `test/my_app_web/live/dashboard_live_test.exs` for LiveView. Use `describe` and `test "description"` with clear descriptions.
2. **ConnCase**: For HTTP; use `get`, `post`, etc. and assert on response and assigns. Set up auth/session in setup when needed.
3. **DataCase**: For repo and context tests; use Repo and context functions. Use setup for fixtures; prefer factories or explicit inserts.
4. **LiveView tests**: Use Phoenix.LiveViewTest (render, follow_redirect, element, etc.). Test mount, handle_params, and key handle_events; assert on rendered content and navigation.
5. **Assertions**: Prefer `assert`, `assert_raise`, `refute`. Use pattern matching in assertions when the shape is important (`assert {:ok, x} = ...`). Keep expected values explicit.
6. **Setup**: Use `setup` or `setup_all` for shared context; use `@tag` for expensive or integration tests; run with `mix test --only tag` when needed.
7. **Verification**: Run `mix test` (optionally with path or filter) to verify. Do not change behaviour beyond what is needed to fix the failure.
