defmodule GameServerWeb.HealthController do
  use GameServerWeb, :controller

  def show(conn, _params) do
    redis_status = check_redis()
    rooms_count = count_active_rooms()
    overall = if redis_status == "ok", do: "ok", else: "degraded"
    status_code = if overall == "ok", do: 200, else: 503

    conn
    |> put_status(status_code)
    |> json(%{
      status: overall,
      node_name: node_name(),
      active_rooms: rooms_count,
      connected_players: 0,
      uptime_seconds: uptime_seconds()
    })
  end

  defp check_redis do
    case Redix.command(:redix, ["PING"]) do
      {:ok, "PONG"} -> "ok"
      _ -> "error"
    end
  rescue
    _ -> "error"
  end

  defp count_active_rooms do
    Registry.count(GameServer.RoomRegistry)
  end

  defp node_name do
    System.get_env("NODE_NAME", "game-server-1")
  end

  defp uptime_seconds do
    {uptime, _} = :erlang.statistics(:wall_clock)
    div(uptime, 1000)
  end
end
