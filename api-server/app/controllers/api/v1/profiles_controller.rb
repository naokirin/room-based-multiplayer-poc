module Api
  module V1
    class ProfilesController < ApplicationController
      def show
        render json: {
          user: {
            id: current_user.id,
            email: current_user.email,
            display_name: current_user.display_name,
            role: current_user.role,
            status: current_user.status,
            created_at: current_user.created_at.iso8601
          }
        }
      end
    end
  end
end
