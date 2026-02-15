# frozen_string_literal: true

module Api
  module V1
    # POST /api/v1/auth/login success: { user, access_token, expires_at }.
    class AuthLoginSerializer
      include Alba::Resource

      one :user, resource: UserWithRoleSerializer
      attributes access_token: %i[String],
                 expires_at: %i[String]
    end
  end
end
