module Admin
  class ApplicationController < ActionController::Base
    include AdminAuthenticatable

    before_action :require_admin!

    layout "admin"
  end
end
