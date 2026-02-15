# frozen_string_literal: true

module Api
  module V1
    # Single game type for GET /api/v1/game_types index.
    class GameTypeSerializer
      include Alba::Resource

      attributes id: %i[String],
                 name: %i[String],
                 player_count: %i[Integer],
                 turn_time_limit: %i[Integer]
    end
  end
end
