# Run Tests and Fix Failures

Run the Phoenix/Elixir test suite and fix any failures using the **phoenix-tester** agent.

- If the user specified a path, file, or tag, run tests for that scope (e.g. `mix test path/to/test_file_test.exs`, `mix test --only integration`) and prioritize fixing failures there.
- Otherwise run the full suite: `mix test`.
