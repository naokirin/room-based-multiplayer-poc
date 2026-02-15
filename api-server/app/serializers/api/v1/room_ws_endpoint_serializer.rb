# frozen_string_literal: true

module Api
  module V1
    # GET /api/v1/rooms/:id/ws_endpoint response.
    class RoomWsEndpointSerializer
      include Alba::Resource

      attributes ws_url: %i[String],
                 node_name: %i[String],
                 room_status: %i[String]
    end
  end
end
