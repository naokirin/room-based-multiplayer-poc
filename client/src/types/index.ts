// User types
export interface User {
  id: string;
  email: string;
  display_name: string;
  role?: "player" | "admin";
  status?: "active" | "frozen";
  created_at?: string;
}

// Auth types
export interface AuthResponse {
  user: User;
  access_token: string;
  expires_at: string;
}

export interface RefreshResponse {
  access_token: string;
  expires_at: string;
}

// Game types
export interface GameType {
  id: string;
  name: string;
  player_count: number;
  turn_time_limit: number;
}

// Matchmaking types
export interface MatchmakingQueuedResponse {
  status: "queued";
  game_type_id: string;
  queued_at: string;
  timeout_seconds: number;
}

export interface MatchmakingMatchedResponse {
  status: "matched";
  room_id: string;
  room_token: string;
  ws_url: string;
  game_type?: GameType;
}

export interface MatchmakingStatusResponse {
  status: "queued" | "matched" | "timeout" | "error";
  room_id?: string;
  room_token?: string;
  ws_url?: string;
  queued_at?: string;
  elapsed_seconds?: number;
  message?: string;
  can_rejoin_queue?: boolean;
}

// Room types
export interface RoomPlayer {
  user_id: string;
  display_name: string;
  connected: boolean;
}

// Card effect entry (for single or composite cards)
export interface CardEffect {
  effect: "deal_damage" | "heal" | "draw_card" | "discard_opponent" | "reshuffle_hand";
  value: number;
}

// Card types
export interface Card {
  id: string;
  name: string;
  effect: "deal_damage" | "heal" | "draw_card" | "discard_opponent" | "reshuffle_hand";
  value: number;
  /** When present, card has multiple effects (composite). First element matches effect/value. */
  effects?: CardEffect[];
}

// Simple card battle: max HP (must match game-server)
export const MAX_HP = 10;

// Game state types
export interface PlayerState {
  display_name: string;
  connected: boolean;
  hp: number;
  hand_count: number;
  deck_count: number;
}

export interface GameState {
  current_turn: string;
  turn_number: number;
  turn_time_remaining: number;
  players: Record<string, PlayerState>;
  your_hand: Card[];
}

// Chat types
export interface ChatMessage {
  message_id: string;
  sender_id: string;
  sender_name: string;
  content: string;
  sent_at: string;
}

// Announcement types
export interface Announcement {
  id: string;
  title: string;
  body: string;
  published_at: string;
}

// API error types
export interface ApiError {
  error: string;
  message: string;
  retry_after?: number;
}

export interface ValidationErrors {
  errors: Record<string, string[]>;
}
