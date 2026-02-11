# Run Format

Format Elixir/Phoenix source and test files with the project formatter.

1. Run `mix format` to format all configured files (typically `lib/**/*.ex` and `test/**/*.exs` per `.formatter.exs`).
2. If the user specified a path, run `mix format path/to/file.ex` (or `.exs`) for that file only.
3. Ensure no formatting-related changes are left unapplied; report any formatter errors.
