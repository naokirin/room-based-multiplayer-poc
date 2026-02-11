---
name: typescript-refactor
description: Simplifying TypeScript code or applying style/idiom rules. Use when refactoring, improving types, or cleaning up structure without changing behaviour.
user-invocable: false
---

# TypeScript Refactor

## When to Use

- Simplifying code structure (extract functions, reduce nesting, split modules).
- Applying style or idiom rules (imports, naming, types).
- Improving type safety (replacing `any`, adding explicit types, narrowing).
- Reducing duplication or improving readability without changing behaviour.

## Principles

1. **Behaviour first**: Refactors must not change observable behaviour. Rely on existing tests.
2. **Incremental**: Prefer small, reviewable steps. One logical change per step.
3. **Types**: Preserve or improve type safety; do not introduce `any` or suppress errors without justification.
4. **Verification**: After refactor run typecheck, tests, and lint; confirm no new failures.
