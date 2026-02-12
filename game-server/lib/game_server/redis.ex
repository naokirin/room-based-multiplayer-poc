defmodule GameServer.Redis do
  @moduledoc """
  Redis connection management using Redix.
  """

  def child_spec(_opts) do
    redis_url = System.get_env("REDIS_URL", "redis://localhost:6379/0")

    %{
      id: __MODULE__,
      start: {Redix, :start_link, [redis_url, [name: :redix]]}
    }
  end

  def command(command) do
    Redix.command(:redix, command)
  end

  def command!(command) do
    Redix.command!(:redix, command)
  end

  def pipeline(commands) do
    Redix.pipeline(:redix, commands)
  end
end
