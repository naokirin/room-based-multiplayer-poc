require "rails_helper"

RSpec.describe "Api::V1::Matchmaking", type: :request do
  let(:user) { create(:user) }
  let(:token) { JwtService.encode({ user_id: user.id }) }
  let(:game_type) { create(:game_type, player_count: 2) }

  before(:each) do
    # Clean up Redis keys between tests
    REDIS.keys("matchmaking:*").each { |key| REDIS.del(key) }
    REDIS.keys("active_game:*").each { |key| REDIS.del(key) }
    REDIS.keys("room_token:*").each { |key| REDIS.del(key) }
    REDIS.del("room_creation_queue")
  end

  describe "POST /api/v1/matchmaking/join" do
    context "when valid join (queued)" do
      it "adds user to queue" do
        post "/api/v1/matchmaking/join",
             params: { game_type_id: game_type.id },
             headers: { "Authorization" => "Bearer #{token}" },
             as: :json

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["status"]).to eq("queued")
        expect(json["queued_at"]).to be_present
        expect(json["timeout_seconds"]).to eq(60)
      end
    end

    context "when match found (2 players)" do
      let!(:user2) { create(:user) }

      it "matches two players immediately" do
        # First player joins
        token1 = JwtService.encode({ user_id: user.id })
        post "/api/v1/matchmaking/join",
             params: { game_type_id: game_type.id },
             headers: { "Authorization" => "Bearer #{token1}" },
             as: :json

        expect(response).to have_http_status(:ok)
        json1 = response.parsed_body
        expect(json1["status"]).to eq("queued")

        # Second player joins and gets matched
        token2 = JwtService.encode({ user_id: user2.id })
        post "/api/v1/matchmaking/join",
             params: { game_type_id: game_type.id },
             headers: { "Authorization" => "Bearer #{token2}" },
             as: :json

        expect(response).to have_http_status(:ok)
        json2 = response.parsed_body
        expect(json2["status"]).to eq("matched")
        expect(json2["room_id"]).to be_present
        expect(json2["room_token"]).to be_present
        expect(json2["ws_url"]).to be_present

        # Verify room was created
        room = Room.find(json2["room_id"])
        expect(room.status).to eq("preparing")
        expect(room.room_players.count).to eq(2)

        # Verify match was created
        match = Match.last
        expect(match.status).to eq("matched")
        expect(match.match_players.count).to eq(2)
      end
    end

    context "when already in queue" do
      before do
        # Add user to queue first
        post "/api/v1/matchmaking/join",
             params: { game_type_id: game_type.id },
             headers: { "Authorization" => "Bearer #{token}" },
             as: :json
      end

      it "returns already_queued status" do
        post "/api/v1/matchmaking/join",
             params: { game_type_id: game_type.id },
             headers: { "Authorization" => "Bearer #{token}" },
             as: :json

        expect(response).to have_http_status(:conflict)
        json = response.parsed_body
        expect(json["status"]).to eq("already_queued")
        expect(json["queued_at"]).to be_present
      end
    end

    context "when already in game" do
      let!(:room) do
        Room.create!(
          game_type_id: game_type.id,
          player_count: 2,
          status: :preparing
        )
      end

      before do
        # Set active game in Redis with a real room (so it is not considered stale)
        REDIS.hset("active_game:#{user.id}", "room_id", room.id)
        REDIS.hset("active_game:#{user.id}", "room_token", "test-token")
        REDIS.hset("active_game:#{user.id}", "ws_url", "ws://localhost:4000/socket")
        REDIS.hset("active_game:#{user.id}", "game_type_id", game_type.id)
        REDIS.hset("active_game:#{user.id}", "status", "preparing")
      end

      it "returns already_in_game status" do
        post "/api/v1/matchmaking/join",
             params: { game_type_id: game_type.id },
             headers: { "Authorization" => "Bearer #{token}" },
             as: :json

        expect(response).to have_http_status(:conflict)
        json = response.parsed_body
        expect(json["status"]).to eq("already_in_game")
        expect(json["room_id"]).to eq(room.id)
        expect(json["room_token"]).to eq("test-token")
        expect(json["ws_url"]).to eq("ws://localhost:4000/socket")
      end
    end

    context "when active_game is stale (room missing or finished)" do
      before do
        # Stale: room_id does not exist in DB (e.g. stack was restarted, Redis kept old key)
        REDIS.hset("active_game:#{user.id}", "room_id", "00000000-0000-0000-0000-000000000000")
        REDIS.hset("active_game:#{user.id}", "room_token", "old-token")
        REDIS.hset("active_game:#{user.id}", "ws_url", "ws://localhost:4000/socket")
        REDIS.hset("active_game:#{user.id}", "game_type_id", game_type.id)
        REDIS.hset("active_game:#{user.id}", "status", "preparing")
      end

      it "clears stale Redis and allows join (returns queued)" do
        post "/api/v1/matchmaking/join",
             params: { game_type_id: game_type.id },
             headers: { "Authorization" => "Bearer #{token}" },
             as: :json

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["status"]).to eq("queued")
        expect(REDIS.exists?("active_game:#{user.id}")).to be_falsey
      end
    end

    context "when invalid game_type" do
      it "returns not_found error" do
        post "/api/v1/matchmaking/join",
             params: { game_type_id: 99999 },
             headers: { "Authorization" => "Bearer #{token}" },
             as: :json

        expect(response).to have_http_status(:not_found)
        json = response.parsed_body
        expect(json["error"]).to eq("invalid_game_type")
        expect(json["message"]).to include("not found")
      end
    end

    context "when inactive game_type" do
      let(:inactive_game_type) { create(:game_type, active: false) }

      it "returns not_found error" do
        post "/api/v1/matchmaking/join",
             params: { game_type_id: inactive_game_type.id },
             headers: { "Authorization" => "Bearer #{token}" },
             as: :json

        expect(response).to have_http_status(:not_found)
        json = response.parsed_body
        expect(json["error"]).to eq("invalid_game_type")
        expect(json["message"]).to include("inactive")
      end
    end

    context "when unauthorized" do
      it "returns 401 without token" do
        post "/api/v1/matchmaking/join",
             params: { game_type_id: game_type.id },
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/matchmaking/status" do
    context "when queued status" do
      before do
        # Add user to queue
        REDIS.hset("matchmaking:user:#{user.id}", "game_type_id", game_type.id)
        REDIS.hset("matchmaking:user:#{user.id}", "queued_at", Time.current.iso8601)
      end

      it "returns queued status" do
        get "/api/v1/matchmaking/status",
            headers: { "Authorization" => "Bearer #{token}" },
            as: :json

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["status"]).to eq("queued")
        expect(json["queued_at"]).to be_present
        expect(json["game_type_id"]).to eq(game_type.id.to_s)
      end
    end

    context "when matched status" do
      let!(:room) do
        Room.create!(
          game_type_id: game_type.id,
          player_count: 2,
          status: :ready
        )
      end

      before do
        # Set active game with a real room (so it is not considered stale)
        REDIS.hset("active_game:#{user.id}", "room_id", room.id)
        REDIS.hset("active_game:#{user.id}", "room_token", "test-token")
        REDIS.hset("active_game:#{user.id}", "ws_url", "ws://localhost:4000/socket")
        REDIS.hset("active_game:#{user.id}", "game_type_id", game_type.id)
        REDIS.hset("active_game:#{user.id}", "status", "ready")
      end

      it "returns matched status" do
        get "/api/v1/matchmaking/status",
            headers: { "Authorization" => "Bearer #{token}" },
            as: :json

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["status"]).to eq("matched")
        expect(json["room_id"]).to eq(room.id)
        expect(json["room_token"]).to eq("test-token")
        expect(json["ws_url"]).to eq("ws://localhost:4000/socket")
      end
    end

    context "when not in queue" do
      it "returns not_queued status" do
        get "/api/v1/matchmaking/status",
            headers: { "Authorization" => "Bearer #{token}" },
            as: :json

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["status"]).to eq("not_queued")
      end
    end

    context "when timeout occurred" do
      before do
        # Add user to queue with old timestamp (70 seconds ago)
        old_time = (Time.current - 70.seconds).iso8601
        REDIS.hset("matchmaking:user:#{user.id}", "game_type_id", game_type.id)
        REDIS.hset("matchmaking:user:#{user.id}", "queued_at", old_time)
        # Add to queue list
        queue_entry = { user_id: user.id, queued_at: old_time }.to_json
        REDIS.lpush("matchmaking:queue:#{game_type.id}", queue_entry)
      end

      it "returns timeout status and cleans up" do
        get "/api/v1/matchmaking/status",
            headers: { "Authorization" => "Bearer #{token}" },
            as: :json

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["status"]).to eq("timeout")
        expect(json["message"]).to eq("Matchmaking timeout")

        # Verify cleanup
        expect(REDIS.exists?("matchmaking:user:#{user.id}")).to be_falsey
      end
    end

    context "when unauthorized" do
      it "returns 401 without token" do
        get "/api/v1/matchmaking/status", as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "DELETE /api/v1/matchmaking/cancel" do
    context "when successful cancel" do
      before do
        # Add user to queue
        queue_entry = { user_id: user.id, queued_at: Time.current.iso8601 }.to_json
        REDIS.lpush("matchmaking:queue:#{game_type.id}", queue_entry)
        REDIS.hset("matchmaking:user:#{user.id}", "game_type_id", game_type.id)
        REDIS.hset("matchmaking:user:#{user.id}", "queued_at", Time.current.iso8601)
      end

      it "removes user from queue" do
        delete "/api/v1/matchmaking/cancel",
               params: { game_type_id: game_type.id },
               headers: { "Authorization" => "Bearer #{token}" },
               as: :json

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["status"]).to eq("cancelled")
        expect(json["user_id"]).to eq(user.id)

        # Verify cleanup
        expect(REDIS.exists?("matchmaking:user:#{user.id}")).to be_falsey
        expect(REDIS.llen("matchmaking:queue:#{game_type.id}")).to eq(0)
      end
    end

    context "when not in queue" do
      it "returns cancelled status (idempotent)" do
        delete "/api/v1/matchmaking/cancel",
               params: { game_type_id: game_type.id },
               headers: { "Authorization" => "Bearer #{token}" },
               as: :json

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["status"]).to eq("cancelled")
      end
    end

    context "when missing game_type_id" do
      it "returns bad_request error" do
        delete "/api/v1/matchmaking/cancel",
               headers: { "Authorization" => "Bearer #{token}" },
               as: :json

        expect(response).to have_http_status(:bad_request)
        json = response.parsed_body
        expect(json["error"]).to eq("missing_parameter")
        expect(json["message"]).to include("game_type_id is required")
      end
    end

    context "when unauthorized" do
      it "returns 401 without token" do
        delete "/api/v1/matchmaking/cancel",
               params: { game_type_id: game_type.id },
               as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
