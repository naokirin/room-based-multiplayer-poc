---
name: vitest-testing
description: Adding or fixing tests with Vitest (or Jest). Use when writing tests, fixing failing tests, or improving test structure and coverage.
user-invocable: false
---

# Vitest / Jest Testing

## When to Use

- Adding tests for new or existing modules (unit or integration).
- Fixing failing tests (determine whether the failure is in implementation or test; fix minimally).
- Improving test structure (`describe`, `it`/`test`, setup) or readability.

## Principles

1. **Layout**: Place tests per project convention: `*.test.ts` / `*.spec.ts` next to source, or under `test/` / `__tests__/`. Use `describe` and `it`/`test` with clear descriptions.
2. **Assertions**: Prefer explicit assertions (e.g. `expect(x).toBe(y)`). Keep expected values clear. Use type-safe matchers when available.
3. **Setup**: Use `beforeEach`/`beforeAll` for shared setup; mock only when necessary; prefer real dependencies for integration-style tests when fast enough.
4. **Verification**: Run the test script (e.g. `npm test`, `npx vitest run`, `npx jest`) to verify. Do not change behaviour beyond what is needed to fix the failure.

## Note

If the project uses Jest instead of Vitest, the same principles apply; adjust commands (e.g. `npx jest` instead of `npx vitest run`).
