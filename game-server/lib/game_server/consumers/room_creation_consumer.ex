defmodule GameServer.Consumers.RoomCreationConsumer do
  @moduledoc """
  GenServer that polls Redis for room creation commands.

  Runs a BRPOP loop on the `room_creation_queue` Redis list using a dedicated
  Redix connection (:redix_brpop) to avoid blocking the shared connection.

  When a command is received:
  1. Parse the JSON command
  2. Spawn a Room GenServer via DynamicSupervisor
  3. On success, notify Rails via internal API
  4. On failure, log the error

  Uses exponential backoff on Redis connection errors.
  """

  use GenServer
  require Logger

  alias GameServer.Rooms.RoomSupervisor

  @queue_key "room_creation_queue"
  @brpop_timeout 5
  # Redix command timeout must exceed BRPOP timeout to avoid false timeouts
  @redix_timeout (@brpop_timeout + 2) * 1_000
  @max_backoff 30_000
  @initial_backoff 1_000

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_state) do
    send(self(), :poll)
    {:ok, %{backoff: @initial_backoff}}
  end

  @impl true
  def handle_info(:poll, state) do
    case Redix.command(:redix_brpop, ["BRPOP", @queue_key, @brpop_timeout],
           timeout: @redix_timeout
         ) do
      {:ok, nil} ->
        # Timeout, no items in queue - reset backoff and continue polling
        send(self(), :poll)
        {:noreply, %{state | backoff: @initial_backoff}}

      {:ok, [_queue_key, command_json]} ->
        # Got a command, process it
        handle_command(command_json)

        # Reset backoff and continue polling
        send(self(), :poll)
        {:noreply, %{state | backoff: @initial_backoff}}

      {:error, reason} ->
        # Redis error, apply backoff
        Logger.error("Redis BRPOP failed: #{inspect(reason)}, backing off #{state.backoff}ms")

        Process.send_after(self(), :poll, state.backoff)

        new_backoff = min(state.backoff * 2, @max_backoff)
        {:noreply, %{state | backoff: new_backoff}}
    end
  end

  defp handle_command(command_json) do
    case Jason.decode(command_json) do
      {:ok, command} ->
        process_command(command)

      {:error, reason} ->
        Logger.error("Failed to decode room creation command: #{inspect(reason)}")
    end
  end

  defp process_command(command) do
    room_id = Map.get(command, "room_id")
    game_type = Map.get(command, "game_type")
    game_config = Map.get(command, "game_config", %{})
    player_ids = Map.get(command, "player_ids", [])

    Logger.info("Creating room #{room_id} for game type #{game_type}")

    room_opts = [
      room_id: room_id,
      game_type: game_type,
      game_config: game_config,
      player_ids: player_ids
    ]

    case RoomSupervisor.start_room(room_opts) do
      {:ok, _pid} ->
        Logger.info("Room #{room_id} created successfully")

      {:error, {:already_started, _pid}} ->
        Logger.warning("Room #{room_id} already exists")

      {:error, reason} ->
        Logger.error("Failed to create room #{room_id}: #{inspect(reason)}")
    end
  end
end
