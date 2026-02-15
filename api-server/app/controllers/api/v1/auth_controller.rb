module Api
  module V1
    class AuthController < ApplicationController
      skip_before_action :authenticate_user!, only: [ :register, :login ]

      def register
        user = User.new(register_params)
        if user.save
          payload = build_register_payload(user)
          render_with_serializer(Api::V1::AuthRegisterSerializer, payload, status: :created)
        else
          render json: { errors: user.errors }, status: :unprocessable_entity
        end
      end

      def login
        user = User.find_by(email: params[:email])

        unless user&.authenticate(params[:password])
          audit_log(action: "user.login.failure", metadata: { email: params[:email] })
          return render_auth_error("invalid_credentials", I18n.t("api.v1.errors.invalid_credentials"), :unauthorized)
        end

        if user.account_frozen?
          audit_log(action: "user.login.frozen", target: user)
          return render_auth_error("account_frozen", I18n.t("api.v1.errors.account_frozen"), :unauthorized)
        end

        audit_log(action: "user.login.success", target: user)
        payload = build_login_payload(user)
        render_with_serializer(Api::V1::AuthLoginSerializer, payload)
      end

      def refresh
        payload = build_refresh_payload
        render_with_serializer(Api::V1::AuthRefreshSerializer, payload)
      end

      private

      def register_params
        params.require(:user).permit(:email, :password, :display_name)
      end

      def build_register_payload(user)
        expires_at = Setting.jwt_expiration_seconds.seconds.from_now.iso8601
        token = JwtService.encode({ user_id: user.id })
        OpenStruct.new(user: user, access_token: token, expires_at: expires_at)
      end

      def build_login_payload(user)
        expires_at = Setting.jwt_expiration_seconds.seconds.from_now.iso8601
        token = JwtService.encode({ user_id: user.id })
        OpenStruct.new(user: user, access_token: token, expires_at: expires_at)
      end

      def build_refresh_payload
        expires_at = Setting.jwt_expiration_seconds.seconds.from_now.iso8601
        token = JwtService.encode({ user_id: current_user.id })
        OpenStruct.new(access_token: token, expires_at: expires_at)
      end

      def render_auth_error(code, message, status)
        payload = OpenStruct.new(error: code, message: message)
        render_with_serializer(Api::V1::ErrorSerializer, payload, status: status)
      end
    end
  end
end
