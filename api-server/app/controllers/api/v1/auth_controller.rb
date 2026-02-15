module Api
  module V1
    class AuthController < ApplicationController
      skip_before_action :authenticate_user!, only: [:register, :login]

      def register
        user = User.new(register_params)
        if user.save
          token = JwtService.encode({ user_id: user.id })
          render json: {
            user: user_json(user),
            access_token: token,
            expires_at: AppConstants::JWT_EXPIRATION.from_now.iso8601
          }, status: :created
        else
          render json: { errors: user.errors }, status: :unprocessable_entity
        end
      end

      def login
        user = User.find_by(email: params[:email])

        unless user&.authenticate(params[:password])
          audit_log(action: "user.login.failure", metadata: { email: params[:email] })
          return render json: { error: "invalid_credentials", message: I18n.t("api.v1.errors.invalid_credentials") }, status: :unauthorized
        end

        if user.account_frozen?
          audit_log(action: "user.login.frozen", target: user)
          return render json: { error: "account_frozen", message: I18n.t("api.v1.errors.account_frozen") }, status: :unauthorized
        end

        audit_log(action: "user.login.success", target: user)
        token = JwtService.encode({ user_id: user.id })
        render json: {
          user: user_json(user, include_role: true),
          access_token: token,
          expires_at: AppConstants::JWT_EXPIRATION.from_now.iso8601
        }
      end

      def refresh
        token = JwtService.encode({ user_id: current_user.id })
        render json: {
          access_token: token,
          expires_at: AppConstants::JWT_EXPIRATION.from_now.iso8601
        }
      end

      private

      def register_params
        params.require(:user).permit(:email, :password, :display_name)
      end

      def user_json(user, include_role: false)
        json = {
          id: user.id,
          email: user.email,
          display_name: user.display_name
        }
        if include_role
          json[:role] = user.role
          json[:status] = user.status
        end
        json
      end
    end
  end
end
