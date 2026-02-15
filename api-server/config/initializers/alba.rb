# frozen_string_literal: true

# Use Rails' JSON encoder for consistency with the rest of the app
# (requires ActiveSupport; no extra gem)
Rails.application.config.after_initialize do
  Alba.backend = :active_support
end
