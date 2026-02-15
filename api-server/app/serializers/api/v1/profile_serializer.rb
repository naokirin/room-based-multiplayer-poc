# frozen_string_literal: true

module Api
  module V1
    # GET /api/v1/profile: { user: { ... } }.
    class ProfileSerializer
      include Alba::Resource

      one :user, resource: UserProfileSerializer
    end
  end
end
