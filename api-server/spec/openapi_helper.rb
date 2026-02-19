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

# Shared info (title is set per-API via the title lambda above)
RSpec::OpenAPI.info = { version: "v1" }
