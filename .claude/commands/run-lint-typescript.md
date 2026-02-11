---
description: Run Biome linter and fix auto-fixable issues
disable-model-invocation: true
argument-hint: "[file or directory]"
---

# Run Lint (Biome)

Run Biome linter and fix auto-fixable issues: $ARGUMENTS

## Instructions

1. Check whether the project uses Biome (presence of `biome.json` or `@biomejs/biome` in package.json devDependencies).
2. Determine scope:
   - If the user specified files or directories, run Biome on that scope (e.g. `npx biome lint src/` or `npx biome lint path/to/file.ts`).
   - Otherwise run on the whole project (e.g. `npx biome lint .` or `npm run lint`).
3. Run Biome lint and note the offenses. Fix auto-fixable ones with `npx biome lint --write .` (or `npm run lint -- --write`), or fix manually.
4. Re-run Biome lint on the same scope to confirm offenses are resolved.
5. If needed, run the test suite and typecheck to ensure changes did not break anything.

If the user said "this file only" or "src only", run and fix within that scope.
