defmodule GameServer.Games.SimpleCardBattleTest do
  use ExUnit.Case, async: true

  alias GameServer.Games.SimpleCardBattle

  # Use string IDs to match GameBehaviour and production (JWT user_id)
  @player1_id "1"
  @player2_id "2"

  describe "init_state/2" do
    test "creates players with 10 HP" do
      config = %{}
      player_ids = [@player1_id, @player2_id]

      {:ok, game_state} = SimpleCardBattle.init_state(config, player_ids)

      assert game_state.players[@player1_id].hp == 10
      assert game_state.players[@player2_id].hp == 10
    end

    test "creates players with 3 cards in hand" do
      config = %{}
      player_ids = [@player1_id, @player2_id]

      {:ok, game_state} = SimpleCardBattle.init_state(config, player_ids)

      assert length(game_state.players[@player1_id].hand) == 3
      assert length(game_state.players[@player2_id].hand) == 3
    end

    test "deck size is correct (15 cards total, 3 in hand = 12 remaining)" do
      config = %{}
      player_ids = [@player1_id, @player2_id]

      {:ok, game_state} = SimpleCardBattle.init_state(config, player_ids)

      # Default deck has 15 cards, 3 drawn = 12 remaining
      assert length(game_state.players[@player1_id].deck) == 12
      assert length(game_state.players[@player2_id].deck) == 12
    end

    test "sets current_turn to first player" do
      config = %{}
      player_ids = [@player1_id, @player2_id]

      {:ok, game_state} = SimpleCardBattle.init_state(config, player_ids)

      assert game_state.current_turn == @player1_id
      assert game_state.turn_number == 1
    end

    test "initializes with empty discard piles" do
      config = %{}
      player_ids = [@player1_id, @player2_id]

      {:ok, game_state} = SimpleCardBattle.init_state(config, player_ids)

      assert game_state.players[@player1_id].discard == []
      assert game_state.players[@player2_id].discard == []
    end

    test "returns error for non-two players" do
      assert SimpleCardBattle.init_state(%{}, []) == {:error, :invalid_player_count}
      assert SimpleCardBattle.init_state(%{}, [@player1_id]) == {:error, :invalid_player_count}

      assert SimpleCardBattle.init_state(%{}, [@player1_id, @player2_id, "3"]) ==
               {:error, :invalid_player_count}
    end
  end

  describe "validate_action/3" do
    setup do
      config = %{}
      player_ids = [@player1_id, @player2_id]
      {:ok, game_state} = SimpleCardBattle.init_state(config, player_ids)
      %{game_state: game_state}
    end

    test "validates valid play_card action", %{game_state: game_state} do
      card = List.first(game_state.players[@player1_id].hand)
      action = %{"action" => "play_card", "card_id" => card["id"]}

      assert SimpleCardBattle.validate_action(game_state, @player1_id, action) == :ok
    end

    test "rejects play_card when not your turn", %{game_state: game_state} do
      card = List.first(game_state.players[@player2_id].hand)
      action = %{"action" => "play_card", "card_id" => card["id"]}

      assert SimpleCardBattle.validate_action(game_state, @player2_id, action) ==
               {:error, "not_your_turn"}
    end

    test "rejects play_card when card not in hand", %{game_state: game_state} do
      action = %{"action" => "play_card", "card_id" => "nonexistent_card"}

      assert SimpleCardBattle.validate_action(game_state, @player1_id, action) ==
               {:error, "card_not_in_hand"}
    end

    test "rejects invalid action type", %{game_state: game_state} do
      action = %{"action" => "invalid_action"}

      assert SimpleCardBattle.validate_action(game_state, @player1_id, action) ==
               {:error, "invalid_action"}
    end
  end

  describe "apply_action/3" do
    setup do
      config = %{}
      player_ids = [@player1_id, @player2_id]
      {:ok, game_state} = SimpleCardBattle.init_state(config, player_ids)
      %{game_state: game_state}
    end

    test "deal_damage reduces opponent HP", %{game_state: game_state} do
      # Find a damage card (Attack card), or add one if not in hand
      damage_card =
        Enum.find(game_state.players[@player1_id].hand, fn card ->
          card["name"] == "Attack"
        end)

      game_state =
        if damage_card == nil do
          damage_card = %{
            "id" => "test_attack",
            "name" => "Attack",
            "effects" => [%{"effect" => "deal_damage", "value" => 3}]
          }

          updated_hand = [damage_card | Enum.drop(game_state.players[@player1_id].hand, 1)]
          put_in(game_state, [:players, @player1_id, :hand], updated_hand)
        else
          game_state
        end

      damage_card =
        Enum.find(game_state.players[@player1_id].hand, fn card ->
          card["name"] == "Attack"
        end)

      action = %{"action" => "play_card", "card_id" => damage_card["id"]}

      {:ok, updated_state, effects} =
        SimpleCardBattle.apply_action(game_state, @player1_id, action)

      # Attack card deals 3 damage (10 - 3 = 7)
      assert updated_state.players[@player2_id].hp == 7

      # Check effects
      assert Enum.any?(effects, fn effect ->
               effect.type == "damage_dealt" and effect.target_id == @player2_id
             end)
    end

    test "heal increases HP (capped at max HP)", %{game_state: game_state} do
      # Set player1 HP to 5
      game_state =
        put_in(game_state, [:players, @player1_id, :hp], 5)

      # Find a heal card, or add one if not in hand
      heal_card =
        Enum.find(game_state.players[@player1_id].hand, fn card ->
          card["name"] == "Heal"
        end)

      game_state =
        if heal_card == nil do
          heal_card = %{
            "id" => "test_heal",
            "name" => "Heal",
            "effects" => [%{"effect" => "heal", "value" => 2}]
          }

          updated_hand = [heal_card | Enum.drop(game_state.players[@player1_id].hand, 1)]
          put_in(game_state, [:players, @player1_id, :hand], updated_hand)
        else
          game_state
        end

      heal_card =
        Enum.find(game_state.players[@player1_id].hand, fn card ->
          card["name"] == "Heal"
        end)

      action = %{"action" => "play_card", "card_id" => heal_card["id"]}

      {:ok, updated_state, effects} =
        SimpleCardBattle.apply_action(game_state, @player1_id, action)

      # Heal card heals 2 HP (5 + 2 = 7)
      assert updated_state.players[@player1_id].hp == 7

      # Check effects
      assert Enum.any?(effects, fn effect ->
               effect.type == "healed" and effect.target_id == @player1_id
             end)
    end

    test "heal is capped at max HP (10)", %{game_state: game_state} do
      # Set player1 HP to 9
      game_state =
        put_in(game_state, [:players, @player1_id, :hp], 9)

      # Find a heal card (or add one if not in hand)
      heal_card =
        Enum.find(game_state.players[@player1_id].hand, fn card ->
          card["name"] == "Heal"
        end)

      # If no heal card in hand, replace first card with a heal card
      game_state =
        if heal_card == nil do
          heal_card = %{
            "id" => "test_heal",
            "name" => "Heal",
            "effects" => [%{"effect" => "heal", "value" => 2}]
          }

          updated_hand = [heal_card | Enum.drop(game_state.players[@player1_id].hand, 1)]
          put_in(game_state, [:players, @player1_id, :hand], updated_hand)
        else
          game_state
        end

      heal_card =
        Enum.find(game_state.players[@player1_id].hand, fn card ->
          card["name"] == "Heal"
        end)

      action = %{"action" => "play_card", "card_id" => heal_card["id"]}

      {:ok, updated_state, _effects} =
        SimpleCardBattle.apply_action(game_state, @player1_id, action)

      # Heal card heals 2 HP but capped at 10 (9 + 2 = 11 -> 10)
      assert updated_state.players[@player1_id].hp == 10
    end

    test "draw_card draws cards from deck", %{game_state: game_state} do
      initial_hand_size = length(game_state.players[@player1_id].hand)

      # Find a draw card, or add one if not in hand
      draw_card =
        Enum.find(game_state.players[@player1_id].hand, fn card ->
          card["name"] == "Draw"
        end)

      game_state =
        if draw_card == nil do
          draw_card = %{
            "id" => "test_draw",
            "name" => "Draw",
            "effects" => [%{"effect" => "draw_card", "value" => 2}]
          }

          updated_hand = [draw_card | Enum.drop(game_state.players[@player1_id].hand, 1)]
          put_in(game_state, [:players, @player1_id, :hand], updated_hand)
        else
          game_state
        end

      draw_card =
        Enum.find(game_state.players[@player1_id].hand, fn card ->
          card["name"] == "Draw"
        end)

      action = %{"action" => "play_card", "card_id" => draw_card["id"]}

      {:ok, updated_state, effects} =
        SimpleCardBattle.apply_action(game_state, @player1_id, action)

      # After playing draw card: hand had initial_hand_size, remove 1 = initial_hand_size - 1.
      # Then draw 2 (capped by hand limit 5): hand = (initial_hand_size - 1) + 2, max 5.
      final_hand_size = length(updated_state.players[@player1_id].hand)
      assert final_hand_size == min(initial_hand_size - 1 + 2, 5)

      # Check effects to see if draw happened
      draw_effect = Enum.find(effects, fn effect -> effect.type == "cards_drawn" end)
      assert draw_effect != nil
      assert draw_effect.player_id == @player1_id
      # The effect should show some cards were drawn
      assert draw_effect.count > 0
    end

    test "draw_card is capped by hand limit (5)", %{game_state: game_state} do
      # Fill hand to 5 with dummy cards so draw has no room
      full_hand =
        for i <- 1..5, do: %{"id" => "dummy_#{i}", "name" => "Dummy", "effects" => []}

      game_state =
        game_state
        |> put_in([:players, @player1_id, :hand], full_hand)
        |> put_in([:players, @player1_id, :deck], [
          %{
            "id" => "draw_1",
            "name" => "Draw",
            "effects" => [%{"effect" => "draw_card", "value" => 2}]
          }
          | Enum.take(game_state.players[@player1_id].deck, 10)
        ])

      # Replace one card in hand with Draw
      draw_card = %{
        "id" => "test_draw",
        "name" => "Draw",
        "effects" => [%{"effect" => "draw_card", "value" => 2}]
      }

      hand_with_draw = [draw_card | Enum.take(full_hand, 4)]
      game_state = put_in(game_state, [:players, @player1_id, :hand], hand_with_draw)

      action = %{"action" => "play_card", "card_id" => draw_card["id"]}

      {:ok, updated_state, effects} =
        SimpleCardBattle.apply_action(game_state, @player1_id, action)

      # Hand was 5, we removed 1 (the Draw card) = 4 slots. Draw 2 would give 6, but cap is 5, so we draw only 1
      assert length(updated_state.players[@player1_id].hand) == 5

      draw_effect = Enum.find(effects, fn e -> e.type == "cards_drawn" end)
      assert draw_effect.count == 1
    end

    test "discard_opponent removes cards from opponent hand", %{game_state: game_state} do
      strip_card = %{
        "id" => "strip_1",
        "name" => "Strip",
        "effects" => [%{"effect" => "discard_opponent", "value" => 1}]
      }

      hand_with_strip = [strip_card | Enum.take(game_state.players[@player1_id].hand, 2)]
      game_state = put_in(game_state, [:players, @player1_id, :hand], hand_with_strip)
      opponent_initial_count = length(game_state.players[@player2_id].hand)

      action = %{"action" => "play_card", "card_id" => strip_card["id"]}

      {:ok, updated_state, effects} =
        SimpleCardBattle.apply_action(game_state, @player1_id, action)

      assert length(updated_state.players[@player2_id].hand) == opponent_initial_count - 1
      discard_effect = Enum.find(effects, fn e -> e.type == "opponent_discarded" end)
      assert discard_effect != nil
      assert discard_effect.target_id == @player2_id
      assert discard_effect.count == 1
    end

    test "reshuffle_hand returns hand to deck and draws same number", %{game_state: game_state} do
      mulligan_card = %{
        "id" => "mulligan_1",
        "name" => "Mulligan",
        "effects" => [%{"effect" => "reshuffle_hand"}]
      }

      hand_with_mulligan = [mulligan_card | Enum.take(game_state.players[@player1_id].hand, 2)]
      game_state = put_in(game_state, [:players, @player1_id, :hand], hand_with_mulligan)
      hand_size_before = 2

      action = %{"action" => "play_card", "card_id" => mulligan_card["id"]}

      {:ok, updated_state, effects} =
        SimpleCardBattle.apply_action(game_state, @player1_id, action)

      assert length(updated_state.players[@player1_id].hand) == hand_size_before
      reshuffle_effect = Enum.find(effects, fn e -> e.type == "hand_reshuffled" end)
      assert reshuffle_effect != nil
      assert reshuffle_effect.player_id == @player1_id
      assert reshuffle_effect.count == hand_size_before
    end

    test "played card is moved to discard pile", %{game_state: game_state} do
      card = List.first(game_state.players[@player1_id].hand)
      action = %{"action" => "play_card", "card_id" => card["id"]}

      {:ok, updated_state, _effects} =
        SimpleCardBattle.apply_action(game_state, @player1_id, action)

      # Card should be in discard pile
      assert length(updated_state.players[@player1_id].discard) == 1
      assert List.first(updated_state.players[@player1_id].discard)["id"] == card["id"]

      # Card should not be in hand
      refute Enum.any?(updated_state.players[@player1_id].hand, fn c -> c["id"] == card["id"] end)
    end
  end

  describe "check_end_condition/1" do
    setup do
      config = %{}
      player_ids = [@player1_id, @player2_id]
      {:ok, game_state} = SimpleCardBattle.init_state(config, player_ids)
      %{game_state: game_state}
    end

    test "returns :continue when both players alive", %{game_state: game_state} do
      assert SimpleCardBattle.check_end_condition(game_state) == :continue
    end

    test "returns :ended when player HP is 0", %{game_state: game_state} do
      # Set player2 HP to 0
      game_state =
        put_in(game_state, [:players, @player2_id, :hp], 0)

      assert SimpleCardBattle.check_end_condition(game_state) ==
               {:ended, @player1_id, "hp_depleted"}
    end

    test "returns :ended when player HP is negative", %{game_state: game_state} do
      # Set player1 HP to -5
      game_state =
        put_in(game_state, [:players, @player1_id, :hp], -5)

      assert SimpleCardBattle.check_end_condition(game_state) ==
               {:ended, @player2_id, "hp_depleted"}
    end

    test "returns :ended when hand and deck are empty", %{game_state: game_state} do
      # Empty player2's hand and deck
      game_state =
        game_state
        |> put_in([:players, @player2_id, :hand], [])
        |> put_in([:players, @player2_id, :deck], [])

      assert SimpleCardBattle.check_end_condition(game_state) ==
               {:ended, @player1_id, "cards_depleted"}
    end

    test "continues when deck is empty but hand has cards", %{game_state: game_state} do
      # Empty player2's deck but keep hand
      game_state =
        put_in(game_state, [:players, @player2_id, :deck], [])

      assert SimpleCardBattle.check_end_condition(game_state) == :continue
    end

    test "continues when hand is empty but deck has cards", %{game_state: game_state} do
      # Empty player2's hand but keep deck
      game_state =
        put_in(game_state, [:players, @player2_id, :hand], [])

      assert SimpleCardBattle.check_end_condition(game_state) == :continue
    end
  end

  describe "on_player_removed/2" do
    setup do
      config = %{}
      player_ids = [@player1_id, @player2_id]
      {:ok, game_state} = SimpleCardBattle.init_state(config, player_ids)
      %{game_state: game_state}
    end

    test "remaining player wins by forfeit when player1 removed", %{game_state: game_state} do
      assert SimpleCardBattle.on_player_removed(game_state, @player1_id) ==
               {:ended, @player2_id, "opponent_forfeit"}
    end

    test "remaining player wins by forfeit when player2 removed", %{game_state: game_state} do
      assert SimpleCardBattle.on_player_removed(game_state, @player2_id) ==
               {:ended, @player1_id, "opponent_forfeit"}
    end
  end
end
