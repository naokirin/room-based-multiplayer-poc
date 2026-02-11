---
name: rails-refactor
description: Refactors Rails code for clarity and style without changing behavior. Use when simplifying controllers, models, queries, or specs; extracting services; or applying Ruby/Rails/RSpec style rules.
user-invocable: false
---

# Rails Refactor

## When to Use

- Simplifying controllers (moving logic to models or services).
- Replacing deprecated or verbose patterns (e.g. old validations, raw SQL, N+1).
- Applying Ruby/Rails/RSpec style (see project rules in `.cursor/rules/` or CLAUDE.md).
- Extracting service objects or form objects.

## Principles

1. **Behavior first**: Refactors must not change observable behavior. Rely on existing tests; add or run specs if coverage is missing.
2. **Incremental**: Prefer small, reviewable steps (e.g. rename, extract method, then move).
3. **Conventions**: After refactor, code should align with the project's Ruby/Rails/RSpec style rules (`.cursor/rules/` or CLAUDE.md).

## Verification

- Run the relevant test suite: `bundle exec rspec` or `bin/rails test`.
- Run RuboCop if the project uses it: `bundle exec rubocop [path]`.
- Confirm no new warnings or failures were introduced.
