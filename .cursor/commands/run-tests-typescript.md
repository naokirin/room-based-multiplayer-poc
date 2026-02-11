# Run Tests and Fix Failures

Run the TypeScript test suite and fix any failures using the **typescript-tester** agent.

- Determine the test runner from package.json or config (vitest, jest, npm test).
- If the user specified a path or pattern, run tests for that scope and prioritize fixing failures there.
- Otherwise run the full suite: `npm test` or equivalent.
