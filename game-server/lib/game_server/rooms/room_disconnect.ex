defmodule GameServer.Rooms.RoomDisconnect do
  @moduledoc """
  Player disconnect handling: mark disconnected, broadcast, start reconnect/disconnect timers.

  Used by Room GenServer so disconnect and "all players left" logic stays in one place.
  """

  require Logger

  alias GameServer.Rooms.RoomBroadcast
  alias GameServer.Rooms.RoomNotifier
  alias GameServer.Rooms.RoomTimers

  @doc """
  Returns true if every player in the room is marked disconnected.
  """
  def all_players_disconnected?(state) do
    Enum.all?(state.players, fn {_user_id, player_info} ->
      not player_info.connected
    end)
  end

  @doc """
  Apply a player disconnect: update state, broadcast, start reconnect timer if playing,
  and if all players are disconnected either abort (if all left voluntarily) or start
  the 60s disconnect timer.
  """
  def apply_disconnect(state, user_id, room_pid) do
    if Map.has_key?(state.players, user_id) do
      player_info = Map.get(state.players, user_id)
      updated_player_info = %{player_info | connected: false}
      updated_players = Map.put(state.players, user_id, updated_player_info)
      state = %{state | players: updated_players}

      RoomBroadcast.broadcast_to_room(state.players, "player:disconnected", %{user_id: user_id})

      state =
        if state.status == :playing do
          start_reconnect_timer_for_player(state, user_id, room_pid)
        else
          state
        end

      if all_players_disconnected?(state) do
        if all_left_voluntarily?(state) do
          Logger.info("All players left voluntarily, aborting room #{state.room_id} immediately")
          RoomNotifier.notify_room_aborted(state.room_id, "all_players_left")
          state = %{state | status: :aborted}
          RoomTimers.schedule_terminate(room_pid)
          state
        else
          %{state | disconnect_timer_ref: RoomTimers.start_disconnect_timer(room_pid, state.disconnect_timer_ref)}
        end
      else
        state
      end
    else
      state
    end
  end

  defp start_reconnect_timer_for_player(state, user_id, room_pid) do
    state = cancel_reconnect_timer_for_player(state, user_id)
    ref = RoomTimers.start_reconnect_timer(room_pid, user_id)
    %{state | reconnect_timers: Map.put(state.reconnect_timers, user_id, ref)}
  end

  defp cancel_reconnect_timer_for_player(state, user_id) do
    case Map.get(state.reconnect_timers, user_id) do
      nil ->
        state

      timer_ref ->
        RoomTimers.cancel(timer_ref)
        %{state | reconnect_timers: Map.delete(state.reconnect_timers, user_id)}
    end
  end

  defp all_left_voluntarily?(state) do
    player_ids = Map.keys(state.players) |> MapSet.new()
    MapSet.equal?(state.voluntary_leaves, player_ids)
  end
end
