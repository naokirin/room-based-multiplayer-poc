---
name: rails-development
description: Implements Rails features following conventions: routing, controllers, models, migrations, and views. Use when adding or changing CRUD, associations, validations, migrations, or request/response flow in a Ruby on Rails app.
---

# Rails Development

## When to Use

- Adding or modifying resources (routes, controllers, models, views).
- Writing or changing migrations, validations, associations, scopes.
- Implementing API or HTML endpoints and form/JSON handling.

## Workflow

1. Follow the project's Ruby/Rails style rules (`.cursor/rules/` .mdc files or CLAUDE.md instructions) for all generated code.
2. **Routing**: Use `namespace` for admin/API grouping. Run `bin/rails routes` after changes to verify.
3. **Controllers**: Use strong parameters. Prefer `before_action` with lexical scope.
4. **Models**: When adding associations or validations, run the relevant specs or tests immediately.
5. **Migrations**: Do not rely on application-level defaults when the DB can enforce them. Run `bin/rails db:migrate:status` after migration.
6. **Views**: Prefer partials and helpers over inline logic. Use route/path helpers instead of hard-coded URLs.

## Quick Checks

- `bin/rails routes` — verify routing after changes.
- `bin/rails db:migrate:status` — ensure migrations are applied.
- `db:schema:load` — ensure schema is loadable for a fresh DB.
- Run the relevant specs or tests after changing validations or associations.
