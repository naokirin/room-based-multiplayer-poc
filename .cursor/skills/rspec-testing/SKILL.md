---
name: rspec-testing
description: Writes and refactors RSpec specs following RSpec style guide: describe/context structure, let/subject order, shared examples, and one-expectation-per-example where appropriate. Use when writing or modifying *_spec.rb or spec/** files.
---

# RSpec Testing

## When to Use

- Writing or editing model, request, feature, or system specs.
- Adding or changing `describe`/`context`/`it`/`let`/`subject`/`before`/`after`.

## Workflow

1. Follow the project's RSpec style rules (`.cursor/rules/rspec-style.mdc` or CLAUDE.md) for all spec code.
2. Use request/controller specs to drive status, redirects, and assigns; keep expectations focused and use `context` for different params or auth states.
3. When adding a new model or feature, create the corresponding spec file under `spec/` mirroring the `app/` directory structure.
4. Run `bundle exec rspec [path]` to verify after writing or editing specs.

## Spec Types Reference

| Spec type | Directory | Tests |
|-----------|-----------|-------|
| Model | `spec/models/` | Validations, associations, scopes, methods |
| Request | `spec/requests/` | HTTP status, response body, redirects |
| System/Feature | `spec/system/` | Full browser-driven user flows |
| Helper | `spec/helpers/` | View helper methods |
| Mailer | `spec/mailers/` | Email delivery and content |
| Job | `spec/jobs/` | Active Job behavior |
