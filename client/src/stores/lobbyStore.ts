import { create } from "zustand";
import { api } from "../services/api";
import type { GameType } from "../types";
import { getErrorMessage } from "../utils/error";

type MatchmakingStatus = "idle" | "queued" | "matched" | "timeout" | "error";

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
	error: string | null;
	isLoading: boolean;
}

interface LobbyActions {
	fetchGameTypes: () => Promise<void>;
	joinQueue: (gameTypeId: string) => Promise<void>;
	cancelQueue: () => Promise<void>;
	checkStatus: () => Promise<void>;
	clearMatch: () => void;
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
				// Enter queue and start polling
				set({
					matchmakingStatus: "queued",
					queuedAt: response.queued_at,
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
						error:
							"Invalid matched response: missing room_id, room_token, or ws_url",
					});
					return;
				}
				clearPollTimer();
				set({
					matchmakingStatus: "matched",
					currentMatch: { room_id, room_token, ws_url },
					queuedAt: null,
				});
			} else if (response.status === "timeout") {
				clearPollTimer();
				set({
					matchmakingStatus: "timeout",
					queuedAt: null,
					error: response.message || "Matchmaking timeout",
				});
			} else if (response.status === "error") {
				clearPollTimer();
				set({
					matchmakingStatus: "error",
					queuedAt: null,
					error: response.message || "Matchmaking error",
				});
			}
			// If still queued, continue polling (timer keeps running)
		} catch (err: unknown) {
			clearPollTimer();
			set({
				matchmakingStatus: "error",
				error: getErrorMessage(err, "Failed to check status"),
			});
		}
	},

	clearMatch: () => {
		set({
			matchmakingStatus: "idle",
			currentMatch: null,
			queuedAt: null,
			error: null,
		});
	},
}));
