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
  isReconnecting: boolean;
  isDisconnected: boolean;
}

interface GameStoreActions {
  joinRoom: (roomId: string, roomToken: string, wsUrl: string) => Promise<void>;
  reconnectToRoom: () => Promise<void>;
  playCard: (cardId: string, target?: string) => void;
  handleGameStarted: (payload: unknown) => void;
  handleActionApplied: (payload: unknown) => void;
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
  isReconnecting: false,
  isDisconnected: false,

  // Actions
  joinRoom: async (roomId: string, roomToken: string, wsUrl: string) => {
    try {
      const token = useAuthStore.getState().token;
      if (!token) {
        throw new Error("Not authenticated");
      }

      // Connect WebSocket
      socketManager.connect(wsUrl, token);

      // Set up disconnect callback (T094)
      socketManager.setDisconnectCallback(() => {
        get().handleDisconnected();
      });

      // Join room channel
      const response = await socketManager.joinRoom(roomId, { room_token: roomToken });

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

      socketManager.onEvent("player:reconnected", (payload) => {
        console.log("Player reconnected:", payload);
      });

      socketManager.onEvent("player:left", (payload) => {
        console.log("Player left:", payload);
      });

      // Handle reconnect token from join response (T096)
      if (response && typeof response === "object" && "reconnect_token" in response) {
        const reconnectToken = (response as { reconnect_token?: string }).reconnect_token;
        if (reconnectToken) {
          set({ reconnectToken });
          localStorage.setItem(RECONNECT_TOKEN_KEY, reconnectToken);
        }
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
      const error = err as { message?: string };
      set({
        error: error.message || "Failed to join room",
      });
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

      // Get WebSocket endpoint from API
      const apiUrl = import.meta.env.VITE_API_URL || "http://localhost:3001";
      const response = await fetch(`${apiUrl}/api/v1/rooms/${roomId}/ws_endpoint`, {
        headers: {
          Authorization: `Bearer ${token}`,
        },
      });

      if (!response.ok) {
        throw new Error("Failed to get WebSocket endpoint");
      }

      const data = await response.json();
      const wsUrl = data.ws_url;

      // Reconnect WebSocket
      socketManager.connect(wsUrl, token);

      // Set up disconnect callback
      socketManager.setDisconnectCallback(() => {
        get().handleDisconnected();
      });

      // Rejoin room with reconnect token
      const rejoinResponse = await socketManager.joinRoom(roomId, {
        reconnect_token: reconnectToken,
      });

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
      const error = err as { message?: string };
      set({
        error: error.message || "Failed to reconnect",
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
      isReconnecting: false,
      isDisconnected: false,
    });
  },
}));
