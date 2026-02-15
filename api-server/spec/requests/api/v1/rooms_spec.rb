# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Rooms", type: :request do
  let(:user) { create(:user) }
  let(:token) { JwtService.encode({ user_id: user.id }) }
  let(:game_type) { create(:game_type) }

  describe "GET /api/v1/rooms/:id/ws_endpoint" do
    context "when room exists and is active" do
      let(:room) do
        create(:room, game_type: game_type, status: :ready, node_name: "game-node-1")
      end

      it "returns ok and expected response format (ws_url, node_name, room_status)" do
        get "/api/v1/rooms/#{room.id}/ws_endpoint",
            headers: { "Authorization" => "Bearer #{token}" },
            as: :json

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json).to have_key("ws_url")
        expect(json["ws_url"]).to be_a(String)
        expect(json).to have_key("node_name")
        expect(json["node_name"]).to eq("game-node-1")
        expect(json).to have_key("room_status")
        expect(json["room_status"]).to eq("ready")
      end
    end

    context "when room not found" do
      it "returns 404 with error format" do
        get "/api/v1/rooms/00000000-0000-0000-0000-000000000000/ws_endpoint",
            headers: { "Authorization" => "Bearer #{token}" },
            as: :json

        expect(response).to have_http_status(:not_found)
        json = response.parsed_body
        expect(json["error"]).to eq("room_not_found")
        expect(json["message"]).to be_present
      end
    end

    context "when unauthorized" do
      let(:room) { create(:room, game_type: game_type, status: :ready) }

      it "returns 401 without token" do
        get "/api/v1/rooms/#{room.id}/ws_endpoint", as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
