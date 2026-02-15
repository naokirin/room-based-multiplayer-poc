# frozen_string_literal: true

module Api
  module V1
    # Serializes API error payloads { error:, message: } with no root key.
    class ErrorSerializer
      include Alba::Resource

      attributes error: %i[String],
                 message: %i[String]
    end
  end
end
