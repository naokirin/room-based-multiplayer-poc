import { create } from "zustand";
import {
	ActionAppliedPayloadSchema,
	GameAbortedPayloadSchema,
	GameEndedPayloadSchema,
	GameStartedPayloadSchema,
	HandUpdatedPayloadSchema,
	ReconnectTokenPayloadSchema,
	TurnChangedPayloadSchema,
} from "../schemas/gameEvents";
import { api } from "../services/api";
import { socketManager } from "../services/socket";
import type { Card, GameState, PlayerState } from "../types";
import { MAX_HP } from "../types";
import { getErrorMessage } from "../utils/error";
import { useAuthStore } from "./authStore";

type GameStatus = "waiting" | "playing" | "finished" | "aborted";

interface GameResult {
	winner_id: string | null;
	reason: string;
}

/** Shown in center after a card is played (both players see who played what) */
export interface LastPlayedCard {
	actorId: string;
	actorDisplayName: string;
	card: Card;
}

interface GameStoreState {
	roomId: string | null;
	gameState: GameState | null;
	myHand: Card[];
	/** Card just played, shown in center until next turn */
	lastPlayedCard: LastPlayedCard | null;
	currentTurn: string | null;
	turnNumber: number;
	turnTimeRemaining: number;
	players: Record<string, PlayerState>;
	isMyTurn: boolean;
	gameResult: GameResult | null;
	reconnectToken: string | null;
	status: GameStatus;
	error: string | null;
	isReconnecting: boolean;
	isDisconnected: boolean;
}

interface GameStoreActions {
	joinRoom: (roomId: string, roomToken: string, wsUrl: string) => Promise<void>;
	reconnectToRoom: () => Promise<void>;
	playCard: (cardId: string, target?: string) => void;
	handleGameStarted: (payload: unknown) => void;
	handleActionApplied: (payload: unknown) => void;
	handleHandUpdated: (payload: unknown) => void;
	handleTurnChanged: (payload: unknown) => void;
	handleGameEnded: (payload: unknown) => void;
	handleGameAborted: (payload: unknown) => void;
	handleReconnectToken: (payload: unknown) => void;
	handleDisconnected: () => void;
	leaveRoom: () => void;
	resetGame: () => void;
}

type GameStore = GameStoreState & GameStoreActions;

const RECONNECT_TOKEN_KEY = "game_reconnect_token";
const ROOM_ID_KEY = "game_room_id";

let turnTimerId: number | null = null;

const clearTurnTimer = () => {
	if (turnTimerId !== null) {
		clearInterval(turnTimerId);
		turnTimerId = null;
	}
};

const startTurnTimer = (updateFn: () => void) => {
	clearTurnTimer();
	turnTimerId = window.setInterval(updateFn, 1000);
};

function serverCardToCard(server: {
	id: string;
	name: string;
	effects?: Array<{ effect: string; value?: number }>;
}): Card {
	const effects = server.effects ?? [];
	const first = effects[0];
	const effect = (first?.effect ?? "deal_damage") as Card["effect"];
	const value = first?.value ?? 0;
	return {
		id: server.id,
		name: server.name,
		effect,
		value,
		effects: effects.map((e) => ({ effect: e.effect, value: e.value ?? 0 })),
	};
}

export const useGameStore = create<GameStore>((set, get) => ({
	// State
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

	// Actions
	joinRoom: async (roomId: string, roomToken: string, wsUrl: string) => {
		set({ error: null });
		try {
			const token = useAuthStore.getState().token;
			if (!token) {
				throw new Error("Not authenticated");
			}

			// Connect WebSocket and wait for connection to open before joining channel
			socketManager.setDisconnectCallback(() => {
				get().handleDisconnected();
			});
			await socketManager.connect(wsUrl, token);

			const user = useAuthStore.getState().user;
			const displayName = user?.display_name ?? "Player";

			// Create channel first (no join yet)
			socketManager.createChannel(roomId, {
				room_token: roomToken,
				display_name: displayName,
			});

			// Register event listeners BEFORE joining so we don't miss game:started
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

			// Now join the channel (events are already registered)
			const response = await socketManager.joinChannel();

			// Handle reconnect token from join response (T096)
			const joinTokenResult = ReconnectTokenPayloadSchema.safeParse(
				response && typeof response === "object" ? response : undefined,
			);
			if (joinTokenResult.success && joinTokenResult.data.reconnect_token) {
				const token = joinTokenResult.data.reconnect_token;
				set({ reconnectToken: token });
				localStorage.setItem(RECONNECT_TOKEN_KEY, token);
			}

			// Store room info (T096)
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
					? "Could not connect to the game server. Please ensure the game server is running (e.g. port 4000)."
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

			// Get WebSocket endpoint from API (use api client for consistency)
			api.setToken(token);
			const { ws_url: wsUrl } = await api.getWsEndpoint(roomId);

			// Reconnect WebSocket and wait for connection
			socketManager.setDisconnectCallback(() => {
				get().handleDisconnected();
			});
			await socketManager.connect(wsUrl, token);

			// Create channel with reconnect token (same pattern as joinRoom)
			socketManager.createChannel(roomId, { reconnect_token: reconnectToken });

			// Register event listeners BEFORE joining (same as joinRoom)
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

			// Rejoin channel; server returns full state when using reconnect_token
			const rejoinResponse = await socketManager.joinChannel();

			// Restore state from rejoin response
			if (rejoinResponse && typeof rejoinResponse === "object") {
				const fullState = rejoinResponse as {
					your_hand?: Card[];
					current_turn?: string;
					turn_number?: number;
					turn_time_remaining?: number;
					players?: Record<string, PlayerState>;
					status?: GameStatus;
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

				// Update reconnect token if server returned a new one
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

				// Restart turn timer if needed
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
		const result = GameStartedPayloadSchema.safeParse(payload);
		if (!result.success || result.data.current_turn === undefined) {
			if (!result.success) {
				console.warn("Invalid game:started payload:", result.error.flatten());
			}
			return;
		}
		const data = result.data;

		const myUserId = useAuthStore.getState().user?.id ?? "";
		const myHand = (data.your_hand ?? []).map(serverCardToCard);
		const currentTurn = data.current_turn;
		const turnNumber = data.turn_number ?? 1;
		const turnTimeRemaining = data.turn_time_remaining ?? 30;
		const isMyTurn = currentTurn === myUserId;
		const opponentId = data.opponent_id ?? "opponent";

		const players: Record<string, PlayerState> = {
			[myUserId]: {
				display_name: data.your_display_name ?? "You",
				connected: true,
				hp: data.your_hp ?? MAX_HP,
				hand_count: myHand.length,
				deck_count: data.your_deck_count ?? 0,
			},
			[opponentId]: {
				display_name: data.opponent_display_name ?? "Opponent",
				connected: true,
				hp: data.opponent_hp ?? MAX_HP,
				hand_count: data.opponent_hand_count ?? 0,
				deck_count: data.opponent_deck_count ?? 0,
			},
		};

		const gameState: GameState = {
			current_turn: currentTurn,
			turn_number: turnNumber,
			turn_time_remaining: turnTimeRemaining,
			players,
			your_hand: myHand,
		};

		set({
			gameState,
			myHand,
			currentTurn,
			turnNumber,
			turnTimeRemaining,
			players,
			isMyTurn,
			status: "playing",
		});

		// Start turn timer
		startTurnTimer(() => {
			const current = get().turnTimeRemaining;
			if (current > 0) {
				set({ turnTimeRemaining: current - 1 });
			}
		});
	},

	handleActionApplied: (payload: unknown) => {
		const result = ActionAppliedPayloadSchema.safeParse(payload);
		if (!result.success) {
			console.warn(
				"Invalid game:action_applied payload:",
				result.error.flatten(),
			);
			return;
		}
		const data = result.data;
		if (!data.players) return;

		// Merge updated player states into existing gameState
		const currentGameState = get().gameState;
		if (!currentGameState) return;

		const updatedPlayers = { ...currentGameState.players, ...data.players };
		const updatedGameState: GameState = {
			...currentGameState,
			players: updatedPlayers,
		};

		// Extract last played card for center display (both players see who played what)
		const cardPlayedEffect = data.effects?.find(
			(e) => e.type === "card_played",
		);
		const serverCard = cardPlayedEffect?.card;
		const actorDisplayName =
			(data.actor_id && updatedPlayers[data.actor_id]?.display_name) ??
			"Player";
		const lastPlayedCard: LastPlayedCard | null =
			serverCard && data.actor_id
				? {
						actorId: data.actor_id,
						actorDisplayName,
						card: serverCardToCard({
							id: serverCard.id,
							name: serverCard.name,
							effects: serverCard.effects,
						}),
					}
				: null;

		set({
			gameState: updatedGameState,
			players: updatedPlayers,
			lastPlayedCard,
		});
	},

	handleHandUpdated: (payload: unknown) => {
		const result = HandUpdatedPayloadSchema.safeParse(payload);
		if (!result.success) {
			console.warn(
				"Invalid game:hand_updated payload:",
				result.error.flatten(),
			);
			return;
		}
		const data = result.data;
		const handAsCards = data.hand.map((c) =>
			serverCardToCard({ id: c.id, name: c.name, effects: c.effects }),
		);

		const myUserId = useAuthStore.getState().user?.id ?? "";
		const currentGameState = get().gameState;

		// Update my hand and deck count in game state
		if (currentGameState) {
			const myPlayer = currentGameState.players[myUserId];
			if (myPlayer) {
				const updatedPlayers = {
					...currentGameState.players,
					[myUserId]: {
						...myPlayer,
						hand_count: handAsCards.length,
						deck_count: data.deck_count ?? myPlayer.deck_count,
					},
				};
				set({
					myHand: handAsCards,
					gameState: { ...currentGameState, players: updatedPlayers },
					players: updatedPlayers,
				});
				return;
			}
		}

		set({ myHand: handAsCards });
	},

	handleTurnChanged: (payload: unknown) => {
		const result = TurnChangedPayloadSchema.safeParse(payload);
		if (!result.success) {
			console.warn(
				"Invalid game:turn_changed payload:",
				result.error.flatten(),
			);
			return;
		}
		const data = result.data;

		const myUserId = useAuthStore.getState().user?.id;
		const isMyTurn = data.current_turn === myUserId;
		const turnTimeRemaining = data.turn_time_remaining ?? 30;

		const updates: Partial<GameStoreState> = {
			currentTurn: data.current_turn,
			turnNumber: data.turn_number,
			turnTimeRemaining,
			isMyTurn,
			lastPlayedCard: null,
		};

		// If we drew a card, add it to our hand
		if (data.drawn_card) {
			const currentHand = get().myHand;
			const drawnCard = serverCardToCard({
				id: data.drawn_card.id,
				name: data.drawn_card.name,
				effects: data.drawn_card.effects,
			});
			updates.myHand = [...currentHand, drawnCard];
		}

		// Keep gameState in sync
		const currentGameState = get().gameState;
		if (currentGameState) {
			updates.gameState = {
				...currentGameState,
				current_turn: data.current_turn,
				turn_number: data.turn_number,
				turn_time_remaining: turnTimeRemaining,
			};
		}

		set(updates);

		// Restart turn timer
		startTurnTimer(() => {
			const current = get().turnTimeRemaining;
			if (current > 0) {
				set({ turnTimeRemaining: current - 1 });
			}
		});
	},

	handleGameEnded: (payload: unknown) => {
		const result = GameEndedPayloadSchema.safeParse(payload);
		if (!result.success) {
			console.warn("Invalid game:ended payload:", result.error.flatten());
			return;
		}
		const data = result.data;

		clearTurnTimer();

		set({
			gameResult: {
				winner_id: data.winner_id,
				reason: data.reason,
			},
			status: "finished",
		});

		// Clear stored room info
		localStorage.removeItem(ROOM_ID_KEY);
		localStorage.removeItem(RECONNECT_TOKEN_KEY);
	},

	handleGameAborted: (payload: unknown) => {
		const result = GameAbortedPayloadSchema.safeParse(payload);
		if (!result.success) {
			console.warn("Invalid game:aborted payload:", result.error.flatten());
			return;
		}
		const data = result.data;

		clearTurnTimer();

		set({
			gameResult: {
				winner_id: null,
				reason: data.reason,
			},
			status: "aborted",
		});

		// Clear stored room info
		localStorage.removeItem(ROOM_ID_KEY);
		localStorage.removeItem(RECONNECT_TOKEN_KEY);
	},

	handleReconnectToken: (payload: unknown) => {
		const result = ReconnectTokenPayloadSchema.safeParse(payload);
		if (!result.success) {
			console.warn("Invalid reconnect_token payload:", result.error.flatten());
			return;
		}
		const token = result.data.reconnect_token;
		set({ reconnectToken: token });
		localStorage.setItem(RECONNECT_TOKEN_KEY, token);
	},

	handleDisconnected: () => {
		set({ isDisconnected: true });

		// Attempt automatic reconnection after a short delay
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
		}, 2000);
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
