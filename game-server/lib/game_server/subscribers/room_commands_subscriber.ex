defmodule GameServer.Subscribers.RoomCommandsSubscriber do
  @moduledoc """
  Subscribes to Redis PubSub channel "room_commands" and dispatches
  commands (e.g., admin terminate) to local Room GenServer processes.
  """

  use GenServer

  require Logger

  @channel "room_commands"

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    redis_url = System.get_env("REDIS_URL", "redis://localhost:6379/0")

    case Redix.PubSub.start_link(redis_url, name: :redix_pubsub) do
      {:ok, pubsub} ->
        Redix.PubSub.subscribe(pubsub, @channel, self())
        Logger.info("[RoomCommandsSubscriber] Subscribed to #{@channel}")
        {:ok, %{pubsub: pubsub}}

      {:error, reason} ->
        Logger.error("[RoomCommandsSubscriber] Failed to connect: #{inspect(reason)}")
        {:ok, %{pubsub: nil}}
    end
  end

  @impl true
  def handle_info({:redix_pubsub, _pubsub, _ref, :subscribed, %{channel: channel}}, state) do
    Logger.info("[RoomCommandsSubscriber] Successfully subscribed to #{channel}")
    {:noreply, state}
  end

  @impl true
  def handle_info(
        {:redix_pubsub, _pubsub, _ref, :message, %{channel: @channel, payload: payload}},
        state
      ) do
    case Jason.decode(payload) do
      {:ok, command} ->
        handle_command(command)

      {:error, reason} ->
        Logger.warning("[RoomCommandsSubscriber] Invalid JSON: #{inspect(reason)}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:redix_pubsub, _pubsub, _ref, :disconnected, _info}, state) do
    Logger.warning("[RoomCommandsSubscriber] Redis disconnected, will auto-reconnect")
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp handle_command(%{"command" => "terminate", "room_id" => room_id} = cmd) do
    reason = Map.get(cmd, "reason", "admin_terminated")
    admin_id = Map.get(cmd, "admin_id")

    case Registry.lookup(GameServer.RoomRegistry, room_id) do
      [{pid, _}] ->
        Logger.info(
          "[RoomCommandsSubscriber] Terminating room #{room_id} (reason: #{reason}, admin: #{admin_id})"
        )

        GenServer.cast(pid, {:admin_terminate, reason})

      [] ->
        # Room not on this node, ignore
        :ok
    end
  end

  defp handle_command(cmd) do
    Logger.warning("[RoomCommandsSubscriber] Unknown command: #{inspect(cmd)}")
  end
end
