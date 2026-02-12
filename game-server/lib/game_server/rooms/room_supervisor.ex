defmodule GameServer.Rooms.RoomSupervisor do
  @moduledoc """
  DynamicSupervisor for managing Room GenServer processes.

  Each room runs as a separate GenServer process under this supervisor.
  Rooms are started dynamically when created and are supervised with
  a :temporary restart strategy (no automatic restart on crash).
  """

  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Start a new room process under this supervisor.

  ## Parameters
    - room_config: Map containing room configuration (room_id, game_type, etc.)

  ## Returns
    - `{:ok, pid}` if the room was started successfully
    - `{:error, reason}` if the room failed to start
  """
  def start_room(room_config) do
    child_spec = {GameServer.Rooms.Room, room_config}
    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  @doc """
  Stop a room process.

  ## Parameters
    - room_pid: PID of the room process to stop

  ## Returns
    - `:ok` if the room was stopped successfully
    - `{:error, reason}` if the room could not be stopped
  """
  def stop_room(room_pid) when is_pid(room_pid) do
    DynamicSupervisor.terminate_child(__MODULE__, room_pid)
  end
end
