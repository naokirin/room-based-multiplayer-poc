module Api
  module V1
    class ApplicationController < ActionController::API
      include Authenticatable
      include Auditable

      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
      rescue_from ActionController::ParameterMissing, with: :bad_request
      rescue_from StandardError, with: :internal_server_error

      private

      def not_found
        render json: { error: "not_found", message: "Resource not found" }, status: :not_found
      end

      def unprocessable_entity(exception)
        render json: { errors: exception.record.errors }, status: :unprocessable_entity
      end

      def bad_request(exception)
        render json: { error: "bad_request", message: exception.message }, status: :bad_request
      end

      def internal_server_error(exception)
        Rails.logger.error("[API Error] #{exception.class}: #{exception.message}\n#{exception.backtrace&.first(5)&.join("\n")}")
        render json: { error: "internal_server_error", message: "An unexpected error occurred" }, status: :internal_server_error
      end
    end
  end
end
