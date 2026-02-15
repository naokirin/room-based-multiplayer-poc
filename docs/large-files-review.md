# 大規模ファイル／モジュールの行数レビュー

行数カウント対象: `**/*.rb`, `**/*.ex`, `**/*.ts`, `**/*.tsx`（`client/node_modules/`, `game-server/deps/` を除外）

プロジェクト指針（CLAUDE.md / coding-style）: **200–400 行を目安、最大 800 行**。これを超えるファイルは分割・リファクタの検討対象とする。

---

## 行数上位 20 件

| 行数 | ファイル |
|-----|----------|
| 750 | `game-server/lib/game_server/rooms/room.ex` |
| 725 | `client/src/game/GameRenderer.ts` |
| 655 | `client/src/stores/gameStore.ts` |
| 398 | `game-server/lib/game_server/games/simple_card_battle.ex` |
| 375 | `api-server/spec/requests/api/v1/matchmaking_spec.rb` |
| 333 | `client/src/components/Game.tsx` |
| 307 | `api-server/spec/requests/internal/rooms_spec.rb` |
| 294 | `client/src/components/Lobby.tsx` |
| 263 | `api-server/app/services/matchmaking_service.rb` |
| 254 | `game-server/lib/game_server_web/channels/room_channel.ex` |
| 253 | `client/src/services/socket.ts` |
| 241 | `client/src/stores/authStore.ts` |
| 224 | `client/src/stores/gameStore.test.ts` |
| 222 | `client/src/components/Chat.tsx` |
| 215 | `client/src/stores/lobbyStore.test.ts` |
| 199 | `client/src/stores/lobbyStore.ts` |
| 184 | `game-server/lib/game_server/api/rails_client.ex` |
| 180 | `client/src/services/api.ts` |
| 179 | `client/src/components/Auth.tsx` |

---

## 分割・リファクタ検討が必要なファイル

### 1. `game-server/lib/game_server/rooms/room.ex`（750 行）— 要対応

- **状況**: 指針の「最大 800 行」に近く、1 モジュールに責務が集中している。
- **役割**: GenServer として「参加/再接続」「ゲームアクション」「チャット」「タイマー/切断/強制終了」をすべて担当。
- **推奨**:
  - **RoomJoinRejoin**: `join` / `rejoin` のロジック（reconnect token 生成・Redis 書き込み・返却 state 構築）を別モジュールに抽出。`Room` は `init` と `handle_call` からそのモジュールを呼ぶだけにする。
  - **RoomStateBuilder**: クライアント用 state の組み立て（`players_for_client` や `full_state` の構築）を関数群として別モジュールに切り出し、`Room` から呼ぶ。
  - **RoomTimers / RoomBroadcast** は既存のため、タイマー・ブロードキャストはそのまま利用。`Room` 内の `start_turn_timer` / `start_reconnect_timer_for_player` 等は「いつタイマーを張るか」の判断だけにし、実装は既存モジュールに寄せる。
  - 上記で **Room は 400 行前後**に収めることを目標にする。

---

### 2. `client/src/game/GameRenderer.ts`（725 行）— 要対応

- **状況**: 1 クラスに描画ロジックがすべて入っており、目安を超えている。
- **構成**: `updateState` → 各種 `render*`（待機メッセージ、相手情報、自分の情報、ターン表示、中央の出したカード、手札）、`createCard`、効果表示用 `getEffect*` 群。
- **推奨**:
  - **カード描画の切り出し**
    - `createCard`（約 120 行）と `getEffectShortName` / `getEffectShortLabel` / `getEffectDisplay` / `getEffectColor`（約 70 行）を **`CardRenderer.ts`**（または `game/cardRenderer.ts`）に移動。  
      - `CardRenderer` は `(card, width, height, interactive) => Container` のような純粋関数または小さなクラスにし、`GameRenderer` はそれを呼ぶだけにする。
  - **UI パーツの切り出し（任意）**
    - `createHPBar` / `createCardBack` を **`game/primitives.ts`** のようなユーティリティにまとめ、色・サイズを引数で渡す。
  - これにより **GameRenderer は 500 行未満**を目標にできる。

---

### 3. `client/src/stores/gameStore.ts`（655 行）— 要対応

- **状況**: 1 つの Zustand ストアに「参加・再接続・退室」と「ゲームイベントハンドラ」がすべて入っている。
- **構成**:
  - 型定義・`serverCardToCard`・定数・タイマー（約 120 行）
  - `joinRoom` / `reconnectToRoom`（約 230 行）：ソケット接続・チャネル作成・イベント登録・localStorage
  - 各 `handle*`（GameStarted, ActionApplied, HandUpdated, TurnChanged, GameEnded, GameAborted, ReconnectToken, Disconnected）と `leaveRoom` / `resetGame`
- **推奨**:
  - **型・変換・定数の分離**
    - **`gameStoreTypes.ts`**（または `stores/game/types.ts`）に `GameStoreState`, `GameStoreActions`, `GameResult`, `LastPlayedCard`, `GameStatus` と `serverCardToCard`、`RECONNECT_TOKEN_KEY` / `ROOM_ID_KEY` を移動。`gameStore.ts` はそれを import するだけにする。
  - **イベントハンドラの分離（推奨）**
    - **`gameStoreHandlers.ts`** に、`(payload, get, set) => void` 形式で `handleGameStarted` … `handleDisconnected` を並べ、`gameStore.ts` では `create` 内で `GameStoreHandlers.handleGameStarted(payload, get, set)` のように呼ぶ。  
      - あるいは「join/reconnect 用」と「game events 用」で 2 ファイルに分けてもよい。
  - **join/reconnect の共通化**
    - `joinRoom` と `reconnectToRoom` で重複している「イベント登録」「チャネル join」を 1 つの内部関数（例: `registerGameEventsAndJoinChannel`）にまとめ、行数と重複を削減する。
  - 上記で **gameStore.ts は 350 行前後**を目標にする。

---

## 現時点で分割必須ではないが、行数に注意したいファイル

| ファイル | 行数 | メモ |
|----------|------|------|
| `game-server/.../simple_card_battle.ex` | 398 | 目安内だがやや大きい。ゲームルールが増えるなら「山札/手札」「ターン進行」「効果解決」でモジュール分割を検討。 |
| `api-server/.../matchmaking_spec.rb` | 375 | シナリオごとに `context` で分割済みならそのままで可。さらに増えるなら「マッチング」「キャンセル」「エラー」で別 spec に分ける選択肢あり。 |
| `client/.../Game.tsx` | 333 | 目安内。子コンポーネント化（ステータス表示・手札エリア等）で 300 行以下を維持するとよい。 |
| `api-server/.../rooms_spec.rb` | 307 | 同様に context/example で整理されていれば現状維持で可。 |
| `client/.../Lobby.tsx` | 294 | 目安内。UI が増えたらコンポーネント分割を検討。 |

---

## 実施したリファクタ（2026-02-15）

1. **room.ex** (750 → 648 行)
   - `GameServer.Rooms.RoomJoinRejoin`: join/rejoin のロジック（reconnect token、Redis、ブロードキャスト、返却 state 構築）を抽出。
   - `GameServer.Rooms.RoomStateBuilder`: クライアント用 state（join_reply_state / rejoin_full_state）を構築するモジュールを追加。
   - `mix test` で 40 テスト通過を確認。

2. **GameRenderer.ts** (725 → 526 行)
   - `client/src/game/CardRenderer.ts`: `createCard` と効果表示ヘルパー（`getEffectShortName`, `getEffectShortLabel`, `getEffectDisplay`, `getEffectColor`）を切り出し。
   - `npm run typecheck` と `npm test` で確認。

3. **gameStore.ts** (655 → 318 行)
   - `client/src/stores/gameStoreTypes.ts`: 型（GameStoreState, GameStoreActions, LastPlayedCard 等）、定数（RECONNECT_TOKEN_KEY, ROOM_ID_KEY）、`serverCardToCard` を分離。
   - `client/src/stores/gameStoreHandlers.ts`: 各 `handle*` をコンテキスト（get/set/clearTurnTimer/startTurnTimer）を受け取る関数として抽出。
   - `registerGameEventListeners(get)` で joinRoom と reconnectToRoom のイベント登録を共通化。
   - `LastPlayedCard` は `gameStore.ts` から re-export して既存の import を維持。

上記により、指針（200–400 行目安・最大 800 行）に沿った行数に収まった。

---

## 追加の責務分割（2026-02-15、400 行目安達成）

### room.ex（648 → 391 行）

- **RoomChat** (`room_chat.ex`): チャットメッセージの追加（リングバッファ）と履歴取得を担当。`add_message/4`, `get_history/1`。
- **RoomGameFlow** (`room_game_flow.ex`): ゲームフロー（開始・アクション処理・ターン進行・終了）を担当。`start_game/3`, `process_action/4`, `advance_turn/4`, `end_game/4`。`room_pid` を受け取り RoomTimers をスケジュール。
- **RoomDisconnect** (`room_disconnect.ex`): プレイヤー切断時の状態更新・ブロードキャスト・再接続/全員切断タイマーを担当。`apply_disconnect/3`, `all_players_disconnected?/1`。

### GameRenderer.ts（537 → 324 行）

- **primitives.ts**: HP バーとカード裏の描画。`createHPBar`, `createCardBack` を提供。
- **PlayerInfoPanel.ts**: 1 プレイヤー分の情報パネル（名前・HP・手札裏 or デック数）。`createPlayerInfoPanel(player, { y, showHandAsBacks })`。相手用・自分用の両方で利用。

両ファイルとも 400 行目安を下回った。
