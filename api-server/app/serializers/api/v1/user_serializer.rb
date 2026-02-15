# frozen_string_literal: true

module Api
  module V1
    # User for auth register (id, email, display_name only).
    class UserSerializer
      include Alba::Resource

      attributes id: %i[String],
                 email: %i[String],
                 display_name: %i[String]
    end
  end
end
