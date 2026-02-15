defmodule GameServer.Application do
  @moduledoc false

  use Application

  @impl Application
  def start(_type, _args) do
    children = [
      {PlugAttack.Storage.Ets,
       name: GameServerWeb.Plugs.RateLimiter.Storage, clean_period: 60_000},
      GameServerWeb.Telemetry,
      GameServer.Redis,
      {Registry, keys: :unique, name: GameServer.RoomRegistry},
      {Finch, name: GameServer.Finch},
      {DNSCluster, query: Application.get_env(:game_server, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: GameServer.PubSub},
      GameServer.Rooms.RoomSupervisor,
      # Dedicated Redix connection for BRPOP (blocking command must not share connection)
      %{
        id: :redix_brpop,
        start:
          {Redix, :start_link,
           [System.get_env("REDIS_URL", "redis://localhost:6379/0"), [name: :redix_brpop]]}
      },
      GameServer.Consumers.RoomCreationConsumer,
      GameServer.Subscribers.RoomCommandsSubscriber,
      GameServerWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: GameServer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl Application
  def config_change(changed, _new, removed) do
    GameServerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
