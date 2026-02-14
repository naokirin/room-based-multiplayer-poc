defmodule GameServer.Rooms.RoomTimers do
  @moduledoc """
  Timer scheduling for room lifecycle events.

  Sends messages to the given process (Room GenServer) after a delay.
  Room holds the returned refs and passes them back for cancellation where needed.
  """

  @turn_time_limit_ms 30_000
  @disconnect_timeout 60_000
  @reconnect_timeout 60_000
  @termination_delay 30_000
  @reveal_delay_ms 2_500

  @doc """
  Sends `{:turn_timeout, turn_number}` to `pid` after the turn time limit.

  Returns a timer reference for later cancellation.
  """
  def start_turn_timer(pid, turn_number) do
    Process.send_after(pid, {:turn_timeout, turn_number}, @turn_time_limit_ms)
  end

  @doc "Cancels a timer. No-op if ref is nil."
  def cancel(nil), do: :ok
  def cancel(ref), do: Process.cancel_timer(ref)

  @doc """
  Sends `:disconnect_timeout` to `pid` after the disconnect timeout.

  Cancels `previous_ref` if non-nil before starting. Returns the new timer reference.
  """
  def start_disconnect_timer(pid, previous_ref) do
    cancel(previous_ref)
    Process.send_after(pid, :disconnect_timeout, @disconnect_timeout)
  end

  @doc """
  Sends `{:reconnect_timeout, user_id}` to `pid` after the reconnect timeout.

  Returns a timer reference for later cancellation.
  """
  def start_reconnect_timer(pid, user_id) do
    Process.send_after(pid, {:reconnect_timeout, user_id}, @reconnect_timeout)
  end

  @doc "Sends `:terminate_room` to `pid` after the termination delay. Not cancelled by Room."
  def schedule_terminate(pid) do
    Process.send_after(pid, :terminate_room, @termination_delay)
    :ok
  end

  @doc "Sends `{:advance_turn_after_reveal, next_player_id}` to `pid` after the reveal delay."
  def schedule_advance_turn(pid, next_player_id) do
    Process.send_after(pid, {:advance_turn_after_reveal, next_player_id}, @reveal_delay_ms)
    :ok
  end
end
