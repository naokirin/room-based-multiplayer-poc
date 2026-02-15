# frozen_string_literal: true

module Matchmaking
  # Serializes POST /matchmaking/join response when status is :already_in_game.
  # Payload must respond to: room_id, room_token, ws_url.
  class JoinAlreadyInGameSerializer
    include Alba::Resource

    attribute :status do |_|
      "already_in_game"
    end
    attributes room_id: %i[String],
               room_token: %i[String],
               ws_url: %i[String]
  end
end
