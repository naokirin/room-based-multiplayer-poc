import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { useAuthStore } from "./authStore";
import { useGameStore } from "./gameStore";

vi.mock("./authStore", () => ({
	useAuthStore: {
		getState: vi.fn(() => ({
			user: { id: "user-1", display_name: "Test User" },
			token: "auth-token",
		})),
	},
}));

describe("gameStore", () => {
	beforeEach(() => {
		vi.useFakeTimers();
		vi.clearAllMocks();
		vi.mocked(useAuthStore.getState).mockReturnValue({
			user: { id: "user-1", display_name: "Test User" },
			token: "auth-token",
		} as ReturnType<typeof useAuthStore.getState>);
		useGameStore.getState().resetGame();
	});

	afterEach(() => {
		vi.useRealTimers();
	});

	describe("handleReconnectToken", () => {
		it("updates state and localStorage when payload is valid", () => {
			const setItem = vi.spyOn(Storage.prototype, "setItem");

			useGameStore.getState().handleReconnectToken({
				reconnect_token: "new-token-123",
			});

			expect(useGameStore.getState().reconnectToken).toBe("new-token-123");
			expect(setItem).toHaveBeenCalledWith(
				"game_reconnect_token",
				"new-token-123",
			);

			setItem.mockRestore();
		});

		it("does not update state when payload is invalid", () => {
			useGameStore.getState().handleReconnectToken({});
			expect(useGameStore.getState().reconnectToken).toBeNull();

			useGameStore.getState().handleReconnectToken({
				reconnect_token: 123,
			});
			expect(useGameStore.getState().reconnectToken).toBeNull();

			useGameStore.getState().handleReconnectToken(null);
			expect(useGameStore.getState().reconnectToken).toBeNull();
		});
	});

	describe("handleGameEnded", () => {
		it("sets gameResult and status when payload is valid", () => {
			const removeItem = vi.spyOn(Storage.prototype, "removeItem");

			useGameStore.getState().handleGameEnded({
				winner_id: "user-1",
				reason: "Opponent defeated",
			});

			expect(useGameStore.getState().status).toBe("finished");
			expect(useGameStore.getState().gameResult).toEqual({
				winner_id: "user-1",
				reason: "Opponent defeated",
			});
			expect(removeItem).toHaveBeenCalledWith("game_room_id");
			expect(removeItem).toHaveBeenCalledWith("game_reconnect_token");

			removeItem.mockRestore();
		});

		it("does not update state when payload is invalid", () => {
			useGameStore.getState().handleGameEnded({});
			expect(useGameStore.getState().status).toBe("waiting");
			expect(useGameStore.getState().gameResult).toBeNull();

			useGameStore.getState().handleGameEnded({ winner_id: "x" });
			expect(useGameStore.getState().gameResult).toBeNull();
		});
	});

	describe("handleGameAborted", () => {
		it("sets gameResult and status when payload is valid", () => {
			const removeItem = vi.spyOn(Storage.prototype, "removeItem");

			useGameStore.getState().handleGameAborted({
				reason: "Opponent left",
			});

			expect(useGameStore.getState().status).toBe("aborted");
			expect(useGameStore.getState().gameResult).toEqual({
				winner_id: null,
				reason: "Opponent left",
			});
			expect(removeItem).toHaveBeenCalledWith("game_room_id");
			expect(removeItem).toHaveBeenCalledWith("game_reconnect_token");

			removeItem.mockRestore();
		});

		it("does not update state when payload is invalid", () => {
			useGameStore.getState().handleGameAborted({});
			expect(useGameStore.getState().status).toBe("waiting");
			expect(useGameStore.getState().gameResult).toBeNull();
		});
	});

	describe("handleGameStarted", () => {
		it("updates state when payload is valid", () => {
			useGameStore.getState().handleGameStarted({
				current_turn: "user-1",
				your_hand: [
					{
						id: "c1",
						name: "Strike",
						effects: [{ effect: "deal_damage", value: 2 }],
					},
				],
				your_hp: 10,
				your_deck_count: 5,
				your_display_name: "Test User",
				opponent_id: "user-2",
				opponent_display_name: "Opponent",
				opponent_hp: 10,
				opponent_hand_count: 3,
				opponent_deck_count: 5,
				turn_number: 1,
				turn_time_remaining: 30,
			});

			expect(useGameStore.getState().status).toBe("playing");
			expect(useGameStore.getState().currentTurn).toBe("user-1");
			expect(useGameStore.getState().turnNumber).toBe(1);
			expect(useGameStore.getState().myHand).toHaveLength(1);
			expect(useGameStore.getState().myHand[0].name).toBe("Strike");
			expect(useGameStore.getState().isMyTurn).toBe(true);
		});

		it("does not update state when payload is invalid", () => {
			useGameStore.getState().handleGameStarted(null);
			expect(useGameStore.getState().status).toBe("waiting");

			useGameStore.getState().handleGameStarted({});
			expect(useGameStore.getState().status).toBe("waiting");

			useGameStore.getState().handleGameStarted({ current_turn: 123 });
			expect(useGameStore.getState().status).toBe("waiting");
		});
	});

	describe("handleHandUpdated", () => {
		it("updates myHand when payload is valid", () => {
			useGameStore.getState().handleHandUpdated({
				hand: [
					{
						id: "c1",
						name: "Strike",
						effects: [{ effect: "deal_damage", value: 2 }],
					},
					{ id: "c2", name: "Heal", effects: [{ effect: "heal", value: 1 }] },
				],
				deck_count: 3,
			});

			expect(useGameStore.getState().myHand).toHaveLength(2);
			expect(useGameStore.getState().myHand[0].name).toBe("Strike");
			expect(useGameStore.getState().myHand[1].name).toBe("Heal");
		});

		it("does not update when payload is invalid", () => {
			useGameStore.getState().handleHandUpdated({});
			expect(useGameStore.getState().myHand).toEqual([]);

			useGameStore.getState().handleHandUpdated({ hand: "not-array" });
			expect(useGameStore.getState().myHand).toEqual([]);
		});
	});

	describe("handleTurnChanged", () => {
		it("updates turn state when payload is valid", () => {
			useGameStore.getState().handleTurnChanged({
				current_turn: "user-2",
				turn_number: 2,
				turn_time_remaining: 25,
			});

			expect(useGameStore.getState().currentTurn).toBe("user-2");
			expect(useGameStore.getState().turnNumber).toBe(2);
			expect(useGameStore.getState().turnTimeRemaining).toBe(25);
			expect(useGameStore.getState().isMyTurn).toBe(false);
		});

		it("does not update when payload is invalid", () => {
			useGameStore.getState().handleTurnChanged({});
			expect(useGameStore.getState().currentTurn).toBeNull();
		});
	});

	describe("resetGame", () => {
		it("clears all game state", () => {
			useGameStore.getState().handleGameStarted({
				current_turn: "user-1",
				turn_number: 1,
				turn_time_remaining: 30,
			});

			useGameStore.getState().resetGame();

			expect(useGameStore.getState().roomId).toBeNull();
			expect(useGameStore.getState().gameState).toBeNull();
			expect(useGameStore.getState().myHand).toEqual([]);
			expect(useGameStore.getState().status).toBe("waiting");
			expect(useGameStore.getState().gameResult).toBeNull();
		});
	});
});
