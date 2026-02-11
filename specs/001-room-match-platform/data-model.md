# Data Model: Room-Based Multiplayer Game Platform (MVP)

**Feature Branch**: `001-room-match-platform`
**Date**: 2026-02-10

## Overview

Data is split across three storage layers per the architectural design:
- **MySQL (Rails)**: Persistent entities — users, rooms, matches, game results, admin data
- **Redis (shared)**: Ephemeral/temporal data — tokens, queues, caches, inter-service messaging (List + PubSub)
- **Elixir Process Memory**: Runtime game state — active room state, player state, chat

## MySQL Entities (Rails)

### users

The core account entity for all players and administrators.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | UUID | PK | Unique user identifier |
| email | VARCHAR(255) | UNIQUE, NOT NULL | Login email |
| password_digest | VARCHAR(255) | NOT NULL | bcrypt hashed password |
| display_name | VARCHAR(50) | NOT NULL | Player display name |
| role | ENUM('player', 'admin') | NOT NULL, DEFAULT 'player' | Account role |
| status | ENUM('active', 'frozen') | NOT NULL, DEFAULT 'active' | Account status |
| frozen_at | DATETIME | NULL | When the account was frozen |
| frozen_reason | TEXT | NULL | Admin note for freeze reason |
| created_at | DATETIME | NOT NULL | Account creation timestamp |
| updated_at | DATETIME | NOT NULL | Last update timestamp |

**Indexes**: `email` (unique), `display_name`, `status`

**State transitions**:
```
active → frozen (admin freeze)
frozen → active (admin unfreeze)
```

### game_types

Configuration for each game variant. MVP ships with one hardcoded type.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | UUID | PK | Game type identifier |
| name | VARCHAR(100) | UNIQUE, NOT NULL | Game type name (e.g., "simple_card_battle") |
| player_count | INTEGER | NOT NULL | Required number of players |
| turn_time_limit | INTEGER | NOT NULL, DEFAULT 60 | Seconds per turn |
| config_json | JSON | NULL | Game-specific configuration |
| active | BOOLEAN | NOT NULL, DEFAULT true | Whether this game type is available for matchmaking |
| created_at | DATETIME | NOT NULL | |
| updated_at | DATETIME | NOT NULL | |

### rooms

Tracks room lifecycle. Rails holds metadata only; game state lives in Phoenix.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | UUID | PK | Room identifier (issued by Rails) |
| game_type_id | UUID | FK → game_types.id, NOT NULL | Which game type |
| status | ENUM('preparing', 'ready', 'playing', 'finished', 'aborted', 'failed') | NOT NULL | Room lifecycle state |
| node_name | VARCHAR(255) | NULL | Phoenix node hosting this room |
| player_count | INTEGER | NOT NULL | Expected player count |
| created_at | DATETIME | NOT NULL | Room creation timestamp |
| started_at | DATETIME | NULL | When game_start was triggered |
| finished_at | DATETIME | NULL | When game ended or was aborted |

**Indexes**: `status`, `game_type_id`, `node_name`, `created_at`

**State transitions (Rails perspective)**:
```
[new] → preparing  (Rails creates room record)
preparing → ready  (Phoenix confirms room process spawned)
preparing → failed (Phoenix failed to create room)
ready → playing    (all players joined, game started)
ready → aborted    (join timeout — not all players connected)
playing → finished (game completed normally)
playing → aborted  (admin force-terminate, or all players left)
```

### room_players

Join table linking players to rooms.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | UUID | PK | |
| room_id | UUID | FK → rooms.id, NOT NULL | |
| user_id | UUID | FK → users.id, NOT NULL | |
| joined_at | DATETIME | NULL | When player joined the room process |
| result | ENUM('winner', 'loser', 'draw', 'aborted') | NULL | Player's outcome |
| created_at | DATETIME | NOT NULL | |

**Indexes**: `(room_id, user_id)` (unique), `user_id`

### game_results

Persisted outcomes for completed games.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | UUID | PK | |
| room_id | UUID | FK → rooms.id, UNIQUE, NOT NULL | One result per room |
| winner_id | UUID | FK → users.id, NULL | Winner (NULL for draw) |
| result_data | JSON | NULL | Detailed game outcome data |
| turns_played | INTEGER | NOT NULL | Total turns in the game |
| duration_seconds | INTEGER | NOT NULL | Game duration |
| created_at | DATETIME | NOT NULL | |

**Indexes**: `room_id` (unique), `winner_id`

### matches

Tracks matchmaking history. One match maps to one room.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | UUID | PK | Match identifier |
| game_type_id | UUID | FK → game_types.id, NOT NULL | Which game type |
| room_id | UUID | FK → rooms.id, NULL | Created room (NULL if match expired/cancelled) |
| status | ENUM('queued', 'matched', 'cancelled', 'timeout') | NOT NULL | Match lifecycle state |
| matched_at | DATETIME | NULL | When the match was formed |
| created_at | DATETIME | NOT NULL | |

**Indexes**: `game_type_id`, `room_id` (unique, nullable), `status`

### match_players

Join table linking players to match queue entries.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | UUID | PK | |
| match_id | UUID | FK → matches.id, NOT NULL | |
| user_id | UUID | FK → users.id, NOT NULL | |
| queued_at | DATETIME | NOT NULL | When the player entered the queue |
| created_at | DATETIME | NOT NULL | |

**Indexes**: `(match_id, user_id)` (unique), `user_id`

### cards

Card definitions for the MVP hardcoded game type. In the future, these will be managed by the DSL system.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | UUID | PK | Card identifier |
| game_type_id | UUID | FK → game_types.id, NOT NULL | Which game type this card belongs to |
| name | VARCHAR(100) | NOT NULL | Card display name (e.g., "Fireball") |
| effect | VARCHAR(50) | NOT NULL | Effect type (deal_damage, heal, draw_card) |
| value | INTEGER | NOT NULL | Effect magnitude |
| cost | INTEGER | NOT NULL, DEFAULT 0 | Resource cost to play (reserved for future use) |
| active | BOOLEAN | NOT NULL, DEFAULT true | Whether this card is in the active pool |
| created_at | DATETIME | NOT NULL | |
| updated_at | DATETIME | NOT NULL | |

**Indexes**: `game_type_id`, `(game_type_id, active)`

**Note**: For MVP, cards are seeded from a hardcoded list. The card data in MySQL serves as the source of truth that Phoenix loads when creating a room.

### card_dsl_versions (Future — MVP Stub)

Version-controlled DSL definitions for cards. **Not actively used in MVP** (cards are hardcoded), but the table is created as a placeholder for the DSL system described in the original design (§7).

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | UUID | PK | Version identifier |
| game_type_id | UUID | FK → game_types.id, NOT NULL | Which game type |
| version | INTEGER | NOT NULL | Version number (monotonically increasing) |
| dsl_text | TEXT | NOT NULL | Raw DSL source text |
| compiled_ast | JSON | NULL | Compiled AST (cached) |
| status | ENUM('draft', 'validated', 'active', 'archived') | NOT NULL, DEFAULT 'draft' | Version lifecycle |
| created_by | UUID | FK → users.id, NOT NULL | Admin who created this version |
| validated_at | DATETIME | NULL | When validation passed |
| activated_at | DATETIME | NULL | When put into production |
| created_at | DATETIME | NOT NULL | |

**Indexes**: `(game_type_id, version)` (unique), `status`

**Note**: This table supports the future DSL system (解消5, 解消9). Rooms reference a specific DSL version at creation time, ensuring version consistency during gameplay.

### announcements

Admin-created notices for players.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | UUID | PK | |
| admin_id | UUID | FK → users.id, NOT NULL | Who created it |
| title | VARCHAR(255) | NOT NULL | Announcement title |
| body | TEXT | NOT NULL | Announcement content |
| active | BOOLEAN | NOT NULL, DEFAULT true | Whether currently visible |
| published_at | DATETIME | NULL | When made visible |
| expires_at | DATETIME | NULL | Auto-hide after this time |
| created_at | DATETIME | NOT NULL | |
| updated_at | DATETIME | NOT NULL | |

### audit_logs

Security and admin event log.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | BIGINT | PK, AUTO_INCREMENT | |
| actor_id | UUID | FK → users.id, NULL | Who performed the action |
| actor_type | ENUM('user', 'admin', 'system') | NOT NULL | |
| action | VARCHAR(100) | NOT NULL | Event type (e.g., "login_failed", "user_frozen", "room_force_terminated") |
| target_type | VARCHAR(50) | NULL | Entity type affected |
| target_id | UUID | NULL | Entity ID affected |
| metadata | JSON | NULL | Additional context |
| ip_address | VARCHAR(45) | NULL | Client IP |
| created_at | DATETIME | NOT NULL | |

**Indexes**: `actor_id`, `action`, `target_id`, `created_at`

## Redis Data Structures

### Matchmaking Queue

| Key | Type | TTL | Description |
|-----|------|-----|-------------|
| `match_queue:{game_type_id}` | List | None (cleaned by background job) | Queue of waiting players |

Entry format: `{ "user_id": "uuid", "queued_at": "ISO8601" }`

### Room Token

| Key | Type | TTL | Description |
|-----|------|-----|-------------|
| `room_token:{token}` | Hash | 5 minutes | Room join credential |

Fields: `room_id`, `user_id`, `status` (pending/used), `created_at`

### Reconnect Token

| Key | Type | TTL | Description |
|-----|------|-----|-------------|
| `reconnect:{room_id}:{user_id}` | String | 24 hours | Reconnection credential |

Value: `{ "token": "uuid", "node_name": "...", "created_at": "ISO8601" }`

### Active Player Tracking

| Key | Type | TTL | Description |
|-----|------|-----|-------------|
| `active_game:{user_id}` | String | None (deleted on room end) | Prevents double-matching |

Value: `room_id`

### Room Creation Queue (Rails → Phoenix)

| Key | Type | TTL | Description |
|-----|------|-----|-------------|
| `room_creation_queue` | List | None | Shared queue for room creation commands. Rails pushes (LPUSH), Phoenix nodes consume (BRPOP). |

Entry format:
```json
{
  "room_id": "uuid",
  "game_type_id": "uuid",
  "player_ids": ["uuid1", "uuid2"],
  "config": {
    "player_count": 2,
    "turn_time_limit": 60,
    "game_rules": "simple_card_battle"
  },
  "enqueued_at": "ISO8601"
}
```

**Consumer**: Each Phoenix node runs a `RoomCreationConsumer` GenServer that calls `BRPOP room_creation_queue 5` in a loop. Redis guarantees exactly-once delivery across competing consumers.

### Room Commands PubSub (Rails → Phoenix)

| Channel | Type | Description |
|---------|------|-------------|
| `room_commands` | PubSub | Broadcast channel for room-targeted commands. All Phoenix nodes subscribe; only the owner of the target room acts. |

Message format:
```json
{
  "command": "terminate",
  "room_id": "uuid",
  "reason": "admin_terminated",
  "admin_id": "uuid",
  "issued_at": "ISO8601"
}
```

**Note**: Redis PubSub is fire-and-forget (no persistence). This is acceptable for admin operations which are infrequent and retriable.

### Persist Failed Recovery

| Key | Type | TTL | Description |
|-----|------|-----|-------------|
| `persist_failed:{room_id}` | String | 7 days | Game result JSON for post-failure recovery. Rails background job scans every 5 min via `SCAN persist_failed:*` and imports results. Alert if key age > 30 min. |

## Elixir Process Memory (Runtime)

### Room State (per GenServer process)

```
%RoomState{
  room_id: UUID,
  game_type_id: UUID,
  status: :waiting | :active | :ending,
  players: %{
    user_id => %PlayerState{
      user_id: UUID,
      display_name: String,
      connected: boolean,
      disconnected_at: DateTime | nil,
      hp: integer,
      hand: [Card],
      deck: [Card]
    }
  },
  current_turn: user_id,
  turn_number: integer,
  turn_started_at: DateTime,
  turn_timer_ref: reference,
  join_timer_ref: reference,
  chat_messages: [%{sender_id, content, sent_at}],  # ephemeral, ring buffer (max 100 messages)
  nonce_cache: %{user_id => MapSet},                # per-player, max 50 nonces each (LRU eviction)
  created_at: DateTime
}
```

### Card (hardcoded for MVP)

```
%Card{
  id: String,
  name: String,
  effect: :deal_damage | :heal | :draw_card,
  value: integer
}
```

## Entity Relationships

```
users 1──N room_players N──1 rooms
users 1──N match_players N──1 matches
users 1──N game_results (as winner)
rooms N──1 game_types
rooms 1──1 game_results
rooms 1──1 matches
matches N──1 game_types
cards N──1 game_types
card_dsl_versions N──1 game_types
card_dsl_versions N──1 users (as created_by)
users 1──N announcements (as admin)
users 1──N audit_logs (as actor)
```
