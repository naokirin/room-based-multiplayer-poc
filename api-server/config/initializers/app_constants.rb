# frozen_string_literal: true

# Application-wide constants. When a constant is shared across services
# (api-server, game-server, client), the definition documents that it must
# be kept in sync with the other codebases.

module AppConstants
  # --- Matchmaking (Rails only; client uses same timeout for UI/fallback) ---
  # 注意: client の Lobby タイムアウトフォールバック（DEFAULT_QUEUE_TIMEOUT_SECONDS）と値を揃えること。
  MATCHMAKING_USER_TTL_SECONDS = 120
  MATCHMAKING_QUEUE_TIMEOUT_SECONDS = 60

  # --- Auth ---
  JWT_EXPIRATION = 1.hour

  # --- WebSocket / game-server ---
  # 注意: game-server の Phoenix デフォルトポートおよび client の接続先と揃えること。
  DEFAULT_GAME_SERVER_WS_PORT = 4000

  # --- Admin UI ---
  ADMIN_PER_PAGE = 25
  ADMIN_USER_GAME_RESULTS_LIMIT = 20

  # --- API error logging ---
  API_ERROR_BACKTRACE_LINES = 5

  # --- Announcements (DB schema title limit) ---
  ANNOUNCEMENT_TITLE_MAX_LENGTH = 255
end
