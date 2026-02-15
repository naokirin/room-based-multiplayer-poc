module Api
  module V1
    class GameTypesController < ApplicationController
      # Returns { game_types: [...] } (client expects array at .game_types).
      def index
        game_types = GameType.active
        json = {
          game_types: game_types.map { |gt| Api::V1::GameTypeSerializer.new(gt).as_json(root_key: nil) }
        }
        render json: json, status: :ok
      end
    end
  end
end
