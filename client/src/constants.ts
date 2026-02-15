/**
 * Application constants.
 * When a constant is shared across services (api-server, game-server, client),
 * the definition documents that it must be kept in sync with the other codebases.
 */

/** 注意: api-server の MATCHMAKING_QUEUE_TIMEOUT_SECONDS と値を揃えること。 */
export const DEFAULT_QUEUE_TIMEOUT_SECONDS = 60;

/** 注意: game-server の Room @turn_time_limit および turn_time_remaining 送信値と揃えること。 */
export const DEFAULT_TURN_TIME_REMAINING = 30;

/** デフォルトのターン番号（サーバから未送信時のフォールバック）。 */
export const DEFAULT_TURN_NUMBER = 1;

/**
 * チャット入力の最大文字数。
 * 注意: game-server の RoomChannel @max_chat_length および api-server のチャット関連制限と揃えること。
 */
export const MAX_CHAT_INPUT_LENGTH = 500;

/**
 * ゲームサーバ WebSocket のデフォルトポート（接続先・エラーメッセージ表記用）。
 * 注意: api-server の DEFAULT_GAME_SERVER_WS_PORT および game-server の Phoenix デフォルトポートと揃えること。
 */
export const DEFAULT_GAME_SERVER_WS_PORT = 4000;

/** キャンバスデフォルト幅（Game / GameRenderer で共通）。 */
export const DEFAULT_CANVAS_WIDTH = 800;

/** キャンバスデフォルト高さ（Game / GameRenderer で共通）。 */
export const DEFAULT_CANVAS_HEIGHT = 600;

/** 切断後の自動再接続を試行するまでの遅延（ミリ秒）。 */
export const AUTO_RECONNECT_DELAY_MS = 2000;

/** ターン残り時間を 1 秒刻みで更新する間隔（ミリ秒）。 */
export const TURN_TIMER_INTERVAL_MS = 1000;

/** マッチング経過秒数表示の更新間隔（ミリ秒）。 */
export const ELAPSED_UPDATE_INTERVAL_MS = 1000;
