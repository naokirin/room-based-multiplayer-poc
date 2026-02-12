defmodule GameServerWeb.Router do
  use GameServerWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :internal do
    plug :accepts, ["json"]
    # Internal API key auth will be added later
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
