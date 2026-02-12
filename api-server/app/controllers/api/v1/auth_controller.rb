module Api
  module V1
    class AuthController < ApplicationController
      skip_before_action :authenticate_user!, only: [:register, :login]

      def register
        user = User.new(register_params)
        if user.save
          token = JwtService.encode(user_id: user.id)
          render json: {
            user: user_json(user),
            access_token: token,
            expires_at: 1.hour.from_now.iso8601
          }, status: :created
        else
          render json: { errors: user.errors }, status: :unprocessable_entity
        end
      end

      def login
        user = User.find_by(email: params[:email])

        unless user&.authenticate(params[:password])
          return render json: { error: "invalid_credentials", message: "Invalid email or password" }, status: :unauthorized
        end

        if user.account_frozen?
          return render json: { error: "account_frozen", message: "Your account has been suspended" }, status: :unauthorized
        end

        token = JwtService.encode(user_id: user.id)
        render json: {
          user: user_json(user, include_role: true),
          access_token: token,
          expires_at: 1.hour.from_now.iso8601
        }
      end

      def refresh
        token = JwtService.encode(user_id: current_user.id)
        render json: {
          access_token: token,
          expires_at: 1.hour.from_now.iso8601
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
