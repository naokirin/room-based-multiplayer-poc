module Internal
  class RoomsController < ApplicationController
    # POST /internal/rooms - Room ready callback
    def create
      room_id = params[:room_id]
      node_name = params[:node_name]

      if room_id.blank?
        return render json: { error: "bad_request", message: "room_id is required" }, status: :bad_request
      end
      if node_name.blank?
        return render json: { error: "bad_request", message: "node_name is required" }, status: :bad_request
      end

      room = Room.find_by(id: room_id)
      unless room
        return render json: {
          error: "room_not_found",
          message: "Room with ID #{room_id} not found"
        }, status: :not_found
      end

      # Update room status to ready
      room.update!(
        status: :ready,
        node_name: node_name
      )

      # Update active_game status in Redis for all players
      room.room_players.each do |room_player|
        if REDIS.exists?("active_game:#{room_player.user_id}")
          REDIS.hset("active_game:#{room_player.user_id}", "status", "ready")
        end
      end

      render json: {
        acknowledged: true,
        room_id: room.id,
        room_status: room.status
      }, status: :ok
    end

    # PUT /internal/rooms/:room_id/started - Game started callback
    def started
      room = Room.find(params[:room_id])
      player_ids = params[:player_ids] || []

      # Verify player_ids match room players
      room_player_ids = room.room_players.pluck(:user_id).sort
      provided_player_ids = player_ids.sort

      unless room_player_ids == provided_player_ids
        return render json: {
          error: "player_mismatch",
          message: "Provided player_ids do not match room players",
          expected: room_player_ids,
          provided: provided_player_ids
        }, status: :bad_request
      end

      # Update room status to playing
      room.update!(
        status: :playing,
        started_at: Time.current
      )

      # Update active_game status in Redis
      room.room_players.each do |room_player|
        if REDIS.exists?("active_game:#{room_player.user_id}")
          REDIS.hset("active_game:#{room_player.user_id}", "status", "playing")
        end
      end

      render json: {
        acknowledged: true,
        room_status: "playing"
      }, status: :ok
    end

    # PUT /internal/rooms/:room_id/finished - Game finished callback
    def finished
      room = Room.find(params[:room_id])
      winner_id = params[:winner_id]
      turns_played = params[:turns_played] || 0
      duration_seconds = params[:duration_seconds] || 0
      # player_results: Hash of user_id (string) => result (e.g. "win", "lose", "draw") from Phoenix
      player_results = params[:player_results] || {}

      # Create GameResult record
      game_result = GameResult.create!(
        room_id: room.id,
        winner_id: winner_id,
        turns_played: turns_played,
        duration_seconds: duration_seconds
      )

      # Update room status and finished_at
      room.update!(
        status: :finished,
        finished_at: Time.current
      )

      # Update room_players results
      player_results.each do |user_id, result|
        room_player = room.room_players.find_by(user_id: user_id)
        if room_player
          room_player.update!(result: result)
        end
      end

      # Clean up active_game Redis keys
      RoomCreationService.cleanup_active_games(room)

      render json: {
        acknowledged: true,
        game_result_id: game_result.id
      }, status: :ok
    end

    # PUT /internal/rooms/:room_id/aborted - Game aborted callback
    def aborted
      room = Room.find(params[:room_id])

      # Update room status
      room.update!(
        status: :aborted
      )

      # Update room_players results to aborted
      room.room_players.update_all(result: :aborted)

      # Clean up active_game Redis keys
      RoomCreationService.cleanup_active_games(room)

      render json: {
        acknowledged: true,
        room_status: "aborted"
      }, status: :ok
    end
  end
end
