module Api
  module V1
    class RoomsController < ApplicationController
      # GET /api/v1/rooms/:id/ws_endpoint
      # T093: Return WebSocket endpoint info for reconnection
      def ws_endpoint
        room = Room.find_by(id: params[:id])

        unless room
          return render_room_error(
            "room_not_found",
            I18n.t("api.v1.errors.room_not_found", id: params[:id]),
            :not_found
          )
        end

        # Check if room is in active status (waiting or playing)
        unless %w[waiting ready playing].include?(room.status)
          return render_room_error(
            "room_not_active",
            I18n.t("api.v1.errors.room_not_active", status: room.status),
            :not_found
          )
        end

        ws_url =
          if room.node_name.present?
            "ws://#{room.node_name}:#{Setting.default_game_server_ws_port}/socket"
          else
            Setting.game_server_ws_url
          end
        payload = OpenStruct.new(ws_url: ws_url, node_name: room.node_name, room_status: room.status)
        render_with_serializer(Api::V1::RoomWsEndpointSerializer, payload, status: :ok)
      end

      private

      def render_room_error(code, message, status)
        payload = OpenStruct.new(error: code, message: message)
        render_with_serializer(Api::V1::ErrorSerializer, payload, status: status)
      end
    end
  end
end
