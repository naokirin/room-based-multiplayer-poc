# frozen_string_literal: true

module Matchmaking
  # Serializes DELETE /matchmaking/cancel response.
  # Payload must respond to: user_id.
  class CancelSerializer
    include Alba::Resource

    attribute :status do |_|
      "cancelled"
    end
    attributes user_id: %i[String]
  end
end
