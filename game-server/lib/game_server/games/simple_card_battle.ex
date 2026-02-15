defmodule GameServer.Games.SimpleCardBattle do
  @moduledoc """
  Simple card battle game implementation.

  Game rules:
  - Each player starts with 10 HP
  - Players draw 3 cards from a shuffled deck at game start
  - Hand limit: 5 cards (draws that would exceed are capped)
  - Turn-based gameplay (players alternate turns)
  - Card effects: deal_damage, heal, draw_card, discard_opponent, reshuffle_hand (and composite)
  - Win conditions: reduce opponent HP to 0 or opponent runs out of cards (no deck reshuffle)
  - Lose condition: disconnect/forfeit
  """

  @behaviour GameServer.Games.GameBehaviour

  @initial_hp 10
  @initial_hand_size 3
  @max_hp 10
  @max_hand_size 5

  @doc """
  Initializes game state for exactly two players.

  `player_ids` must be a list of exactly two player IDs. Returns
  `{:error, :invalid_player_count}` for any other length.
  """
  @impl GameServer.Games.GameBehaviour
  def init_state(_config, player_ids) when length(player_ids) != 2 do
    {:error, :invalid_player_count}
  end

  @impl GameServer.Games.GameBehaviour
  def init_state(config, player_ids) when length(player_ids) == 2 do
    [player1_id, player2_id] = player_ids

    deck_cards = Map.get(config, "deck", default_deck())

    player1_state = init_player_state(deck_cards)
    player2_state = init_player_state(deck_cards)

    game_state = %{
      players: %{
        player1_id => Map.put(player1_state, :player_id, player1_id),
        player2_id => Map.put(player2_state, :player_id, player2_id)
      },
      current_turn: player1_id,
      turn_number: 1,
      player_order: [player1_id, player2_id]
    }

    {:ok, game_state}
  end

  @impl GameServer.Games.GameBehaviour
  def validate_action(game_state, player_id, %{"action" => "play_card"} = action) do
    with :ok <- validate_player_turn(game_state, player_id),
         :ok <- validate_card_in_hand(game_state, player_id, action) do
      :ok
    end
  end

  def validate_action(_game_state, _player_id, _action) do
    {:error, "invalid_action"}
  end

  @impl GameServer.Games.GameBehaviour
  def apply_action(game_state, player_id, %{"action" => "play_card"} = action) do
    card_id = Map.get(action, "card_id")
    player_state = get_in(game_state, [:players, player_id])

    # Find the card and remove it from hand first
    card_index = Enum.find_index(player_state.hand, &(&1["id"] == card_id))
    card = Enum.at(player_state.hand, card_index)
    hand_after_play = List.delete_at(player_state.hand, card_index)

    # Update game_state with card removed BEFORE applying effects,
    # so that draw_card effects append to the correct hand
    state_after_remove =
      put_in(game_state, [:players, player_id, :hand], hand_after_play)

    # Apply card effects (draw_card will add to hand_after_play)
    {updated_game_state, effects} =
      apply_card_effects(
        state_after_remove,
        player_id,
        card,
        Map.get(action, "target")
      )

    # Move card to discard pile
    updated_player_state =
      updated_game_state
      |> get_in([:players, player_id])
      |> Map.update(:discard, [card], &[card | &1])

    final_game_state = put_in(updated_game_state, [:players, player_id], updated_player_state)

    # Include full card for client display (both players see who played what)
    card_for_display = %{
      "id" => card["id"],
      "name" => card["name"],
      "effects" => Map.get(card, "effects", [])
    }

    card_played_effect = %{
      type: "card_played",
      player_id: player_id,
      card_id: card_id,
      card_name: card["name"],
      card: card_for_display
    }

    {:ok, final_game_state, [card_played_effect | effects]}
  end

  @impl GameServer.Games.GameBehaviour
  def check_end_condition(game_state) do
    Enum.reduce_while(game_state.players, :continue, fn {player_id, player_state}, _acc ->
      opponent_id = get_opponent_id(game_state, player_id)

      cond do
        player_state.hp <= 0 ->
          {:halt, {:ended, opponent_id, "hp_depleted"}}

        player_state.hp > 0 and Enum.empty?(player_state.hand) and Enum.empty?(player_state.deck) ->
          {:halt, {:ended, opponent_id, "cards_depleted"}}

        true ->
          {:cont, :continue}
      end
    end)
  end

  @impl GameServer.Games.GameBehaviour
  def on_player_removed(game_state, player_id) do
    opponent_id = get_opponent_id(game_state, player_id)
    {:ended, opponent_id, "opponent_forfeit"}
  end

  # Private functions

  defp init_player_state(deck_cards) do
    shuffled_deck = Enum.shuffle(deck_cards)
    {hand, remaining_deck} = Enum.split(shuffled_deck, @initial_hand_size)

    %{
      hp: @initial_hp,
      hand: hand,
      deck: remaining_deck,
      discard: []
    }
  end

  defp validate_player_turn(game_state, player_id) do
    if game_state.current_turn == player_id do
      :ok
    else
      {:error, "not_your_turn"}
    end
  end

  defp validate_card_in_hand(game_state, player_id, action) do
    card_id = Map.get(action, "card_id")
    player_state = get_in(game_state, [:players, player_id])

    if Enum.any?(player_state.hand, &(&1["id"] == card_id)) do
      :ok
    else
      {:error, "card_not_in_hand"}
    end
  end

  defp apply_card_effects(game_state, player_id, card, _target) do
    effects = Map.get(card, "effects", [])

    Enum.reduce(effects, {game_state, []}, fn effect, {current_state, effect_list} ->
      {updated_state, new_effects} = apply_single_effect(current_state, player_id, effect)
      {updated_state, effect_list ++ new_effects}
    end)
  end

  defp apply_single_effect(game_state, player_id, %{"effect" => "deal_damage", "value" => damage}) do
    opponent_id = get_opponent_id(game_state, player_id)
    opponent_state = get_in(game_state, [:players, opponent_id])
    new_hp = max(opponent_state.hp - damage, 0)

    updated_state =
      put_in(game_state, [:players, opponent_id, :hp], new_hp)

    effect = %{
      type: "damage_dealt",
      target_id: opponent_id,
      damage: damage,
      new_hp: new_hp
    }

    {updated_state, [effect]}
  end

  defp apply_single_effect(game_state, player_id, %{"effect" => "heal", "value" => heal_amount}) do
    player_state = get_in(game_state, [:players, player_id])
    new_hp = min(player_state.hp + heal_amount, @max_hp)

    updated_state = put_in(game_state, [:players, player_id, :hp], new_hp)

    effect = %{
      type: "healed",
      target_id: player_id,
      heal_amount: heal_amount,
      new_hp: new_hp
    }

    {updated_state, [effect]}
  end

  defp apply_single_effect(game_state, player_id, %{"effect" => "draw_card", "value" => count}) do
    player_state = get_in(game_state, [:players, player_id])
    slots_available = max(0, @max_hand_size - length(player_state.hand))
    draw_count = min(count, slots_available)

    {drawn_cards, remaining_deck} = draw_cards(player_state.deck, draw_count)
    new_hand = player_state.hand ++ drawn_cards

    updated_player_state =
      player_state
      |> Map.put(:hand, new_hand)
      |> Map.put(:deck, remaining_deck)

    updated_state = put_in(game_state, [:players, player_id], updated_player_state)

    effect = %{
      type: "cards_drawn",
      player_id: player_id,
      count: length(drawn_cards)
    }

    {updated_state, [effect]}
  end

  defp apply_single_effect(game_state, player_id, %{
         "effect" => "discard_opponent",
         "value" => count
       }) do
    opponent_id = get_opponent_id(game_state, player_id)
    opponent_state = get_in(game_state, [:players, opponent_id])
    hand = opponent_state.hand
    discard_count = min(count, length(hand))

    if discard_count == 0 do
      effect = %{
        type: "opponent_discarded",
        target_id: opponent_id,
        count: 0,
        discarded_card_ids: []
      }

      {game_state, [effect]}
    else
      to_discard = hand |> Enum.shuffle() |> Enum.take(discard_count)
      new_hand = hand -- to_discard
      new_discard = to_discard ++ (opponent_state.discard || [])

      updated_opponent =
        opponent_state
        |> Map.put(:hand, new_hand)
        |> Map.put(:discard, new_discard)

      updated_state = put_in(game_state, [:players, opponent_id], updated_opponent)
      discarded_ids = Enum.map(to_discard, & &1["id"])

      effect = %{
        type: "opponent_discarded",
        target_id: opponent_id,
        count: discard_count,
        discarded_card_ids: discarded_ids
      }

      {updated_state, [effect]}
    end
  end

  defp apply_single_effect(game_state, player_id, %{"effect" => "reshuffle_hand"}) do
    player_state = get_in(game_state, [:players, player_id])
    hand = player_state.hand
    hand_size = length(hand)

    if hand_size == 0 do
      effect = %{type: "hand_reshuffled", player_id: player_id, count: 0}
      {game_state, [effect]}
    else
      combined = hand ++ player_state.deck
      shuffled_deck = Enum.shuffle(combined)
      draw_count = min(hand_size, @max_hand_size)
      {drawn_cards, remaining_deck} = Enum.split(shuffled_deck, draw_count)

      updated_player_state =
        player_state
        |> Map.put(:hand, drawn_cards)
        |> Map.put(:deck, remaining_deck)

      updated_state = put_in(game_state, [:players, player_id], updated_player_state)

      effect = %{
        type: "hand_reshuffled",
        player_id: player_id,
        count: length(drawn_cards)
      }

      {updated_state, [effect]}
    end
  end

  defp apply_single_effect(game_state, _player_id, _effect) do
    # Unknown effect, skip
    {game_state, []}
  end

  defp draw_cards(deck, count) do
    Enum.split(deck, count)
  end

  defp get_opponent_id(game_state, player_id) do
    Enum.find(game_state.player_order, &(&1 != player_id))
  end

  defp default_deck do
    # 15-card deck: fewer Attack, base cards, Strip/Mulligan (replacing old Draw), composites
    attack_cards =
      for i <- 1..3 do
        %{
          "id" => "dmg_#{i}",
          "name" => "Attack",
          "effects" => [%{"effect" => "deal_damage", "value" => 3}]
        }
      end

    heal_cards =
      for i <- 1..2 do
        %{
          "id" => "heal_#{i}",
          "name" => "Heal",
          "effects" => [%{"effect" => "heal", "value" => 2}]
        }
      end

    # Opponent discards N cards from hand (replaces old 2-draw)
    strip_cards =
      for i <- 1..2 do
        %{
          "id" => "strip_#{i}",
          "name" => "Strip",
          "effects" => [%{"effect" => "discard_opponent", "value" => 1}]
        }
      end

    # Return hand to deck, shuffle, draw same number (replaces old 2-draw)
    mulligan_cards =
      for i <- 1..2 do
        %{
          "id" => "mulligan_#{i}",
          "name" => "Mulligan",
          "effects" => [%{"effect" => "reshuffle_hand"}]
        }
      end

    # Composite: 2 damage + 1 draw
    strike_cards =
      for i <- 1..2 do
        %{
          "id" => "strike_#{i}",
          "name" => "Strike",
          "effects" => [
            %{"effect" => "deal_damage", "value" => 2},
            %{"effect" => "draw_card", "value" => 1}
          ]
        }
      end

    # Composite: 1 heal + 1 draw
    burst_cards =
      for i <- 1..2 do
        %{
          "id" => "burst_#{i}",
          "name" => "Burst",
          "effects" => [
            %{"effect" => "heal", "value" => 1},
            %{"effect" => "draw_card", "value" => 1}
          ]
        }
      end

    # Composite: 1 damage + 1 heal
    vamp_cards =
      for i <- 1..2 do
        %{
          "id" => "vamp_#{i}",
          "name" => "Vamp",
          "effects" => [
            %{"effect" => "deal_damage", "value" => 1},
            %{"effect" => "heal", "value" => 1}
          ]
        }
      end

    attack_cards ++
      heal_cards ++ strip_cards ++ mulligan_cards ++ strike_cards ++ burst_cards ++ vamp_cards
  end
end
