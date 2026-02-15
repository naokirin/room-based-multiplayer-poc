defmodule GameServer.Rooms.RoomChat do
  @moduledoc """
  Chat message handling for a room: add message (ring buffer) and get history.

  Used by Room GenServer so chat logic stays in one place.
  """

  alias GameServer.Rooms.RoomBroadcast

  @doc """
  Add a chat message from a player. Returns {:ok, updated_state, message_id} or {:error, :not_in_room}.
  """
  def add_message(state, user_id, content, max_messages) do
    if Map.has_key?(state.players, user_id) do
      message_id = UUID.uuid4()
      player = Map.get(state.players, user_id)
      sender_name = player.display_name
      sent_at = DateTime.utc_now() |> DateTime.to_iso8601()

      message = %{
        id: message_id,
        sender_id: user_id,
        sender_name: sender_name,
        content: content,
        sent_at: sent_at
      }

      updated_messages = [message | state.chat_messages] |> Enum.take(max_messages)
      state = %{state | chat_messages: updated_messages}

      RoomBroadcast.broadcast_to_room(state.players, "chat:new_message", message)

      {:ok, state, message_id}
    else
      {:error, :not_in_room}
    end
  end

  @doc """
  Return chat history in chronological order (oldest first).
  """
  def get_history(state) do
    Enum.reverse(state.chat_messages)
  end
end
