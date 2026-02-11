---
name: typescript-development
description: General TypeScript development following strict typing, ES modules, and best practices. Use when writing or modifying TypeScript code, adding modules, or defining types and APIs.
user-invocable: false
---

# TypeScript Development

## When to Use

- Writing new TypeScript code (modules, functions, types, public API).
- Adding or changing types, interfaces, or type utilities.
- Designing or evolving public APIs and module boundaries.
- Adding dependencies and updating package.json or tsconfig.

## Principles

1. **Types**: Prefer strict TypeScript; avoid `any`. Use explicit types for public APIs and boundaries. Use `unknown` when the type is truly unknown; narrow with type guards.
2. **Modules**: Use ES modules (`import`/`export`). Prefer destructuring for named imports: `import { foo } from 'bar'`.
3. **Style**: Follow the project's TypeScript style and idiom rules (CLAUDE.md or `.cursor/rules/` .mdc files). Use camelCase for variables and functions; PascalCase for types and classes.
4. **Layout**: Keep functions and modules focused; prefer small, testable units. Place tests per project convention (`*.test.ts`, `__tests__/`, or `test/`).

## Verification

- `npm run typecheck` or `npx tsc --noEmit`.
- `npm test` (or project test command).
- `npm run lint` when available (fix or allow with justification).
- `npm run format` or Biome (or rely on the format hook).
