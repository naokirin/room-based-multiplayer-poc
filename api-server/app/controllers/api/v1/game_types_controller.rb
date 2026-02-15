module Api
  module V1
    class GameTypesController < ApplicationController
      def index
        game_types = GameType.active
        payload = OpenStruct.new(game_types: game_types)
        render_with_serializer(Api::V1::GameTypesIndexSerializer, payload, root_key: :default)
      end
    end
  end
end
