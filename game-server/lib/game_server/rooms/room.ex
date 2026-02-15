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

  alias GameServer.Games.SimpleCardBattle
  alias GameServer.Rooms.RoomNotifier
  alias GameServer.Rooms.RoomTimers
  alias GameServer.Rooms.RoomBroadcast
  alias GameServer.Rooms.RoomChat
  alias GameServer.Rooms.RoomDisconnect
  alias GameServer.Rooms.RoomGameFlow
  alias GameServer.Rooms.RoomJoinRejoin

  # 注意: turn_time_limit は client のデフォルト turn_time_remaining 表示と揃えること。
  @turn_time_limit 30
  @max_nonces_per_player 50
  @max_chat_messages 100
  # 注意: reconnect_token_ttl は api-server が発行する reconnect トークンの有効期限と整合させること。
  @reconnect_token_ttl 300
  @nonce_cache_ttl_minutes 5

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
  Notify that a player is leaving voluntarily (e.g. clicked "Leave Game").
  When all players have left voluntarily, the room is aborted immediately.
  """
  def leave_voluntarily(room_id, user_id) do
    GenServer.cast(via_tuple(room_id), {:leave_voluntarily, user_id})
  end

  @doc """
  Handle player disconnect.
  """
  def disconnect(room_id, user_id) do
    GenServer.cast(via_tuple(room_id), {:disconnect, user_id})
  end

  @doc """
  Add a chat message.
  """
  def add_chat_message(room_id, user_id, content) do
    GenServer.call(via_tuple(room_id), {:add_chat_message, user_id, content})
  end

  @doc """
  Get chat history.
  """
  def get_chat_history(room_id) do
    GenServer.call(via_tuple(room_id), :get_chat_history)
  end

  @doc """
  Get current room state (for debugging/admin).
  """
  def get_state(room_id) do
    GenServer.call(via_tuple(room_id), :get_state)
  end

  # Server Callbacks

  @impl GenServer
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
      reconnect_timers: %{},
      voluntary_leaves: MapSet.new(),
      chat_messages: [],
      nonce_cache: cache_name
    }

    # Notify Rails that room is ready
    node_name = Atom.to_string(Node.self())
    RoomNotifier.notify_room_ready(room_id, node_name)

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:join, user_id, display_name, channel_pid}, _from, state) do
    case RoomJoinRejoin.apply_join(
           state,
           user_id,
           display_name,
           channel_pid,
           @reconnect_token_ttl
         ) do
      {:ok, state, reply_state} ->
        state =
          if map_size(state.players) == length(state.expected_player_ids) do
            RoomGameFlow.start_game(state, self(), @turn_time_limit)
          else
            state
          end

        {:reply, {:ok, reply_state}, state}

      {:error, :not_expected} ->
        {:reply, {:error, :not_expected}, state}
    end
  end

  @impl GenServer
  def handle_call({:rejoin, user_id, channel_pid}, _from, state) do
    case RoomJoinRejoin.apply_rejoin(state, user_id, channel_pid, @turn_time_limit) do
      {:ok, state, full_state} ->
        state = cancel_reconnect_timer_for_player(state, user_id)
        {:reply, {:ok, full_state}, state}

      {:error, :not_in_room} ->
        {:reply, {:error, :not_in_room}, state}
    end
  end

  @impl GenServer
  def handle_call({:handle_action, user_id, action, nonce}, _from, state) do
    if state.status != :playing do
      {:reply, {:error, :game_not_started}, state}
    else
      # Check nonce
      case check_and_store_nonce(state.nonce_cache, user_id, nonce) do
        :ok ->
          RoomGameFlow.process_action(state, user_id, action, self())

        {:error, :duplicate_nonce} ->
          {:reply, {:error, :duplicate_action}, state}
      end
    end
  end

  @impl GenServer
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl GenServer
  def handle_call({:add_chat_message, user_id, content}, _from, state) do
    case RoomChat.add_message(state, user_id, content, @max_chat_messages) do
      {:ok, state, message_id} -> {:reply, {:ok, message_id}, state}
      {:error, :not_in_room} -> {:reply, {:error, :not_in_room}, state}
    end
  end

  @impl GenServer
  def handle_call(:get_chat_history, _from, state) do
    history = RoomChat.get_history(state)
    {:reply, history, state}
  end

  @impl GenServer
  def handle_cast({:admin_terminate, reason}, state) do
    Logger.info("Room #{state.room_id} admin terminated: #{reason}")
    RoomNotifier.notify_room_aborted(state.room_id, reason)
    state = %{state | status: :aborted}
    RoomBroadcast.broadcast_to_room(state.players, "room:aborted", %{reason: reason})
    RoomTimers.schedule_terminate(self())
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:leave_voluntarily, user_id}, state) do
    state =
      if Map.has_key?(state.players, user_id) do
        %{state | voluntary_leaves: MapSet.put(state.voluntary_leaves, user_id)}
      else
        state
      end

    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:disconnect, user_id}, state) do
    state = RoomDisconnect.apply_disconnect(state, user_id, self())
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:turn_timeout, turn_number}, state) do
    if state.status == :playing and state.game_state.turn_number == turn_number do
      Logger.info("Turn timeout in room #{state.room_id}, skipping turn")

      next_player_id = get_next_player_id(state)

      RoomBroadcast.broadcast_to_room(state.players, "game:turn_skipped", %{
        turn_number: turn_number
      })

      state = RoomGameFlow.advance_turn(state, next_player_id, self(), @turn_time_limit)

      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info({:advance_turn_after_reveal, next_player_id}, state) do
    if state.status == :playing do
      state = RoomGameFlow.advance_turn(state, next_player_id, self(), @turn_time_limit)
      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info(:disconnect_timeout, state) do
    if RoomDisconnect.all_players_disconnected?(state) do
      Logger.info("All players disconnected for too long, aborting room #{state.room_id}")
      RoomNotifier.notify_room_aborted(state.room_id, "all_players_disconnected")
      state = %{state | status: :aborted}
      RoomTimers.schedule_terminate(self())

      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info({:reconnect_timeout, user_id}, state) do
    # T089: Handle reconnect timeout for a specific player
    player_info = Map.get(state.players, user_id)

    if player_info && !player_info.connected do
      Logger.info("Player #{user_id} failed to reconnect in time, removing from game")

      # Broadcast player left (T091)
      RoomBroadcast.broadcast_to_room(state.players, "player:left", %{
        user_id: user_id,
        reason: "reconnect_timeout"
      })

      # Call game behaviour's on_player_removed
      if state.status == :playing && state.game_state do
        case state.game_module.on_player_removed(state.game_state, user_id) do
          {:ended, winner_id, reason} ->
            state = RoomGameFlow.end_game(state, winner_id, reason, self())
            {:noreply, state}

          _ ->
            {:noreply, state}
        end
      else
        {:noreply, state}
      end
    else
      # Player already reconnected, ignore
      {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info(:terminate_room, state) do
    Logger.info("Terminating room #{state.room_id}")

    # Stop the nonce cache (Cachex cache is a GenServer)
    if Process.whereis(state.nonce_cache) do
      GenServer.stop(state.nonce_cache)
    end

    {:stop, :normal, state}
  end

  @impl GenServer
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

  defp cancel_reconnect_timer_for_player(state, user_id) do
    case Map.get(state.reconnect_timers, user_id) do
      nil ->
        state

      timer_ref ->
        RoomTimers.cancel(timer_ref)
        %{state | reconnect_timers: Map.delete(state.reconnect_timers, user_id)}
    end
  end

  defp get_next_player_id(state) do
    game_state = state.game_state
    current_turn = game_state.current_turn
    player_order = game_state.player_order

    current_index = Enum.find_index(player_order, &(&1 == current_turn))
    next_index = rem(current_index + 1, length(player_order))
    Enum.at(player_order, next_index)
  end

  defp check_and_store_nonce(cache_name, user_id, nonce) do
    key = "#{user_id}:#{nonce}"

    case Cachex.get(cache_name, key) do
      {:ok, nil} ->
        Cachex.put(cache_name, key, true, ttl: :timer.minutes(@nonce_cache_ttl_minutes))
        :ok

      {:ok, _} ->
        {:error, :duplicate_nonce}

      {:error, _} ->
        {:error, :cache_error}
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
