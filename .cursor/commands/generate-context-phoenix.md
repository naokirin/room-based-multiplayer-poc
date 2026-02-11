# Generate Phoenix Context (scaffold)

Generate a new Phoenix context with schema, migrations, and CRUD using the official generators.

1. Use `mix phx.gen.context ContextName ResourceName resource_name table_name field:type ...` for a context with schema and migrations (e.g. `mix phx.gen.context Accounts User users email:string`).
2. Use `mix phx.gen.html` for a full HTML scaffold (context + controller + views + templates + tests) when the user wants a full CRUD UI.
3. Use `mix phx.gen.live` for a LiveView-based CRUD scaffold when the user wants LiveView instead of dead views.
4. After generation, run `mix ecto.migrate` (or instruct the user to do so in dev). Run `mix test` to verify generated tests pass.
5. Do not edit existing migration files; add new migrations for further schema changes.
