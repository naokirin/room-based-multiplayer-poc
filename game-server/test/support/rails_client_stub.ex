defmodule GameServer.Api.RailsClientStub do
  @moduledoc """
  Default stub for RailsClientBehaviour used in tests.

  Returns `{:ok, %{}}` for all calls so that Room lifecycle
  notifications succeed silently without hitting the real Rails server.
  """

  @behaviour GameServer.Api.RailsClientBehaviour

  @impl GameServer.Api.RailsClientBehaviour
  def room_ready(_room_id, _node_name), do: {:ok, %{}}

  @impl GameServer.Api.RailsClientBehaviour
  def room_started(_room_id, _started_at, _player_ids), do: {:ok, %{}}

  @impl GameServer.Api.RailsClientBehaviour
  def room_finished(_room_id, _result_data), do: {:ok, %{}}

  @impl GameServer.Api.RailsClientBehaviour
  def room_aborted(_room_id, _reason), do: {:ok, %{}}

  @impl GameServer.Api.RailsClientBehaviour
  def verify_token(_token), do: {:error, :unauthorized}
end
