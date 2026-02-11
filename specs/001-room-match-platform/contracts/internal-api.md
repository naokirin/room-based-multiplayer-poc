# API Contract: Phoenix ↔ Rails Internal API

**Feature Branch**: `001-room-match-platform`
**Base URL**: `http://api-server:3001/internal`
**Auth**: API Key in `X-Internal-Api-Key` header
**Format**: JSON
**Timeout**: 5 seconds per request
**Retry**: Exponential backoff, max 3 attempts

## Authentication

All internal API requests must include:

```
X-Internal-Api-Key: {shared_api_key}
```

Rails validates the key matches the configured `INTERNAL_API_KEY` environment variable. Requests without a valid key receive `401 Unauthorized`.

**Key management policy**: The internal API key is managed via environment variables (injected through Docker secrets or `.env` files) and MUST be rotatable without code changes. For MVP, a single shared key is used. Production hardening should consider: (1) key rotation procedure (deploy new key to both services simultaneously, support accepting both old and new keys during a transition window), (2) per-service keys if additional internal services are added, (3) short-lived tokens (e.g., mTLS or signed requests) as a future replacement for static keys.

## Room Lifecycle

### POST /internal/rooms

Called by Phoenix → Rails when a room process is successfully spawned.

**When**: After Rails calls Phoenix to create a room and Phoenix successfully spawns the process.

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

**On failure (after retries)**: Phoenix writes result to Redis `persist_failed:{room_id}` key and terminates the room. Rails recovers via background job polling.

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

## Room Creation (Rails → Phoenix)

This is the reverse direction: Rails calls Phoenix to create a room process.

### POST http://game-server:4000/internal/rooms/create

Called by Rails → Phoenix when matchmaking produces a room.

**Request**:
```json
{
  "room_id": "uuid",
  "game_type_id": "uuid",
  "player_ids": ["uuid1", "uuid2"],
  "config": {
    "player_count": 2,
    "turn_time_limit": 60,
    "game_rules": "simple_card_battle"
  }
}
```

**Response 200** (success):
```json
{
  "created": true,
  "room_id": "uuid",
  "node_name": "game-server-1"
}
```

**Response 503** (cannot create room):
```json
{
  "created": false,
  "reason": "capacity_exceeded"
}
```

## Admin Operations (Rails → Phoenix)

### POST http://game-server:4000/internal/rooms/:room_id/terminate

Called by Rails → Phoenix when an admin force-terminates a room.

**Request**:
```json
{
  "room_id": "uuid",
  "reason": "admin_terminated",
  "admin_id": "uuid"
}
```

**Response 200**:
```json
{
  "terminated": true
}
```

**Response 404** (room not found on this node):
```json
{
  "terminated": false,
  "reason": "room_not_found"
}
```

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
