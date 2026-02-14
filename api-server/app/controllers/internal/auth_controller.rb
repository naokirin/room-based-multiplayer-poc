module Internal
  class AuthController < ApplicationController
    def verify
      payload = JwtService.decode(params[:token])
      unless payload
        return render json: { valid: false, reason: I18n.t("internal.auth.invalid_token") }
      end

      user = User.find_by(id: payload[:user_id])
      unless user
        return render json: { valid: false, reason: I18n.t("internal.auth.user_not_found") }
      end

      render json: {
        valid: true,
        user_id: user.id,
        display_name: user.display_name,
        role: user.role,
        status: user.status
      }
    end
  end
end
