import { create } from "zustand";
import { api } from "../services/api";
import type { GameType } from "../types";
import { getErrorMessage } from "../utils/error";
import { useGameStore } from "./gameStore";

type MatchmakingStatus =
	| "idle"
	| "queued"
	| "matched"
	| "timeout"
	| "error"
	| "restored";

interface MatchInfo {
	room_id: string;
	room_token: string;
	ws_url: string;
}

interface LobbyState {
	gameTypes: GameType[];
	matchmakingStatus: MatchmakingStatus;
	currentMatch: MatchInfo | null;
	queuedAt: string | null;
	/** Timeout in seconds from API (MatchmakingQueuedResponse.timeout_seconds). Used for countdown. */
	queuedTimeoutSeconds: number | null;
	error: string | null;
	isLoading: boolean;
}

interface LobbyActions {
	fetchGameTypes: () => Promise<void>;
	joinQueue: (gameTypeId: string) => Promise<void>;
	cancelQueue: () => Promise<void>;
	checkStatus: () => Promise<void>;
	clearMatch: () => void;
	restoreMatch: () => Promise<void>;
}

type LobbyStore = LobbyState & LobbyActions;

const POLL_INTERVAL = 3000; // 3 seconds

let pollTimerId: number | null = null;

const clearPollTimer = () => {
	if (pollTimerId !== null) {
		clearInterval(pollTimerId);
		pollTimerId = null;
	}
};

const startPolling = (checkStatusFn: () => Promise<void>) => {
	clearPollTimer();
	pollTimerId = window.setInterval(() => {
		checkStatusFn().catch((err) => {
			console.error("Status poll failed:", err);
		});
	}, POLL_INTERVAL);
};

export const useLobbyStore = create<LobbyStore>((set, get) => ({
	// State
	gameTypes: [],
	matchmakingStatus: "idle",
	currentMatch: null,
	queuedAt: null,
	queuedTimeoutSeconds: null,
	error: null,
	isLoading: false,

	// Actions
	fetchGameTypes: async () => {
		set({ isLoading: true, error: null });
		try {
			const response = await api.getGameTypes();
			set({
				gameTypes: response.game_types,
				isLoading: false,
			});
		} catch (err: unknown) {
			set({
				isLoading: false,
				error: getErrorMessage(err, "Failed to fetch game types"),
			});
		}
	},

	joinQueue: async (gameTypeId: string) => {
		set({ isLoading: true, error: null });
		try {
			const response = await api.joinMatchmaking(gameTypeId);

			if (response.status === "matched") {
				// Immediately matched
				clearPollTimer();
				set({
					matchmakingStatus: "matched",
					currentMatch: {
						room_id: response.room_id,
						room_token: response.room_token,
						ws_url: response.ws_url,
					},
					queuedAt: null,
					isLoading: false,
				});
			} else if (response.status === "queued") {
				// Enter queue and start polling (use API timeout_seconds for countdown)
				set({
					matchmakingStatus: "queued",
					queuedAt: response.queued_at,
					queuedTimeoutSeconds: response.timeout_seconds ?? null,
					isLoading: false,
				});

				// Start polling status
				startPolling(get().checkStatus);
			}
		} catch (err: unknown) {
			set({
				matchmakingStatus: "error",
				isLoading: false,
				error: getErrorMessage(err, "Failed to join queue"),
			});
		}
	},

	cancelQueue: async () => {
		try {
			await api.cancelMatchmaking();
			clearPollTimer();
			set({
				matchmakingStatus: "idle",
				queuedAt: null,
				queuedTimeoutSeconds: null,
				error: null,
			});
		} catch (err: unknown) {
			set({
				error: getErrorMessage(err, "Failed to cancel queue"),
			});
		}
	},

	checkStatus: async () => {
		try {
			const response = await api.getMatchmakingStatus();

			if (response.status === "matched") {
				const { room_id, room_token, ws_url } = response;
				if (room_id == null || room_token == null || ws_url == null) {
					set({
						matchmakingStatus: "error",
						queuedAt: null,
						queuedTimeoutSeconds: null,
						error:
							"Invalid matched response: missing room_id, room_token, or ws_url",
					});
					return;
				}
				clearPollTimer();
				// If we were queued, this is a fresh match -> auto-join (matched).
				// If we were idle (checking on mount), this is an existing game -> manual reconnect (restored).
				const nextStatus =
					get().matchmakingStatus === "queued" ? "matched" : "restored";

				set({
					matchmakingStatus: nextStatus,
					currentMatch: { room_id, room_token, ws_url },
					queuedAt: null,
					queuedTimeoutSeconds: null,
				});
			} else if (response.status === "timeout") {
				clearPollTimer();
				set({
					matchmakingStatus: "timeout",
					queuedAt: null,
					queuedTimeoutSeconds: null,
					error: response.message || "Matchmaking timeout",
				});
			} else if (response.status === "error") {
				clearPollTimer();
				set({
					matchmakingStatus: "error",
					queuedAt: null,
					queuedTimeoutSeconds: null,
					error: response.message || "Matchmaking error",
				});
			} else if (response.status === "not_queued") {
				clearPollTimer();
				set({
					matchmakingStatus: "idle",
					queuedAt: null,
					queuedTimeoutSeconds: null,
					error: null,
				});
			}
			// If still queued, continue polling (timer keeps running)
		} catch (err: unknown) {
			clearPollTimer();
			set({
				matchmakingStatus: "error",
				queuedAt: null,
				queuedTimeoutSeconds: null,
				error: getErrorMessage(err, "Failed to check status"),
			});
		}
	},

	clearMatch: () => {
		set({
			matchmakingStatus: "idle",
			currentMatch: null,
			queuedAt: null,
			queuedTimeoutSeconds: null,
			error: null,
		});
	},

	restoreMatch: async () => {
		try {
			const { currentMatch } = get();
			// First try to reconnect if we have local data
			try {
				await useGameStore.getState().reconnectToRoom();
			} catch (e) {
				// If reconnection fails (e.g. missing token in LS), try joining with the room token we just got
				// This handles cases where we have the room info from API but no local session logic yet
				if (currentMatch) {
					console.log(
						"Reconnection failed, trying to join with room token...",
						e,
					);
					await useGameStore
						.getState()
						.joinRoom(
							currentMatch.room_id,
							currentMatch.room_token,
							currentMatch.ws_url,
						);
					// If join succeeds, we trigger the App.tsx effect via roomId change, or we can manually set "matched"
					// actually joinRoom sets roomId in gameStore, which App.tsx watches.
					// We should also update our status to matched to be safe/consistent?
					// Actually App.tsx only watches gameStore.roomId to switch to game.
					return;
				}
				throw e;
			}
		} catch (err: unknown) {
			set({
				error: getErrorMessage(err, "Failed to restore match"),
			});
		}
	},
}));
