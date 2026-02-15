defmodule GameServer.Api.RailsClientBehaviour do
  @moduledoc """
  Behaviour for the Rails internal API client.

  Allows swapping in a mock implementation during tests via Mox.
  """

  @callback room_ready(room_id :: String.t(), node_name :: String.t()) ::
              {:ok, map()} | {:error, term()}

  @callback room_started(
              room_id :: String.t(),
              started_at :: String.t(),
              player_ids :: [String.t()]
            ) ::
              {:ok, map()} | {:error, term()}

  @callback room_finished(room_id :: String.t(), result_data :: map()) ::
              {:ok, map()} | {:error, term()}

  @callback room_aborted(room_id :: String.t(), reason :: String.t()) ::
              {:ok, map()} | {:error, term()}

  @callback verify_token(token :: String.t()) ::
              {:ok, map()} | {:error, term()}
end
