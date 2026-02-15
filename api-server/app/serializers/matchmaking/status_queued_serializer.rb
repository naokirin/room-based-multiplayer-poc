# frozen_string_literal: true

module Matchmaking
  # Serializes GET /matchmaking/status response when status is :queued.
  # Payload must respond to: queued_at, game_type_id.
  class StatusQueuedSerializer
    include Alba::Resource

    attribute :status do |_|
      "queued"
    end
    attributes queued_at: %i[String],
               game_type_id: %i[String]
  end
end
