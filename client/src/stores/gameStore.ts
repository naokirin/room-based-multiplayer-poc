import { create } from "zustand";
import {
	AUTO_RECONNECT_DELAY_MS,
	DEFAULT_GAME_SERVER_WS_PORT,
	TURN_TIMER_INTERVAL_MS,
} from "../constants";
import { ReconnectTokenPayloadSchema } from "../schemas/gameEvents";
import { api } from "../services/api";
import { socketManager } from "../services/socket";
import type { Card, PlayerState } from "../types";
import { getErrorMessage } from "../utils/error";
import { useAuthStore } from "./authStore";
import * as gameHandlers from "./gameStoreHandlers";
import {
	type GameStore,
	type GameStoreState,
	RECONNECT_TOKEN_KEY,
	ROOM_ID_KEY,
} from "./gameStoreTypes";

// Re-export for consumers that import from gameStore
export type { LastPlayedCard } from "./gameStoreTypes";

let turnTimerId: number | null = null;

const clearTurnTimer = () => {
	if (turnTimerId !== null) {
		clearInterval(turnTimerId);
		turnTimerId = null;
	}
};

const startTurnTimer = (updateFn: () => void) => {
	clearTurnTimer();
	turnTimerId = window.setInterval(updateFn, TURN_TIMER_INTERVAL_MS);
};

function registerGameEventListeners(get: () => GameStore): void {
	socketManager.onEvent("game:started", (payload) => {
		get().handleGameStarted(payload);
	});
	socketManager.onEvent("game:action_applied", (payload) => {
		get().handleActionApplied(payload);
	});
	socketManager.onEvent("game:hand_updated", (payload) => {
		get().handleHandUpdated(payload);
	});
	socketManager.onEvent("game:turn_changed", (payload) => {
		get().handleTurnChanged(payload);
	});
	socketManager.onEvent("game:ended", (payload) => {
		get().handleGameEnded(payload);
	});
	socketManager.onEvent("game:aborted", (payload) => {
		get().handleGameAborted(payload);
	});
	socketManager.onEvent("player:reconnected", (payload) => {
		console.log("Player reconnected:", payload);
	});
	socketManager.onEvent("player:left", (payload) => {
		console.log("Player left:", payload);
	});
}

function makeHandlerContext(
	get: () => GameStore,
	set: (
		u:
			| Partial<GameStoreState>
			| ((s: GameStoreState) => Partial<GameStoreState>),
	) => void,
): gameHandlers.GameStoreHandlerContext {
	return {
		get,
		set,
		clearTurnTimer,
		startTurnTimer,
	};
}

export const useGameStore = create<GameStore>((set, get) => ({
	roomId: null,
	gameState: null,
	myHand: [],
	lastPlayedCard: null,
	currentTurn: null,
	turnNumber: 0,
	turnTimeRemaining: 0,
	players: {},
	isMyTurn: false,
	gameResult: null,
	reconnectToken: null,
	status: "waiting",
	error: null,
	isReconnecting: false,
	isDisconnected: false,

	joinRoom: async (roomId: string, roomToken: string, wsUrl: string) => {
		set({ error: null });
		try {
			const token = useAuthStore.getState().token;
			if (!token) {
				throw new Error("Not authenticated");
			}

			socketManager.setDisconnectCallback(() => {
				get().handleDisconnected();
			});
			await socketManager.connect(wsUrl, token);

			const user = useAuthStore.getState().user;
			const displayName = user?.display_name ?? "Player";

			socketManager.createChannel(roomId, {
				room_token: roomToken,
				display_name: displayName,
			});

			registerGameEventListeners(get);

			const response = await socketManager.joinChannel();

			const joinTokenResult = ReconnectTokenPayloadSchema.safeParse(
				response && typeof response === "object" ? response : undefined,
			);
			if (joinTokenResult.success && joinTokenResult.data.reconnect_token) {
				const tok = joinTokenResult.data.reconnect_token;
				set({ reconnectToken: tok });
				localStorage.setItem(RECONNECT_TOKEN_KEY, tok);
			}

			set({
				roomId,
				status: "waiting",
				error: null,
				isDisconnected: false,
				isReconnecting: false,
			});

			localStorage.setItem(ROOM_ID_KEY, roomId);
		} catch (err: unknown) {
			const msg = getErrorMessage(err, "Failed to join room");
			const friendlyMessage =
				msg.includes("WebSocket") || msg.includes("connection")
					? `Could not connect to the game server. Please ensure the game server is running (e.g. port ${DEFAULT_GAME_SERVER_WS_PORT}).`
					: msg;
			set({ error: friendlyMessage });
			throw err;
		}
	},

	reconnectToRoom: async () => {
		try {
			set({ isReconnecting: true, error: null });

			const token = useAuthStore.getState().token;
			const roomId = localStorage.getItem(ROOM_ID_KEY);
			const reconnectToken = localStorage.getItem(RECONNECT_TOKEN_KEY);

			if (!token || !roomId || !reconnectToken) {
				throw new Error("Missing reconnection data");
			}

			api.setToken(token);
			const { ws_url: wsUrl } = await api.getWsEndpoint(roomId);

			socketManager.setDisconnectCallback(() => {
				get().handleDisconnected();
			});
			await socketManager.connect(wsUrl, token);

			socketManager.createChannel(roomId, { reconnect_token: reconnectToken });

			registerGameEventListeners(get);

			const rejoinResponse = await socketManager.joinChannel();

			if (rejoinResponse && typeof rejoinResponse === "object") {
				const fullState = rejoinResponse as {
					your_hand?: Card[];
					current_turn?: string;
					turn_number?: number;
					turn_time_remaining?: number;
					players?: Record<string, PlayerState>;
					status?: GameStoreState["status"];
				};

				const myUserId = useAuthStore.getState().user?.id;
				const isMyTurn = fullState.current_turn === myUserId;

				set({
					roomId,
					myHand: fullState.your_hand || [],
					currentTurn: fullState.current_turn || null,
					turnNumber: fullState.turn_number || 0,
					turnTimeRemaining: fullState.turn_time_remaining || 0,
					players: fullState.players || {},
					isMyTurn,
					status: fullState.status || "waiting",
					isReconnecting: false,
					isDisconnected: false,
				});

				const rejoinTokenResult = ReconnectTokenPayloadSchema.safeParse(
					rejoinResponse && typeof rejoinResponse === "object"
						? rejoinResponse
						: undefined,
				);
				if (
					rejoinTokenResult.success &&
					rejoinTokenResult.data.reconnect_token
				) {
					const newToken = rejoinTokenResult.data.reconnect_token;
					set({ reconnectToken: newToken });
					localStorage.setItem(RECONNECT_TOKEN_KEY, newToken);
				}

				if (fullState.turn_time_remaining) {
					startTurnTimer(() => {
						const current = get().turnTimeRemaining;
						if (current > 0) {
							set({ turnTimeRemaining: current - 1 });
						}
					});
				}
			}
		} catch (err: unknown) {
			set({
				error: getErrorMessage(err, "Failed to reconnect"),
				isReconnecting: false,
			});
			throw err;
		}
	},

	playCard: (cardId: string, target?: string) => {
		const { isMyTurn, status } = get();
		if (!isMyTurn || status !== "playing") {
			console.warn("Cannot play card: not your turn or game not playing");
			return;
		}

		try {
			socketManager.pushAction("play_card", cardId, target);
		} catch (err: unknown) {
			set({ error: getErrorMessage(err, "Failed to play card") });
		}
	},

	handleGameStarted: (payload: unknown) => {
		gameHandlers.handleGameStarted(makeHandlerContext(get, set), payload);
	},

	handleActionApplied: (payload: unknown) => {
		gameHandlers.handleActionApplied(makeHandlerContext(get, set), payload);
	},

	handleHandUpdated: (payload: unknown) => {
		gameHandlers.handleHandUpdated(makeHandlerContext(get, set), payload);
	},

	handleTurnChanged: (payload: unknown) => {
		gameHandlers.handleTurnChanged(makeHandlerContext(get, set), payload);
	},

	handleGameEnded: (payload: unknown) => {
		gameHandlers.handleGameEnded(makeHandlerContext(get, set), payload);
	},

	handleGameAborted: (payload: unknown) => {
		gameHandlers.handleGameAborted(makeHandlerContext(get, set), payload);
	},

	handleReconnectToken: (payload: unknown) => {
		gameHandlers.handleReconnectToken(makeHandlerContext(get, set), payload);
	},

	handleDisconnected: () => {
		set({ isDisconnected: true });

		setTimeout(async () => {
			const roomId = localStorage.getItem(ROOM_ID_KEY);
			const reconnectToken = localStorage.getItem(RECONNECT_TOKEN_KEY);

			if (roomId && reconnectToken) {
				try {
					await get().reconnectToRoom();
				} catch (error) {
					console.error("Auto-reconnect failed:", error);
				}
			}
		}, AUTO_RECONNECT_DELAY_MS);
	},

	leaveRoom: () => {
		clearTurnTimer();
		socketManager.leaveRoom(() => {
			localStorage.removeItem(ROOM_ID_KEY);
			localStorage.removeItem(RECONNECT_TOKEN_KEY);
			get().resetGame();
		});
	},

	resetGame: () => {
		set({
			roomId: null,
			gameState: null,
			myHand: [],
			lastPlayedCard: null,
			currentTurn: null,
			turnNumber: 0,
			turnTimeRemaining: 0,
			players: {},
			isMyTurn: false,
			gameResult: null,
			reconnectToken: null,
			status: "waiting",
			error: null,
			isReconnecting: false,
			isDisconnected: false,
		});
	},
}));
