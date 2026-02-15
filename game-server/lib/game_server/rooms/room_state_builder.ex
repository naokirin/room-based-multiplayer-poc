defmodule GameServer.Rooms.RoomStateBuilder do
  @moduledoc """
  Builds client-safe state payloads for join/rejoin responses.

  Used by Room GenServer so that join/rejoin reply construction stays in one place
  and Room remains focused on orchestration.
  """

  alias GameServer.Rooms.RoomBroadcast

  @doc """
  Build the reply state sent to the client on successful join.

  Returns a map with only JSON-serializable fields (no PIDs).
  """
  def join_reply_state(state, reconnect_token) do
    %{
      players: RoomBroadcast.players_for_client(state.players),
      status: state.status,
      reconnect_token: reconnect_token
    }
  end

  @doc """
  Build the full state sent to the client on successful rejoin.

  When the room is playing, includes game state (your_hand, current_turn, etc.).
  When waiting, includes only players and chat_messages.
  """
  def rejoin_full_state(state, user_id, turn_time_limit) do
    if state.status == :playing and state.game_state do
      build_playing_rejoin_state(state, user_id, turn_time_limit)
    else
      build_waiting_rejoin_state(state)
    end
  end

  defp build_playing_rejoin_state(state, user_id, turn_time_limit) do
    player_game_state = get_in(state.game_state, [:players, user_id])

    players_state =
      Enum.reduce(state.players, %{}, fn {player_id, pinfo}, acc ->
        game_player_state = get_in(state.game_state, [:players, player_id])

        player_data = %{
          display_name: pinfo.display_name,
          connected: pinfo.connected,
          hp: game_player_state[:hp],
          hand_count: length(game_player_state[:hand] || []),
          deck_count: length(game_player_state[:deck])
        }

        Map.put(acc, player_id, player_data)
      end)

    %{
      room_id: state.room_id,
      status: state.status,
      players: players_state,
      your_hand: RoomBroadcast.flatten_cards(player_game_state[:hand]),
      current_turn: state.game_state.current_turn,
      turn_number: state.game_state.turn_number,
      turn_time_remaining: turn_time_limit,
      chat_messages: state.chat_messages
    }
  end

  defp build_waiting_rejoin_state(state) do
    %{
      room_id: state.room_id,
      status: state.status,
      players: RoomBroadcast.players_for_client(state.players),
      chat_messages: state.chat_messages
    }
  end
end
