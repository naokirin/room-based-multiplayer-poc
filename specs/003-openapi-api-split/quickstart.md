# Quickstart: OpenAPI Support (Internal/External API Split)

## Prerequisites

- Ruby 3.3+, Rails 8.0+ (api-server already set up)
- Existing RSpec request specs passing

## Setup (one-time)

1. Add `rspec-openapi` gem to Gemfile:

```ruby
# api-server/Gemfile
group :development, :test do
  gem "rspec-openapi"
end
```

2. Run `bundle install`

3. Create configuration file `spec/openapi_helper.rb`:

```ruby
require "rspec/openapi"

# Route specs to separate files based on API namespace
RSpec::OpenAPI.path = ->(example) {
  case example.file_path
  when %r{spec/requests/internal/}
    "doc/openapi/internal.yaml"
  else
    "doc/openapi/external.yaml"
  end
}

# Set titles per API
RSpec::OpenAPI.title = ->(example) {
  case example.file_path
  when %r{spec/requests/internal/}
    "Room-Based Multiplayer Platform — Internal API"
  else
    "Room-Based Multiplayer Platform — External API"
  end
}

# Security schemes
RSpec::OpenAPI.security_schemes = {
  "bearerAuth" => {
    type: "http",
    scheme: "bearer",
    bearerFormat: "JWT"
  },
  "apiKeyAuth" => {
    type: "apiKey",
    in: "header",
    name: "X-Internal-Api-Key"
  }
}

# Additional configuration
RSpec::OpenAPI.info = ->(example) {
  case example.file_path
  when %r{spec/requests/internal/}
    { version: "v1", description: "Internal service-to-service API" }
  else
    { version: "v1", description: "Public-facing API for client applications" }
  end
}
```

4. Require in `spec/rails_helper.rb`:

```ruby
require "openapi_helper" if ENV["OPENAPI"]
```

## Generate OpenAPI Files

```bash
cd api-server
OPENAPI=1 bundle exec rspec
```

This generates:
- `doc/openapi/external.yaml` — External API (10 endpoints)
- `doc/openapi/internal.yaml` — Internal API (5 endpoints)

## Validate Generated Files

```bash
# Using npx (no install needed)
npx @redocly/cli lint doc/openapi/external.yaml
npx @redocly/cli lint doc/openapi/internal.yaml
```

## Preview in VSCode

Install one of these extensions:
- [Swagger Viewer](https://marketplace.visualstudio.com/items?itemName=Arjun.swagger-viewer)
- [OpenAPI (Swagger) Editor](https://marketplace.visualstudio.com/items?itemName=42Crunch.vscode-openapi)

Then open any `.yaml` file and use the preview command.

## Workflow for API Changes

1. Modify API endpoint (controller, serializer, route)
2. Update/add corresponding RSpec request spec
3. Run `OPENAPI=1 bundle exec rspec`
4. Review changes in `doc/openapi/*.yaml`
5. Commit code + updated YAML files together
