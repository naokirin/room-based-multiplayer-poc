defmodule GameServerWeb.Plugs.RateLimiter do
  @moduledoc """
  Rate limiter plug using PlugAttack for HTTP endpoints.
  Limits requests per IP to prevent abuse.
  """

  use PlugAttack

  @throttle_period_ms 60_000
  @throttle_limit 60

  rule "throttle by ip", conn do
    throttle(conn.remote_ip,
      period: @throttle_period_ms,
      limit: @throttle_limit,
      storage: {PlugAttack.Storage.Ets, GameServerWeb.Plugs.RateLimiter.Storage}
    )
  end

  def allow_action(conn, {:throttle, data}, _opts) do
    conn
    |> Plug.Conn.put_resp_header("x-ratelimit-limit", to_string(data[:limit]))
    |> Plug.Conn.put_resp_header("x-ratelimit-remaining", to_string(data[:remaining]))
    |> Plug.Conn.put_resp_header("x-ratelimit-reset", to_string(data[:expires_at]))
  end

  def allow_action(conn, _data, _opts), do: conn

  def block_action(conn, {:throttle, data}, _opts) do
    conn
    |> Plug.Conn.put_resp_header("x-ratelimit-limit", to_string(data[:limit]))
    |> Plug.Conn.put_resp_header("x-ratelimit-remaining", "0")
    |> Plug.Conn.put_resp_header(
      "retry-after",
      to_string(div(data[:expires_at] - System.system_time(:millisecond), 1_000))
    )
    |> Plug.Conn.send_resp(
      429,
      Jason.encode!(%{error: "rate_limited", message: "Too many requests"})
    )
    |> Plug.Conn.halt()
  end

  def block_action(conn, _data, _opts) do
    conn
    |> Plug.Conn.send_resp(403, Jason.encode!(%{error: "forbidden"}))
    |> Plug.Conn.halt()
  end
end
