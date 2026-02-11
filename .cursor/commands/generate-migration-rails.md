# Generate Migration

1. Confirm the desired change (add/remove tables, add/remove/change columns, indexes, foreign keys, etc.).
2. Propose or run the appropriate `bin/rails generate migration` command.
   - Example: `bin/rails g migration AddNameToUsers name:string`
   - Example: `bin/rails g migration CreateProducts name:string price:decimal`
3. When editing the generated migration:
   - Prefer the `change` method (avoid `up`/`down` when reversible).
   - Add `default` and `null: false` for boolean columns.
   - Add `foreign_key: true` to `t.references` / `t.belongs_to`.
   - Use `_id` suffix for columns referencing another table (e.g. `user_id`).
   - Add indexes for columns used in queries and lookups (`add_index`). Use `unique: true` for uniqueness constraints.
   - Example: `add_index :users, :email, unique: true`
4. Tell the user to run `bin/rails db:migrate`. For rollback, `bin/rails db:rollback`.
5. If the project keeps schema in the repo, remind them to commit `db/schema.rb` (or `structure.sql`).

If the user described a change (e.g. "add X", "remove Y column"), tailor the migration to that.
