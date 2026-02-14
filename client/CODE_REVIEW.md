# TypeScript コードレビュー: client/

実施日: 2026-02-15  
対象: `client/` 以下全体（TypeScript/React/PixiJS）

---

## 総評

- **strict 有効**・型定義が整理されており、全体の品質は良いです。
- 改善したい点は主に **エラーハンドリングの型安全性**・**テスト不足**・**一部のクロージャ/API 前提** です。

---

## Critical（修正推奨）

該当なし。致命的な不具合やセキュリティ問題は見当たりません。

---

## Warning（対応を推奨）

### 1. エラーオブジェクトの `message` 参照

**箇所**: 各 store の `catch (err: unknown)` 内で `(err as { message?: string }).message` を使用。

**内容**: キャストに依存しており、API が別形状のエラーを返すと `message` がなくフォールバックのみになる。また、`api.request` の `!response.ok` 時に投げるオブジェクトの型が明示されていない。

**提案**:
- `types/index.ts` の `ApiError` を活用し、`api.request` では `ApiError` 型（または `status` 付きの拡張型）を throw するようにする。
- エラーメッセージ取り出しを共通化する（例: `getErrorMessage(err: unknown): string` を `src/utils/error.ts` に定義）。

### 2. Game.tsx – カードクリック時のクロージャ

**箇所**: `src/components/Game.tsx` の `useEffect`（renderer 初期化）の依存配列が `[]`。

**内容**: `onCardClick` 内で `myHand`, `gameState`, `user` を参照しているため、初回レンダー時点の値に固定される。手札や対戦相手が更新されても、クリック時には古い state が使われる可能性がある。

**提案**:
- コールバック内で `useGameStore.getState()` / `useAuthStore.getState()` から現在の `myHand`, `gameState`, `user` を取得する。
- または、依存配列に `myHand`, `gameState`, `user`, `playCard` を入れ、そのたびに renderer を再生成・コールバック再登録する（パフォーマンスに注意）。

### 3. Chat – メッセージ ID の不整合

**箇所**: `src/types/index.ts` の `ChatMessage` は `message_id`、`src/stores/chatStore.ts` の `ChatMessage` は `id`。

**内容**: サーバーが `message_id` を返す場合、store 側で `id` として扱うと `undefined` になり、`key={msg.id}` で key が undefined になる可能性がある。

**提案**:
- 型を一本化する（`types/index.ts` の `ChatMessage` に合わせる）。
- ソケット受信時に `message_id` を `id` にマッピングするか、コンポーネントでは `msg.message_id ?? msg.id` のようにする。

### 4. gameStore – reconnectToRoom の fetch と JSON

**箇所**: `src/stores/gameStore.ts` の `reconnectToRoom` 内で `await response.json()` の結果を `data.ws_url` として使用。

**内容**: `response.ok` でない場合や body が JSON でない場合の処理が不十分。`data` の形が保証されていない。

**提案**:
- `!response.ok` の場合は `throw new Error(...)` する。
- `data` を型付けし、`ws_url` の存在チェック（またはバリデーション）を行ってから `wsUrl` に代入する。

### 5. WebSocket / Phoenix のレスポンス形状

**箇所**: `src/services/socket.ts` の `joinChannel().receive("error", (response) => ...)` で `response.reason` を参照。

**内容**: Phoenix のエラーレスポンスの実際の形が変わると、`response.reason` が undefined になる可能性がある。

**提案**:
- `(response as { reason?: string }).reason ?? "Failed to join room"` のように安全に参照する。
- 必要なら型を `types/` に定義する。

### 6. テストが存在しない

**箇所**: `client/` 全体。

**内容**: `vitest` と `@testing-library/react` は `package.json` にあるが、`*.test.ts` / `*.test.tsx` が存在しない。`test` スクリプトも未定義。

**提案**:
- `npm run test`（または `vitest`）用のスクリプトを追加する。
- 重要フロー（認証ストアの login/logout、lobby の join/cancel、API クライアントのエラー処理など）からユニットテストを追加する。

### 7. ErrorBoundary – error の型

**箇所**: `src/components/ErrorBoundary.tsx` の `this.state.error.message`。

**内容**: `getDerivedStateFromError(error: Error)` で受けているが、React の実装によっては Error 以外が渡る可能性がある。その場合 `error.message` で例外になる可能性がある。

**提案**:
- `render` 内で `this.state.error instanceof Error ? this.state.error.message : String(this.state.error)` のようにする。
- または State の型を `error: Error | null` のままにして、表示時だけ上記のガードを行う。

---

## Suggestion（任意）

### 8. Lobby – マッチングタイムアウト秒数

**箇所**: `src/components/Lobby.tsx` の `TIMEOUT_SECONDS = 60`。

**内容**: API の `MatchmakingQueuedResponse.timeout_seconds` と別の値にすると、クライアントとサーバーでタイムアウトの印象がずれる。

**提案**: 可能なら `timeout_seconds` を API から取得して表示・カウントダウンに使う。

### 9. インラインスタイルの集約

**箇所**: `App.tsx`, `Lobby.tsx`, `Auth.tsx`, `Game.tsx`, `ErrorBoundary.tsx` の多数の `style={{ ... }}`。

**内容**: 保守性と一貫性のため、繰り返しのスタイルは CSS モジュールや CSS 変数（例: `index.css` の `:root`）に寄せると見通しが良くなる。

### 10. アクセシビリティ

**内容**: ボタンに `aria-label` がない箇所がある（アイコンのみや文脈が不明な場合）。フォームは `label` + `htmlFor` で紐付いているのは良い。

**提案**: 特に「Leave Game」「Retry」「Cancel」など、文脈で補足するとよいボタンに `aria-label` を検討する。

### 11. GameRenderer – PixiJS の destroy

**箇所**: `src/game/GameRenderer.ts` の `destroy()` 内で `app.stop?.()` や `app._cancelResize` を参照。

**内容**: 内部 API に依存している可能性がある。

**提案**: コメントで「PixiJS v8 の破棄時対策」などと意図を残す。将来の Pixi バージョンで挙動を確認する。

### 12. API レスポンスのランタイム検証

**内容**: `api.request<T>()` は `response.json()` をそのまま `T` として返している。サーバーが想定外の JSON を返すと型と実体がずれる。

**提案**: 重要なエンドポイント（auth, matchmaking, room join など）では、zod などのスキーマで `parse` し、失敗時は `ApiError` として扱うと安全。

---

## 良い点

- `tsconfig.app.json` で `strict: true`, `noUnusedLocals`, `noUnusedParameters` が有効。
- `verbatimModuleSyntax` により import の意図が明確。
- 型定義が `src/types/index.ts` に集約されている。
- 認証トークンの扱い（localStorage + API クライアント）と `serverUnreachable` の分離が整理されている。
- ゲーム状態は store で一元管理され、イミュータブルな更新（`{ ...currentGameState }` 等）がされている。
- セキュリティ: シークレットのハードコードはなく、API URL は `import.meta.env.VITE_*` で取得している。
- React のデフォルトのエスケープにより、チャットの `msg.content` は XSS 観点で妥当。`maxLength={500}` で入力長を制限している。

---

## チェックコマンド

```bash
cd client
npm run typecheck
npm run lint
# テスト追加後
npm run test
```

以上です。
