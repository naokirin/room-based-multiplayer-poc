defmodule GameServerWeb.UserSocket do
  use Phoenix.Socket

  channel "room:*", GameServerWeb.RoomChannel

  @supported_protocol_versions ["1.0"]

  @impl true
  def connect(%{"token" => token, "protocol_version" => version} = _params, socket, _connect_info) do
    with :ok <- validate_protocol_version(version),
         {:ok, claims} <- GameServer.Auth.JWT.verify_token(token) do
      socket =
        socket
        |> assign(:user_id, claims["user_id"])
        |> assign(:protocol_version, version)

      {:ok, socket}
    else
      {:error, :unsupported_protocol_version} ->
        {:error, %{reason: "unsupported_protocol_version", supported: @supported_protocol_versions}}

      {:error, _reason} ->
        {:error, %{reason: "unauthorized"}}
    end
  end

  def connect(_params, _socket, _connect_info) do
    {:error, %{reason: "unauthorized"}}
  end

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.user_id}"

  defp validate_protocol_version(version) when version in @supported_protocol_versions, do: :ok
  defp validate_protocol_version(_), do: {:error, :unsupported_protocol_version}
end
