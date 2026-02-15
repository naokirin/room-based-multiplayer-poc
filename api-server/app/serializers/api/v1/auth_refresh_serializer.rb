# frozen_string_literal: true

module Api
  module V1
    # POST /api/v1/auth/refresh: { access_token, expires_at }.
    class AuthRefreshSerializer
      include Alba::Resource

      attributes access_token: %i[String],
                 expires_at: %i[String]
    end
  end
end
