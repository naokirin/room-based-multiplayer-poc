module Api
  module V1
    class RoomsController < ApplicationController
      # GET /api/v1/rooms/:id/ws_endpoint
      # T093: Return WebSocket endpoint info for reconnection
      def ws_endpoint
        room = Room.find_by(id: params[:id])

        unless room
          return render json: {
            error: "room_not_found",
            message: I18n.t("api.v1.errors.room_not_found", id: params[:id])
          }, status: :not_found
        end

        # Check if room is in active status (waiting or playing)
        unless %w[waiting ready playing].include?(room.status)
          return render json: {
            error: "room_not_active",
            message: I18n.t("api.v1.errors.room_not_active", status: room.status)
          }, status: :not_found
        end

        # Build WebSocket URL
        ws_url =
          if room.node_name.present?
            "ws://#{room.node_name}:#{Setting.default_game_server_ws_port}/socket/websocket"
          else
            Setting.game_server_ws_url
          end

        render json: {
          ws_url: ws_url,
          node_name: room.node_name,
          room_status: room.status
        }, status: :ok
      end
    end
  end
end
