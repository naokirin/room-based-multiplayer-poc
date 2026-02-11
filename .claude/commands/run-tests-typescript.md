---
description: Run tests and fix failures (npm test / vitest / jest)
context: fork
agent: typescript-tester
argument-hint: "[path or test name pattern]"
---

# Run Tests and Fix Failures

Run the TypeScript test suite and fix any failures.

## Instructions

1. Determine the test runner from package.json (e.g. `test`, `vitest`, `jest`) or config files.
2. If the user specified a path or pattern, run tests for that scope (e.g. `npm test -- path/to/file.test.ts`, `npx vitest run path/to/file`).
3. Otherwise run the full suite: `npm test` or equivalent.
4. Parse the output to identify failing tests; determine whether the failure is in the implementation or the test; apply a minimal fix.
5. Re-run the affected tests to confirm they pass. Keep changes consistent with CLAUDE.md (or `.cursor/rules/`). Do not change behaviour beyond what is needed to fix the failure. Run typecheck after changes if the project has a typecheck script.

Output a short summary: what failed, what you changed, and that the relevant tests now pass.
