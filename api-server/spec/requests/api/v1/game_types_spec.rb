# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::GameTypes", type: :request do
  let(:user) { create(:user) }
  let(:token) { JwtService.encode({ user_id: user.id }) }

  describe "GET /api/v1/game_types" do
    it "returns ok and game_types as array (response format check)" do
      create(:game_type, name: "simple_card_battle", player_count: 2, turn_time_limit: 60)

      get "/api/v1/game_types",
          headers: { "Authorization" => "Bearer #{token}" },
          as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json).to have_key("game_types")
      expect(json["game_types"]).to be_an(Array)
      expect(json["game_types"].first).to include(
        "id" => kind_of(String),
        "name" => "simple_card_battle",
        "player_count" => 2,
        "turn_time_limit" => 60
      )
    end

    it "returns empty array when no game types" do
      get "/api/v1/game_types",
          headers: { "Authorization" => "Bearer #{token}" },
          as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["game_types"]).to eq([])
    end
  end
end
