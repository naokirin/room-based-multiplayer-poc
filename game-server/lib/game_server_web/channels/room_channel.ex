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
  @max_chat_length 500

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
      :ok ->
        action = Map.get(payload, "action")
        nonce = Map.get(payload, "nonce")

        if nonce do
          case Room.handle_action(room_id, user_id, action, nonce) do
            :ok ->
              {:reply, :ok, socket}

            {:error, reason} ->
              {:reply, {:error, %{reason: to_string(reason)}}, socket}
          end
        else
          {:reply, {:error, %{reason: "missing_nonce"}}, socket}
        end

      {:error, :rate_limited} ->
        {:reply, {:error, %{reason: "rate_limited"}}, socket}
    end
  end

  @impl true
  def handle_in("chat:send", %{"content" => content}, socket) do
    user_id = socket.assigns.user_id
    room_id = socket.assigns.room_id

    # Validate content
    cond do
      content == nil or String.trim(content) == "" ->
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
            stored_room_id = Map.get(token_data, "room_id")
            stored_user_id = Map.get(token_data, "user_id")
            status = Map.get(token_data, "status")

            if stored_room_id == room_id and stored_user_id == user_id and status == "pending" do
              # Mark token as used
              Redis.command(["SETEX", redis_key, 10, Jason.encode!(%{status: "used"})])

              # Get display name from params or use default
              display_name = Map.get(params, "display_name", "Player")

              # Join the room
              case Room.join(room_id, user_id, display_name, self()) do
                {:ok, room_state} ->
                  socket =
                    socket
                    |> assign(:room_id, room_id)
                    |> assign(:last_action_at, 0)

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

      {:error, _reason} ->
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
                |> assign(:last_action_at, 0)

              {:ok, full_state, socket}

            {:error, reason} ->
              {:error, %{reason: to_string(reason)}}
          end
        else
          {:error, %{reason: "reconnect_token_mismatch"}}
        end

      {:error, _reason} ->
        {:error, %{reason: "redis_error"}}
    end
  end

  defp check_rate_limit(socket) do
    now = System.monotonic_time(:millisecond)
    last_action_at = Map.get(socket.assigns, :last_action_at, 0)

    if now - last_action_at >= @rate_limit_window do
      assign(socket, :last_action_at, now)
      :ok
    else
      {:error, :rate_limited}
    end
  end

  defp check_chat_rate_limit(socket) do
    now = System.monotonic_time(:millisecond)
    chat_messages = Map.get(socket.assigns, :chat_messages, [])

    # Remove messages older than rate limit window
    recent_messages = Enum.filter(chat_messages, fn timestamp ->
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
