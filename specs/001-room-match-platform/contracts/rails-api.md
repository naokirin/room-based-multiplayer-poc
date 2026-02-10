# API Contract: Client ↔ Rails REST API

**Feature Branch**: `001-room-match-platform`
**Base URL**: `http://localhost:3001/api/v1`
**Auth**: JWT Bearer token in `Authorization` header (except login/register)
**Format**: JSON

## Authentication

### POST /auth/register

Create a new user account.

**Request**:
```json
{
  "user": {
    "email": "player@example.com",
    "password": "securepassword",
    "display_name": "Player1"
  }
}
```

**Response 201**:
```json
{
  "user": {
    "id": "uuid",
    "email": "player@example.com",
    "display_name": "Player1"
  },
  "access_token": "jwt.token.here",
  "expires_at": "2026-02-10T02:00:00Z"
}
```

**Response 422** (validation error):
```json
{
  "errors": {
    "email": ["has already been taken"],
    "password": ["is too short (minimum is 8 characters)"]
  }
}
```

### POST /auth/login

Authenticate and receive access token.

**Request**:
```json
{
  "email": "player@example.com",
  "password": "securepassword"
}
```

**Response 200**:
```json
{
  "user": {
    "id": "uuid",
    "email": "player@example.com",
    "display_name": "Player1",
    "role": "player",
    "status": "active"
  },
  "access_token": "jwt.token.here",
  "expires_at": "2026-02-10T02:00:00Z"
}
```

**Response 401** (invalid credentials or frozen):
```json
{
  "error": "invalid_credentials",
  "message": "Invalid email or password"
}
```

```json
{
  "error": "account_frozen",
  "message": "Your account has been suspended"
}
```

### POST /auth/refresh

Refresh an expiring access token.

**Request**: Authorization header with current (valid) JWT.

**Response 200**:
```json
{
  "access_token": "new.jwt.token",
  "expires_at": "2026-02-10T03:00:00Z"
}
```

## Profile

### GET /profile

Get current user's profile.

**Response 200**:
```json
{
  "user": {
    "id": "uuid",
    "email": "player@example.com",
    "display_name": "Player1",
    "role": "player",
    "status": "active",
    "created_at": "2026-01-01T00:00:00Z"
  }
}
```

## Matchmaking

### POST /matchmaking/join

Enter the matchmaking queue for a game type.

**Request**:
```json
{
  "game_type_id": "uuid"
}
```

**Response 200** (queued successfully):
```json
{
  "status": "queued",
  "game_type_id": "uuid",
  "queued_at": "2026-02-10T01:00:00Z",
  "timeout_seconds": 60
}
```

**Response 409** (already in game or queue):
```json
{
  "error": "already_active",
  "message": "You are already in an active game or matchmaking queue"
}
```

**Response 200** (match found immediately):
```json
{
  "status": "matched",
  "room_id": "uuid",
  "room_token": "jwt.room.token",
  "ws_url": "ws://localhost:4000/socket",
  "game_type": {
    "id": "uuid",
    "name": "simple_card_battle",
    "player_count": 2
  }
}
```

### Match Notification Mechanism

When a player joins the matchmaking queue and a match is not found immediately, the client needs to know when a match is eventually found. The MVP uses a **polling approach**:

1. Client calls `POST /matchmaking/join` and receives `status: "queued"`
2. Client polls `GET /matchmaking/status` every 3-5 seconds
3. When a match is found, the status response returns `status: "matched"` with `room_id`, `room_token`, and `ws_url`
4. Client stops polling and connects to the WebSocket

**Why polling over WebSocket push for MVP**: The WebSocket connection to Phoenix is not yet established at matchmaking time (it's established after receiving the `ws_url`). Adding a separate notification channel for matchmaking adds complexity. Polling at 3-5 second intervals is sufficient for MVP. A future enhancement could use Server-Sent Events (SSE) or establish the Phoenix WebSocket connection earlier (at login) to push match notifications.

### DELETE /matchmaking/cancel

Cancel matchmaking and leave the queue.

**Response 200**:
```json
{
  "status": "cancelled"
}
```

**Response 404** (not in queue):
```json
{
  "error": "not_in_queue",
  "message": "You are not in a matchmaking queue"
}
```

### GET /matchmaking/status

Check current matchmaking status (polling fallback).

**Response 200** (still queued):
```json
{
  "status": "queued",
  "queued_at": "2026-02-10T01:00:00Z",
  "elapsed_seconds": 15
}
```

**Response 200** (match found):
```json
{
  "status": "matched",
  "room_id": "uuid",
  "room_token": "jwt.room.token",
  "ws_url": "ws://localhost:4000/socket"
}
```

**Response 200** (timed out):
```json
{
  "status": "timeout",
  "message": "No match found within the time limit"
}
```

## Rooms

### GET /rooms/:room_id/ws_endpoint

Get WebSocket endpoint for reconnection.

**Response 200**:
```json
{
  "ws_url": "ws://localhost:4000/socket",
  "node_name": "game-server-1",
  "room_status": "playing"
}
```

**Response 404** (room not found or finished):
```json
{
  "error": "room_not_found",
  "message": "Room does not exist or has ended"
}
```

## Game Types

### GET /game_types

List available game types.

**Response 200**:
```json
{
  "game_types": [
    {
      "id": "uuid",
      "name": "simple_card_battle",
      "player_count": 2,
      "turn_time_limit": 60
    }
  ]
}
```

## Announcements

### GET /announcements

Get active announcements for the current user.

**Response 200**:
```json
{
  "announcements": [
    {
      "id": "uuid",
      "title": "Scheduled Maintenance",
      "body": "The server will be down for maintenance from 2:00 AM to 4:00 AM.",
      "published_at": "2026-02-10T00:00:00Z"
    }
  ]
}
```

## Health Check

### GET /health

Public health check endpoint for load balancer and monitoring.

**Response 200** (healthy):
```json
{
  "status": "ok",
  "services": {
    "database": "ok",
    "redis": "ok"
  }
}
```

**Response 503** (unhealthy):
```json
{
  "status": "degraded",
  "services": {
    "database": "ok",
    "redis": "error"
  }
}
```

**Note**: This endpoint does not require authentication. It checks database and Redis connectivity and is used by Docker health checks, load balancers, and monitoring systems. Corresponds to 解消11 in the original design document.

## Common Error Responses

**401 Unauthorized** (missing/invalid/expired JWT):
```json
{
  "error": "unauthorized",
  "message": "Invalid or expired token"
}
```

**403 Forbidden** (account frozen):
```json
{
  "error": "forbidden",
  "message": "Account is frozen"
}
```

**429 Too Many Requests** (rate limited):
```json
{
  "error": "rate_limited",
  "message": "Too many requests, please try again later"
}
```

**500 Internal Server Error**:
```json
{
  "error": "internal_error",
  "message": "An unexpected error occurred"
}
```
