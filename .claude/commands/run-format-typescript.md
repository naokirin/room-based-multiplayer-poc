---
description: Format TypeScript/JavaScript source with Biome
---

# Run Format (Biome)

Format TypeScript and JavaScript source files with Biome.

1. Check for Biome (package.json scripts or `@biomejs/biome` in devDependencies; `biome.json`).
2. Run `npm run format` or `npx biome format --write .` (or the project's format script) to format all configured files.
3. If the user specified a path, run Biome format on that path only (e.g. `npx biome format --write path/to/file.ts`).
4. Ensure no formatting-related changes are left unapplied; report any Biome errors.
