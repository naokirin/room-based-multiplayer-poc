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

### 3. Room.rejoin の hand_count が冗長

**ファイル**: `lib/game_server/rooms/room.ex` 付近 252 行

**内容**:  
`if(player_id == user_id, do: length(game_player_state[:hand]), else: length(game_player_state[:hand]))` は両分岐が同じ式のため、単に `length(game_player_state[:hand])` でよい。

**推奨**: 上記のように簡略化する（可読性と意図の明確化）。

---

### 4. Room モジュールが長い（責務の集中）

**ファイル**: `lib/game_server/rooms/room.ex`（約 530 行）

**内容**: 1 モジュールに「参加/離脱/切断/再接続」「ゲーム進行・ターン・タイマー」「チャット」「nonce」「Rails 通知」が集中している。機能的には正しいが、ファイルが長く変更時の影響範囲が大きい。

**推奨**: 段階的にでも責務を分離するとよい。
- 例: タイマー開始/キャンセルを `RoomTimers` のようなヘルパーに切り出す。
- 例: Rails 通知の一連の呼び出しを `RoomRailsNotifier` のような薄いラッパーにまとめる（既存の `RailsClient` を呼ぶだけでも可）。

---

### 5. RoomChannel の join で `chat_messages` を assign していない

**ファイル**: `lib/game_server_web/channels/room_channel.ex`

**内容**: `check_chat_rate_limit/1` は `Map.get(socket.assigns, :chat_messages, [])` で未設定時は `[]` を使うため動作上は問題ないが、レート制限用の状態が「join 時に明示的に初期化されていない」形になっている。

**推奨**: `handle_room_token_join` / `handle_reconnect_token_join` のいずれでも、`assign(:chat_messages, [])` をしておくと、レート制限の意図がコード上で明確になる。

---

### 6. SimpleCardBattle.init_state/2 の 2 人以外のケース

**ファイル**: `lib/game_server/games/simple_card_battle.ex`

**内容**: `init_state(config, player_ids) when length(player_ids) == 2` のみ定義されている。1 人や 3 人で呼ばれると FunctionClauseError になる。

**推奨**: 現状が「2 人用のみ保証」の設計であれば、`@doc` に「player_ids は長さ 2 のリストである必要がある」と明記する。または、ガードでない clause を追加し `{:error, :invalid_player_count}` などを返すようにする（呼び出し元の Room でどう扱うかと合わせて検討）。

---

### 7. JWT テストの setup と環境変数

**ファイル**: `test/game_server/auth/jwt_test.exs`

**内容**: `setup` で `JWT_SECRET` を設定し、`on_exit` で同じ値を再度 `put_env` している。元の値を保存して復元しているわけではないため、並行実行や他テストで別の値が設定されている場合に影響しうる。

**推奨**: テスト開始時に元の値を保存し、`on_exit` で復元する。

```elixir
setup do
  previous = System.get_env("JWT_SECRET")
  System.put_env("JWT_SECRET", @jwt_secret)
  on_exit(fn ->
    if previous, do: System.put_env("JWT_SECRET", previous), else: System.delete_env("JWT_SECRET")
  end)
  :ok
end
```

---

### 8. internal パイプラインに認証が無い

**ファイル**: `lib/game_server_web/router.ex`

**内容**: コメントに「Internal API key auth will be added later」とあるが、`/internal/health` は現状認証なしで公開されている。health のみなら許容できるが、今後 internal に認証が必要なルートを足す場合はパイプラインで API key 等を検証する必要がある。

**推奨**: 現状は「internal は health のみで、認証は未実装」と README や設計メモに明記しておく。internal に別ルートを追加するタイミングで、API key チェック用の Plug をパイプラインに追加する。

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

### 11. テストが不足している箇所

**対象**: 次のモジュールにテストが無い。

- `GameServerWeb.RoomChannel`（join with room_token / reconnect_token, game:action, chat:send, rate limit, leave, disconnect）
- `GameServer.Rooms.Room`（GenServer のため、start_link から join/leave/action までの主要シナリオをテストするとよい）
- `GameServer.Consumers.RoomCreationConsumer`（Redis に依存するため、Mox 等で Redis をスタブするか、integration タグで最小限のテストを検討）
- `GameServer.Subscribers.RoomCommandsSubscriber`（同様に Redis PubSub に依存）
- `GameServerWeb.HealthController`（ConnCase で GET /health の 200/503 と body のキー程度）

**推奨**: 重要度の高い順に、RoomChannel（join + 1〜2 イベント）、HealthController、Room の主要フローを ExUnit で追加すると、リグレッション防止と設計の明確化に役立つ。

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
| テスト（ExUnit, describe, setup） | ⚠️ 主要ドメインはカバー、Channel/Room/Controller 等は不足 |
| 設定・秘密情報（env） | ✅ JWT_SECRET 等は env から取得 |
| ファイルサイズ・責務 | ⚠️ Room が長いため、将来的な分割を推奨 |

---

## 次のアクション提案

1. ~~**必須**: HealthController の Redis 呼び出しを `GameServer.Redis` 経由に変更。~~ → 対応済み
2. ~~**必須**: AGENTS.md と HTTP クライアント（Tesla vs Req）の記述を一致させる。~~ → Req 統一済み
3. **推奨**: Room の hand_count 冗長分岐の削除、RoomChannel の `chat_messages` 初期 assign、JWT テストの環境変数復元。
4. **余裕があれば**: Room の責務分割、SimpleCardBattle の 2 人以外のドキュメント/返却値、Channel と HealthController のテスト追加。

以上で game-server のコードレビューを完了とする。
