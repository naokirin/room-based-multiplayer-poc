defmodule GameServerWeb.ConnCase do
  @moduledoc """
  Test case for tests that require a connection (e.g. controller tests).

  Uses `Phoenix.ConnTest` and provides a default `conn` in setup.
  This project does not use Ecto/database; no SQL sandbox is configured.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint GameServerWeb.Endpoint

      use GameServerWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import GameServerWeb.ConnCase
    end
  end

  setup _tags do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
