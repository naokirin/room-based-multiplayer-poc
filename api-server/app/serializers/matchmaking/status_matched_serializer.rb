# frozen_string_literal: true

module Matchmaking
  # Serializes GET /matchmaking/status response when status is :matched.
  # Payload must respond to: room_id, room_token, ws_url.
  class StatusMatchedSerializer
    include Alba::Resource

    attribute :status do |_|
      "matched"
    end
    attributes room_id: %i[String],
               room_token: %i[String],
               ws_url: %i[String]
  end
end
