# Data Model: Room-Based Multiplayer Game Platform (MVP)

**Feature Branch**: `001-room-match-platform`
**Date**: 2026-02-10

## Overview

Data is split across three storage layers per the architectural design:
- **MySQL (Rails)**: Persistent entities — users, rooms, matches, game results, admin data
- **Redis (shared)**: Ephemeral/temporal data — tokens, queues, caches
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

### Persist Failed Recovery

| Key | Type | TTL | Description |
|-----|------|-----|-------------|
| `persist_failed:{room_id}` | String | 7 days | Game result JSON for post-failure recovery |

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
  chat_messages: [%{sender_id, content, sent_at}],  # ephemeral, limited buffer
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
users 1──N game_results (as winner)
rooms N──1 game_types
rooms 1──1 game_results
users 1──N announcements (as admin)
users 1──N audit_logs (as actor)
```
