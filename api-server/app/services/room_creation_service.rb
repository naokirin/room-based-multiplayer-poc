class RoomCreationService
  ROOM_TOKEN_TTL = 300 # 5 minutes
  ROOM_TIMEOUT = 15 # 15 seconds

  class << self
    # Create room, room players, and enqueue room creation job
    # Returns: { room:, room_tokens: {user_id => token}, ws_url: }
    def create_room(match, user_ids, game_type)
      # Create Room record
      room = Room.create!(
        game_type_id: game_type.id,
        player_count: game_type.player_count,
        status: :preparing
      )

      # Create RoomPlayer records and generate room tokens
      room_tokens = {}
      user_ids.each do |user_id|
        RoomPlayer.create!(
          room_id: room.id,
          user_id: user_id
        )

        # Generate room token (JWT)
        token = JwtService.encode(
          { room_id: room.id, user_id: user_id, type: "room_token" },
          expiration: ROOM_TOKEN_TTL.seconds
        )
        room_tokens[user_id] = token

        # Store room token in Redis
        REDIS.hset("room_token:#{token}", "room_id", room.id)
        REDIS.hset("room_token:#{token}", "user_id", user_id)
        REDIS.hset("room_token:#{token}", "status", "pending")
        REDIS.expire("room_token:#{token}", ROOM_TOKEN_TTL)

        # Set active game for user
        ws_url = ENV.fetch("GAME_SERVER_WS_URL", "ws://localhost:4000/socket")
        REDIS.hset("active_game:#{user_id}", "room_id", room.id)
        REDIS.hset("active_game:#{user_id}", "room_token", token)
        REDIS.hset("active_game:#{user_id}", "ws_url", ws_url)
        REDIS.hset("active_game:#{user_id}", "game_type_id", game_type.id)
        REDIS.hset("active_game:#{user_id}", "game_type_name", game_type.name)
        REDIS.hset("active_game:#{user_id}", "status", "preparing")
        # No TTL on active_game - cleaned up when room finishes/aborts
      end

      # Push room creation command to Redis queue for Phoenix to consume
      room_creation_command = {
        room_id: room.id,
        game_type_id: game_type.id,
        player_ids: user_ids,
        config: {
          player_count: game_type.player_count,
          turn_time_limit: game_type.turn_time_limit
        },
        enqueued_at: Time.current.iso8601
      }.to_json

      REDIS.lpush("room_creation_queue", room_creation_command)

      # Return room data
      {
        room: room,
        room_tokens: room_tokens,
        ws_url: ENV.fetch("GAME_SERVER_WS_URL", "ws://localhost:4000/socket")
      }
    end

    # Check if room has timed out during preparation
    def check_room_timeout(room_id)
      room = Room.find_by(id: room_id)
      return { status: :not_found } unless room
      return { status: :ok } unless room.preparing?

      # Check if room was created more than ROOM_TIMEOUT seconds ago
      if room.created_at < ROOM_TIMEOUT.seconds.ago
        # Mark room as failed
        room.update!(status: :failed)

        # Clean up active_game keys for all players
        room.room_players.each do |room_player|
          REDIS.del("active_game:#{room_player.user_id}")
        end

        # Update match status if exists
        if room.match
          room.match.update!(status: :timeout)
        end

        {
          status: :timeout,
          room_id: room.id,
          message: "Room creation timed out"
        }
      else
        {
          status: :ok,
          room_id: room.id,
          elapsed: Time.current - room.created_at
        }
      end
    end

    # Clean up active_game Redis keys for room players
    def cleanup_active_games(room)
      room.room_players.each do |room_player|
        REDIS.del("active_game:#{room_player.user_id}")
      end
    end
  end
end
