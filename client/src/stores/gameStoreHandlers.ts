import {
	ActionAppliedPayloadSchema,
	GameAbortedPayloadSchema,
	GameEndedPayloadSchema,
	GameStartedPayloadSchema,
	HandUpdatedPayloadSchema,
	ReconnectTokenPayloadSchema,
	TurnChangedPayloadSchema,
} from "../schemas/gameEvents";
import type { GameState, PlayerState } from "../types";
import { MAX_HP } from "../types";
import { useAuthStore } from "./authStore";
import type {
	GameStore,
	GameStoreState,
	LastPlayedCard,
} from "./gameStoreTypes";
import {
	RECONNECT_TOKEN_KEY,
	ROOM_ID_KEY,
	serverCardToCard,
} from "./gameStoreTypes";

export interface GameStoreHandlerContext {
	get: () => GameStore;
	set: (
		partial:
			| Partial<GameStoreState>
			| ((s: GameStoreState) => Partial<GameStoreState>),
	) => void;
	clearTurnTimer: () => void;
	startTurnTimer: (updateFn: () => void) => void;
}

export function handleGameStarted(
	ctx: GameStoreHandlerContext,
	payload: unknown,
): void {
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

	ctx.set({
		gameState,
		myHand,
		currentTurn,
		turnNumber,
		turnTimeRemaining,
		players,
		isMyTurn,
		status: "playing",
	});

	ctx.startTurnTimer(() => {
		const current = ctx.get().turnTimeRemaining;
		if (current > 0) {
			ctx.set({ turnTimeRemaining: current - 1 });
		}
	});
}

export function handleActionApplied(
	ctx: GameStoreHandlerContext,
	payload: unknown,
): void {
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

	const currentGameState = ctx.get().gameState;
	if (!currentGameState) return;

	const updatedPlayers = { ...currentGameState.players, ...data.players };
	const updatedGameState: GameState = {
		...currentGameState,
		players: updatedPlayers,
	};

	const cardPlayedEffect = data.effects?.find((e) => e.type === "card_played");
	const serverCard = cardPlayedEffect?.card;
	const actorDisplayName =
		(data.actor_id && updatedPlayers[data.actor_id]?.display_name) ?? "Player";
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

	ctx.set({
		gameState: updatedGameState,
		players: updatedPlayers,
		lastPlayedCard,
	});
}

export function handleHandUpdated(
	ctx: GameStoreHandlerContext,
	payload: unknown,
): void {
	const result = HandUpdatedPayloadSchema.safeParse(payload);
	if (!result.success) {
		console.warn("Invalid game:hand_updated payload:", result.error.flatten());
		return;
	}
	const data = result.data;
	const handAsCards = data.hand.map((c) =>
		serverCardToCard({ id: c.id, name: c.name, effects: c.effects }),
	);

	const myUserId = useAuthStore.getState().user?.id ?? "";
	const currentGameState = ctx.get().gameState;

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
			ctx.set({
				myHand: handAsCards,
				gameState: { ...currentGameState, players: updatedPlayers },
				players: updatedPlayers,
			});
			return;
		}
	}

	ctx.set({ myHand: handAsCards });
}

export function handleTurnChanged(
	ctx: GameStoreHandlerContext,
	payload: unknown,
): void {
	const result = TurnChangedPayloadSchema.safeParse(payload);
	if (!result.success) {
		console.warn("Invalid game:turn_changed payload:", result.error.flatten());
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

	if (data.drawn_card) {
		const currentHand = ctx.get().myHand;
		const drawnCard = serverCardToCard({
			id: data.drawn_card.id,
			name: data.drawn_card.name,
			effects: data.drawn_card.effects,
		});
		updates.myHand = [...currentHand, drawnCard];
	}

	const currentGameState = ctx.get().gameState;
	if (currentGameState) {
		updates.gameState = {
			...currentGameState,
			current_turn: data.current_turn,
			turn_number: data.turn_number,
			turn_time_remaining: turnTimeRemaining,
		};
	}

	ctx.set(updates);

	ctx.startTurnTimer(() => {
		const current = ctx.get().turnTimeRemaining;
		if (current > 0) {
			ctx.set({ turnTimeRemaining: current - 1 });
		}
	});
}

export function handleGameEnded(
	ctx: GameStoreHandlerContext,
	payload: unknown,
): void {
	const result = GameEndedPayloadSchema.safeParse(payload);
	if (!result.success) {
		console.warn("Invalid game:ended payload:", result.error.flatten());
		return;
	}
	const data = result.data;

	ctx.clearTurnTimer();

	ctx.set({
		gameResult: {
			winner_id: data.winner_id,
			reason: data.reason,
		},
		status: "finished",
	});

	localStorage.removeItem(ROOM_ID_KEY);
	localStorage.removeItem(RECONNECT_TOKEN_KEY);
}

export function handleGameAborted(
	ctx: GameStoreHandlerContext,
	payload: unknown,
): void {
	const result = GameAbortedPayloadSchema.safeParse(payload);
	if (!result.success) {
		console.warn("Invalid game:aborted payload:", result.error.flatten());
		return;
	}
	const data = result.data;

	ctx.clearTurnTimer();

	ctx.set({
		gameResult: {
			winner_id: null,
			reason: data.reason,
		},
		status: "aborted",
	});

	localStorage.removeItem(ROOM_ID_KEY);
	localStorage.removeItem(RECONNECT_TOKEN_KEY);
}

export function handleReconnectToken(
	ctx: GameStoreHandlerContext,
	payload: unknown,
): void {
	const result = ReconnectTokenPayloadSchema.safeParse(payload);
	if (!result.success) {
		console.warn("Invalid reconnect_token payload:", result.error.flatten());
		return;
	}
	const token = result.data.reconnect_token;
	ctx.set({ reconnectToken: token });
	localStorage.setItem(RECONNECT_TOKEN_KEY, token);
}
