# MatchmakingController 条件分岐整理の計画

## 現状の課題

- **`join`**: `game_type` の検証 + サービス戻り値 `result[:status]` による 5 分岐（matched / queued / already_in_game / already_queued / else）。各分岐で JSON と HTTP status を個別に組み立てている。
- **`status`**: `result[:status]` による 5 分岐（matched / queued / timeout / not_queued / else）。同様に分岐ごとに render を記述。
- **`cancel`**: 分岐は少ないが、レスポンス組み立てのパターンは他と統一すると一貫する。

コントローラが「サービス結果 → HTTP レスポンス」のマッピングを一手に担っており、分岐追加時にコントローラが肥大化しやすい。

---

## 整理の基本方針

1. **コントローラは薄く保つ**  
   リクエスト受付 → サービス呼び出し → **レスポンスの決定と render** のみにする。
2. **「結果 → レスポンス」の責務を分離する**  
   サービスが返す `{ status:, data: }` から、`json` と `status` を決めるロジックをコントローラ外に移す。
3. **既存の振る舞い・API 契約を変えない**  
   既存の request spec がそのまま通るようにする。
4. **Rails の慣習に合わせる**  
   Fat Model / Skinny Controller、サービスオブジェクトの活用（既に `MatchmakingService` あり）。

---

## 推奨アプローチ: レスポンダーオブジェクトの導入

「サービス結果 → 返す JSON と HTTP status」の対応を **レスポンダー** に集約する。

### 1. `Matchmaking::JoinResponder`（join 用）

- **入力**: `result`（`MatchmakingService.join_queue` の戻り値）、`current_user_id`
- **出力**: `{ json: Hash, status: Symbol }`（`render` に渡す引数）
- **役割**:
  - `result[:status]` が `:matched` / `:queued` / `:already_in_game` / `:already_queued` のとき、既存仕様どおりの JSON と status を返す。
  - 上記以外は `error: "matchmaking_error"` + 500 を返す。

コントローラの `join` は次のように簡略化するイメージ:

```ruby
def join
  game_type = GameType.active.find_by(id: params[:game_type_id])
  unless game_type
    return render json: { error: "invalid_game_type", message: I18n.t("api.v1.errors.invalid_game_type") }, status: :not_found
  end

  result = MatchmakingService.join_queue(current_user.id, game_type.id)
  response = Matchmaking::JoinResponder.call(result, current_user.id)
  render response
end
```

`render response` のため、レスポンダーは `render` にそのまま渡せる形（例: `render json: response[:json], status: response[:status]`）を返すか、または `render response` で動くように `response` を Hash で返す（Rails の `render` は `render json: ..., status: ...` の Hash を解釈するので、`response` を `**response` で展開するか、`render response.slice(:json, :status)` などで渡す）。

※ 実装時は `render **Matchmaking::JoinResponder.call(...)` のように Hash で返す形にするとよい。

### 2. `Matchmaking::StatusResponder`（status 用）

- **入力**: `result`（`MatchmakingService.queue_status` の戻り値）
- **出力**: 上記と同様の `{ json:, status: }`
- **役割**: `:matched` / `:queued` / `:timeout` / `:not_queued` / それ以外 の 5 パターンを既存仕様どおりにマッピング。

### 3. game_type 検証の扱い

- **現状のまま** `join` 内で `find_by` + `unless game_type; return render ...` でもよい。
- **あるいは** `before_action :require_game_type, only: [:join]` を追加し、`require_game_type` で `GameType.active.find_by(id: params[:game_type_id])` を実行し、見つからなければ既存と同様の `invalid_game_type` で render して `return`（または `throw :abort`）する。
- エラー形式は既存どおり `{ error:, message: }` + `:not_found` を維持する。

### 4. cancel

- 現在の 1 パターンだけなので、そのままでも可。
- 統一するなら `Matchmaking::CancelResponder` を用意し、`result` から `{ json:, status: }` を返すようにする。

---

## ディレクトリ・ファイル構成案

```
app/
  controllers/api/v1/
    matchmaking_controller.rb   # 薄い：検証・サービス呼び出し・render のみ
  services/
    matchmaking_service.rb       # 既存のまま
  responders/                   # 新規でも可。または services の下でも可
    matchmaking/
      join_responder.rb
      status_responder.rb
      cancel_responder.rb        # 任意
```

`responders` を新設せず、`app/services/matchmaking/` の下に `join_responder.rb` などを置く構成でもよい（サービスと「その結果をどう API レスポンスにするか」が近いため）。

---

## 実装ステップ（推奨順）

| 順番 | 内容 | リスク |
|------|------|--------|
| 1 | `Matchmaking::JoinResponder` を追加し、`join` から case を移す。既存 request spec で検証。 | 低 |
| 2 | `Matchmaking::StatusResponder` を追加し、`status` から case を移す。同様に spec で検証。 | 低 |
| 3 | （任意）game_type 検証を `before_action` に抽出。 | 低 |
| 4 | （任意）cancel 用の Responder を追加し、レスポンス組み立てを統一。 | 低 |

各ステップ後には `bundle exec rspec spec/requests/api/v1/matchmaking_spec.rb` と RuboCop を実行し、既存仕様・スタイルを維持する。

---

## 代替案（参考）

- **Responder を使わず private メソッドに分割**  
  `render_join_result(result)` / `render_status_result(result)` をコントローラの private に置く。分岐はコントローラ内に残るが、1 アクションあたりの行数は減る。レスポンス仕様の変更が少ないならこれでも可。
- **ActiveModel::Serializers や Jbuilder の活用**  
  今回の「status ごとに形が違う」という構造では、単一の serializer にまとめるより、Responder で分岐してから必要な JSON を組み立てる方が素直。

---

## まとめ

- **条件分岐の整理**は、**「サービス結果 → JSON + HTTP status」のマッピングをレスポンダーに移す**ことで行う。
- コントローラは「検証 → サービス呼び出し → レスポンダーでレスポンス取得 → render」に限定し、case 分岐をレスポンダー側に集約する。
- 既存の request spec で振る舞いを担保し、段階的にリファクタする。

この計画で進めて問題なければ、まず Step 1（JoinResponder）から実装に落とし込むのがよい。
