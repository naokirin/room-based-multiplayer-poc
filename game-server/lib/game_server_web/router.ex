defmodule GameServerWeb.Router do
  use GameServerWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Internal scope: currently only /internal/health (no auth). When adding
  # other internal routes, add API key auth to this pipeline.
  pipeline :internal do
    plug :accepts, ["json"]
  end

  # Public health check (e.g. Docker, load balancers). No auth.
  scope "/", GameServerWeb do
    pipe_through :api
    get "/health", HealthController, :show
  end

  scope "/internal", GameServerWeb do
    pipe_through :api
    get "/health", HealthController, :show
  end

  # Enable Swoosh mailbox preview in development
  if Application.compile_env(:game_server, :dev_routes) do
    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]
    end
  end
end
