# Key Flow Sequence Diagrams

## 1. Authentication Flow (Login / Registration)

```mermaid
sequenceDiagram
    actor Player as Player
    participant Client as Client<br/>(React)
    participant API as API Server<br/>(Rails :3001)
    participant DB as MySQL

    Player->>Client: Enter email + password
    Client->>API: POST /api/v1/auth/login
    API->>DB: User lookup + password verification
    DB-->>API: User record

    alt Authentication success
        API->>API: Generate JWT (HS256, TTL 1 hour)
        API->>DB: Record AuditLog
        API-->>Client: 200 { access_token, expires_at, user }
        Client->>Client: Save to localStorage + update authStore
    else Authentication failure
        API->>DB: Record AuditLog (login_failed)
        API-->>Client: 401 Unauthorized
    end

    Note over Client: Background token refresh
    loop 5 minutes before expiration
        Client->>API: POST /api/v1/auth/refresh
        API->>API: Issue new JWT
        API-->>Client: 200 { access_token, expires_at }
        Client->>Client: Update localStorage
    end
```

## 2. Matchmaking Flow

```mermaid
sequenceDiagram
    actor Player as Player
    participant Client as Client<br/>(React)
    participant API as API Server<br/>(Rails :3001)
    participant Redis as Redis
    participant Game as Game Server<br/>(Phoenix :4000)
    participant DB as MySQL

    Player->>Client: "Start Matchmaking" button
    Client->>API: POST /api/v1/matchmaking/join { game_type_id }

    API->>Redis: GET active_game:{user_id}
    Note over API: Duplicate join check

    API->>Redis: LPUSH match_queue:{game_type_id}<br/>{ user_id, queued_at }
    API-->>Client: 200 { status: "queued", timeout_seconds: 60 }

    Note over API: Matchmaking process
    API->>Redis: Lua script: atomically POP N players
    API->>DB: Create Match, Room records (status: preparing)
    API->>Redis: SET room_token:{token} (TTL 5 min)
    API->>Redis: SET active_game:{user_id}
    API->>Redis: LPUSH room_creation_queue<br/>{ room_id, game_type_id, player_ids, config }

    Note over Game: Room creation (BRPOP Consumer)
    Game->>Redis: BRPOP room_creation_queue 5
    Redis-->>Game: Room creation command
    Game->>Game: Start Room GenServer
    Game->>API: POST /internal/rooms<br/>{ room_id, node_name, status: ready }
    API->>DB: Room.status = ready

    Note over Client: Polling (3-5 second interval)
    loop Max 20 times/min
        Client->>API: GET /api/v1/matchmaking/status
        API->>DB: Check match status
        alt Still waiting
            API-->>Client: 200 { status: "queued" }
        else Match found
            API-->>Client: 200 { status: "matched",<br/>room_id, room_token, ws_url }
        end
    end
```

## 3. Game Room Lifecycle

```mermaid
sequenceDiagram
    actor P1 as Player 1
    actor P2 as Player 2
    participant Client1 as Client 1
    participant Client2 as Client 2
    participant Game as Game Server<br/>(Phoenix :4000)
    participant Redis as Redis
    participant API as API Server<br/>(Rails :3001)
    participant DB as MySQL

    Note over Client1,Client2: Room Join Phase
    Client1->>Game: Socket.connect({token: jwt})
    Game->>Game: JWT verification

    Client1->>Game: channel.join("room:{room_id}",<br/>{room_token})
    Game->>Redis: GET room_token:{token}
    Game->>Game: Room.join(user_id)
    Game->>Redis: SET reconnect:{room_id}:{user_id}<br/>(TTL 24h)
    Game-->>Client1: joined { room_id, status: waiting,<br/>players, reconnect_token }

    Client2->>Game: Socket.connect + channel.join
    Game->>Game: Room.join(user_id)
    Game->>Redis: SET reconnect:{room_id}:{user_id}

    Note over Game: All players joined → Game starts
    Game->>API: PUT /internal/rooms/{room_id}/started
    API->>DB: Room.status = playing
    Game-->>Client1: game:started { players, first_turn,<br/>your_hand, hp }
    Game-->>Client2: game:started { players, first_turn,<br/>your_hand, hp }

    Note over Client1,Client2: Gameplay (turn-based)
    loop Until game ends
        P1->>Client1: Play card
        Client1->>Game: game:action { action, card_id,<br/>target, nonce }
        Game->>Game: Rate limit (1/sec) + nonce dedup check
        Game->>Game: validate_action → apply_action
        Game-->>Client1: game:action_applied { effects }
        Game-->>Client2: game:action_applied { effects }
        Game-->>Client2: game:turn_changed<br/>{ current_turn, drawn_card }
    end

    Note over Game: Game ends
    Game->>Game: check_end_condition → determine winner
    Game-->>Client1: game:ended { winner, final_state }
    Game-->>Client2: game:ended { winner, final_state }
    Game->>API: PUT /internal/rooms/{room_id}/finished<br/>{ result_data, winner_id }
    API->>DB: Create GameResult, Room.status = finished
    Game->>Game: Room GenServer terminate
```

## 4. Reconnection Flow

```mermaid
sequenceDiagram
    actor Player as Player
    participant Client as Client<br/>(React)
    participant Game as Game Server<br/>(Phoenix :4000)
    participant Redis as Redis
    participant OtherClient as Other Player's<br/>Client

    Note over Client,Game: Disconnection occurs
    Client--xGame: WebSocket disconnected
    Game->>Game: RoomChannel.terminate
    Game->>Game: Room.disconnect(user_id)
    Game-->>OtherClient: player:disconnected { user_id }

    Note over Game: 60-second timeout starts

    alt Reconnects within 60 seconds
        Player->>Client: Returns to app
        Client->>Client: Retrieve reconnect_token<br/>from localStorage
        Client->>Game: Socket.connect({token: jwt})
        Client->>Game: channel.join("room:{room_id}",<br/>{reconnect_token})
        Game->>Redis: GET reconnect:{room_id}:{user_id}
        Game->>Game: Room.rejoin(user_id)
        Game-->>Client: joined { game_state, current_turn,<br/>players, your_hand }
        Note over Client: Full state restored
        Game-->>OtherClient: player:reconnected { user_id }
    else 60-second timeout
        Game->>Game: reconnect_timeout
        Game->>Game: on_player_removed(game_state)
        Game-->>OtherClient: player:left<br/>{ reason: "reconnect_timeout" }
        Note over Game: Continue game or abort decision
    end
```

## 5. Chat Flow

```mermaid
sequenceDiagram
    actor Player as Player
    participant Client as Client<br/>(React)
    participant Game as Game Server<br/>(Phoenix :4000)
    participant Others as Other Players'<br/>Clients

    Player->>Client: Enter message
    Client->>Game: chat:send { content }

    Game->>Game: Validation
    Note over Game: Rate limit: 5/10sec<br/>Length: max 500 chars<br/>Empty check

    alt Validation success
        Game->>Game: Room.add_chat_message<br/>(ring buffer, max 100)
        Game-->>Client: chat:new_message<br/>{ sender_id, content, sent_at }
        Game-->>Others: chat:new_message<br/>{ sender_id, content, sent_at }
    else Validation failure
        Game-->>Client: error { reason }
    end

    Note over Game: Chat is ephemeral<br/>Lost when Room ends
```

## 6. Matchmaking Cancellation Flow

```mermaid
sequenceDiagram
    actor Player as Player
    participant Client as Client<br/>(React)
    participant API as API Server<br/>(Rails :3001)
    participant Redis as Redis

    Player->>Client: "Cancel" button<br/>(during 60-second countdown)
    Client->>API: DELETE /api/v1/matchmaking/cancel

    API->>Redis: LREM match_queue:{game_type_id}<br/>user_id entry
    API->>Redis: DEL active_game:{user_id}
    API-->>Client: 200 { status: "cancelled" }
    Client->>Client: Reset lobbyStore

    Note over API: Auto-cancel on timeout
    API->>API: MatchmakingCleanupJob (periodic)
    API->>Redis: Scan & remove entries older than 60 seconds
```

## 7. Admin Operation Flow (Force Terminate Room)

```mermaid
sequenceDiagram
    actor Admin as Admin
    participant AdminUI as Admin Panel<br/>(Rails)
    participant API as API Server<br/>(Rails :3001)
    participant Redis as Redis
    participant Game as Game Server<br/>(Phoenix :4000)
    participant Clients as All Clients
    participant DB as MySQL

    Admin->>AdminUI: Force terminate room button
    AdminUI->>API: POST /admin/rooms/{id}/terminate
    API->>DB: Record AuditLog
    API->>Redis: PUBLISH room_commands<br/>{ command: "terminate",<br/>room_id, admin_id }

    Game->>Redis: SUBSCRIBE room_commands
    Redis-->>Game: Receive terminate command

    Game->>Game: Check local registry<br/>(only owning node executes)
    Game->>Game: Room GenServer stop

    Game-->>Clients: game:aborted<br/>{ reason: "admin_terminated" }
    Game->>API: PUT /internal/rooms/{room_id}/aborted
    API->>DB: Room.status = aborted
```

## 8. Room State Transition Diagram

```mermaid
stateDiagram-v2
    [*] --> preparing: Match found<br/>(Rails)

    preparing --> ready: Phoenix Room GenServer started
    ready --> playing: All players joined

    playing --> finished: Game ended normally<br/>(winner determined)
    playing --> aborted: Admin force termination<br/>or all players left

    preparing --> aborted: Room creation failed<br/>or timeout

    finished --> [*]
    aborted --> [*]
```
