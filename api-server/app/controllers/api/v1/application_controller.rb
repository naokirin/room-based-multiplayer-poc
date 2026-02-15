require "ostruct"

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
        payload = OpenStruct.new(error: code.to_s, message: message.to_s)
        render_with_serializer(Api::V1::ErrorSerializer, payload, status: status)
      end

      # Renders JSON using an Alba serializer. Use from subclasses for success/error responses.
      # @param serializer_class [Class] Alba::Resource class (e.g. Api::V1::ErrorSerializer)
      # @param payload [Object] object passed to serializer (e.g. OpenStruct, ActiveRecord)
      # @param status [Symbol] HTTP status, default :ok
      # @param root_key [nil, :default] nil => as_json(root_key: nil); :default => as_json (serializer root_key)
      def render_with_serializer(serializer_class, payload, status: :ok, root_key: nil)
        render **serializer_render_options(serializer_class, payload, status: status, root_key: root_key)
      end

      # Returns { json:, status: } for use with render **options (e.g. in responders).
      def serializer_render_options(serializer_class, payload, status: :ok, root_key: nil)
        json = (root_key == :default) ? serializer_class.new(payload).as_json : serializer_class.new(payload).as_json(root_key: root_key)
        { json: json, status: status }
      end
    end
  end
end
