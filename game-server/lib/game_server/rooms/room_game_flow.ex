defmodule GameServer.Rooms.RoomGameFlow do
  @moduledoc """
  Game flow logic for a room: start game, process action, advance turn, end game.

  Used by Room GenServer so game loop and broadcasts stay in one place.
  Receives room_pid for timer scheduling.
  """

  require Logger

  alias GameServer.Rooms.RoomBroadcast
  alias GameServer.Rooms.RoomNotifier
  alias GameServer.Rooms.RoomTimers

  def start_game(state, room_pid, turn_time_limit) do
    player_ids = Map.keys(state.players)

    case state.game_module.init_state(state.game_config, player_ids) do
      {:ok, game_state} ->
        state = %{state | game_state: game_state, status: :playing}

        started_at = DateTime.utc_now() |> DateTime.to_iso8601()
        RoomNotifier.notify_room_started(state.room_id, started_at, player_ids)

        Enum.each(state.players, fn {user_id, pinfo} ->
          player_state = get_in(game_state, [:players, user_id])
          opponent_id = get_room_opponent_id(game_state, user_id)
          opponent_game_state = get_in(game_state, [:players, opponent_id])
          opponent_info = Map.get(state.players, opponent_id)

          RoomBroadcast.send_to_player(state.players, user_id, "game:started", %{
            your_hand: RoomBroadcast.flatten_cards(player_state.hand),
            your_hp: player_state.hp,
            your_deck_count: length(player_state.deck),
            your_display_name: pinfo.display_name,
            opponent_id: opponent_id,
            opponent_display_name: opponent_info.display_name,
            opponent_hp: opponent_game_state.hp,
            opponent_hand_count: length(opponent_game_state.hand),
            opponent_deck_count: length(opponent_game_state.deck),
            current_turn: game_state.current_turn,
            turn_number: game_state.turn_number,
            turn_time_remaining: turn_time_limit
          })
        end)

        %{state | turn_timer_ref: RoomTimers.start_turn_timer(room_pid, game_state.turn_number)}

      {:error, reason} ->
        Logger.error("Failed to start game in room #{state.room_id}: #{inspect(reason)}")
        state
    end
  end

  def process_action(state, user_id, action, room_pid) do
    game_state = state.game_state
    game_module = state.game_module

    with :ok <- game_module.validate_action(game_state, user_id, action),
         {:ok, new_game_state, effects} <- game_module.apply_action(game_state, user_id, action) do
      state = %{state | game_state: new_game_state}

      Enum.each(state.players, fn {player_id, pinfo} ->
        player_game_state = get_in(new_game_state, [:players, player_id])
        opp_id = get_room_opponent_id(new_game_state, player_id)
        opp_game_state = get_in(new_game_state, [:players, opp_id])
        opp_info = Map.get(state.players, opp_id)

        RoomBroadcast.send_to_player(state.players, player_id, "game:action_applied", %{
          actor_id: user_id,
          effects: effects,
          players: %{
            player_id => %{
              display_name: pinfo.display_name,
              connected: pinfo.connected,
              hp: player_game_state.hp,
              hand_count: length(player_game_state.hand),
              deck_count: length(player_game_state.deck)
            },
            opp_id => %{
              display_name: opp_info.display_name,
              connected: opp_info.connected,
              hp: opp_game_state.hp,
              hand_count: length(opp_game_state.hand),
              deck_count: length(opp_game_state.deck)
            }
          }
        })
      end)

      case game_module.check_end_condition(new_game_state) do
        :continue ->
          acting_player_state = get_in(new_game_state, [:players, user_id])

          RoomBroadcast.send_to_player(state.players, user_id, "game:hand_updated", %{
            hand: RoomBroadcast.flatten_cards(acting_player_state.hand),
            deck_count: length(acting_player_state.deck)
          })

          RoomTimers.cancel(state.turn_timer_ref)
          state = %{state | turn_timer_ref: nil}

          next_player_id = get_next_player_id(state)
          RoomTimers.schedule_advance_turn(room_pid, next_player_id)

          {:reply, :ok, state}

        {:ended, winner_id, reason} ->
          state = end_game(state, winner_id, reason, room_pid)
          {:reply, :ok, state}
      end
    else
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def advance_turn(state, next_player_id, room_pid, turn_time_limit) do
    game_state = state.game_state
    new_turn_number = game_state.turn_number + 1

    new_game_state =
      game_state
      |> Map.put(:current_turn, next_player_id)
      |> Map.put(:turn_number, new_turn_number)

    next_hand = get_in(new_game_state, [:players, next_player_id, :hand]) || []
    max_hand = max_hand_size_for_game(state.game_type)

    new_game_state =
      case {get_in(new_game_state, [:players, next_player_id, :deck]),
            length(next_hand) < max_hand} do
        {[top_card | rest_deck], true} ->
          new_game_state
          |> update_in([:players, next_player_id, :hand], &(&1 ++ [top_card]))
          |> put_in([:players, next_player_id, :deck], rest_deck)

        _ ->
          new_game_state
      end

    state = %{state | game_state: new_game_state}

    RoomBroadcast.broadcast_to_room(state.players, "game:turn_changed", %{
      current_turn: next_player_id,
      turn_number: new_turn_number,
      turn_time_remaining: turn_time_limit
    })

    next_player_state = get_in(new_game_state, [:players, next_player_id])

    RoomBroadcast.send_to_player(state.players, next_player_id, "game:hand_updated", %{
      hand: RoomBroadcast.flatten_cards(next_player_state.hand),
      deck_count: length(next_player_state.deck)
    })

    RoomTimers.cancel(state.turn_timer_ref)
    %{state | turn_timer_ref: RoomTimers.start_turn_timer(room_pid, new_turn_number)}
  end

  def end_game(state, winner_id, reason, room_pid) do
    state = %{state | status: :finished}

    result_data = %{
      winner_id: winner_id,
      reason: reason,
      ended_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    RoomBroadcast.broadcast_to_room(state.players, "game:ended", result_data)
    RoomNotifier.notify_room_finished(state.room_id, result_data)

    RoomTimers.cancel(state.turn_timer_ref)
    RoomTimers.schedule_terminate(room_pid)
    state
  end

  defp get_room_opponent_id(game_state, user_id) do
    Enum.find(game_state.player_order, &(&1 != user_id))
  end

  defp get_next_player_id(state) do
    game_state = state.game_state
    current_turn = game_state.current_turn
    player_order = game_state.player_order

    current_index = Enum.find_index(player_order, &(&1 == current_turn))
    next_index = rem(current_index + 1, length(player_order))
    Enum.at(player_order, next_index)
  end

  defp max_hand_size_for_game("simple_card_battle"), do: 5
  defp max_hand_size_for_game(_), do: 99
end
