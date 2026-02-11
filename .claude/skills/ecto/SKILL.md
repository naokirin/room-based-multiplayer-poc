---
name: ecto
description: Ecto schemas, changesets, queries, and migrations. Use when working with the data layer, migrations, or repo.
user-invocable: false
---

# Ecto

## When to Use

- Adding or changing Ecto schemas and changesets.
- Writing or refactoring context functions that use the repo (get, insert, update, delete, queries).
- Creating or reviewing migrations.
- Optimizing queries (preload, join, avoid N+1).

## Principles

1. **Schemas**: In `lib/my_app/` under the context. Use `@primary_key`, `@foreign_key_type`, `@timestamps`; use `@enforce_keys` for required fields. Keep changeset functions in the schema module or context.
2. **Context API**: Expose functions like `get_user!(id)`, `create_user(attrs)`, `update_user(user, attrs)` that return `{:ok, struct}` / `{:error, changeset}` or raise for get!-style APIs. Use the repo only inside context (or dedicated query modules).
3. **Migrations**: Create with `mix ecto.gen.migration name`. **Do not edit migration files after they have been run in production.** Add new migrations for further schema changes.
4. **Queries**: Prefer `from` for readability; use preload or join to avoid N+1. For complex queries, consider a dedicated query module.
5. **Verification**: After schema or migration changes, run `mix ecto.migrate` (in dev) and `mix test`. Do not modify existing migrations.
