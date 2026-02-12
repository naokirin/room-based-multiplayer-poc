module Api
  module V1
    class ApplicationController < ActionController::API
      include Authenticatable

      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity

      private

      def not_found
        render json: { error: "not_found", message: "Resource not found" }, status: :not_found
      end

      def unprocessable_entity(exception)
        render json: { errors: exception.record.errors }, status: :unprocessable_entity
      end
    end
  end
end
