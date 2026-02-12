defmodule GameServer.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      GameServerWeb.Telemetry,
      GameServer.Redis,
      {Registry, keys: :unique, name: GameServer.RoomRegistry},
      {Finch, name: GameServer.Finch},
      {DNSCluster, query: Application.get_env(:game_server, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: GameServer.PubSub},
      GameServer.Rooms.RoomSupervisor,
      GameServer.Consumers.RoomCreationConsumer,
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
