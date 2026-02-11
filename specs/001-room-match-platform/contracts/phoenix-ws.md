# API Contract: Client ↔ Phoenix WebSocket Protocol

**Feature Branch**: `001-room-match-platform`
**Endpoint**: `ws://localhost:4000/socket`
**Protocol**: Phoenix Channels (phoenix.js client)
**Auth**: JWT access_token passed as param on socket connect

## Connection

### Socket Connect

Client connects to the Phoenix socket with JWT authentication and protocol version.

```javascript
import { Socket } from "phoenix"

const socket = new Socket("ws://localhost:4000/socket", {
  params: { token: accessToken, protocol_version: "1.0" }
})
socket.connect()
```

**Parameters**:
- `token`: JWT access_token
- `protocol_version`: Client protocol version string (e.g., `"1.0"`). Server checks against its supported versions and rejects unsupported versions.

**Server validates**: JWT signature, expiration, user status (not frozen), protocol version compatibility.

**On success**: Socket connected, heartbeat begins.
**On failure**: Socket error callback with `{ reason: "unauthorized" }` or `{ reason: "unsupported_protocol_version", supported: ["1.0"] }`.

**Note on frozen accounts**: User status (frozen) is checked only at connection time (socket connect) and channel join/rejoin. If a user is frozen by an admin while already connected and in a game, the existing session is NOT actively terminated. The freeze takes effect at the next authentication boundary (reconnect, new matchmaking, or re-login). See spec Edge Cases for rationale.

### Protocol Versioning

Phoenix maintains a list of supported protocol versions. When a client connects with an unsupported version, the connection is rejected with the list of supported versions so the client can prompt the user to update.

| Version | Status | Notes |
|---------|--------|-------|
| 1.0 | Current | MVP initial version |

## Security: Replay Attack Protection

All client → server game actions include a `nonce` field to prevent replay attacks. The nonce is a client-generated unique string (e.g., UUID v4) per action.

**Server-side validation**:
1. Phoenix maintains a per-player nonce cache (in-memory, bounded set of recent nonces per room session)
2. On receiving a `game:action`, the server checks whether the nonce has been seen before
3. If duplicate nonce detected: action is rejected with `{ "reason": "duplicate_nonce" }`
4. Nonces are scoped per player per room session and cleared when the room ends

**Client implementation**:
```javascript
import { v4 as uuidv4 } from "uuid"

channel.push("game:action", {
  action: "play_card",
  card_id: "card_1",
  nonce: uuidv4()
})
```

**Note**: Chat messages (`chat:send`) do not require nonces as they are idempotent broadcasts with server-assigned IDs.

## Channel: `room:{room_id}`

The primary game channel. Handles game events, player actions, and room chat.

### Join

Client joins with the room_token received from matchmaking.

```javascript
const channel = socket.channel(`room:${roomId}`, { room_token: roomToken })
channel.join()
  .receive("ok", (response) => { /* joined */ })
  .receive("error", (response) => { /* rejected */ })
```

**Room Token Verification Flow (Redis-based)**:

When a client joins with a `room_token`, Phoenix performs the following verification against Redis:

1. **Signature check**: Verify room_token JWT signature using shared secret (HS256)
2. **Redis lookup**: Query `room_token:{token}` key in Redis
3. **Validate**: Check `room_id` and `user_id` match, and status is `pending` (not already `used`)
4. **Mark used**: On successful join, set status to `used` with a short TTL (10 seconds) instead of immediate deletion. This handles the case where the client disconnects before receiving the `joined` response — they can retry within the 10-second window.
5. **Cleanup**: Redis TTL (5 minutes from creation) automatically removes expired tokens

**Why not immediate deletion**: If the join succeeds on the server but the `joined` response doesn't reach the client (network cut), the token would already be deleted. The "used + short TTL" approach allows a brief retry window.

**Join success response**:
```json
{
  "room_id": "uuid",
  "status": "waiting",
  "players": [
    { "user_id": "uuid", "display_name": "Player1", "connected": true }
  ],
  "reconnect_token": "opaque-uuid-token"
}
```

**Join error response** (invalid token, room full, room not found):
```json
{
  "reason": "invalid_token"
}
```

```json
{
  "reason": "token_already_used"
}
```

### Rejoin (Reconnection)

Client reconnects using reconnect_token instead of room_token.

```javascript
const channel = socket.channel(`room:${roomId}`, { reconnect_token: reconnectToken })
channel.join()
  .receive("ok", (response) => { /* reconnected with state */ })
  .receive("error", (response) => { /* reconnection failed */ })
```

**Rejoin success response**:
```json
{
  "room_id": "uuid",
  "status": "active",
  "game_state": {
    "current_turn": "user_id",
    "turn_number": 5,
    "turn_time_remaining": 42,
    "players": {
      "user_id_1": {
        "display_name": "Player1",
        "connected": true,
        "hp": 15,
        "hand_count": 3,
        "deck_count": 2
      },
      "user_id_2": {
        "display_name": "Player2",
        "connected": true,
        "hp": 12,
        "hand_count": 2,
        "deck_count": 1
      }
    },
    "your_hand": [
      { "id": "card_1", "name": "Fireball", "effect": "deal_damage", "value": 3 },
      { "id": "card_2", "name": "Heal", "effect": "heal", "value": 2 }
    ]
  },
  "reconnect_token": "new-opaque-uuid-token"
}
```

## Client → Server Messages (push)

### game:action

Submit a game action during your turn. Each action must include a unique `nonce` for replay protection (see Security section above).

```javascript
channel.push("game:action", {
  action: "play_card",
  card_id: "card_1",
  target: "opponent",  // optional, depends on card
  nonce: "uuid-v4"     // required, unique per action
})
```

**Reply "ok"**:
```json
{
  "accepted": true,
  "action_id": "uuid"
}
```

**Reply "error"** (invalid action):
```json
{
  "accepted": false,
  "reason": "not_your_turn"
}
```

```json
{
  "accepted": false,
  "reason": "invalid_card",
  "message": "Card not in your hand"
}
```

```json
{
  "accepted": false,
  "reason": "rate_limited",
  "message": "Too many actions"
}
```

```json
{
  "accepted": false,
  "reason": "duplicate_nonce",
  "message": "Action already processed"
}
```

### chat:send

Send a chat message to the room.

```javascript
channel.push("chat:send", {
  content: "Good luck!"
})
```

**Reply "ok"**:
```json
{
  "sent": true,
  "message_id": "uuid"
}
```

**Reply "error"** (rate limited or content too long):
```json
{
  "sent": false,
  "reason": "rate_limited"
}
```

## Server → Client Messages (broadcast)

### game:started

Broadcast when all players have joined and the game begins.

```json
{
  "event": "game:started",
  "payload": {
    "game_type": "simple_card_battle",
    "players": [
      { "user_id": "uuid", "display_name": "Player1" },
      { "user_id": "uuid", "display_name": "Player2" }
    ],
    "first_turn": "user_id",
    "your_hand": [
      { "id": "card_1", "name": "Fireball", "effect": "deal_damage", "value": 3 },
      { "id": "card_2", "name": "Heal", "effect": "heal", "value": 2 },
      { "id": "card_3", "name": "Draw", "effect": "draw_card", "value": 1 }
    ],
    "your_hp": 20,
    "opponent_hp": 20,
    "turn_time_limit": 60
  }
}
```

### game:action_applied

Broadcast when a player's action has been validated and applied.

```json
{
  "event": "game:action_applied",
  "payload": {
    "actor": "user_id",
    "action": "play_card",
    "card": { "id": "card_1", "name": "Fireball", "effect": "deal_damage", "value": 3 },
    "effects": [
      { "type": "damage", "target": "user_id_2", "amount": 3, "new_hp": 12 }
    ],
    "turn_number": 5
  }
}
```

### game:turn_changed

Broadcast when the turn changes to the next player.

```json
{
  "event": "game:turn_changed",
  "payload": {
    "current_turn": "user_id",
    "turn_number": 6,
    "turn_time_limit": 60,
    "drawn_card": { "id": "card_4", "name": "Heal", "effect": "heal", "value": 2 }
  }
}
```

Note: `drawn_card` is only included for the player whose turn it is (sent as a targeted message, not broadcast). Other players receive `drawn_card: null`.

### game:turn_skipped

Broadcast when a player's turn was skipped due to timeout.

```json
{
  "event": "game:turn_skipped",
  "payload": {
    "skipped_player": "user_id",
    "reason": "timeout",
    "next_turn": "user_id_2",
    "turn_number": 7
  }
}
```

### game:ended

Broadcast when the game reaches its end condition.

```json
{
  "event": "game:ended",
  "payload": {
    "winner": "user_id",
    "reason": "opponent_defeated",
    "final_state": {
      "user_id_1": { "hp": 5, "result": "winner" },
      "user_id_2": { "hp": 0, "result": "loser" }
    },
    "turns_played": 12,
    "duration_seconds": 340
  }
}
```

### game:aborted

Broadcast when the game is forcibly ended (admin, all disconnected, system error).

```json
{
  "event": "game:aborted",
  "payload": {
    "reason": "admin_terminated",
    "message": "The game has been terminated by an administrator"
  }
}
```

### player:joined

Broadcast when a player joins the room.

```json
{
  "event": "player:joined",
  "payload": {
    "user_id": "uuid",
    "display_name": "Player1",
    "players_joined": 1,
    "players_required": 2
  }
}
```

### player:disconnected

Broadcast when a player's connection drops.

```json
{
  "event": "player:disconnected",
  "payload": {
    "user_id": "uuid",
    "display_name": "Player1"
  }
}
```

### player:reconnected

Broadcast when a disconnected player reconnects.

```json
{
  "event": "player:reconnected",
  "payload": {
    "user_id": "uuid",
    "display_name": "Player1"
  }
}
```

### player:left

Broadcast when a player is removed (reconnect timeout expired).

```json
{
  "event": "player:left",
  "payload": {
    "user_id": "uuid",
    "display_name": "Player1",
    "reason": "reconnect_timeout"
  }
}
```

### chat:new_message

Broadcast when a chat message is sent in the room.

```json
{
  "event": "chat:new_message",
  "payload": {
    "message_id": "uuid",
    "sender_id": "uuid",
    "sender_name": "Player1",
    "content": "Good luck!",
    "sent_at": "2026-02-10T01:05:00Z"
  }
}
```

## Error Handling

All push operations return replies with `"ok"` or `"error"` status. Channel-level errors (e.g., authorization failure mid-session) trigger a channel close event.

## Rate Limits

| Action | Limit |
|--------|-------|
| game:action | 1 per second per user |
| chat:send | 5 per 10 seconds per user |
| channel join | 3 attempts per minute |
