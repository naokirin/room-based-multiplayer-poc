# frozen_string_literal: true

module Api
  module V1
    # GET /api/v1/game_types: { game_types: [...] }.
    class GameTypesIndexSerializer
      include Alba::Resource

      root_key :game_types

      many :game_types, resource: GameTypeSerializer
    end
  end
end
