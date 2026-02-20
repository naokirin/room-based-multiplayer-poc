require "committee/rails"

EXTERNAL_SCHEMA_PATH = Rails.root.join("doc/openapi/external.yaml").to_s
INTERNAL_SCHEMA_PATH = Rails.root.join("doc/openapi/internal.yaml").to_s

RSpec.configure do |config|
  config.include Committee::Rails::Test::Methods, type: :request

  config.add_setting :committee_options
  config.committee_options = {
    schema_path: EXTERNAL_SCHEMA_PATH,
    parse_response_by_content_type: true,
    strict_reference_validation: true
  }

  # After each request spec, validate the response against the appropriate OpenAPI schema.
  # Uses internal.yaml for /internal/ paths, external.yaml for everything else.
  config.after(:each, type: :request) do
    next unless response
    next unless response.media_type == "application/json"

    schema_path = if request.path.start_with?("/internal/")
      INTERNAL_SCHEMA_PATH
    else
      EXTERNAL_SCHEMA_PATH
    end

    # Override committee_options for this specific assertion
    original_options = RSpec.configuration.committee_options
    RSpec.configuration.committee_options = original_options.merge(schema_path: schema_path)
    begin
      assert_response_schema_confirm(response.status)
    ensure
      RSpec.configuration.committee_options = original_options
    end
  end
end
