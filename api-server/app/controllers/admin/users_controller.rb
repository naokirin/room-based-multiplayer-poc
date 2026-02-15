module Admin
  class UsersController < ApplicationController
    before_action :set_user, only: [:show, :freeze, :unfreeze]

    # GET /admin/users
    def index
      @users = User.order(created_at: :desc)

      if params[:search].present?
        search_term = "%#{params[:search]}%"
        @users = @users.where("display_name LIKE :q OR email LIKE :q", q: search_term)
      end

      @page = [params[:page].to_i, 1].max
      @per_page = Setting.admin_per_page
      @total_count = @users.count
      @users = @users.offset((@page - 1) * @per_page).limit(@per_page)
    end

    # GET /admin/users/:id
    def show
      @game_results = GameResult
        .joins(room: :room_players)
        .where(room_players: { user_id: @user.id })
        .includes(room: :game_type)
        .order(created_at: :desc)
        .limit(Setting.admin_user_game_results_limit)
    end

    # POST /admin/users/:id/freeze
    def freeze
      if @user.admin?
        redirect_to admin_user_path(@user), alert: I18n.t("admin.users.cannot_freeze_admin")
        return
      end

      @user.freeze_account!(reason: params[:reason] || "Frozen by admin")
      audit_log(action: "admin.user.freeze", target: @user, metadata: { reason: params[:reason] })
      redirect_to admin_user_path(@user), notice: I18n.t("admin.users.freeze_success")
    end

    # POST /admin/users/:id/unfreeze
    def unfreeze
      @user.unfreeze_account!
      audit_log(action: "admin.user.unfreeze", target: @user)
      redirect_to admin_user_path(@user), notice: I18n.t("admin.users.unfreeze_success")
    end

    private

    def set_user
      @user = User.find(params[:id])
    end
  end
end
