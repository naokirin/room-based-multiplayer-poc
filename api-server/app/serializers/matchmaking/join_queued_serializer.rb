# frozen_string_literal: true

module Matchmaking
  # Serializes POST /matchmaking/join response when status is :queued.
  # Payload must respond to: game_type_id, queued_at, timeout_seconds.
  class JoinQueuedSerializer
    include Alba::Resource

    attribute :status do |_|
      "queued"
    end
    attributes game_type_id: %i[String],
               queued_at: %i[String],
               timeout_seconds: %i[Integer]
  end
end
