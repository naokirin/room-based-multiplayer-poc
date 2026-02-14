defmodule GameServer.Rooms.RoomBroadcast do
  @moduledoc """
  Helpers for broadcasting events to room players and building client-safe payloads.

  Used by Room GenServer to send WebSocket messages via channel PIDs and to
  serialize game state (e.g. cards, players) for JSON without PIDs.
  """

  @doc """
  Send an event and payload to all connected players in the room.
  """
  def broadcast_to_room(players, event, payload) do
    Enum.each(players, fn {_user_id, player_info} ->
      if player_info.connected do
        send(player_info.channel_pid, {:broadcast, event, payload})
      end
    end)
  end

  @doc """
  Send an event and payload to a single player if connected.
  """
  def send_to_player(players, user_id, event, payload) do
    case Map.get(players, user_id) do
      %{connected: true, channel_pid: pid} ->
        send(pid, {:broadcast, event, payload})

      _ ->
        :ok
    end
  end

  @doc """
  Build a players map for client (no channel_pid; PIDs are not JSON-serializable).
  """
  def players_for_client(players) do
    Map.new(players, fn {user_id, info} ->
      {user_id, %{display_name: info.display_name, connected: info.connected}}
    end)
  end

  @doc """
  Serialize a list of cards for the client (effect names and values only).
  """
  def flatten_cards(nil), do: []
  def flatten_cards(cards), do: Enum.map(cards, &flatten_card/1)

  @doc """
  Serialize a single card for the client.
  """
  def flatten_card(card) do
    effects_list = card["effects"] || []
    first_effect = List.first(effects_list) || %{}
    effects_for_client =
      Enum.map(effects_list, fn e -> %{"effect" => e["effect"], "value" => e["value"] || 0} end)

    %{
      "id" => card["id"],
      "name" => card["name"],
      "effect" => first_effect["effect"],
      "value" => first_effect["value"] || 0,
      "effects" => effects_for_client
    }
  end
end
