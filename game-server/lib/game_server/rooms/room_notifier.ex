defmodule GameServer.Rooms.RoomNotifier do
  @moduledoc """
  Thin wrapper around RailsClient for room lifecycle events.

  Calls the Rails internal API and logs success or failure so that Room
  does not repeat the same case/Logger pattern in multiple places.
  """

  require Logger
  alias GameServer.Api.RailsClient

  @doc "Notify Rails that a room is ready."
  def notify_room_ready(room_id, node_name) do
    case RailsClient.room_ready(room_id, node_name) do
      {:ok, _} ->
        Logger.info("Room #{room_id} ready on node #{node_name}")

      {:error, reason} ->
        Logger.error("Failed to notify Rails of room ready: #{inspect(reason)}")
    end
  end

  @doc "Notify Rails that a room has started."
  def notify_room_started(room_id, started_at, player_ids) do
    case RailsClient.room_started(room_id, started_at, player_ids) do
      {:ok, _} ->
        Logger.info("Room #{room_id} started successfully")

      {:error, reason} ->
        Logger.error("Failed to notify Rails of room start: #{inspect(reason)}")
    end
  end

  @doc "Notify Rails that a room has finished."
  def notify_room_finished(room_id, result_data) do
    case RailsClient.room_finished(room_id, result_data) do
      {:ok, _} ->
        Logger.info("Room #{room_id} finished successfully")

      {:error, reason} ->
        Logger.error("Failed to notify Rails of room finish: #{inspect(reason)}")
    end
  end

  @doc "Notify Rails that a room has been aborted."
  def notify_room_aborted(room_id, reason) do
    case RailsClient.room_aborted(room_id, to_string(reason)) do
      {:ok, _} ->
        Logger.info("Room #{room_id} aborted successfully")

      {:error, err} ->
        Logger.error("Failed to notify Rails of room abort: #{inspect(err)}")
    end
  end
end
