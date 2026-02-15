require "rails_helper"

RSpec.describe "Internal::Rooms", type: :request do
  let(:api_key) { "test-internal-api-key" }
  let(:game_type) { create(:game_type) }
  let(:user1) { create(:user) }
  let(:user2) { create(:user) }
  let(:room) do
    Room.create!(
      game_type_id: game_type.id,
      player_count: 2,
      status: :preparing
    )
  end

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("INTERNAL_API_KEY").and_return(api_key)

    # Create room players
    RoomPlayer.create!(room_id: room.id, user_id: user1.id)
    RoomPlayer.create!(room_id: room.id, user_id: user2.id)

    # Clean up Redis
    REDIS.keys("active_game:*").each { |key| REDIS.del(key) }
  end

  describe "POST /internal/rooms" do
    context "with valid room ready callback" do
      before do
        # Set up active_game keys
        REDIS.hset("active_game:#{user1.id}", "room_id", room.id)
        REDIS.hset("active_game:#{user1.id}", "status", "preparing")
        REDIS.hset("active_game:#{user2.id}", "room_id", room.id)
        REDIS.hset("active_game:#{user2.id}", "status", "preparing")
      end

      it "updates room status to ready" do
        # Verify Redis keys exist before request
        expect(REDIS.exists?("active_game:#{user1.id}")).to be_truthy
        expect(REDIS.exists?("active_game:#{user2.id}")).to be_truthy

        post "/internal/rooms",
             params: { room_id: room.id, node_name: "game-node-1" },
             headers: { "X-Internal-Api-Key" => api_key },
             as: :json

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["acknowledged"]).to be true
        expect(json["room_id"]).to eq(room.id)
        expect(json["room_status"]).to eq("ready")

        # Verify room was updated
        room.reload
        expect(room.status).to eq("ready")
        expect(room.node_name).to eq("game-node-1")

        # Verify Redis was updated
        expect(REDIS.hget("active_game:#{user1.id}", "status")).to eq("ready")
        expect(REDIS.hget("active_game:#{user2.id}", "status")).to eq("ready")
      end
    end

    context "with missing room" do
      it "returns 404 error" do
        post "/internal/rooms",
             params: { room_id: 99999, node_name: "game-node-1" },
             headers: { "X-Internal-Api-Key" => api_key },
             as: :json

        expect(response).to have_http_status(:not_found)
        json = response.parsed_body
        expect(json["error"]).to eq("room_not_found")
        expect(json["message"]).to include("not found")
      end
    end

    context "without API key" do
      it "returns 401 error" do
        post "/internal/rooms",
             params: { room_id: room.id, node_name: "game-node-1" },
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PUT /internal/rooms/:room_id/started" do
    before do
      room.update!(status: :ready)
      # Set up active_game keys
      REDIS.hset("active_game:#{user1.id}", "room_id", room.id)
      REDIS.hset("active_game:#{user1.id}", "status", "ready")
      REDIS.hset("active_game:#{user2.id}", "room_id", room.id)
      REDIS.hset("active_game:#{user2.id}", "status", "ready")
    end

    context "with valid player_ids" do
      it "marks room as playing" do
        put "/internal/rooms/#{room.id}/started",
            params: { player_ids: [ user1.id, user2.id ] },
            headers: { "X-Internal-Api-Key" => api_key },
            as: :json

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["acknowledged"]).to be true
        expect(json["room_status"]).to eq("playing")

        # Verify room was updated
        room.reload
        expect(room.status).to eq("playing")
        expect(room.started_at).to be_present

        # Verify Redis was updated
        expect(REDIS.hget("active_game:#{user1.id}", "status")).to eq("playing")
        expect(REDIS.hget("active_game:#{user2.id}", "status")).to eq("playing")
      end
    end

    context "with player_ids in different order" do
      it "accepts players in any order" do
        put "/internal/rooms/#{room.id}/started",
            params: { player_ids: [ user2.id, user1.id ] },
            headers: { "X-Internal-Api-Key" => api_key },
            as: :json

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["acknowledged"]).to be true
      end
    end

    context "with mismatched player_ids" do
      let(:user3) { create(:user) }

      it "returns 400 error" do
        put "/internal/rooms/#{room.id}/started",
            params: { player_ids: [ user1.id, user3.id ] },
            headers: { "X-Internal-Api-Key" => api_key },
            as: :json

        expect(response).to have_http_status(:bad_request)
        json = response.parsed_body
        expect(json["error"]).to eq("player_mismatch")
        expect(json["message"]).to include("do not match")
        expect(json["expected"]).to be_present
        expect(json["provided"]).to be_present
      end
    end

    context "with missing room" do
      it "returns 404 error" do
        put "/internal/rooms/99999/started",
            params: { player_ids: [ user1.id, user2.id ] },
            headers: { "X-Internal-Api-Key" => api_key },
            as: :json

        expect(response).to have_http_status(:not_found)
      end
    end

    context "without API key" do
      it "returns 401 error" do
        put "/internal/rooms/#{room.id}/started",
            params: { player_ids: [ user1.id, user2.id ] },
            as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PUT /internal/rooms/:room_id/finished" do
    before do
      room.update!(status: :playing, started_at: 5.minutes.ago)
      # Set up active_game keys
      REDIS.hset("active_game:#{user1.id}", "room_id", room.id)
      REDIS.hset("active_game:#{user1.id}", "status", "playing")
      REDIS.hset("active_game:#{user2.id}", "room_id", room.id)
      REDIS.hset("active_game:#{user2.id}", "status", "playing")
    end

    context "with valid game result" do
      it "creates game result and updates players" do
        put "/internal/rooms/#{room.id}/finished",
            params: {
              winner_id: user1.id,
              turns_played: 10,
              duration_seconds: 300,
              player_results: {
                user1.id.to_s => "winner",
                user2.id.to_s => "loser"
              }
            },
            headers: { "X-Internal-Api-Key" => api_key },
            as: :json

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["acknowledged"]).to be true
        expect(json["game_result_id"]).to be_present

        # Verify room was updated
        room.reload
        expect(room.status).to eq("finished")
        expect(room.finished_at).to be_present

        # Verify game result was created
        game_result = GameResult.find(json["game_result_id"])
        expect(game_result.room_id).to eq(room.id)
        expect(game_result.winner_id).to eq(user1.id)
        expect(game_result.turns_played).to eq(10)
        expect(game_result.duration_seconds).to eq(300)

        # Verify room players were updated
        room_player1 = room.room_players.find_by(user_id: user1.id)
        room_player2 = room.room_players.find_by(user_id: user2.id)
        expect(room_player1.result).to eq("winner")
        expect(room_player2.result).to eq("loser")

        # Verify Redis cleanup
        expect(REDIS.exists?("active_game:#{user1.id}")).to be_falsey
        expect(REDIS.exists?("active_game:#{user2.id}")).to be_falsey
      end
    end

    context "with missing room" do
      it "returns 404 error" do
        put "/internal/rooms/99999/finished",
            params: { winner_id: user1.id },
            headers: { "X-Internal-Api-Key" => api_key },
            as: :json

        expect(response).to have_http_status(:not_found)
      end
    end

    context "without API key" do
      it "returns 401 error" do
        put "/internal/rooms/#{room.id}/finished",
            params: { winner_id: user1.id },
            as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PUT /internal/rooms/:room_id/aborted" do
    before do
      room.update!(status: :playing)
      # Set up active_game keys
      REDIS.hset("active_game:#{user1.id}", "room_id", room.id)
      REDIS.hset("active_game:#{user1.id}", "status", "playing")
      REDIS.hset("active_game:#{user2.id}", "room_id", room.id)
      REDIS.hset("active_game:#{user2.id}", "status", "playing")
    end

    context "with valid abort request" do
      it "marks room as aborted" do
        put "/internal/rooms/#{room.id}/aborted",
            headers: { "X-Internal-Api-Key" => api_key },
            as: :json

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["acknowledged"]).to be true
        expect(json["room_status"]).to eq("aborted")

        # Verify room was updated
        room.reload
        expect(room.status).to eq("aborted")

        # Verify all room players marked as aborted
        room.room_players.each do |room_player|
          expect(room_player.result).to eq("aborted")
        end

        # Verify Redis cleanup
        expect(REDIS.exists?("active_game:#{user1.id}")).to be_falsey
        expect(REDIS.exists?("active_game:#{user2.id}")).to be_falsey
      end
    end

    context "with missing room" do
      it "returns 404 error" do
        put "/internal/rooms/99999/aborted",
            headers: { "X-Internal-Api-Key" => api_key },
            as: :json

        expect(response).to have_http_status(:not_found)
      end
    end

    context "without API key" do
      it "returns 401 error" do
        put "/internal/rooms/#{room.id}/aborted",
            as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
