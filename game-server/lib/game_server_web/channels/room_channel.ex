defmodule GameServerWeb.RoomChannel do
  @moduledoc """
  Phoenix Channel for game room communication.

  Handles:
  - Room joining with room_token or reconnect_token
  - Game actions (with rate limiting and nonce validation)
  - Chat messages
  - Player disconnect tracking
  """

  use Phoenix.Channel
  require Logger

  alias GameServer.Rooms.Room
  alias GameServer.Redis

  @rate_limit_window 1_000
  @chat_rate_limit_window 10_000
  @chat_rate_limit_count 5
  # 注意: client のチャット入力 maxLength および api-server のチャット関連制限と揃えること。
  @max_chat_length 500
  # Reconnect トークンを「使用済み」としてマークする際の Redis TTL（秒）。短い値で十分。
  @reconnect_token_used_ttl_seconds 10

  @impl true
  def join("room:" <> room_id, params, socket) do
    user_id = socket.assigns.user_id

    cond do
      Map.has_key?(params, "room_token") ->
        handle_room_token_join(room_id, user_id, params, socket)

      Map.has_key?(params, "reconnect_token") ->
        handle_reconnect_token_join(room_id, user_id, params, socket)

      true ->
        {:error, %{reason: "missing_token"}}
    end
  end

  @impl true
  def handle_in("game:action", payload, socket) do
    user_id = socket.assigns.user_id
    room_id = socket.assigns.room_id

    # Rate limit check
    case check_rate_limit(socket) do
      {:ok, updated_socket} ->
        nonce = Map.get(payload, "nonce")
        action = Map.drop(payload, ["nonce"])

        if nonce do
          case Room.handle_action(room_id, user_id, action, nonce) do
            :ok ->
              {:reply, :ok, updated_socket}

            {:error, reason} ->
              {:reply, {:error, %{reason: to_string(reason)}}, updated_socket}
          end
        else
          {:reply, {:error, %{reason: "missing_nonce"}}, updated_socket}
        end

      {:error, :rate_limited} ->
        {:reply, {:error, %{reason: "rate_limited"}}, socket}
    end
  end

  @impl true
  def handle_in("room:leave", _payload, socket) do
    user_id = socket.assigns.user_id
    room_id = socket.assigns.room_id

    Room.leave_voluntarily(room_id, user_id)
    {:reply, :ok, socket}
  end

  @impl true
  def handle_in("chat:send", payload, socket) do
    user_id = socket.assigns.user_id
    room_id = socket.assigns.room_id
    content = Map.get(payload, "content")

    # Validate content (missing, non-string, or empty)
    cond do
      content == nil or not is_binary(content) or String.trim(content) == "" ->
        {:reply, {:error, %{reason: "content_empty"}}, socket}

      String.length(content) > @max_chat_length ->
        {:reply, {:error, %{reason: "content_too_long"}}, socket}

      true ->
        # Check chat rate limit
        case check_chat_rate_limit(socket) do
          {:ok, updated_socket} ->
            case Room.add_chat_message(room_id, user_id, content) do
              {:ok, message_id} ->
                {:reply, {:ok, %{message_id: message_id, sent: true}}, updated_socket}

              {:error, reason} ->
                {:reply, {:error, %{reason: to_string(reason)}}, updated_socket}
            end

          {:error, :rate_limited} ->
            {:reply, {:error, %{reason: "rate_limited"}}, socket}
        end
    end
  end

  @impl true
  def handle_info({:broadcast, event, payload}, socket) do
    push(socket, event, payload)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:force_disconnect, reason}, socket) do
    push(socket, "force_disconnect", %{reason: reason})
    {:stop, :normal, socket}
  end

  @impl true
  def terminate(reason, socket) do
    Logger.debug("Channel terminating: #{inspect(reason)}")

    if Map.has_key?(socket.assigns, :room_id) and Map.has_key?(socket.assigns, :user_id) do
      room_id = socket.assigns.room_id
      user_id = socket.assigns.user_id

      Room.disconnect(room_id, user_id)
    end

    :ok
  end

  # Private Functions

  defp handle_room_token_join(room_id, user_id, params, socket) do
    room_token = Map.get(params, "room_token")

    # Verify token in Redis
    redis_key = "room_token:#{room_token}"

    case Redis.command(["GET", redis_key]) do
      {:ok, nil} ->
        {:error, %{reason: "invalid_token"}}

      {:ok, token_data_json} ->
        case Jason.decode(token_data_json) do
          {:ok, token_data} ->
            # Normalize to string for comparison (Redis/JSON may store ids as string or number)
            stored_room_id = token_data |> Map.get("room_id") |> to_string()
            stored_user_id = token_data |> Map.get("user_id") |> to_string()
            status = Map.get(token_data, "status")
            room_id_str = to_string(room_id)
            user_id_str = to_string(user_id)

            if stored_room_id == room_id_str and stored_user_id == user_id_str and
                 status == "pending" do
              # Mark token as used
              Redis.command([
                "SETEX",
                redis_key,
                @reconnect_token_used_ttl_seconds,
                Jason.encode!(%{status: "used"})
              ])

              # Get display name from params or use default
              display_name = Map.get(params, "display_name", "Player")

              # Join the room
              case Room.join(room_id, user_id, display_name, self()) do
                {:ok, room_state} ->
                  socket =
                    socket
                    |> assign(:room_id, room_id)
                    |> assign(:chat_messages, [])
                    |> assign(
                      :last_action_at,
                      System.monotonic_time(:millisecond) - @rate_limit_window
                    )

                  {:ok, room_state, socket}

                {:error, reason} ->
                  {:error, %{reason: to_string(reason)}}
              end
            else
              {:error, %{reason: "token_mismatch"}}
            end

          {:error, _} ->
            {:error, %{reason: "invalid_token_data"}}
        end

      {:error, reason} ->
        Logger.error("RoomChannel room_token Redis GET failed: #{inspect(reason)}")
        {:error, %{reason: "redis_error"}}
    end
  end

  defp handle_reconnect_token_join(room_id, user_id, params, socket) do
    reconnect_token = Map.get(params, "reconnect_token")

    # Verify reconnect token in Redis
    redis_key = "reconnect:#{room_id}:#{user_id}"

    case Redis.command(["GET", redis_key]) do
      {:ok, nil} ->
        {:error, %{reason: "invalid_reconnect_token"}}

      {:ok, stored_token} ->
        if stored_token == reconnect_token do
          # Rejoin the room
          case Room.rejoin(room_id, user_id, self()) do
            {:ok, full_state} ->
              socket =
                socket
                |> assign(:room_id, room_id)
                |> assign(:chat_messages, [])
                |> assign(:last_action_at, 0)

              {:ok, full_state, socket}

            {:error, reason} ->
              {:error, %{reason: to_string(reason)}}
          end
        else
          {:error, %{reason: "reconnect_token_mismatch"}}
        end

      {:error, reason} ->
        Logger.error("RoomChannel reconnect_token Redis GET failed: #{inspect(reason)}")
        {:error, %{reason: "redis_error"}}
    end
  end

  defp check_rate_limit(socket) do
    now = System.monotonic_time(:millisecond)
    last_action_at = socket.assigns.last_action_at

    if now - last_action_at >= @rate_limit_window do
      {:ok, assign(socket, :last_action_at, now)}
    else
      {:error, :rate_limited}
    end
  end

  defp check_chat_rate_limit(socket) do
    now = System.monotonic_time(:millisecond)
    chat_messages = Map.get(socket.assigns, :chat_messages, [])

    # Remove messages older than rate limit window
    recent_messages =
      Enum.filter(chat_messages, fn timestamp ->
        now - timestamp < @chat_rate_limit_window
      end)

    if length(recent_messages) >= @chat_rate_limit_count do
      {:error, :rate_limited}
    else
      updated_socket = assign(socket, :chat_messages, [now | recent_messages])
      {:ok, updated_socket}
    end
  end
end
