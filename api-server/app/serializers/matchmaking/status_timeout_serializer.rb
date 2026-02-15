# frozen_string_literal: true

module Matchmaking
  # Serializes GET /matchmaking/status response when status is :timeout.
  # Payload must respond to: message.
  class StatusTimeoutSerializer
    include Alba::Resource

    attribute :status do |_|
      "timeout"
    end
    attributes message: %i[String]
  end
end
