module Admin
  class RoomsController < ApplicationController
    before_action :set_room, only: [ :show, :terminate ]

    # GET /admin/rooms
    def index
      @rooms = Room.includes(:game_type).order(created_at: :desc)

      if params[:status].present? && Room.statuses.key?(params[:status])
        @rooms = @rooms.where(status: params[:status])
      end

      @page = [ params[:page].to_i, 1 ].max
      @per_page = Setting.admin_per_page
      @total_count = @rooms.count
      @rooms = @rooms.offset((@page - 1) * @per_page).limit(@per_page)
    end

    # GET /admin/rooms/:id
    def show
      @room_players = @room.room_players.includes(:user)
      @game_result = @room.game_result
    end

    # POST /admin/rooms/:id/terminate
    def terminate
      unless @room.status.in?(%w[preparing ready playing])
        redirect_to admin_room_path(@room), alert: I18n.t("admin.rooms.not_active_terminate")
        return
      end

      command = {
        command: "terminate",
        room_id: @room.id,
        reason: "admin_terminated",
        admin_id: current_admin.id,
        issued_at: Time.current.iso8601
      }

      REDIS.publish("room_commands", JSON.generate(command))
      audit_log(action: "admin.room.terminate", target: @room, metadata: { reason: "admin_terminated" })

      redirect_to admin_room_path(@room), notice: I18n.t("admin.rooms.terminate_success")
    end

    private

    def set_room
      @room = Room.find(params[:id])
    end
  end
end
