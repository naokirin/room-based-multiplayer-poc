module Admin
  class ApplicationController < ActionController::Base
    include AdminAuthenticatable

    layout "admin"

    private

    def require_admin!
      redirect_to admin_login_path unless current_admin
    end
  end
end
