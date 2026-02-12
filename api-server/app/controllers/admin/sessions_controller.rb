module Admin
  class SessionsController < ApplicationController
    skip_before_action :require_admin!, only: [:new, :create]

    # GET /admin/login
    def new
      redirect_to admin_root_path if current_admin
    end

    # POST /admin/login
    def create
      user = User.find_by(email: params[:email])

      if user&.authenticate(params[:password]) && user.admin?
        session[:admin_user_id] = user.id
        redirect_to admin_root_path, notice: "Logged in successfully"
      else
        flash.now[:alert] = "Invalid email or password, or not an admin"
        render :new, status: :unprocessable_entity
      end
    end

    # DELETE /admin/logout
    def destroy
      session.delete(:admin_user_id)
      redirect_to admin_login_path, notice: "Logged out successfully"
    end
  end
end
