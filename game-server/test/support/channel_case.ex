defmodule GameServerWeb.ChannelCase do
  @moduledoc """
  Test case for Phoenix Channel tests.

  Uses Phoenix.ChannelTest. Use `build_socket/1` in tests to get a socket
  with user_id assign (bypasses JWT for unit testing the channel).
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint GameServerWeb.Endpoint

      import Phoenix.ChannelTest
      import GameServerWeb.ChannelCase
    end
  end

  @doc """
  Builds a socket with the given user_id for channel tests.

  Bypasses UserSocket.connect/3 (no JWT). Use when testing channel logic
  that only needs socket.assigns.user_id.
  """
  defmacro build_socket(user_id \\ "test-user") do
    quote do
      socket(GameServerWeb.UserSocket, "user_socket:#{unquote(user_id)}", %{user_id: unquote(user_id)})
    end
  end
end
