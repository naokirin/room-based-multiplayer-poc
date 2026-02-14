# Code Review: game-server (Phoenix/Elixir)

実施日: 2026-02-15  
対象: `game-server/` 以下全体（コンテキスト境界・イディオム・Ecto 非使用・Channel/Web 層・エラーハンドリング・テスト）

---

## 総評

- **コンテキスト境界**: `GameServer`（Rooms, Games, Auth, Api, Redis, Consumers, Subscribers）と `GameServerWeb`（Channel, Controller, Plug）の分離は明確で良い。
- **イディオム**: パイプ・パターンマッチ・`with` が適切に使われている。一部だけ改善の余地あり。
- **エラーハンドリング**: `{:ok, _}` / `{:error, reason}` の返却が一貫している。Rails 通知失敗時はログのみで進行する設計で妥当。
- **テスト**: Auth/JWT、Games/SimpleCardBattle、ErrorJSON はよくカバーされている。Channel・Room・Consumer・Subscriber・HealthController のテストが無い。

以下、**Critical** / **Warning** / **Suggestion** に分けて記載する。

---

## Critical（必須で直す）

### 1. HealthController が Redix を直接参照している — **修正済み (2026-02-15)**

**ファイル**: `lib/game_server_web/controllers/health_controller.ex`

**対応**: `GameServer.Redis.command(["PING"])` 経由に変更済み。

---

### 2. AGENTS.md と依存の不一致（HTTP クライアント） — **修正済み (2026-02-15)**

**ファイル**: `game-server/AGENTS.md`, `mix.exs`, `lib/game_server/api/rails_client.ex`

**対応**: Req に統一済み。Tesla を deps から削除し、`GameServer.Api.RailsClient` を Req ベースで書き換え。AGENTS.md の「Use Req, avoid Tesla」と実装が一致。

---

## Warning（できるだけ直す）

### 3. Room.rejoin の hand_count が冗長 — **修正済み (2026-02-15)**

**対応**: `length(game_player_state[:hand] || [])` に簡略化。

---

### 4. Room モジュールが長い（責務の集中） — **対応済み (2026-02-15)**

**対応**: Rails 通知を `GameServer.Rooms.RoomNotifier`、タイマーを `GameServer.Rooms.RoomTimers` に切り出し。Room は両モジュールを呼ぶだけに変更。

---

### 5. RoomChannel の join で `chat_messages` を assign していない — **修正済み (2026-02-15)**

**対応**: `handle_room_token_join` と `handle_reconnect_token_join` の成功時に `assign(:chat_messages, [])` を追加。

---

### 6. SimpleCardBattle.init_state/2 の 2 人以外のケース — **修正済み (2026-02-15)**

**対応**: `@doc` を追加し、`length(player_ids) != 2` の clause で `{:error, :invalid_player_count}` を返すようにした。テストを追加。

---

### 7. JWT テストの setup と環境変数 — **修正済み (2026-02-15)**

**対応**: テスト開始時に `System.get_env("JWT_SECRET")` を保存し、`on_exit` で復元または `delete_env` するように変更。

---

### 8. internal パイプラインに認証が無い — **対応済み (2026-02-15)**

**対応**: Router のコメントを「internal は現状 health のみ・認証なし。他ルート追加時に API key を追加すること」に更新。プロジェクト README の Key Design Decisions に同趣旨を追記。

---

## Suggestion（任意）

### 9. GameServer メインコンテキストモジュールが空

**ファイル**: `lib/game_server.ex`

**内容**: `GameServer` は「コンテキストの入口」として moduledoc のみで、関数は無い。このプロジェクトでは Rooms/Games 等を直接呼んでいるため、現状のままでも問題はない。

**推奨**: 将来「ルーム作成」などを API として提供する場合は、`GameServer.create_room/1` のようなファサードをここに置くと、コンテキストの境界がより分かりやすくなる。必須ではない。

---

### 10. RoomBroadcast.flatten_card のマップキー

**ファイル**: `lib/game_server/rooms/room_broadcast.ex`

**内容**: カードが `"id"`, `"name"`, `"effects"` などの文字列キーで渡される前提。ゲーム側（SimpleCardBattle）も同様のマップ構造なので一貫している。

**推奨**: 特に対応不要。将来的に「クライアント用シリアライズ」を別モジュールにまとめる場合は、期待するキーを `@doc` や typespec で書いておくとよい。

---

### 11. テストが不足している箇所 — **一部対応済み (2026-02-15)**

**対応**: 以下を追加した。
- **HealthController**: `test/game_server_web/controllers/health_controller_test.exs` — GET /health の 200/503 と body のキー（status, node_name, active_rooms, connected_players, uptime_seconds）を検証。
- **RoomChannel**: `test/support/channel_case.ex` と `test/game_server_web/channels/room_channel_test.exs` — join（missing_token / invalid token / 有効 room_token で成功）、game:action（missing_nonce）、room:leave をテスト。

**未実施**: Room GenServer の主要フロー、RoomCreationConsumer、RoomCommandsSubscriber のテストは未追加（必要に応じて検討）。

---

### 12. RoomSupervisor.stop_room/1 の引数

**ファイル**: `lib/game_server/rooms/room_supervisor.ex`

**内容**: `stop_room(room_pid)` は PID を受け取る。Room は `room_id` で Registry に登録されているため、停止するには「Registry から room_id で PID を取得してから stop_room(pid)」という手順になる。

**推奨**: ドキュメントに「Room を停止する場合は、まず `Registry.lookup(GameServer.RoomRegistry, room_id)` で PID を取得すること」と書いておくか、`stop_room_by_id(room_id)` のようなヘルパーを用意すると利用しやすい。

---

## チェックリスト（Phoenix/Elixir 観点）

| 項目 | 状態 |
|------|------|
| コンテキスト境界（lib/game_server vs lib/game_server_web） | ✅ 良好 |
| イディオム（pipe, pattern match, with） | ✅ おおむね良好（1 箇所冗長あり） |
| エラーハンドリング（{:ok}/{:error}） | ✅ 一貫している |
| Ecto 使用 | N/A（DB なし） |
| Channel（join/terminate, メッセージ処理） | ✅ 適切。assign の初期化だけ改善余地 |
| テスト（ExUnit, describe, setup） | ✅ HealthController・RoomChannel を追加。Room/Consumer/Subscriber は未追加 |
| 設定・秘密情報（env） | ✅ JWT_SECRET 等は env から取得 |
| ファイルサイズ・責務 | ⚠️ Room が長いため、将来的な分割を推奨 |

---

## 次のアクション提案

1. ~~**必須**: HealthController の Redis 呼び出しを `GameServer.Redis` 経由に変更。~~ → 対応済み
2. ~~**必須**: AGENTS.md と HTTP クライアント（Tesla vs Req）の記述を一致させる。~~ → Req 統一済み
3. ~~**推奨**: Room の hand_count 冗長分岐の削除、RoomChannel の `chat_messages` 初期 assign、JWT テストの環境変数復元。~~ → 対応済み
4. ~~**余裕があれば**: Channel と HealthController のテスト追加、Room のタイマー責務分割。~~ → 対応済み（RoomTimers に分離済み）。

以上で game-server のコードレビューを完了とする。
