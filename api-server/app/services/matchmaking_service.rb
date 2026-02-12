class MatchmakingService
  class << self
    # Add user to matchmaking queue for a specific game type
    # Returns: { status: :queued/:matched, data: {...} }
    def join_queue(user_id, game_type_id)
      # Check if user already has active game
      if active_game_exists?(user_id)
        active_game = get_active_game(user_id)
        return {
          status: :already_in_game,
          data: active_game
        }
      end

      # Check if user is already in queue
      if in_queue?(user_id, game_type_id)
        queue_info = get_queue_info(user_id)
        return {
          status: :already_queued,
          data: queue_info
        }
      end

      # Add to queue
      queue_entry = {
        user_id: user_id,
        queued_at: Time.current.iso8601
      }.to_json

      REDIS.lpush("matchmaking:queue:#{game_type_id}", queue_entry)
      REDIS.hset("matchmaking:user:#{user_id}", "game_type_id", game_type_id)
      REDIS.hset("matchmaking:user:#{user_id}", "queued_at", Time.current.iso8601)
      REDIS.expire("matchmaking:user:#{user_id}", 120) # 2 min TTL

      # Check if we can match immediately
      match_result = check_queue(game_type_id)
      if match_result[:status] == :matched
        match_result
      else
        {
          status: :queued,
          data: {
            game_type_id: game_type_id,
            queued_at: Time.current.iso8601,
            timeout_seconds: 60
          }
        }
      end
    end

    # Check queue and create match if enough players
    # Returns: { status: :waiting/:matched, data: {...} }
    def check_queue(game_type_id)
      game_type = GameType.find(game_type_id)
      required_players = game_type.player_count

      queue_key = "matchmaking:queue:#{game_type_id}"
      queue_length = REDIS.llen(queue_key)

      if queue_length < required_players
        return {
          status: :waiting,
          data: {
            current_players: queue_length,
            required_players: required_players
          }
        }
      end

      # Atomically pop N players using Lua script
      lua_script = <<~LUA
        local queue_key = KEYS[1]
        local count = tonumber(ARGV[1])
        local players = {}
        for i = 1, count do
          local player = redis.call('RPOP', queue_key)
          if player then
            table.insert(players, player)
          end
        end
        return players
      LUA

      popped_entries = REDIS.eval(lua_script, keys: [queue_key], argv: [required_players])

      if popped_entries.empty? || popped_entries.length < required_players
        # Put them back if we couldn't get enough
        popped_entries.each do |entry|
          REDIS.lpush(queue_key, entry)
        end
        return {
          status: :waiting,
          data: {
            current_players: queue_length,
            required_players: required_players
          }
        }
      end

      # Parse player entries
      players = popped_entries.map { |entry| JSON.parse(entry) }
      user_ids = players.map { |p| p["user_id"] }

      # Create Match record
      match = Match.create!(
        game_type_id: game_type_id,
        status: :matched
      )

      # Create MatchPlayer records
      user_ids.each do |user_id|
        match.match_players.create!(user_id: user_id)
      end

      # Create Room via RoomCreationService
      room_data = RoomCreationService.create_room(match, user_ids, game_type)

      # Clean up queue status for matched players
      user_ids.each do |user_id|
        REDIS.del("matchmaking:user:#{user_id}")
      end

      # Update match with room
      match.update!(room_id: room_data[:room].id)

      {
        status: :matched,
        data: room_data
      }
    end

    # Remove user from queue
    def cancel_queue(user_id, game_type_id)
      queue_key = "matchmaking:queue:#{game_type_id}"

      # Find and remove user's entry from queue
      queue_entries = REDIS.lrange(queue_key, 0, -1)
      queue_entries.each do |entry|
        parsed = JSON.parse(entry)
        if parsed["user_id"] == user_id
          REDIS.lrem(queue_key, 1, entry)
          break
        end
      end

      # Remove user queue status
      REDIS.del("matchmaking:user:#{user_id}")

      {
        status: :cancelled,
        data: { user_id: user_id }
      }
    end

    # Get queue status for a user
    def queue_status(user_id)
      # Check if user has active game
      if active_game_exists?(user_id)
        active_game = get_active_game(user_id)
        return {
          status: :matched,
          data: active_game
        }
      end

      # Check if user is in queue
      queue_info = get_queue_info(user_id)
      if queue_info
        # Check for timeout (60 seconds)
        queued_at = Time.parse(queue_info["queued_at"])
        if Time.current - queued_at > 60
          # Timeout - remove from queue
          cancel_queue(user_id, queue_info["game_type_id"])
          return {
            status: :timeout,
            data: {
              message: "Matchmaking timeout",
              queued_at: queue_info["queued_at"]
            }
          }
        end

        return {
          status: :queued,
          data: queue_info
        }
      end

      # Not in queue and no active game
      {
        status: :not_queued,
        data: {}
      }
    end

    private

    def active_game_exists?(user_id)
      REDIS.exists?("active_game:#{user_id}") == 1
    end

    def get_active_game(user_id)
      game_data = REDIS.hgetall("active_game:#{user_id}")
      game_data.present? ? game_data : nil
    end

    def in_queue?(user_id, game_type_id)
      queue_info = REDIS.hgetall("matchmaking:user:#{user_id}")
      queue_info.present? && queue_info["game_type_id"] == game_type_id
    end

    def get_queue_info(user_id)
      queue_info = REDIS.hgetall("matchmaking:user:#{user_id}")
      queue_info.present? ? queue_info : nil
    end
  end
end
