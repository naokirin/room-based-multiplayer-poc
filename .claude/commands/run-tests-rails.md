---
description: Run tests and fix failures (RSpec or Minitest)
context: fork
agent: rails-tester
argument-hint: "[file or directory]"
---

# Run Tests and Fix Failures

Run the project test suite and fix any failures.

## Instructions

1. Determine the test framework:
   - RSpec: `bundle exec rspec` (include path or file if the user specified a scope).
   - Minitest: `bin/rails test` or `bundle exec rake test`.
2. If the user specified files or directories, run tests for that scope first: `$ARGUMENTS`
3. Parse the output to identify failing examples or tests: assertion message, expected vs actual, and file:line.
4. Determine whether the failure is due to implementation or to the test itself; then apply a minimal fix to code or spec.
5. Re-run the affected tests to confirm they pass. If new failures appear, iterate.
6. Keep changes consistent with project style (Ruby/Rails/RSpec conventions in CLAUDE.md). Do not change behavior beyond what is needed to fix the failure.

Output a short summary: what failed, what you changed, and that the relevant tests now pass.
