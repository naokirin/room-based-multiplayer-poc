defmodule GameServer.Api.RailsClient do
  @moduledoc """
  HTTP client for communicating with Rails internal API.

  Uses Req with Finch adapter and automatic retry for transient errors.
  All requests include the X-Internal-Api-Key header for authentication.

  Base URL and API key are read at runtime so that Docker/runtime env (e.g.
  RAILS_INTERNAL_URL=http://api-server:3001) are applied correctly.
  """

  @behaviour GameServer.Api.RailsClientBehaviour

  @max_retries 3
  @retry_delay_base_ms 500
  @retry_delay_exponent 2

  @doc """
  Notify Rails that a room is ready.

  ## Parameters
    - room_id: The room ID
    - node_name: The Elixir node name where the room is running

  ## Returns
    - `{:ok, response}` on success
    - `{:error, reason}` on failure
  """
  @impl GameServer.Api.RailsClientBehaviour
  def room_ready(room_id, node_name) do
    body = %{
      room_id: room_id,
      node_name: node_name,
      status: "ready"
    }

    post("/internal/rooms", body)
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
  @impl GameServer.Api.RailsClientBehaviour
  def room_started(room_id, started_at, player_ids) do
    body = %{
      started_at: started_at,
      player_ids: player_ids
    }

    put("/internal/rooms/#{room_id}/started", body)
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
  @impl GameServer.Api.RailsClientBehaviour
  def room_finished(room_id, result_data) do
    body = %{
      result: result_data
    }

    put("/internal/rooms/#{room_id}/finished", body)
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
  @impl GameServer.Api.RailsClientBehaviour
  def room_aborted(room_id, reason) do
    body = %{
      reason: reason
    }

    put("/internal/rooms/#{room_id}/aborted", body)
  end

  @doc """
  Verify a token with Rails internal API.

  ## Parameters
    - token: The token to verify

  ## Returns
    - `{:ok, claims}` on success
    - `{:error, reason}` on failure
  """
  @impl GameServer.Api.RailsClientBehaviour
  def verify_token(token) do
    body = %{
      token: token
    }

    case post("/internal/auth/verify", body) do
      {:ok, response_body} ->
        {:ok, response_body}

      {:error, {:http_error, 401, _}} ->
        {:error, :unauthorized}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private: build base URL and headers from runtime env
  defp base_url do
    System.get_env("RAILS_INTERNAL_URL", "http://localhost:3001")
    |> String.trim_trailing("/")
  end

  defp internal_headers do
    key = System.get_env("INTERNAL_API_KEY", "")
    [{"content-type", "application/json"}, {"x-internal-api-key", key}]
  end

  defp req_options do
    [
      base_url: base_url(),
      headers: internal_headers(),
      finch: GameServer.Finch,
      retry: :transient,
      max_retries: @max_retries,
      retry_delay: fn attempt ->
        (@retry_delay_base_ms * :math.pow(@retry_delay_exponent, attempt)) |> round()
      end
    ]
  end

  defp post(path, body) do
    req = Req.new(req_options())

    case Req.post(req, url: path, json: body) do
      {:ok, %Req.Response{status: status, body: response_body}} when status in 200..299 ->
        {:ok, response_body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, %Req.TransportError{reason: reason}} ->
        {:error, reason}

      {:error, %Req.HTTPError{reason: reason}} ->
        {:error, reason}

      {:error, other} ->
        {:error, other}
    end
  end

  defp put(path, body) do
    req = Req.new(req_options())

    case Req.put(req, url: path, json: body) do
      {:ok, %Req.Response{status: status, body: response_body}} when status in 200..299 ->
        {:ok, response_body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, %Req.TransportError{reason: reason}} ->
        {:error, reason}

      {:error, %Req.HTTPError{reason: reason}} ->
        {:error, reason}

      {:error, other} ->
        {:error, other}
    end
  end
end
