module Api
  module V1
    class RoomsController < ApplicationController
      before_action :authenticate_user!

      # GET /api/v1/rooms/:id/ws_endpoint
      # T093: Return WebSocket endpoint info for reconnection
      def ws_endpoint
        room = Room.find_by(id: params[:id])

        unless room
          return render json: {
            error: "room_not_found",
            message: "Room with ID #{params[:id]} not found"
          }, status: :not_found
        end

        # Check if room is in active status (waiting or playing)
        unless %w[waiting ready playing].include?(room.status)
          return render json: {
            error: "room_not_active",
            message: "Room is not active (status: #{room.status})"
          }, status: :not_found
        end

        # Build WebSocket URL
        ws_url = if room.node_name.present?
                   "ws://#{room.node_name}:4000/socket/websocket"
                 else
                   # Fallback to default game server
                   game_server_url = ENV.fetch("GAME_SERVER_WS_URL", "ws://localhost:4000/socket/websocket")
                   game_server_url
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
