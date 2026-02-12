import { create } from "zustand";
import type { GameState, Card, PlayerState } from "../types";
import { socketManager } from "../services/socket";
import { useAuthStore } from "./authStore";

type GameStatus = "waiting" | "playing" | "finished" | "aborted";

interface GameResult {
  winner_id: string | null;
  reason: string;
}

interface GameStoreState {
  roomId: string | null;
  gameState: GameState | null;
  myHand: Card[];
  currentTurn: string | null;
  turnNumber: number;
  turnTimeRemaining: number;
  players: Record<string, PlayerState>;
  isMyTurn: boolean;
  gameResult: GameResult | null;
  reconnectToken: string | null;
  status: GameStatus;
  error: string | null;
}

interface GameStoreActions {
  joinRoom: (roomId: string, roomToken: string, wsUrl: string) => Promise<void>;
  playCard: (cardId: string, target?: string) => void;
  handleGameStarted: (payload: unknown) => void;
  handleActionApplied: (payload: unknown) => void;
  handleTurnChanged: (payload: unknown) => void;
  handleGameEnded: (payload: unknown) => void;
  handleGameAborted: (payload: unknown) => void;
  handleReconnectToken: (payload: unknown) => void;
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

export const useGameStore = create<GameStore>((set, get) => ({
  // State
  roomId: null,
  gameState: null,
  myHand: [],
  currentTurn: null,
  turnNumber: 0,
  turnTimeRemaining: 0,
  players: {},
  isMyTurn: false,
  gameResult: null,
  reconnectToken: null,
  status: "waiting",
  error: null,

  // Actions
  joinRoom: async (roomId: string, roomToken: string, wsUrl: string) => {
    try {
      const token = useAuthStore.getState().token;
      if (!token) {
        throw new Error("Not authenticated");
      }

      // Connect WebSocket
      socketManager.connect(wsUrl, token);

      // Join room channel
      await socketManager.joinRoom(roomId, { room_token: roomToken });

      // Set up event listeners
      socketManager.onEvent("game:started", (payload) => {
        get().handleGameStarted(payload);
      });

      socketManager.onEvent("game:action_applied", (payload) => {
        get().handleActionApplied(payload);
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

      socketManager.onEvent("room:reconnect_token", (payload) => {
        get().handleReconnectToken(payload);
      });

      // Store room info
      set({
        roomId,
        status: "waiting",
        error: null,
      });

      localStorage.setItem(ROOM_ID_KEY, roomId);
    } catch (err: unknown) {
      const error = err as { message?: string };
      set({
        error: error.message || "Failed to join room",
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
      const error = err as { message?: string };
      set({ error: error.message || "Failed to play card" });
    }
  },

  handleGameStarted: (payload: unknown) => {
    const data = payload as {
      game_state: GameState;
    };

    const myUserId = useAuthStore.getState().user?.id;
    const isMyTurn = data.game_state.current_turn === myUserId;

    set({
      gameState: data.game_state,
      myHand: data.game_state.your_hand,
      currentTurn: data.game_state.current_turn,
      turnNumber: data.game_state.turn_number,
      turnTimeRemaining: data.game_state.turn_time_remaining,
      players: data.game_state.players,
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
    const data = payload as {
      actor_id: string;
      card_played: Card;
      effects: Array<{ type: string; target_id: string; value: number }>;
      game_state: GameState;
    };

    const myUserId = useAuthStore.getState().user?.id;
    const isMyTurn = data.game_state.current_turn === myUserId;

    set({
      gameState: data.game_state,
      myHand: data.game_state.your_hand,
      currentTurn: data.game_state.current_turn,
      turnNumber: data.game_state.turn_number,
      turnTimeRemaining: data.game_state.turn_time_remaining,
      players: data.game_state.players,
      isMyTurn,
    });
  },

  handleTurnChanged: (payload: unknown) => {
    const data = payload as {
      current_turn: string;
      turn_number: number;
      turn_time_remaining: number;
      drawn_card?: Card;
    };

    const myUserId = useAuthStore.getState().user?.id;
    const isMyTurn = data.current_turn === myUserId;

    const updates: Partial<GameStoreState> = {
      currentTurn: data.current_turn,
      turnNumber: data.turn_number,
      turnTimeRemaining: data.turn_time_remaining,
      isMyTurn,
    };

    // If we drew a card, add it to our hand
    if (data.drawn_card) {
      const currentHand = get().myHand;
      updates.myHand = [...currentHand, data.drawn_card];
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
    const data = payload as {
      winner_id: string | null;
      reason: string;
    };

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
    const data = payload as {
      reason: string;
    };

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
    const data = payload as {
      reconnect_token: string;
    };

    set({ reconnectToken: data.reconnect_token });
    localStorage.setItem(RECONNECT_TOKEN_KEY, data.reconnect_token);
  },

  leaveRoom: () => {
    clearTurnTimer();
    socketManager.disconnect();

    localStorage.removeItem(ROOM_ID_KEY);
    localStorage.removeItem(RECONNECT_TOKEN_KEY);

    get().resetGame();
  },

  resetGame: () => {
    set({
      roomId: null,
      gameState: null,
      myHand: [],
      currentTurn: null,
      turnNumber: 0,
      turnTimeRemaining: 0,
      players: {},
      isMyTurn: false,
      gameResult: null,
      reconnectToken: null,
      status: "waiting",
      error: null,
    });
  },
}));
