module Api
  module V1
    # Base controller for API v1. All error responses use the format:
    #   { error: "<code>", message: "<human-readable>" }
    # (except unprocessable_entity which uses { errors: <ActiveRecord errors> })
    class ApplicationController < ActionController::API
      include Authenticatable
      include Auditable

      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
      rescue_from ActionController::ParameterMissing, with: :bad_request
      rescue_from StandardError, with: :internal_server_error

      private

      def not_found
        render_api_error("not_found", I18n.t("api.v1.errors.not_found"), :not_found)
      end

      def unprocessable_entity(exception)
        render json: { errors: exception.record.errors }, status: :unprocessable_entity
      end

      def bad_request(exception)
        render_api_error("bad_request", exception.message, :bad_request)
      end

      def internal_server_error(exception)
        Rails.logger.error("[API Error] #{exception.class}: #{exception.message}\n#{exception.backtrace&.first(Setting.api_error_backtrace_lines)&.join("\n")}")
        render_api_error("internal_server_error", I18n.t("api.v1.errors.internal_server_error"), :internal_server_error)
      end

      def render_api_error(code, message, status)
        render json: { error: code, message: message }, status: status
      end
    end
  end
end
