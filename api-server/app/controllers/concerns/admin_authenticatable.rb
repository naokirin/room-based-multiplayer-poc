module AdminAuthenticatable
  extend ActiveSupport::Concern

  included do
    helper_method :current_admin
  end

  private

  def current_admin
    @current_admin ||= User.find_by(id: session[:admin_user_id], role: :admin) if session[:admin_user_id]
  end

  def require_admin!
    unless current_admin
      redirect_to admin_login_path, alert: "Please log in as admin"
      nil
    end
  end
end
