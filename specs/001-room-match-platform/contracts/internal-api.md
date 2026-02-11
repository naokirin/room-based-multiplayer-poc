# API Contract: Internal Service Communication

**Feature Branch**: `001-room-match-platform`

## Communication Overview

| Direction | Method | Details |
|-----------|--------|---------|
| Phoenix → Rails | HTTP REST | Base URL: `http://api-server:3001/internal`, API Key auth, JSON |
| Rails → Phoenix (room creation) | Redis List (BRPOP) | Queue: `room_creation_queue` |
| Rails → Phoenix (room operations) | Redis PubSub | Channel: `room_commands` |

**Phoenix → Rails HTTP settings**:
- **Auth**: API Key in `X-Internal-Api-Key` header
- **Format**: JSON
- **Timeout**: 5 seconds per request
- **Retry**: Exponential backoff, max 3 attempts

**Design principle**: Phoenix does NOT expose HTTP endpoints. All Rails → Phoenix communication is mediated through Redis (see [R-009](../research.md#r-009-rails--phoenix-communication-architecture)).

## Authentication

All internal API requests must include:

```
X-Internal-Api-Key: {shared_api_key}
```

Rails validates the key matches the configured `INTERNAL_API_KEY` environment variable. Requests without a valid key receive `401 Unauthorized`.

**Key management policy**: The internal API key is managed via environment variables (injected through Docker secrets or `.env` files) and MUST be rotatable without code changes. For MVP, a single shared key is used. Production hardening should consider: (1) key rotation procedure (deploy new key to both services simultaneously, support accepting both old and new keys during a transition window), (2) per-service keys if additional internal services are added, (3) short-lived tokens (e.g., mTLS or signed requests) as a future replacement for static keys.

## Room Lifecycle (Phoenix → Rails HTTP Callbacks)

### POST /internal/rooms

Called by Phoenix → Rails when a room process is successfully spawned.

**When**: After Phoenix consumes a room creation command from `room_creation_queue` (Redis BRPOP) and successfully spawns the Room GenServer process.

**Request**:
```json
{
  "room_id": "uuid",
  "node_name": "game-server-1",
  "status": "ready"
}
```

**Response 200**:
```json
{
  "acknowledged": true
}
```

**Response 404** (room_id not found in Rails DB):
```json
{
  "error": "room_not_found"
}
```

### PUT /internal/rooms/:room_id/started

Called by Phoenix → Rails when all players have joined and the game starts.

**When**: All expected players have joined the room channel.

**Request**:
```json
{
  "room_id": "uuid",
  "started_at": "2026-02-10T01:02:00Z",
  "player_ids": ["uuid1", "uuid2"]
}
```

**Response 200**:
```json
{
  "acknowledged": true,
  "room_status": "playing"
}
```

### PUT /internal/rooms/:room_id/finished

Called by Phoenix → Rails when the game ends normally.

**When**: Game end condition is detected (player HP reaches 0, deck exhausted, etc.).

**Request**:
```json
{
  "room_id": "uuid",
  "winner_id": "uuid",
  "result_data": {
    "players": {
      "uuid1": { "hp": 5, "result": "winner" },
      "uuid2": { "hp": 0, "result": "loser" }
    },
    "turns_played": 12,
    "duration_seconds": 340
  },
  "finished_at": "2026-02-10T01:08:00Z"
}
```

**Response 200**:
```json
{
  "acknowledged": true,
  "game_result_id": "uuid"
}
```

**On failure (after retries)**: Phoenix writes result to Redis `persist_failed:{room_id}` key (TTL: 7 days) and terminates the room. Rails recovers via background job:

- **Scan interval**: Every 5 minutes (configurable via `PERSIST_RECOVERY_INTERVAL_SECONDS` env var, default: 300)
- **Scan method**: `SCAN` with `persist_failed:*` pattern (not `KEYS` — safe for production Redis)
- **Per-key flow**: Read JSON → call `PUT /internal/rooms/:room_id/finished` internally → on success, delete key → on failure, log and retry next cycle
- **Max recovery latency**: 5 minutes (one scan interval) under normal conditions
- **Alert threshold**: If any `persist_failed:*` key exists for longer than 30 minutes (6 consecutive scan failures), emit a `persist_recovery_stalled` alert event
- **Manual fallback**: Admin can view and manually import stalled results via the admin panel

### PUT /internal/rooms/:room_id/aborted

Called by Phoenix → Rails when a room is terminated abnormally.

**When**: Join timeout, admin force-terminate, all players disconnected, or process crash.

**Request**:
```json
{
  "room_id": "uuid",
  "reason": "join_timeout",
  "aborted_at": "2026-02-10T01:04:00Z"
}
```

Valid reasons: `join_timeout`, `all_disconnected`, `admin_terminated`, `process_error`

**Response 200**:
```json
{
  "acknowledged": true,
  "room_status": "aborted"
}
```

## Token Verification

### POST /internal/auth/verify

Called by Phoenix → Rails to verify a JWT access_token during WebSocket connection.

**When**: Client connects to the Phoenix socket with a JWT.

**Request**:
```json
{
  "token": "jwt.token.here"
}
```

**Response 200** (valid):
```json
{
  "valid": true,
  "user_id": "uuid",
  "display_name": "Player1",
  "role": "player",
  "status": "active"
}
```

**Response 200** (invalid):
```json
{
  "valid": false,
  "reason": "expired"
}
```

**Note**: Phoenix may also verify JWT locally using the shared secret (HS256) for performance. This endpoint serves as a fallback and for user status checks (frozen accounts).

## Room Creation (Rails → Phoenix via Redis)

Rails does **not** call Phoenix directly via HTTP. Instead, Rails pushes a room creation command to a shared Redis List, and Phoenix nodes consume commands via BRPOP. This eliminates the need for Phoenix to expose HTTP endpoints and solves multi-node routing naturally.

See [R-009 in research.md](../research.md#r-009-rails--phoenix-communication-architecture) for the full rationale.

### Redis Queue: `room_creation_queue`

**Producer (Rails)**: After matchmaking produces a match, Rails creates a room record (status: `preparing`), then pushes a creation command to the Redis List.

```
LPUSH room_creation_queue <JSON payload>
```

**Payload**:
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
  "enqueued_at": "2026-02-10T01:00:00Z"
}
```

**Consumer (Phoenix)**: Each Phoenix node runs a `RoomCreationConsumer` GenServer that calls `BRPOP room_creation_queue 5` in a loop. When a command is received:

1. Phoenix spawns the Room GenServer process
2. On success: Phoenix calls `POST /internal/rooms` (Phoenix → Rails) to confirm `ready` status
3. On failure: Phoenix calls `POST /internal/rooms` with a failure indicator, or the room times out on the Rails side

**Multiple consumers**: Each Phoenix node runs its own independent consumer. Redis List BRPOP guarantees exactly-once delivery across competing consumers — adding nodes automatically adds consumers for natural load balancing.

**Room creation timeout policy**: Rails enforces a total deadline of 15 seconds from the moment the command is pushed to Redis. Rails polls the room record status (or uses Redis key notification) to detect confirmation. If the deadline is exceeded:

1. Rails marks the match as `failed` and the room record as `failed`
2. Rails removes `active_game:{user_id}` keys from Redis for all matched players
3. Rails returns the match failure to clients polling `GET /matchmaking/status`:
   ```json
   {
     "status": "error",
     "message": "Failed to create game room. Please try again.",
     "can_rejoin_queue": true
   }
   ```
4. Players are free to re-enter the matchmaking queue immediately
5. Rails logs the failure as a structured event (`room_creation_failed`) with room_id and error details for operational monitoring
6. If a Phoenix node later picks up and processes a timed-out command, it detects the `failed` status via the `POST /internal/rooms` callback and discards the room

This corresponds to the spec Edge Case: "What happens when the system cannot create a game room after matching succeeds?"

## Room Operations (Rails → Phoenix via Redis PubSub)

Rails sends room-targeted commands (e.g., admin force-terminate) via Redis PubSub. All Phoenix nodes subscribe to the channel; only the node hosting the target room acts on the command.

### Redis PubSub Channel: `room_commands`

**Publisher (Rails)**:
```
PUBLISH room_commands <JSON payload>
```

**Payload** (terminate example):
```json
{
  "command": "terminate",
  "room_id": "uuid",
  "reason": "admin_terminated",
  "admin_id": "uuid",
  "issued_at": "2026-02-10T01:04:00Z"
}
```

**Subscriber (Phoenix)**: Each Phoenix node subscribes to `room_commands` at startup. On receiving a message:

1. Phoenix looks up the room_id in its local process registry
2. If the room exists on this node: execute the command (e.g., terminate the Room GenServer, which triggers the `PUT /internal/rooms/:room_id/aborted` callback to Rails)
3. If the room does not exist on this node: ignore the message (no-op)

**Supported commands**:

| Command | Fields | Effect |
|---------|--------|--------|
| `terminate` | `room_id`, `reason`, `admin_id` | Force-terminate the room; triggers `aborted` callback to Rails |

**Delivery guarantees**: Redis PubSub is fire-and-forget. If no Phoenix node is subscribed (e.g., all nodes are down), the message is lost. This is acceptable for admin operations because:
- Admin can retry the terminate action
- If the room's Phoenix node is down, the room process is already dead
- Rails can detect stale rooms via periodic health checks

**Fan-out overhead**: All subscribed nodes receive every message. For MVP scale (< 10 nodes) and low-frequency operations (admin terminate), this is negligible. At larger scale, consider per-node queues or Redis Streams.

## Health Check

### GET http://game-server:4000/internal/health

**Response 200**:
```json
{
  "status": "ok",
  "node_name": "game-server-1",
  "active_rooms": 42,
  "connected_players": 78,
  "uptime_seconds": 3600
}
```

## Error Handling

| Scenario | Behavior |
|----------|----------|
| Network timeout (5s) | Retry with exponential backoff |
| 3 consecutive failures | Abort operation, log error |
| 401 Unauthorized | Do not retry, log security event |
| 404 Not Found | Do not retry, handle gracefully |
| 5xx Server Error | Retry with backoff |
