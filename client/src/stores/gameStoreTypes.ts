import type { Card, GameState, PlayerState } from "../types";

export type GameStatus = "waiting" | "playing" | "finished" | "aborted";

export interface GameResult {
	winner_id: string | null;
	reason: string;
}

/** Shown in center after a card is played (both players see who played what) */
export interface LastPlayedCard {
	actorId: string;
	actorDisplayName: string;
	card: Card;
}

export interface GameStoreState {
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

export interface GameStoreActions {
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

export type GameStore = GameStoreState & GameStoreActions;

export const RECONNECT_TOKEN_KEY = "game_reconnect_token";
export const ROOM_ID_KEY = "game_room_id";

/**
 * Convert server card payload to client Card type.
 */
export function serverCardToCard(server: {
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
