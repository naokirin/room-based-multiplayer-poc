defmodule GameServer.Rooms.Room do
  @moduledoc """
  GenServer managing a single game room.

  Responsibilities:
  - Player connection/disconnection tracking
  - Game state management via Game Behaviour
  - Turn timer management
  - Nonce validation for action deduplication
  - Chat message handling
  - Game end detection and cleanup
  - Communication with Rails API
  """

  use GenServer
  require Logger

  alias GameServer.Api.RailsClient
  alias GameServer.Games.SimpleCardBattle

  @turn_time_limit 30
  @disconnect_timeout 60_000
  @termination_delay 30_000
  @max_nonces_per_player 50

  # Client API

  def start_link(opts) do
    room_id = Keyword.fetch!(opts, :room_id)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(room_id))
  end

  def child_spec(opts) do
    %{
      id: {__MODULE__, Keyword.fetch!(opts, :room_id)},
      start: {__MODULE__, :start_link, [opts]},
      restart: :temporary
    }
  end

  @doc """
  Join a room.
  """
  def join(room_id, user_id, display_name, channel_pid) do
    GenServer.call(via_tuple(room_id), {:join, user_id, display_name, channel_pid})
  end

  @doc """
  Rejoin a room (reconnect).
  """
  def rejoin(room_id, user_id, channel_pid) do
    GenServer.call(via_tuple(room_id), {:rejoin, user_id, channel_pid})
  end

  @doc """
  Handle a game action.
  """
  def handle_action(room_id, user_id, action, nonce) do
    GenServer.call(via_tuple(room_id), {:handle_action, user_id, action, nonce})
  end

  @doc """
  Handle player disconnect.
  """
  def disconnect(room_id, user_id) do
    GenServer.cast(via_tuple(room_id), {:disconnect, user_id})
  end

  @doc """
  Send a chat message.
  """
  def send_chat(room_id, user_id, message) do
    GenServer.cast(via_tuple(room_id), {:send_chat, user_id, message})
  end

  @doc """
  Get current room state (for debugging/admin).
  """
  def get_state(room_id) do
    GenServer.call(via_tuple(room_id), :get_state)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    room_id = Keyword.fetch!(opts, :room_id)
    game_type = Keyword.fetch!(opts, :game_type)
    game_config = Keyword.get(opts, :game_config, %{})
    expected_player_ids = Keyword.get(opts, :player_ids, [])

    # Start nonce cache for this room
    cache_name = nonce_cache_name(room_id)

    {:ok, _} =
      Cachex.start_link(cache_name,
        limit: @max_nonces_per_player * length(expected_player_ids)
      )

    state = %{
      room_id: room_id,
      game_type: game_type,
      game_module: game_module_for(game_type),
      game_config: game_config,
      game_state: nil,
      players: %{},
      expected_player_ids: expected_player_ids,
      status: :waiting,
      turn_timer_ref: nil,
      disconnect_timer_ref: nil,
      chat_messages: [],
      nonce_cache: cache_name
    }

    # Notify Rails that room is ready
    node_name = Atom.to_string(Node.self())

    case RailsClient.room_ready(room_id, node_name) do
      {:ok, _} ->
        Logger.info("Room #{room_id} ready on node #{node_name}")

      {:error, reason} ->
        Logger.error("Failed to notify Rails of room ready: #{inspect(reason)}")
    end

    {:ok, state}
  end

  @impl true
  def handle_call({:join, user_id, display_name, channel_pid}, _from, state) do
    if user_id in state.expected_player_ids do
      if Map.has_key?(state.players, user_id) do
        {:reply, {:error, :already_joined}, state}
      else
        player_info = %{
          display_name: display_name,
          connected: true,
          channel_pid: channel_pid
        }

        updated_players = Map.put(state.players, user_id, player_info)
        state = %{state | players: updated_players}

        # Monitor the channel process
        Process.monitor(channel_pid)

        # Broadcast player joined
        broadcast_to_room(state, "player:joined", %{
          user_id: user_id,
          display_name: display_name
        })

        # Check if all players have joined
        state =
          if map_size(state.players) == length(state.expected_player_ids) do
            start_game(state)
          else
            state
          end

        {:reply, {:ok, %{players: state.players, status: state.status}}, state}
      end
    else
      {:reply, {:error, :not_expected}, state}
    end
  end

  @impl true
  def handle_call({:rejoin, user_id, channel_pid}, _from, state) do
    if Map.has_key?(state.players, user_id) do
      player_info = Map.get(state.players, user_id)
      updated_player_info = %{player_info | connected: true, channel_pid: channel_pid}
      updated_players = Map.put(state.players, user_id, updated_player_info)
      state = %{state | players: updated_players}

      # Monitor the new channel process
      Process.monitor(channel_pid)

      # Cancel disconnect timer if all players are back
      state = maybe_cancel_disconnect_timer(state)

      # Broadcast player reconnected
      broadcast_to_room(state, "player:reconnected", %{user_id: user_id})

      # Send full state to rejoining player
      full_state = %{
        room_id: state.room_id,
        status: state.status,
        players: state.players,
        game_state: state.game_state,
        chat_messages: state.chat_messages
      }

      {:reply, {:ok, full_state}, state}
    else
      {:reply, {:error, :not_in_room}, state}
    end
  end

  @impl true
  def handle_call({:handle_action, user_id, action, nonce}, _from, state) do
    if state.status != :playing do
      {:reply, {:error, :game_not_started}, state}
    else
      # Check nonce
      case check_and_store_nonce(state.nonce_cache, user_id, nonce) do
        :ok ->
          process_action(state, user_id, action)

        {:error, :duplicate_nonce} ->
          {:reply, {:error, :duplicate_action}, state}
      end
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:disconnect, user_id}, state) do
    if Map.has_key?(state.players, user_id) do
      player_info = Map.get(state.players, user_id)
      updated_player_info = %{player_info | connected: false}
      updated_players = Map.put(state.players, user_id, updated_player_info)
      state = %{state | players: updated_players}

      # Broadcast player disconnected
      broadcast_to_room(state, "player:disconnected", %{user_id: user_id})

      # Check if all players are disconnected
      state =
        if all_players_disconnected?(state) do
          start_disconnect_timer(state)
        else
          state
        end

      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:send_chat, user_id, message}, state) do
    if Map.has_key?(state.players, user_id) do
      timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

      chat_message = %{
        user_id: user_id,
        message: message,
        timestamp: timestamp
      }

      state = %{state | chat_messages: [chat_message | state.chat_messages]}

      broadcast_to_room(state, "chat:message", chat_message)

      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:turn_timeout, turn_number}, state) do
    if state.status == :playing and state.game_state.turn_number == turn_number do
      Logger.info("Turn timeout in room #{state.room_id}, skipping turn")

      # Skip turn
      next_player_id = get_next_player_id(state)

      broadcast_to_room(state, "game:turn_skipped", %{
        turn_number: turn_number
      })

      state = advance_turn(state, next_player_id)

      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:disconnect_timeout, state) do
    if all_players_disconnected?(state) do
      Logger.info("All players disconnected for too long, aborting room #{state.room_id}")

      case RailsClient.room_aborted(state.room_id, "all_players_disconnected") do
        {:ok, _} ->
          Logger.info("Room #{state.room_id} aborted successfully")

        {:error, reason} ->
          Logger.error("Failed to notify Rails of room abort: #{inspect(reason)}")
      end

      state = %{state | status: :aborted}

      # Schedule termination
      Process.send_after(self(), :terminate_room, @termination_delay)

      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:terminate_room, state) do
    Logger.info("Terminating room #{state.room_id}")

    # Stop the nonce cache (Cachex cache is a GenServer)
    if Process.whereis(state.nonce_cache) do
      GenServer.stop(state.nonce_cache)
    end

    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Channel process died, find which player and mark as disconnected
    case find_player_by_pid(state, pid) do
      {:ok, user_id} ->
        handle_cast({:disconnect, user_id}, state)

      :not_found ->
        {:noreply, state}
    end
  end

  # Private Functions

  defp via_tuple(room_id) do
    {:via, Registry, {GameServer.RoomRegistry, room_id}}
  end

  defp game_module_for("simple_card_battle"), do: SimpleCardBattle
  defp game_module_for(_), do: SimpleCardBattle

  defp nonce_cache_name(room_id), do: :"nonce_cache_#{room_id}"

  defp start_game(state) do
    player_ids = Map.keys(state.players)

    case state.game_module.init_state(state.game_config, player_ids) do
      {:ok, game_state} ->
        state = %{state | game_state: game_state, status: :playing}

        # Notify Rails
        started_at = DateTime.utc_now() |> DateTime.to_iso8601()

        case RailsClient.room_started(state.room_id, started_at, player_ids) do
          {:ok, _} ->
            Logger.info("Room #{state.room_id} started successfully")

          {:error, reason} ->
            Logger.error("Failed to notify Rails of room start: #{inspect(reason)}")
        end

        # Broadcast game started with each player's hand
        Enum.each(state.players, fn {user_id, _player_info} ->
          player_state = get_in(game_state, [:players, user_id])

          send_to_player(state, user_id, "game:started", %{
            your_hand: player_state.hand,
            your_hp: player_state.hp,
            opponent_hp: get_opponent_hp(game_state, user_id),
            current_turn: game_state.current_turn,
            turn_number: game_state.turn_number
          })
        end)

        # Start turn timer
        start_turn_timer(state, game_state.turn_number)

      {:error, reason} ->
        Logger.error("Failed to start game in room #{state.room_id}: #{inspect(reason)}")
        state
    end
  end

  defp process_action(state, user_id, action) do
    game_state = state.game_state
    game_module = state.game_module

    with :ok <- game_module.validate_action(game_state, user_id, action),
         {:ok, new_game_state, effects} <- game_module.apply_action(game_state, user_id, action) do
      state = %{state | game_state: new_game_state}

      # Broadcast effects
      Enum.each(effects, fn effect ->
        broadcast_to_room(state, "game:action_applied", effect)
      end)

      # Check for game end
      case game_module.check_end_condition(new_game_state) do
        :continue ->
          # Advance turn
          next_player_id = get_next_player_id(state)
          state = advance_turn(state, next_player_id)

          # Send updated hand to acting player
          player_state = get_in(new_game_state, [:players, user_id])

          send_to_player(state, user_id, "game:hand_updated", %{
            hand: player_state.hand,
            deck_count: length(player_state.deck)
          })

          {:reply, :ok, state}

        {:ended, winner_id, reason} ->
          end_game(state, winner_id, reason)
          {:reply, :ok, state}
      end
    else
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  defp advance_turn(state, next_player_id) do
    game_state = state.game_state
    new_turn_number = game_state.turn_number + 1

    new_game_state =
      game_state
      |> Map.put(:current_turn, next_player_id)
      |> Map.put(:turn_number, new_turn_number)

    state = %{state | game_state: new_game_state}

    broadcast_to_room(state, "game:turn_changed", %{
      current_turn: next_player_id,
      turn_number: new_turn_number
    })

    # Cancel old timer and start new one
    if state.turn_timer_ref do
      Process.cancel_timer(state.turn_timer_ref)
    end

    start_turn_timer(state, new_turn_number)
  end

  defp end_game(state, winner_id, reason) do
    state = %{state | status: :finished}

    result_data = %{
      winner_id: winner_id,
      reason: reason,
      ended_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    broadcast_to_room(state, "game:ended", result_data)

    # Notify Rails
    case RailsClient.room_finished(state.room_id, result_data) do
      {:ok, _} ->
        Logger.info("Room #{state.room_id} finished successfully")

      {:error, reason} ->
        Logger.error("Failed to notify Rails of room finish: #{inspect(reason)}")
    end

    # Cancel turn timer
    if state.turn_timer_ref do
      Process.cancel_timer(state.turn_timer_ref)
    end

    # Schedule termination
    Process.send_after(self(), :terminate_room, @termination_delay)

    state
  end

  defp start_turn_timer(state, turn_number) do
    timer_ref = Process.send_after(self(), {:turn_timeout, turn_number}, @turn_time_limit * 1000)
    %{state | turn_timer_ref: timer_ref}
  end

  defp start_disconnect_timer(state) do
    if state.disconnect_timer_ref do
      Process.cancel_timer(state.disconnect_timer_ref)
    end

    timer_ref = Process.send_after(self(), :disconnect_timeout, @disconnect_timeout)
    %{state | disconnect_timer_ref: timer_ref}
  end

  defp maybe_cancel_disconnect_timer(state) do
    if not all_players_disconnected?(state) and state.disconnect_timer_ref do
      Process.cancel_timer(state.disconnect_timer_ref)
      %{state | disconnect_timer_ref: nil}
    else
      state
    end
  end

  defp all_players_disconnected?(state) do
    Enum.all?(state.players, fn {_user_id, player_info} ->
      not player_info.connected
    end)
  end

  defp get_next_player_id(state) do
    game_state = state.game_state
    current_turn = game_state.current_turn
    player_order = game_state.player_order

    current_index = Enum.find_index(player_order, &(&1 == current_turn))
    next_index = rem(current_index + 1, length(player_order))
    Enum.at(player_order, next_index)
  end

  defp get_opponent_hp(game_state, user_id) do
    opponent_id =
      Enum.find(game_state.player_order, &(&1 != user_id))

    get_in(game_state, [:players, opponent_id, :hp])
  end

  defp check_and_store_nonce(cache_name, user_id, nonce) do
    key = "#{user_id}:#{nonce}"

    case Cachex.get(cache_name, key) do
      {:ok, nil} ->
        Cachex.put(cache_name, key, true, ttl: :timer.minutes(5))
        :ok

      {:ok, _} ->
        {:error, :duplicate_nonce}

      {:error, _} ->
        {:error, :cache_error}
    end
  end

  defp broadcast_to_room(state, event, payload) do
    Enum.each(state.players, fn {_user_id, player_info} ->
      if player_info.connected do
        send(player_info.channel_pid, {:broadcast, event, payload})
      end
    end)
  end

  defp send_to_player(state, user_id, event, payload) do
    case Map.get(state.players, user_id) do
      %{connected: true, channel_pid: pid} ->
        send(pid, {:broadcast, event, payload})

      _ ->
        :ok
    end
  end

  defp find_player_by_pid(state, pid) do
    case Enum.find(state.players, fn {_user_id, player_info} ->
           player_info.channel_pid == pid
         end) do
      {user_id, _} -> {:ok, user_id}
      nil -> :not_found
    end
  end
end
