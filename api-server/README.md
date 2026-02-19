# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...

## OpenAPI Documentation

The API is documented using OpenAPI 3.0 definition files, auto-generated from RSpec request specs via the `rspec-openapi` gem.

### Generated Files

- `doc/openapi/external.yaml` — External API (11 endpoints under `/api/v1/`)
- `doc/openapi/internal.yaml` — Internal API (5 endpoints under `/internal/`)

### Regenerate

```bash
OPENAPI=1 bundle exec rspec
```

### Validate

```bash
npx @redocly/cli lint doc/openapi/external.yaml --config .redocly.yaml
npx @redocly/cli lint doc/openapi/internal.yaml --config .redocly.yaml
```

### Preview

Install an OpenAPI preview extension in VSCode (e.g., [OpenAPI Editor](https://marketplace.visualstudio.com/items?itemName=42Crunch.vscode-openapi)) and open any `.yaml` file.
