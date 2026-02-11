---
description: Run TypeScript type checker (tsc --noEmit)
---

# Run Typecheck

Run the TypeScript compiler in check-only mode.

1. Check for a typecheck script in package.json (e.g. `typecheck`, `type-check`, `tsc --noEmit`) or use `npx tsc --noEmit`.
2. Run the typecheck command. Parse the output for errors (file, line, message).
3. Fix type errors with minimal changes; avoid suppressing with `any` or `@ts-ignore` unless justified.
4. Re-run typecheck to confirm no errors remain.

Output a short summary of any errors fixed.
