defmodule GameServer.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      GameServerWeb.Telemetry,
      GameServer.Redis,
      {DNSCluster, query: Application.get_env(:game_server, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: GameServer.PubSub},
      GameServerWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: GameServer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    GameServerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
