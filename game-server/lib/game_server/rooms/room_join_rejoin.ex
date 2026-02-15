defmodule GameServer.Rooms.RoomJoinRejoin do
  @moduledoc """
  Join and rejoin logic for game rooms.

  Handles reconnect token generation, Redis storage, player map updates,
  process monitoring, and broadcast. Room GenServer delegates to these functions
  and then performs follow-up (e.g. start_game, cancel_reconnect_timer).
  """

  require Logger

  alias GameServer.Redis
  alias GameServer.Rooms.RoomBroadcast
  alias GameServer.Rooms.RoomStateBuilder

  @doc """
  Apply a join: duplicate handling, reconnect token, update state, broadcast, build reply.

  Returns `{:ok, updated_state, reply_state}` or `{:error, :not_expected}`.
  The caller (Room) is responsible for calling `start_game(updated_state)` if all players have joined.
  """
  def apply_join(state, user_id, display_name, channel_pid, reconnect_token_ttl) do
    if user_id in state.expected_player_ids do
      state = maybe_disconnect_duplicate(state, user_id)

      reconnect_token = UUID.uuid4()
      redis_key = "reconnect:#{state.room_id}:#{user_id}"

      case Redis.command(["SETEX", redis_key, reconnect_token_ttl, reconnect_token]) do
        {:ok, _} -> :ok
        {:error, reason} -> Logger.error("Failed to store reconnect token: #{inspect(reason)}")
      end

      player_info = %{
        display_name: display_name,
        connected: true,
        channel_pid: channel_pid
      }

      updated_players = Map.put(state.players, user_id, player_info)
      state = %{state | players: updated_players}

      Process.monitor(channel_pid)

      RoomBroadcast.broadcast_to_room(state.players, "player:joined", %{
        user_id: user_id,
        display_name: display_name
      })

      reply_state = RoomStateBuilder.join_reply_state(state, reconnect_token)
      {:ok, state, reply_state}
    else
      {:error, :not_expected}
    end
  end

  @doc """
  Apply a rejoin: update player as connected, monitor channel, broadcast, build full state.

  Returns `{:ok, updated_state, full_state}` or `{:error, :not_in_room}`.
  The caller (Room) should call `cancel_reconnect_timer_for_player(updated_state, user_id)` before replying.
  """
  def apply_rejoin(state, user_id, channel_pid, turn_time_limit) do
    if Map.has_key?(state.players, user_id) do
      player_info = Map.get(state.players, user_id)
      updated_player_info = %{player_info | connected: true, channel_pid: channel_pid}
      updated_players = Map.put(state.players, user_id, updated_player_info)
      state = %{state | players: updated_players}

      Process.monitor(channel_pid)

      RoomBroadcast.broadcast_to_room(state.players, "player:reconnected", %{user_id: user_id})

      full_state = RoomStateBuilder.rejoin_full_state(state, user_id, turn_time_limit)
      {:ok, state, full_state}
    else
      {:error, :not_in_room}
    end
  end

  defp maybe_disconnect_duplicate(state, user_id) do
    if Map.has_key?(state.players, user_id) do
      old_player_info = Map.get(state.players, user_id)

      if old_player_info.connected do
        send(old_player_info.channel_pid, {:force_disconnect, "duplicate_connection"})
      end

      state
    else
      state
    end
  end
end
