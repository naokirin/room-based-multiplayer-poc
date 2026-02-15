# frozen_string_literal: true

module Matchmaking
  # Serializes POST /matchmaking/join response when status is :already_queued.
  # Payload must respond to: queued_at.
  class JoinAlreadyQueuedSerializer
    include Alba::Resource

    attribute :status do |_|
      "already_queued"
    end
    attributes queued_at: %i[String]
  end
end
