# Run Lint (Biome)

Run Biome linter and fix auto-fixable issues.

1. Check whether the project uses Biome (`biome.json` or `biome` in package.json devDependencies).
2. If the user specified files or directories, run Biome on that scope; otherwise run on the whole project.
3. Fix auto-fixable offenses with `npx biome lint --write .` or `npm run lint -- --write`; fix others manually.
4. Re-run Biome lint to confirm offenses are resolved. Run tests/typecheck if needed.
