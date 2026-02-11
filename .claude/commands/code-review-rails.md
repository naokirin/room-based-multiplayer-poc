---
description: Review Rails code for style, security, and maintainability
context: fork
agent: rails-code-reviewer
argument-hint: "[files, commit, or scope]"
---

# Rails Code Review

Review the given changes (or the latest diff) for style, conventions, security, and maintainability: $ARGUMENTS

## Instructions

1. Obtain the code to review. If no scope is given, use the most relevant changed files (`git diff --name-only` or `git diff --staged --name-only`).
2. Review against:
   - **Ruby style**: indentation, naming, expressions, line length.
   - **Rails style**: routing (`resources`/`member`/`collection`), skinny controllers, model macros, association `dependent`, queries (no interpolation; `find`/`find_by`/`where`, `find_each`), migrations.
   - **RSpec style** (if specs are in scope): describe/context/let/subject order and layout.
   - **ERB style** (if views are in scope): minimal logic in templates, partials with locals, output escaping.
   - **Hotwire style** (if Turbo/Stimulus code is in scope): frame/stream usage, Stimulus controller conventions.
   - **Security**: strong parameters, no SQL interpolation, auth/authorization where needed.
   - **Maintainability**: duplication, clarity, appropriate use of services or form objects.
3. Categorize feedback as:
   - **Critical**: must fix (bugs, security, broken tests).
   - **Warning**: should fix (conventions, performance, clarity).
   - **Suggestion**: optional improvement.
4. For each point, cite file and line (or range) and give a concrete fix or code snippet when helpful.
5. Keep the review concise and actionable. If the change set is large, focus on the highest-impact files first.
