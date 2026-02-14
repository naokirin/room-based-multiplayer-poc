import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { api } from "../services/api";
import { useLobbyStore } from "./lobbyStore";

vi.mock("../services/api", () => ({
	api: {
		getGameTypes: vi.fn(),
		joinMatchmaking: vi.fn(),
		getMatchmakingStatus: vi.fn(),
		cancelMatchmaking: vi.fn(),
	},
}));

describe("lobbyStore", () => {
	beforeEach(() => {
		vi.clearAllMocks();
		useLobbyStore.getState().clearMatch();
		useLobbyStore.setState({ gameTypes: [], error: null });
	});

	afterEach(() => {
		// Clear polling timer if test left store in queued state
		if (useLobbyStore.getState().matchmakingStatus === "queued") {
			vi.mocked(api.cancelMatchmaking).mockResolvedValue({
				status: "cancelled",
			});
			return useLobbyStore.getState().cancelQueue();
		}
	});

	describe("fetchGameTypes", () => {
		it("sets gameTypes and clears loading on success", async () => {
			const gameTypes = [
				{
					id: "gt1",
					name: "Simple Card Battle",
					player_count: 2,
					turn_time_limit: 30,
				},
			];
			vi.mocked(api.getGameTypes).mockResolvedValue({ game_types: gameTypes });

			await useLobbyStore.getState().fetchGameTypes();

			expect(useLobbyStore.getState().gameTypes).toEqual(gameTypes);
			expect(useLobbyStore.getState().isLoading).toBe(false);
			expect(useLobbyStore.getState().error).toBeNull();
		});

		it("sets error and clears loading on failure", async () => {
			vi.mocked(api.getGameTypes).mockRejectedValue(new Error("Network error"));

			await useLobbyStore.getState().fetchGameTypes();

			expect(useLobbyStore.getState().gameTypes).toEqual([]);
			expect(useLobbyStore.getState().isLoading).toBe(false);
			expect(useLobbyStore.getState().error).toContain("Network error");
		});
	});

	describe("joinQueue", () => {
		it("sets matched state when API returns matched", async () => {
			vi.mocked(api.joinMatchmaking).mockResolvedValue({
				status: "matched",
				room_id: "room-1",
				room_token: "token-1",
				ws_url: "ws://localhost:4000/ws",
			});

			await useLobbyStore.getState().joinQueue("gt1");

			expect(useLobbyStore.getState().matchmakingStatus).toBe("matched");
			expect(useLobbyStore.getState().currentMatch).toEqual({
				room_id: "room-1",
				room_token: "token-1",
				ws_url: "ws://localhost:4000/ws",
			});
			expect(useLobbyStore.getState().isLoading).toBe(false);
		});

		it("sets queued state and starts polling when API returns queued", async () => {
			vi.mocked(api.joinMatchmaking).mockResolvedValue({
				status: "queued",
				game_type_id: "gt1",
				queued_at: "2026-01-01T00:00:00Z",
				timeout_seconds: 60,
			});

			await useLobbyStore.getState().joinQueue("gt1");

			expect(useLobbyStore.getState().matchmakingStatus).toBe("queued");
			expect(useLobbyStore.getState().queuedAt).toBe("2026-01-01T00:00:00Z");
			expect(useLobbyStore.getState().queuedTimeoutSeconds).toBe(60);
			expect(useLobbyStore.getState().isLoading).toBe(false);
		});

		it("sets error state when API rejects", async () => {
			vi.mocked(api.joinMatchmaking).mockRejectedValue(
				new Error("Join failed"),
			);

			await useLobbyStore.getState().joinQueue("gt1");

			expect(useLobbyStore.getState().matchmakingStatus).toBe("error");
			expect(useLobbyStore.getState().error).toContain("Join failed");
		});
	});

	describe("cancelQueue", () => {
		it("resets to idle and clears error on success", async () => {
			vi.mocked(api.joinMatchmaking).mockResolvedValue({
				status: "queued",
				game_type_id: "gt1",
				queued_at: "2026-01-01T00:00:00Z",
				timeout_seconds: 60,
			});
			await useLobbyStore.getState().joinQueue("gt1");
			vi.mocked(api.cancelMatchmaking).mockResolvedValue({
				status: "cancelled",
			});

			await useLobbyStore.getState().cancelQueue();

			expect(useLobbyStore.getState().matchmakingStatus).toBe("idle");
			expect(useLobbyStore.getState().queuedAt).toBeNull();
			expect(useLobbyStore.getState().error).toBeNull();
		});

		it("sets error when cancel API fails", async () => {
			vi.mocked(api.joinMatchmaking).mockResolvedValue({
				status: "queued",
				game_type_id: "gt1",
				queued_at: "2026-01-01T00:00:00Z",
				timeout_seconds: 60,
			});
			await useLobbyStore.getState().joinQueue("gt1");
			vi.mocked(api.cancelMatchmaking).mockRejectedValue(
				new Error("Cancel failed"),
			);

			await useLobbyStore.getState().cancelQueue();

			expect(useLobbyStore.getState().error).toContain("Cancel failed");
		});
	});

	describe("checkStatus", () => {
		it("sets matched and currentMatch when status is matched", async () => {
			vi.mocked(api.getMatchmakingStatus).mockResolvedValue({
				status: "matched",
				room_id: "room-2",
				room_token: "token-2",
				ws_url: "ws://localhost:4000/ws",
			});

			await useLobbyStore.getState().checkStatus();

			expect(useLobbyStore.getState().matchmakingStatus).toBe("matched");
			expect(useLobbyStore.getState().currentMatch).toEqual({
				room_id: "room-2",
				room_token: "token-2",
				ws_url: "ws://localhost:4000/ws",
			});
		});

		it("sets timeout state when status is timeout", async () => {
			vi.mocked(api.getMatchmakingStatus).mockResolvedValue({
				status: "timeout",
				message: "No match found",
			});

			await useLobbyStore.getState().checkStatus();

			expect(useLobbyStore.getState().matchmakingStatus).toBe("timeout");
			expect(useLobbyStore.getState().error).toContain("No match found");
		});

		it("sets error when matched response lacks room_id", async () => {
			vi.mocked(api.getMatchmakingStatus).mockResolvedValue({
				status: "matched",
				room_token: "token-2",
				ws_url: "ws://localhost:4000/ws",
			});

			await useLobbyStore.getState().checkStatus();

			expect(useLobbyStore.getState().matchmakingStatus).toBe("error");
			expect(useLobbyStore.getState().error).toContain("missing room_id");
		});
	});

	describe("clearMatch", () => {
		it("resets match state to idle", () => {
			useLobbyStore.setState({
				matchmakingStatus: "matched",
				currentMatch: {
					room_id: "r",
					room_token: "t",
					ws_url: "wss://x",
				},
				queuedAt: "x",
				queuedTimeoutSeconds: 60,
				error: "old",
			});

			useLobbyStore.getState().clearMatch();

			expect(useLobbyStore.getState().matchmakingStatus).toBe("idle");
			expect(useLobbyStore.getState().currentMatch).toBeNull();
			expect(useLobbyStore.getState().queuedAt).toBeNull();
			expect(useLobbyStore.getState().queuedTimeoutSeconds).toBeNull();
			expect(useLobbyStore.getState().error).toBeNull();
		});
	});
});
