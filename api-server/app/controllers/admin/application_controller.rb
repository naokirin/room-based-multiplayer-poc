module Admin
  class ApplicationController < ActionController::Base
    include AdminAuthenticatable
    include Auditable

    before_action :require_admin!

    layout "admin"
  end
end
