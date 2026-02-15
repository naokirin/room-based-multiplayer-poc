# frozen_string_literal: true

module Api
  module V1
    # User with role and status (for login response).
    class UserWithRoleSerializer
      include Alba::Resource

      attributes id: %i[String],
                 email: %i[String],
                 display_name: %i[String],
                 role: %i[String],
                 status: %i[String]
    end
  end
end
