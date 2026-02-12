defmodule GameServer.Api.RailsClient do
  @moduledoc """
  HTTP client for communicating with Rails internal API.

  Uses Tesla with Finch adapter and automatic retry with exponential backoff.
  All requests include the X-Internal-Api-Key header for authentication.
  """

  use Tesla

  @base_url System.get_env("RAILS_INTERNAL_URL", "http://localhost:3001")
  @api_key System.get_env("INTERNAL_API_KEY", "")
  @max_retries 3
  @retry_delay 500

  plug Tesla.Middleware.BaseUrl, @base_url
  plug Tesla.Middleware.JSON
  plug Tesla.Middleware.Headers, [
    {"content-type", "application/json"},
    {"x-internal-api-key", @api_key}
  ]

  plug Tesla.Middleware.Retry,
    delay: @retry_delay,
    max_retries: @max_retries,
    max_delay: 5_000,
    should_retry: fn
      {:ok, %{status: status}} when status in [500, 502, 503, 504] -> true
      {:ok, _} -> false
      {:error, _} -> true
    end

  adapter Tesla.Adapter.Finch, name: GameServer.Finch

  @doc """
  Notify Rails that a room is ready.

  ## Parameters
    - room_id: The room ID
    - node_name: The Elixir node name where the room is running

  ## Returns
    - `{:ok, response}` on success
    - `{:error, reason}` on failure
  """
  def room_ready(room_id, node_name) do
    body = %{
      room_id: room_id,
      node_name: node_name,
      status: "ready"
    }

    case post("/internal/rooms", body) do
      {:ok, %Tesla.Env{status: status, body: response_body}} when status in 200..299 ->
        {:ok, response_body}

      {:ok, %Tesla.Env{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Notify Rails that a room has started.

  ## Parameters
    - room_id: The room ID
    - started_at: ISO8601 timestamp when the game started
    - player_ids: List of player IDs in the game

  ## Returns
    - `{:ok, response}` on success
    - `{:error, reason}` on failure
  """
  def room_started(room_id, started_at, player_ids) do
    body = %{
      started_at: started_at,
      player_ids: player_ids
    }

    case put("/internal/rooms/#{room_id}/started", body) do
      {:ok, %Tesla.Env{status: status, body: response_body}} when status in 200..299 ->
        {:ok, response_body}

      {:ok, %Tesla.Env{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Notify Rails that a room has finished.

  ## Parameters
    - room_id: The room ID
    - result_data: Map containing game result (winner_id, reason, etc.)

  ## Returns
    - `{:ok, response}` on success
    - `{:error, reason}` on failure
  """
  def room_finished(room_id, result_data) do
    body = %{
      result: result_data
    }

    case put("/internal/rooms/#{room_id}/finished", body) do
      {:ok, %Tesla.Env{status: status, body: response_body}} when status in 200..299 ->
        {:ok, response_body}

      {:ok, %Tesla.Env{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Notify Rails that a room has been aborted.

  ## Parameters
    - room_id: The room ID
    - reason: Reason for abortion (e.g., "all_players_disconnected")

  ## Returns
    - `{:ok, response}` on success
    - `{:error, reason}` on failure
  """
  def room_aborted(room_id, reason) do
    body = %{
      reason: reason
    }

    case put("/internal/rooms/#{room_id}/aborted", body) do
      {:ok, %Tesla.Env{status: status, body: response_body}} when status in 200..299 ->
        {:ok, response_body}

      {:ok, %Tesla.Env{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Verify a token with Rails internal API.

  ## Parameters
    - token: The token to verify

  ## Returns
    - `{:ok, claims}` on success
    - `{:error, reason}` on failure
  """
  def verify_token(token) do
    body = %{
      token: token
    }

    case post("/internal/auth/verify", body) do
      {:ok, %Tesla.Env{status: 200, body: response_body}} ->
        {:ok, response_body}

      {:ok, %Tesla.Env{status: 401}} ->
        {:error, :unauthorized}

      {:ok, %Tesla.Env{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
