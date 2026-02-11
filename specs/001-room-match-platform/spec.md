# Feature Specification: Room-Based Multiplayer Game Platform (MVP)

**Feature Branch**: `001-room-match-platform`
**Created**: 2026-02-10
**Status**: Draft
**Input**: User description: "Room-based multiplayer game platform with authentication, room matching, real-time turn-based gameplay, room chat, reconnection support, and admin management"

### Platform Positioning

This project is a **server-client game platform** — a reusable infrastructure for hosting room-based multiplayer games, not a specific game itself. Target game characteristics:

- Room-match multiplayer as the primary play mode
- Card games, board games, or other low-latency-insensitive genres with small player counts (2–10 players)
- Optional chat or communication features per game
- Designed for long-term operation with incremental feature additions and configuration-driven updates
- **MVP client**: Web browser (PixiJS/TypeScript); **future extension**: Unity/C#

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Match and Play a Game (Priority: P1)

A player logs in, requests to be matched with other players, and plays a turn-based game in a room. The system automatically finds suitable opponents, creates a game room, and manages the entire game flow from start to finish with server-driven progression.

**Why this priority**: This is the core value proposition of the platform. Without the ability to match and play, nothing else matters. It encompasses authentication, matching, room creation, and game progression.

**Independent Test**: Can be fully tested by having 2 players log in, request a match, get placed in a room, take turns, and complete a game. Delivers the fundamental multiplayer experience.

**Acceptance Scenarios**:

1. **Given** a registered player is logged in, **When** the player requests a match, **Then** the player enters a matching queue and sees a "searching for opponents" status.
2. **Given** enough players are in the matching queue for a game type, **When** the required number of players is reached, **Then** a game room is created and all matched players are notified with room access.
3. **Given** all matched players have joined the room, **When** the last player joins, **Then** the game starts automatically and all players are notified.
4. **Given** a game is in progress and it is a player's turn, **When** the player submits an action, **Then** the server validates the action against game rules and applies it if valid.
5. **Given** a game is in progress, **When** a player submits an invalid action (wrong turn, insufficient resources, illegal move), **Then** the action is rejected and the player is informed of the reason.
6. **Given** a game reaches its end condition, **When** the game ends, **Then** all players are notified of the result and the game outcome is recorded.

---

### User Story 2 - Reconnect to an Ongoing Game (Priority: P2)

A player who loses network connection during a game can reconnect and resume playing from where they left off, seeing the current game state including any changes that occurred while disconnected.

**Why this priority**: Network interruptions are common, especially on mobile. Without reconnection, any disconnection ruins the experience for all players in the room. This is critical for user retention and fair gameplay.

**Independent Test**: Can be tested by having a player disconnect mid-game, then reconnect within the allowed window and verify they see the up-to-date game state and can continue playing.

**Acceptance Scenarios**:

1. **Given** a player is in a game and loses connection, **When** the connection drops, **Then** other players in the room are notified that the player is temporarily disconnected.
2. **Given** a player is temporarily disconnected, **When** the player reconnects within the allowed time window, **Then** the player receives the current game state and can resume playing.
3. **Given** a player is temporarily disconnected, **When** the reconnection time window expires, **Then** the player is removed from the game and other players are notified.
4. **Given** a player is temporarily disconnected during their turn, **When** their turn timer expires, **Then** the turn is skipped and game progresses to the next player.
5. **Given** a player has reconnected, **When** they view the game state, **Then** all actions that occurred during their disconnection are reflected accurately.

---

### User Story 3 - Chat with Other Players in a Room (Priority: P3)

A player in a game room can send and receive text messages with other players in the same room in real-time, enabling social interaction and strategic communication during gameplay.

**Why this priority**: Multiplayer games are social experiences. Room chat enhances engagement and enjoyment. It is scoped to room-level only for MVP (global chat is deferred).

**Independent Test**: Can be tested by having multiple players in a room send messages and verify all room members receive them in real-time.

**Acceptance Scenarios**:

1. **Given** a player is in a game room, **When** the player sends a chat message, **Then** all other players in the room see the message immediately.
2. **Given** a player is in a game room, **When** another player sends a message, **Then** the player receives and sees the message in real-time.
3. **Given** a player reconnects to a game room, **When** the player views the chat, **Then** the player does not see messages that were sent while they were disconnected (chat is ephemeral).
4. **Given** a game has ended, **When** the room is closed, **Then** the chat history is no longer accessible.

---

### User Story 4 - Cancel Matchmaking (Priority: P3)

A player who is waiting in the matching queue can cancel the search and return to the lobby without being forced into a game.

**Why this priority**: Player autonomy is important. Users should not feel trapped in a process they want to exit.

**Independent Test**: Can be tested by having a player enter the matching queue, then cancel before a match is found, and verify they are removed from the queue.

**Acceptance Scenarios**:

1. **Given** a player is in the matching queue, **When** the player requests to cancel, **Then** the player is removed from the queue and returned to the lobby.
2. **Given** a player is in the matching queue, **When** the matching timeout expires without finding opponents, **Then** the player is informed that no match was found and returned to the lobby.

---

### User Story 5 - Admin Manages Users and Rooms (Priority: P4)

An administrator can search for users, freeze accounts of malicious players, view active and completed game rooms, and force-terminate problematic rooms.

**Why this priority**: Operational management is essential for a live service. Without admin tools, there is no way to handle abuse or operational incidents.

**Independent Test**: Can be tested by having an admin search for a user, freeze their account, view room lists, and force-terminate a room.

**Acceptance Scenarios**:

1. **Given** an administrator is logged into the admin panel, **When** the admin searches for a user by name or ID, **Then** the matching user profile and basic information are displayed.
2. **Given** an administrator views a user profile, **When** the admin freezes the account, **Then** the user cannot log in or enter matchmaking until unfrozen.
3. **Given** an administrator views the room list, **When** the admin views active rooms, **Then** room status (in progress, finished, aborted) is displayed.
4. **Given** an administrator identifies a problematic room, **When** the admin force-terminates the room, **Then** all players are notified and the room is closed.
5. **Given** an administrator needs to communicate with users, **When** the admin creates an announcement, **Then** users see the announcement (e.g., maintenance notice).

---

### Edge Cases

- What happens when a player tries to join a room after it has already started? The system rejects the join attempt.
- What happens when all players disconnect from a room simultaneously? The room enters a waiting state; if no one reconnects within the timeout, the room is aborted.
- What happens when a player tries to match while already in a game? The system rejects the matchmaking request and informs the player they are already in a game.
- What happens when the system cannot create a game room after matching succeeds? The match is cancelled, players are notified of the failure, and they can re-enter the queue.
- What happens when a player submits actions extremely rapidly? The system enforces rate limiting and rejects excessive actions.
- What happens when a player attempts to use another player's identity to reconnect? The system validates reconnection credentials and rejects unauthorized attempts.
- What happens when the admin force-terminates a room mid-game? All players receive a game-aborted notification and the game result is not recorded as a normal outcome.
- What happens when a frozen user attempts to log in? The system denies access and displays a message indicating the account is suspended.
- What happens when a user is frozen while already connected to a game via WebSocket? For MVP, the platform does NOT actively disconnect the player mid-game. The freeze takes effect at the next authentication boundary (login, matchmaking join, WebSocket reconnect). Active game sessions are allowed to complete naturally. Rationale: active session disconnection behavior is game-type-specific (some games may forfeit, others may pause), and implementing a cross-service push mechanism (Rails → Phoenix) adds significant complexity for a rare operational scenario. This is a deliberate MVP scope decision; game-type-specific freeze behavior can be added as a future Behaviour callback (e.g., `on_player_frozen/2`).

## Requirements *(mandatory)*

### Functional Requirements

#### Authentication & Account

- **FR-001**: System MUST allow users to register and create accounts with unique credentials.
- **FR-002**: System MUST authenticate users before allowing access to any game features.
- **FR-003**: System MUST maintain user sessions and handle session expiration gracefully, prompting re-authentication when needed.
- **FR-004**: System MUST prevent frozen accounts from logging in or accessing any features.

#### Matchmaking

- **FR-010**: System MUST provide a queue-based matchmaking system that automatically groups players by game type and required player count.
- **FR-011**: System MUST notify players of their queue status (searching, match found, timeout).
- **FR-012**: System MUST allow players to cancel matchmaking while in the queue.
- **FR-013**: System MUST timeout matchmaking after a configurable period (default: 60 seconds) and inform the player.
- **FR-014**: System MUST prevent players who are already in an active game from entering the matchmaking queue.

#### Room & Game

- **FR-020**: System MUST create a game room when matching is successful and all required players are determined.
- **FR-021**: System MUST wait for all matched players to join the room before starting the game, with a configurable timeout (default: 120 seconds).
- **FR-022**: System MUST abort the room and notify players if not all players join within the timeout period.
- **FR-023**: System MUST enforce turn-based game progression where only the current-turn player can submit actions.
- **FR-024**: System MUST validate all player actions server-side against game rules before applying them (server-authoritative).
- **FR-025**: System MUST reject invalid actions and provide clear feedback to the player.
- **FR-026**: System MUST detect game-end conditions and notify all players of the outcome.
- **FR-027**: System MUST persist game results upon completion. Individual game actions are held in-memory only during the game and are not persisted for MVP. Action replay/audit logging is a future enhancement.
- **FR-028**: System MUST support 1 to approximately 12 players per room, depending on game type.
- **FR-029**: System MUST enforce a per-turn time limit and automatically skip the turn if the player does not act in time.

#### Reconnection

- **FR-030**: System MUST allow disconnected players to reconnect to their active game within a configurable time window.
- **FR-031**: System MUST provide the full current game state to reconnecting players so they can resume seamlessly.
- **FR-032**: System MUST notify other players in the room when a player disconnects and when they reconnect.
- **FR-033**: System MUST treat a player as having left the game if they do not reconnect within the allowed window. The platform notifies the Behaviour module via a callback (e.g., `on_player_removed/2`); the game-type module decides whether the game continues with remaining players or aborts.
- **FR-034**: System MUST prevent duplicate simultaneous connections for the same player in the same room (disconnect the older session).

#### Room Chat

- **FR-040**: System MUST allow players in a game room to send and receive text messages in real-time.
- **FR-041**: System MUST deliver chat messages only to players within the same room.
- **FR-042**: Room chat MUST be ephemeral - messages are not persisted after the room ends.
- **FR-043**: System MUST enforce a maximum chat message length of 500 characters and reject empty messages. This limit is hardcoded for MVP; future enhancement may make it configurable per game type.

#### Administration

- **FR-050**: System MUST provide an admin interface for searching users by name or ID.
- **FR-051**: System MUST allow admins to freeze and unfreeze user accounts.
- **FR-052**: System MUST provide a list of active and completed rooms with their statuses.
- **FR-053**: System MUST allow admins to force-terminate active rooms.
- **FR-054**: System MUST allow admins to create and publish announcements visible to users.

#### Security

- **FR-060**: System MUST validate all inputs server-side; no game logic decisions are made on the client.
- **FR-061**: System MUST enforce rate limiting on player actions to prevent abuse.
- **FR-062**: System MUST log all security-relevant events (failed logins, rejected actions, admin operations) for auditing.
- **FR-063**: System MUST include replay attack protection (nonce) for game actions to prevent duplicate action submission.

### Key Entities

- **User**: A registered player with an account, profile information, and account status (active/frozen). Identified uniquely. Can participate in games.
- **Game Room**: A temporary space where matched players play a game together. Has a lifecycle (preparing, ready, playing, finished/aborted). Belongs to a game type.
- **Game Type**: A configuration defining the rules of a specific game variant, including required player count, turn structure, and win conditions.
- **Match Queue Entry**: A temporary record of a player waiting to be matched, associated with a game type and entry timestamp.
- **Game Action**: A player's input during their turn (e.g., play a card, move a piece). Validated server-side.
- **Game Result**: The outcome of a completed game, including winner(s) and relevant statistics.
- **Chat Message**: An ephemeral text message sent by a player within a game room.
- **Announcement**: A notice created by administrators visible to all users (e.g., maintenance windows).
- **Audit Log**: A record of security-relevant and administrative events for operational monitoring.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Players can go from login to playing a game (match found, room joined, game started) in under 90 seconds when sufficient players are available.
- **SC-002**: The system supports at least 100 concurrent game rooms with up to 4 players each without degradation in game responsiveness.
- **SC-003**: Disconnected players can reconnect and see the current game state within 5 seconds of re-establishing connection.
- **SC-004**: Chat messages are delivered to all room members within 1 second of being sent.
- **SC-005**: 95% of valid player actions receive a server response (accepted or rejected with reason) within 2 seconds.
- **SC-006**: All player actions are validated server-side with zero game logic executed on the client, ensuring cheat resistance.
- **SC-007**: Administrators can find and take action on a user account within 30 seconds using the admin interface.
- **SC-008**: Game results are persisted for 100% of normally completed games (excluding force-terminated or aborted games).

## Assumptions

- **A-001**: MVP targets web browser users only; native/mobile app clients are out of scope.
- **A-002**: Global chat is deferred to post-MVP; only room-level chat is included.
- **A-003**: This project is a **game-agnostic platform** (not a specific game implementation). Game rules and actions are abstracted behind an Elixir Behaviour (callback interface) — each game type implements a module with callbacks such as `init_state/1`, `validate_action/2`, `apply_action/2`, `check_end_condition/1`. The platform runtime is generic; game-specific logic is swapped in via the Behaviour module. Game configuration (cards, rules, balance) is managed via code and configuration files for MVP; a DSL-based dynamic configuration system is a future enhancement.
- **A-004**: For MVP, a minimal sample game (e.g., simple turn-based card or board game) will be included solely to validate the platform architecture. The sample game is not the deliverable; the platform infrastructure is.
- **A-005**: Standard email/password authentication is assumed for MVP; OAuth or SSO integration is a future enhancement. Cross-service auth strategy: Rails issues a JWT on login for **authentication** (identity verification); Phoenix validates the JWT signature independently. However, **authorization** (e.g., "is this player allowed to join this room?") requires Phoenix to call a Rails API endpoint on WebSocket connect to verify room assignment, account status (frozen), and other access rules.
- **A-006**: The admin interface is a separate, authenticated web application accessible only to authorized operators.
- **A-007**: The platform operates in a single region for MVP; multi-region deployment is out of scope.
- **A-008**: Turn time limit defaults to 60 seconds per turn (configurable per game type in the future).
- **A-009**: Reconnection window defaults to the duration of the game session (a disconnected player can reconnect as long as the game is still active).

## Out of Scope

- Global chat (lobby-wide messaging)
- DSL-based game configuration system
- Multiple game types in MVP (platform ships with one minimal sample game for validation only)
- Native/mobile app clients
- Leaderboards and ranking system
- Friend lists and social features
- Spectator mode
- Tournament / organized play support
- Multi-region deployment
- Automated content moderation for chat

## Clarifications

### Session 2026-02-11

- Q: What is the MVP game type to implement? → A: No specific game. This is a game-agnostic platform for room-based multiplayer games (card games, board games, 2–10 player low-latency-insensitive genres). A minimal sample game is included only to validate the platform. Future client extension to Unity/C#.
- Q: How should game logic be abstracted for pluggability? → A: Elixir Behaviour (callback interface) pattern. Each game type implements a module with defined callbacks (init_state, validate_action, apply_action, check_end_condition, etc.). Platform runtime is generic.
- Q: What happens to the game when a disconnected player is permanently removed? → A: Game continues; the Behaviour module decides via `on_player_removed/2` callback (continue with fewer players or abort). Decision is game-type-specific, not platform-level.
- Q: Should individual game actions be persisted for replay/audit? → A: MVP persists only final game results. Actions exist in-memory during the game only. Action replay/audit logging is a future enhancement.
- Q: How does Phoenix authenticate and authorize WebSocket connections? → A: Hybrid — JWT for authentication (identity, validated by Phoenix independently via shared secret), plus Rails API call for authorization (room assignment, account status, access rules) on each WebSocket connect.
- Q: What happens to an active WebSocket session when a user is frozen by an admin? → A: MVP does NOT actively disconnect frozen users mid-game. The freeze takes effect at the next authentication boundary (login, matchmaking, reconnect). Active sessions complete naturally. Rationale: (1) the appropriate response to mid-game freeze is game-type-specific (forfeit vs pause vs continue), so the platform should not impose a single policy; (2) implementing Rails→Phoenix push notification for freeze events adds cross-service complexity for a rare admin operation. Future enhancement: Behaviour callback `on_player_frozen/2` to let each game type decide.
