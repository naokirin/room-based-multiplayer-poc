defmodule GameServer.Games.GameBehaviour do
  @moduledoc """
  Behaviour defining the contract for game implementations.

  All game modules must implement these callbacks to integrate with the Room GenServer.
  """

  @doc """
  Initialize the game state with config and player IDs.

  ## Parameters
    - config: Game-specific configuration (e.g., deck definitions, rules)
    - player_ids: List of player IDs participating in the game

  ## Returns
    - `{:ok, game_state}` on success
  """
  @callback init_state(config :: map(), player_ids :: [String.t()]) ::
              {:ok, game_state :: map()}

  @doc """
  Validate whether a player can perform the given action.

  ## Parameters
    - game_state: Current game state
    - player_id: ID of the player attempting the action
    - action: The action to validate

  ## Returns
    - `:ok` if action is valid
    - `{:error, reason}` if action is invalid
  """
  @callback validate_action(
              game_state :: map(),
              player_id :: String.t(),
              action :: map()
            ) :: :ok | {:error, String.t()}

  @doc """
  Apply a validated action to the game state.

  ## Parameters
    - game_state: Current game state
    - player_id: ID of the player performing the action
    - action: The action to apply

  ## Returns
    - `{:ok, new_state, effects}` where effects is a list of game effects to broadcast
  """
  @callback apply_action(
              game_state :: map(),
              player_id :: String.t(),
              action :: map()
            ) :: {:ok, new_state :: map(), effects :: [map()]}

  @doc """
  Check if the game has reached an end condition.

  ## Parameters
    - game_state: Current game state

  ## Returns
    - `:continue` if the game should continue
    - `{:ended, winner_id, reason}` if the game has ended (winner_id can be nil for draw)
  """
  @callback check_end_condition(game_state :: map()) ::
              :continue | {:ended, winner_id :: String.t() | nil, reason :: String.t()}

  @doc """
  Handle a player being removed from the game (disconnect/leave).

  ## Parameters
    - game_state: Current game state
    - player_id: ID of the removed player

  ## Returns
    - `{:ok, new_state}` to continue the game with updated state
    - `{:ended, winner_id, reason}` to end the game
  """
  @callback on_player_removed(game_state :: map(), player_id :: String.t()) ::
              {:ok, new_state :: map()} | {:ended, winner_id :: String.t(), reason :: String.t()}
end
