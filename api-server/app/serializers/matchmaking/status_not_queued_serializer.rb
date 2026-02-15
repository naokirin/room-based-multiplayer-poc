# frozen_string_literal: true

module Matchmaking
  # Serializes GET /matchmaking/status response when status is :not_queued.
  # No payload required (status is fixed).
  class StatusNotQueuedSerializer
    include Alba::Resource

    attribute :status do |_|
      "not_queued"
    end
  end
end
