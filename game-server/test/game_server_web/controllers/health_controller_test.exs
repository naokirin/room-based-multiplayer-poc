defmodule GameServerWeb.HealthControllerTest do
  use GameServerWeb.ConnCase, async: true

  describe "GET /health" do
    test "returns 200 and body with expected keys when Redis is ok", %{conn: conn} do
      conn = get(conn, ~p"/health")

      assert conn.status == 200
      body = json_response(conn, 200)
      assert Map.has_key?(body, "status")
      assert body["status"] in ["ok", "degraded"]
      assert Map.has_key?(body, "node_name")
      assert Map.has_key?(body, "active_rooms")
      assert Map.has_key?(body, "connected_players")
      assert Map.has_key?(body, "uptime_seconds")
      assert is_integer(body["active_rooms"]) and body["active_rooms"] >= 0
      assert body["connected_players"] == 0
      assert is_integer(body["uptime_seconds"]) and body["uptime_seconds"] >= 0
    end

    test "response status is 200 or 503 depending on Redis", %{conn: conn} do
      conn = get(conn, ~p"/health")
      assert conn.status in [200, 503]
    end
  end
end
