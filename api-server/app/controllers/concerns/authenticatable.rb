module Authenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
  end

  private

  def authenticate_user!
    token = extract_token
    return render_unauthorized unless token

    payload = JwtService.decode(token)
    return render_unauthorized unless payload

    @current_user = User.find_by(id: payload[:user_id])
    return render_unauthorized unless @current_user
    return render_forbidden if @current_user.account_frozen?
  end

  def current_user
    @current_user
  end

  def extract_token
    header = request.headers["Authorization"]
    header&.split(" ")&.last
  end

  def render_unauthorized
    render json: { error: "unauthorized", message: I18n.t("api.v1.errors.unauthorized") }, status: :unauthorized
  end

  def render_forbidden
    render json: { error: "forbidden", message: I18n.t("api.v1.errors.forbidden") }, status: :forbidden
  end
end
