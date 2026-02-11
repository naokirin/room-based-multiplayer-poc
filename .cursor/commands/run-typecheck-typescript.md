# Run Typecheck

Run the TypeScript compiler in check-only mode.

1. Run `npm run typecheck` or `npx tsc --noEmit` (or project typecheck script).
2. Parse the output for type errors; fix with minimal changes. Avoid `any` or `@ts-ignore` unless justified.
3. Re-run typecheck to confirm no errors remain.

Output a short summary of any errors fixed.
