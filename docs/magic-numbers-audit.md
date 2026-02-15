# マジックナンバー洗い出し・定数化結果（api-server / game-server / client）

ビジネスロジック・設定・閾値として直接書かれていた数値リテラルを定数化しました。  
**複数サービスで揃える必要がある値**は、各定数の定義箇所に「注意: … と揃えること」とコメントで記載しています。

---

## 定数化後の一覧

### api-server（Rails）

設定は `config/x/*.yml` に格納し、`Setting` モジュール（`lib/setting.rb`）で `config_for` をラップして `Setting.xxx` で参照します。YAML は環境別（default / development / test / production）でマージされます。

| メソッド | 対応 YAML | 値（default） | 備考（他サービスとの整合） |
|----------|-----------|----------------|-----------------------------|
| `Setting.matchmaking_user_ttl_seconds` | config/x/matchmaking.yml | 120 | クライアントの Lobby タイムアウトフォールバックと意味的に連動 |
| `Setting.matchmaking_queue_timeout_seconds` | config/x/matchmaking.yml | 60 | **client の `DEFAULT_QUEUE_TIMEOUT_SECONDS` と値を揃えること** |
| `Setting.jwt_expiration_seconds` | config/x/auth.yml | 3600 | 呼び出し側で `.seconds` して利用 |
| `Setting.default_game_server_ws_port` | config/x/game_server.yml | 4000 | **game-server の Phoenix ポート・client の `DEFAULT_GAME_SERVER_WS_PORT` と揃えること** |
| `Setting.game_server_ws_url` | config/x/game_server.yml + ENV | - | `ENV["GAME_SERVER_WS_URL"]` または localhost:default_ws_port の URL |
| `Setting.admin_per_page` | config/x/admin.yml | 25 | - |
| `Setting.admin_user_game_results_limit` | config/x/admin.yml | 20 | - |
| `Setting.api_error_backtrace_lines` | config/x/api.yml | 5 | - |
| `Setting.announcement_title_max_length` | config/x/api.yml | 255 | DB スキーマと一致 |

既存の `MatchmakingService::PREPARING_STALE_THRESHOLD`（30.seconds）と `ROOM_INACTIVE_STALE_THRESHOLD`（5.minutes）はそのまま利用しています。

---

### game-server（Phoenix / Elixir）

各モジュールのモジュール属性として定義。コメントで他サービスとの整合を記載しています。

| モジュール | 定数（属性） | 値 | 備考（他サービスとの整合） |
|------------|--------------|-----|-----------------------------|
| `GameServer.Rooms.Room` | `@turn_time_limit` | 30 | **client の `DEFAULT_TURN_TIME_REMAINING` と揃えること** |
| `GameServer.Rooms.Room` | `@reconnect_token_ttl` | 300 | api-server が発行する reconnect トークン有効期限と整合させること |
| `GameServer.Rooms.Room` | `@nonce_cache_ttl_minutes` | 5 | 新規追加（以前はリテラル 5） |
| `GameServerWeb.RoomChannel` | `@max_chat_length` | 500 | **client の `MAX_CHAT_INPUT_LENGTH` と揃えること** |
| `GameServerWeb.RoomChannel` | `@reconnect_token_used_ttl_seconds` | 10 | 新規追加（以前はリテラル 10） |
| `GameServerWeb.Plugs.RateLimiter` | `@throttle_period_ms` | 60_000 | 新規追加 |
| `GameServerWeb.Plugs.RateLimiter` | `@throttle_limit` | 60 | 新規追加 |
| `GameServer.Api.RailsClient` | `@retry_delay_base_ms` | 500 | 新規追加 |
| `GameServer.Api.RailsClient` | `@retry_delay_exponent` | 2 | 新規追加 |

---

### client（TypeScript / React）

共通定数は `src/constants.ts` に定義。他サービスとの整合はコメントで記載しています。

| 定数 | 値 | 備考（他サービスとの整合） |
|------|-----|-----------------------------|
| `DEFAULT_QUEUE_TIMEOUT_SECONDS` | 60 | **api-server の `MATCHMAKING_QUEUE_TIMEOUT_SECONDS` と揃えること** |
| `DEFAULT_TURN_TIME_REMAINING` | 30 | **game-server の Room `@turn_time_limit` と揃えること** |
| `DEFAULT_TURN_NUMBER` | 1 | サーバ未送信時のフォールバック |
| `MAX_CHAT_INPUT_LENGTH` | 500 | **game-server の RoomChannel `@max_chat_length` と揃えること** |
| `DEFAULT_GAME_SERVER_WS_PORT` | 4000 | **api-server の `DEFAULT_GAME_SERVER_WS_PORT`・game-server のポートと揃えること** |
| `DEFAULT_CANVAS_WIDTH` | 800 | Game / GameRenderer で共通 |
| `DEFAULT_CANVAS_HEIGHT` | 600 | Game / GameRenderer で共通 |
| `AUTO_RECONNECT_DELAY_MS` | 2000 | - |
| `TURN_TIMER_INTERVAL_MS` | 1000 | - |
| `ELAPSED_UPDATE_INTERVAL_MS` | 1000 | 経過秒数更新・秒計算に使用 |

その他: `src/types/index.ts` の `MAX_HP`（10）に「game-server の SimpleCardBattle `@max_hp` と揃えること」をコメント済み。  
`src/services/socket.ts` の `SOCKET_PROTOCOL_VERSION`（"1.0"）に「game-server の user_socket と揃えること」をコメント済み。  
`RESULT_DIALOG_DELAY_MS`（Game.tsx）、`POLL_INTERVAL`（lobbyStore）、`REFRESH_INTERVAL`（authStore）、`MAX_MESSAGES`（chatStore）、`PlayerInfoPanel` の定数は従来どおりローカルで定義済みです。

---

## 複数サービスで揃える必要がある値（一覧）

変更する場合は、以下をまとめて確認・更新してください。

| 意味 | api-server | game-server | client |
|------|------------|-------------|--------|
| マッチングキュー待ちタイムアウト（秒） | `Setting.matchmaking_queue_timeout_seconds` (60) | - | `DEFAULT_QUEUE_TIMEOUT_SECONDS` (60) |
| ターン制限／デフォルト残り時間（秒） | - | `Room` `@turn_time_limit` (30) | `DEFAULT_TURN_TIME_REMAINING` (30) |
| チャット最大文字数 | - | `RoomChannel` `@max_chat_length` (500) | `MAX_CHAT_INPUT_LENGTH` (500) |
| ゲームサーバ WS ポート | `Setting.default_game_server_ws_port` (4000) | Phoenix デフォルト | `DEFAULT_GAME_SERVER_WS_PORT` (4000) |
| 最大 HP（simple_card_battle） | - | `SimpleCardBattle` `@max_hp` (10) | `MAX_HP` (10) in types |
| ソケットプロトコルバージョン | - | user_socket `@supported_protocol_versions` ["1.0"] | `SOCKET_PROTOCOL_VERSION` "1.0" |

---

## 意図的に定数化していないもの

- テスト・スキーマ・マイグレーション内の数値（テストデータ、DB の limit 等）
- レイアウト・フォントサイズ・色の一部（GameRenderer / CardRenderer / primitives 等の細かいピクセル値）は、可読性と変更頻度を考慮しリテラルのまま
- HTTP ステータスコード（200, 403, 429 等）は Phoenix/Rails で一般的なためそのまま
- Puma のスレッド数・ポートは ENV で上書き可能なため既存のまま
