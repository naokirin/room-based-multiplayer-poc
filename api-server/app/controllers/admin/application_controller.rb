module Admin
  class ApplicationController < ActionController::Base
    include AdminAuthenticatable
    include Auditable

    before_action :require_admin!

    rescue_from ActiveRecord::RecordNotFound, with: :not_found

    layout "admin"

    private

    def not_found
      redirect_to admin_root_path, alert: I18n.t("admin.not_found")
    end
  end
end
