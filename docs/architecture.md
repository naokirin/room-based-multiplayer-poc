# Architecture Overview

## System Overview

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

## Service Connection Details

```mermaid
flowchart LR
    subgraph Client ["Client (:3000)"]
        direction TB
        C_REST["REST Client<br/>(fetch)"]
        C_WS["WebSocket Client<br/>(phoenix.js)"]
    end

    subgraph API ["API Server (:3001)"]
        direction TB
        A_PUBLIC["/api/v1/*<br/>Auth, Matchmaking, Profile"]
        A_INTERNAL["/internal/*<br/>Room & Auth Internal API"]
        A_ADMIN["/admin/*<br/>Admin Panel"]
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

## Data Flow (3-Layer Architecture)

```mermaid
graph TB
    subgraph Persistent ["Persistent Layer:<br/> MySQL (Managed by Rails)"]
        T1["users"]
        T2["rooms / room_players"]
        T3["matches / match_players"]
        T4["game_types / cards"]
        T5["game_results"]
        T6["announcements"]
        T7["audit_logs"]
    end

    subgraph Temporary ["Temporary Layer:<br/> Redis (Shared)"]
        R1["match_queue:{game_type_id}<br/>(List) Matchmaking wait queue"]
        R2["room_creation_queue<br/>(List) Room creation commands"]
        R3["room_token:{token}<br/>(Hash, TTL 5min) Room join auth"]
        R4["reconnect:{room_id}:{user_id}<br/>(String, TTL 24h) Reconnect token"]
        R5["active_game:{user_id}<br/>(String) Duplicate join prevention"]
        R6["room_commands<br/>(PubSub) Room operation commands"]
        R7["persist_failed:{room_id}<br/>(String, TTL 7d) Result save failure recovery"]
    end

    subgraph Runtime ["Runtime Layer:<br/> Elixir Process Memory"]
        P1["RoomState GenServer"]
        P2["players: HP, hand, deck, connected"]
        P3["current_turn, turn_number"]
        P4["chat_messages (ring buffer, max 100)"]
        P5["nonce_cache (max 50 per player)"]
    end

    Persistent --- Temporary --- Runtime
```

## ER Diagram

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

    users ||--o{ room_players : "joins"
    users ||--o{ match_players : "matchmaking"
    users ||--o{ audit_logs : "action logs"
    game_types ||--o{ rooms : "game type"
    game_types ||--o{ matches : "matchmaking"
    game_types ||--o{ cards : "cards"
    rooms ||--o{ room_players : "players"
    rooms ||--o| game_results : "result"
    matches ||--o{ match_players : "players"
```

## Directory Structure

```
room-based-multiplayer-poc/
├── client/                     # TypeScript/React/PixiJS web client
│   └── src/
│       ├── components/         # Auth, Lobby, Game, Chat screen components
│       ├── stores/             # Zustand state management (auth, lobby, game, chat)
│       ├── services/           # WebSocket connection & REST API calls
│       ├── game/               # PixiJS game rendering logic
│       ├── schemas/            # Zod validation schemas
│       └── types/              # TypeScript type definitions
│
├── api-server/                 # Ruby on Rails API + Admin panel
│   └── app/
│       ├── controllers/
│       │   ├── api/v1/         # Auth, matchmaking, profile
│       │   ├── admin/          # Admin panel (users, rooms, announcements)
│       │   └── internal/       # Phoenix → Rails internal API
│       ├── models/             # User, Room, GameType, Match, Card, etc.
│       ├── serializers/        # Alba JSON serializers
│       ├── services/           # Matchmaking, RoomCreation, JWT
│       └── jobs/               # Background jobs
│
├── game-server/                # Elixir/Phoenix game server
│   └── lib/
│       ├── game_server/
│       │   ├── rooms/          # Room GenServer, Supervisor
│       │   ├── games/          # Game Behaviour, SimpleCardBattle implementation
│       │   ├── consumers/      # Redis BRPOP (Room creation)
│       │   └── subscribers/    # Redis PubSub (Room operation commands)
│       └── game_server_web/
│           └── channels/       # UserSocket, RoomChannel
│
├── infra/                      # Docker Compose, MySQL/Redis config
├── specs/                      # Feature specifications
└── docs/                       # Project documentation
```

## Design Principles

| Layer | Responsibilities | Out of Scope |
|-------|-----------------|--------------|
| **Client** | Display and input only | Game logic, validation |
| **Rails (API Server)** | Auth, matchmaking, persistence, admin | Game state management, real-time communication |
| **Phoenix (Game Server)** | Game execution, room management, chat, reconnection | Data persistence, user management |

This is a **server-authoritative** architecture where all game actions are validated server-side.
