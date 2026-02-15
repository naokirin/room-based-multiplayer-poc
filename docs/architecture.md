# アーキテクチャ概要

## システム全体構成

```mermaid
graph TB
    subgraph "Client (Browser)"
        CLIENT[React / PixiJS / Zustand<br/>:3000]
    end

    subgraph "Backend Services"
        API[Rails API Server<br/>:3001]
        GAME[Phoenix Game Server<br/>:4000]
    end

    subgraph "Data Stores"
        MYSQL[(MySQL 8.0<br/>:3306)]
        REDIS[(Redis 7<br/>:6379)]
    end

    CLIENT -- "REST API (HTTP)<br/>/api/v1/*" --> API
    CLIENT -- "WebSocket<br/>/socket" --> GAME

    API -- "SQL" --> MYSQL
    API -- "Queue / Cache" --> REDIS

    GAME -- "BRPOP / PubSub" --> REDIS
    GAME -- "Internal API (HTTP)<br/>/internal/*" --> API
```

## サービス間接続の詳細

```mermaid
flowchart LR
    subgraph Client ["Client (:3000)"]
        direction TB
        C_REST["REST Client<br/>(fetch)"]
        C_WS["WebSocket Client<br/>(phoenix.js)"]
    end

    subgraph API ["API Server (:3001)"]
        direction TB
        A_PUBLIC["/api/v1/*<br/>認証・マッチメイキング・プロフィール"]
        A_INTERNAL["/internal/*<br/>Room・Auth内部API"]
        A_ADMIN["/admin/*<br/>管理画面"]
    end

    subgraph Game ["Game Server (:4000)"]
        direction TB
        G_WS["WebSocket<br/>/socket → RoomChannel"]
        G_BRPOP["BRPOP Consumer<br/>room_creation_queue"]
        G_PUBSUB["PubSub Subscriber<br/>room_commands"]
    end

    subgraph Redis ["Redis (:6379)"]
        direction TB
        R_QUEUE["List: match_queue, room_creation_queue"]
        R_KV["KV: room_token, reconnect, active_game"]
        R_PS["PubSub: room_commands"]
    end

    subgraph MySQL ["MySQL (:3306)"]
        direction TB
        DB["users, rooms, matches,<br/>game_results, cards,<br/>announcements, audit_logs"]
    end

    C_REST --> A_PUBLIC
    C_WS --> G_WS

    A_PUBLIC --> R_QUEUE
    A_PUBLIC --> R_KV
    A_PUBLIC --> DB
    A_ADMIN --> DB

    G_WS --> R_KV
    G_BRPOP --> R_QUEUE
    G_PUBSUB --> R_PS
    Game -- "HTTP" --> A_INTERNAL
    A_INTERNAL --> DB
    A_ADMIN -- "PUBLISH" --> R_PS
```

## データフロー（3層構造）

```mermaid
graph TB
    subgraph Persistent ["永続層:<br/> MySQL (Rails管理)"]
        T1["users"]
        T2["rooms / room_players"]
        T3["matches / match_players"]
        T4["game_types / cards"]
        T5["game_results"]
        T6["announcements"]
        T7["audit_logs"]
    end

    subgraph Temporary ["一時層:<br/> Redis (共有)"]
        R1["match_queue:{game_type_id}<br/>(List) マッチング待機キュー"]
        R2["room_creation_queue<br/>(List) Room作成命令"]
        R3["room_token:{token}<br/>(Hash, TTL 5分) Room参加認証"]
        R4["reconnect:{room_id}:{user_id}<br/>(String, TTL 24h) 再接続トークン"]
        R5["active_game:{user_id}<br/>(String) 二重参加防止"]
        R6["room_commands<br/>(PubSub) Room操作コマンド"]
        R7["persist_failed:{room_id}<br/>(String, TTL 7日) 結果保存失敗リカバリ"]
    end

    subgraph Runtime ["ランタイム層:<br/> Elixir Process Memory"]
        P1["RoomState GenServer"]
        P2["players: HP, hand, deck, connected"]
        P3["current_turn, turn_number"]
        P4["chat_messages (ring buffer, 最大100件)"]
        P5["nonce_cache (player毎 最大50件)"]
    end

    Persistent --- Temporary --- Runtime
```

## ER図

```mermaid
erDiagram
    users {
        bigint id PK
        string email UK
        string display_name
        string password_digest
        string status "active/frozen"
        datetime created_at
    }

    game_types {
        bigint id PK
        string name UK
        int min_players
        int max_players
        jsonb config
        boolean active
    }

    rooms {
        bigint id PK
        string room_id UK
        bigint game_type_id FK
        string status "preparing/ready/playing/finished/aborted"
        string node_name
        datetime started_at
        datetime finished_at
    }

    room_players {
        bigint id PK
        bigint room_id FK
        bigint user_id FK
        string role
        datetime joined_at
    }

    matches {
        bigint id PK
        bigint game_type_id FK
        string status "pending/matched/cancelled/expired"
        datetime matched_at
    }

    match_players {
        bigint id PK
        bigint match_id FK
        bigint user_id FK
        datetime queued_at
    }

    game_results {
        bigint id PK
        bigint room_id FK
        bigint winner_id FK
        jsonb result_data
        int turns_played
        datetime completed_at
    }

    cards {
        bigint id PK
        bigint game_type_id FK
        string name
        string card_type
        int attack
        int defense
        int cost
    }

    announcements {
        bigint id PK
        string title
        text body
        boolean active
        datetime published_at
    }

    audit_logs {
        bigint id PK
        bigint user_id FK
        string event
        jsonb metadata
        string ip_address
        datetime created_at
    }

    users ||--o{ room_players : "参加"
    users ||--o{ match_players : "マッチング"
    users ||--o{ audit_logs : "操作ログ"
    game_types ||--o{ rooms : "ゲーム種別"
    game_types ||--o{ matches : "マッチング"
    game_types ||--o{ cards : "カード"
    rooms ||--o{ room_players : "プレイヤー"
    rooms ||--o| game_results : "結果"
    matches ||--o{ match_players : "プレイヤー"
```

## ディレクトリ構造

```
room-based-multiplayer-poc/
├── client/                     # TypeScript/React/PixiJS Webクライアント
│   └── src/
│       ├── components/         # Auth, Lobby, Game, Chat 画面コンポーネント
│       ├── stores/             # Zustand 状態管理 (auth, lobby, game, chat)
│       ├── services/           # WebSocket接続・REST API呼び出し
│       ├── game/               # PixiJS ゲーム描画ロジック
│       ├── schemas/            # Zod バリデーションスキーマ
│       └── types/              # TypeScript型定義
│
├── api-server/                 # Ruby on Rails API + 管理画面
│   └── app/
│       ├── controllers/
│       │   ├── api/v1/         # 認証・マッチメイキング・プロフィール
│       │   ├── admin/          # 管理画面 (users, rooms, announcements)
│       │   └── internal/       # Phoenix → Rails 内部API
│       ├── models/             # User, Room, GameType, Match, Card等
│       ├── serializers/        # Alba JSONシリアライザ
│       ├── services/           # Matchmaking, RoomCreation, JWT
│       └── jobs/               # バックグラウンドジョブ
│
├── game-server/                # Elixir/Phoenix ゲームサーバー
│   └── lib/
│       ├── game_server/
│       │   ├── rooms/          # Room GenServer, Supervisor
│       │   ├── games/          # Game Behaviour, SimpleCardBattle実装
│       │   ├── consumers/      # Redis BRPOP (Room作成)
│       │   └── subscribers/    # Redis PubSub (Room操作コマンド)
│       └── game_server_web/
│           └── channels/       # UserSocket, RoomChannel
│
├── infra/                      # Docker Compose, MySQL/Redis設定
├── specs/                      # 機能仕様書
└── docs/                       # プロジェクトドキュメント
```

## 設計原則

| レイヤー | 責務 | やらないこと |
|---------|------|------------|
| **Client** | 表示・入力のみ | ゲームロジック、バリデーション |
| **Rails (API Server)** | 認証、マッチメイキング、永続化、管理 | ゲーム状態管理、リアルタイム通信 |
| **Phoenix (Game Server)** | ゲーム実行、ルーム管理、チャット、再接続 | データ永続化、ユーザー管理 |

すべてのゲームアクションはサーバー側で検証される **サーバーオーソリタティブ** アーキテクチャです。
