defmodule GameServerWeb.RoomChannel do
  use Phoenix.Channel

  @impl true
  def join("room:" <> _room_id, _params, socket) do
    # Placeholder - will be implemented in Phase 3
    {:error, %{reason: "not_implemented"}}
  end
end
