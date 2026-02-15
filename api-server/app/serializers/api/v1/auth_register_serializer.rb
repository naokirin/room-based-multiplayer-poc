# frozen_string_literal: true

module Api
  module V1
    # POST /api/v1/auth/register success: { user, access_token, expires_at }.
    class AuthRegisterSerializer
      include Alba::Resource

      one :user, resource: UserSerializer
      attributes access_token: %i[String],
                 expires_at: %i[String]
    end
  end
end
