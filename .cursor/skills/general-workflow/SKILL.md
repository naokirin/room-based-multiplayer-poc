# General Development Workflow

Language-agnostic workflow for feature implementation and code quality.

## When to Use

- Implementing new features in any language
- Refactoring or improving existing code
- When no language-specific skill is more relevant

## Feature Implementation Workflow

1. **Plan First**
   - Use **planner** agent or `/plan` for complex features
   - Identify dependencies and risks
   - Break down into phases

2. **TDD Approach** (when tests apply)
   - Write tests first (RED)
   - Implement to pass tests (GREEN)
   - Refactor (IMPROVE)
   - Verify coverage where project defines a target

3. **Code Review**
   - Use **code-reviewer** agent or `/code-review` after writing code
   - Address CRITICAL and HIGH issues
   - Fix MEDIUM issues when possible

4. **Commit & Push**
   - Use conventional commit format: `type: description`
   - Types: feat, fix, refactor, docs, test, chore, perf, ci

## Code Quality Checklist

Before marking work complete:
- [ ] Code is readable and well-named
- [ ] Functions are small (<50 lines)
- [ ] Files are focused (<800 lines)
- [ ] No deep nesting (>4 levels)
- [ ] Proper error handling
- [ ] No hardcoded values (use constants or config)
- [ ] No mutation (immutable patterns where applicable)

## TodoWrite

Use TodoWrite tool to:
- Track progress on multi-step tasks
- Verify understanding of instructions
- Show granular implementation steps
