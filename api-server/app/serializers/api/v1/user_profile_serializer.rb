# frozen_string_literal: true

module Api
  module V1
    # User profile (GET /api/v1/profile) with created_at.
    class UserProfileSerializer
      include Alba::Resource

      attributes id: %i[String],
                 email: %i[String],
                 display_name: %i[String],
                 role: %i[String],
                 status: %i[String]
      attribute :created_at do |user|
        user.created_at.iso8601
      end
    end
  end
end
