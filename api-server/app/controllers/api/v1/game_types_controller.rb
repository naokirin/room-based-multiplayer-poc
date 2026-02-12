module Api
  module V1
    class GameTypesController < ApplicationController
      def index
        game_types = GameType.active
        render json: {
          game_types: game_types.map { |gt|
            {
              id: gt.id,
              name: gt.name,
              player_count: gt.player_count,
              turn_time_limit: gt.turn_time_limit
            }
          }
        }
      end
    end
  end
end
