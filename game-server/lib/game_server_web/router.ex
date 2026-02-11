defmodule GameServerWeb.Router do
  use GameServerWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", GameServerWeb do
    pipe_through :api
  end
end
