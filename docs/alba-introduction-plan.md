# Alba 導入計画（API レスポンス JSON 構築）

## 1. Alba とは・選定理由

- **Alba**: Ruby 用の高速 JSON シリアライザ。ActiveRecord に依存せず、任意のオブジェクトをシリアライズ可能。
- **公式**: https://github.com/okuramasafumi/alba
- **最新**: 3.x（Ruby 3.0+）。Rails 8 と互換性あり。
- **特徴**: 依存少・高速、`attributes` / `attribute` / `root_key`、**型チェック（`attributes name: [ :String ]` 等）**、条件付き属性、Hash 出力（`as_json`）で `render json:` にそのまま渡せる。

## 2. 導入範囲（今回）

- **対象**: `Api::V1::MatchmakingController` のレスポンス JSON 構築のみに Alba を導入する。
- **既存 API 契約**: 変更しない（status・キー名・HTTP status は現状どおり）。
- 他コントローラ（auth, rooms, profiles 等）は今回触れず、必要に応じて後から Alba 化可能。

## 3. 技術方針

### 3.1 設定

- **Gem**: `gem "alba"` を Gemfile に追加。
- **Backend**: Rails と揃えるため `Alba.backend = :active_support` を initializer で設定（Rails 標準の JSON エンコーダを使用）。
- **配置**: Serializer クラスは `app/serializers/` に配置。

### 3.2 レスポンス形状と Serializer 設計

Matchmaking のレスポンスは **status ごとに形が異なる** ため、**レスポンス種別ごとに 1 Serializer クラス** を用意する。

| エンドポイント | result[:status] | レスポンス例 | Serializer クラス |
|----------------|-----------------|--------------|-------------------|
| join | :matched | status, room_id, room_token, ws_url | Matchmaking::JoinMatchedSerializer |
| join | :queued | status, queued_at, timeout_seconds | Matchmaking::JoinQueuedSerializer |
| join | :already_in_game | status, room_id, room_token, ws_url | Matchmaking::JoinAlreadyInGameSerializer |
| join | :already_queued | status, queued_at | Matchmaking::JoinAlreadyQueuedSerializer |
| join | (else) | error, message | Api::V1::ErrorSerializer |
| status | :matched | status, room_id, room_token, ws_url | Matchmaking::StatusMatchedSerializer |
| status | :queued | status, queued_at, game_type_id | Matchmaking::StatusQueuedSerializer |
| status | :timeout | status, message | Matchmaking::StatusTimeoutSerializer |
| status | :not_queued | status | Matchmaking::StatusNotQueuedSerializer |
| status | (else) | error, message | Api::V1::ErrorSerializer |
| cancel | - | status, user_id | Matchmaking::CancelSerializer |

- **ルートキー**: 現行 API はルートでラップしていない。Serializer で `as_json(root_key: nil)` を指定し、フラットな JSON を返す。
- **型チェック**: Alba の `attributes name: [ :String ]` や `timeout_seconds: [ :Integer ]` で型を指定すると、シリアライズ時にチェックされ、型が合わない場合は `TypeError` が発生する。payload 生成時に `.to_s` / `.to_i` で揃えると安全。
- **入力**: コントローラの **private メソッド**で payload（OpenStruct 等）を組み立て、対応する Serializer に渡す。変換ロジックはアクション内に書かず、`build_xxx_payload(result)` や `join_response(result)` のようにメソッドに分離する。

### 3.3 ペイロードの渡し方とコントローラの薄さ

- アクションは「サービス呼び出し → レスポンス用メソッド呼び出し → `render **response`」に限定する。
- 例: `def join; ...; render **join_response(result); end`。`join_response` 内で `result[:status]` に応じて `render_join_matched(result)` 等を呼び、各メソッドが `build_xxx_payload` で payload を組み立て、Serializer で JSON 化し `{ json:, status: }` を返す。
- OpenStruct は `require "ostruct"` をコントローラ先頭で読み込む。

### 3.4 エラー用の共通 Serializer

- `Api::V1::ErrorSerializer` で `error` / `message` を共通化し、`invalid_game_type` / `matchmaking_error` / `status_error` で使い回す。

## 4. 実装ステップ

| 順番 | 内容 |
|------|------|
| 1 | Gemfile に `gem "alba"` を追加し、`bundle install` |
| 2 | `config/initializers/alba.rb` で `Alba.backend = :active_support` を設定 |
| 3 | `app/serializers/` を作成し、Matchmaking 用 Serializer クラスを追加（型指定付き） |
| 4 | エラー用 `Api::V1::ErrorSerializer` を追加 |
| 5 | MatchmakingController で payload 生成を `build_xxx_payload`、レスポンス組み立てを `join_response` / `status_response` 等の private メソッドに抽出し、`render **xxx_response(result)` で描画 |
| 6 | `bundle exec rspec spec/requests/api/v1/matchmaking_spec.rb` と `bundle exec rubocop` で検証 |

## 5. ディレクトリ構成（案）

```
app/
  serializers/
    api/
      v1/
        error_serializer.rb        # 共通エラー { error, message }（型指定あり）
    matchmaking/
      join_matched_serializer.rb
      join_queued_serializer.rb
      join_already_in_game_serializer.rb
      join_already_queued_serializer.rb
      status_matched_serializer.rb
      status_queued_serializer.rb
      status_timeout_serializer.rb
      status_not_queued_serializer.rb
      cancel_serializer.rb
  controllers/api/v1/
    matchmaking_controller.rb     # join_response / build_xxx_payload で Serializer を呼び出して render
config/
  initializers/
    alba.rb
```

## 6. 注意点

- **キー形式**: 現行 API は snake_case のキーで返しているため、Alba の `transform_keys` は使わず、attribute 名をそのまま snake_case で定義する（またはデフォルトのまま）。
- **nil**: フィールドが無い場合はキーごと出さない等、既存仕様に合わせる。Alba の conditional attributes や `select` で制御可能。
- **既存 spec**: レスポンスの JSON 構造と HTTP status を変えないため、既存の request spec がそのままパスすることを確認する。

## 7. 今後の拡張

- 他コントローラ（auth の user、game_types、announcements 等）の JSON も Alba Serializer に寄せていく場合は、同様に `app/serializers/` に Serializer を追加し、`render json: XxxSerializer.new(...).as_json(root_key: nil)` に置き換え即可。
- Matchmaking の「結果 → レスポンス」の分岐を Responder に寄せる refactor は、前出の `docs/refactor-matchmaking-controller-plan.md` のとおり、Alba 導入後でも実施可能（Responder 内で Serializer を呼ぶ形になる）。
