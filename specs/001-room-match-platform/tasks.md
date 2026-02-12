# Tasks: Room-Based Multiplayer Game Platform (MVP)

**Input**: Design documents from `/specs/001-room-match-platform/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Per Constitution Principle IV (Test-First for Contracts and Critical Paths), test tasks are included for API contracts, WebSocket channels, and critical game flows. Tests MUST be written before or alongside implementation.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **client/**: TypeScript/React/PixiJS web client
- **api-server/**: Ruby on Rails API + Admin
- **game-server/**: Elixir/Phoenix game server
- **infra/**: Docker Compose, MySQL/Redis config

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization, Docker infrastructure, and scaffolding for all 3 services

- [x] T001 Create Docker Compose configuration with 5 services (client, api-server, game-server, mysql, redis) in infra/docker-compose.yml
- [x] T002 [P] Create MySQL init script with database creation in infra/mysql/init.sql
- [x] T003 [P] Create Redis configuration in infra/redis/redis.conf
- [x] T004 [P] Initialize Rails 8 project (full mode, not --api) in api-server/ with Gemfile (jwt, rack-attack, redis, bcrypt, mysql2, uuid, turbo-rails, stimulus-rails)
- [x] T005 [P] Initialize Phoenix 1.7 project (no Ecto, no HTML) in game-server/ with mix.exs (joken, plug_attack, redix)
- [x] T006 [P] Initialize Vite + React + TypeScript project in client/ with package.json (react, pixi.js, zustand, phoenix, uuid)
- [x] T007 [P] Configure Biome linting/formatting in client/biome.json
- [x] T008 Create shared environment variable template in .env.example with JWT_SECRET, INTERNAL_API_KEY, DATABASE_URL, REDIS_URL

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Database & Models (Rails)

- [x] T009 Create Rails migration for users table (UUID PK, email, password_digest, display_name, role, status, frozen_at, frozen_reason) in api-server/db/migrate/
- [x] T010 Create Rails migration for game_types table (UUID PK, name, player_count, turn_time_limit, config_json, active) in api-server/db/migrate/
- [x] T011 Create Rails migration for rooms table (UUID PK, game_type_id FK, status enum, node_name, player_count, started_at, finished_at) in api-server/db/migrate/
- [x] T012 Create Rails migration for room_players table (UUID PK, room_id FK, user_id FK, joined_at, result enum) in api-server/db/migrate/
- [x] T013 Create Rails migration for game_results table (UUID PK, room_id FK unique, winner_id FK, result_data JSON, turns_played, duration_seconds) in api-server/db/migrate/
- [x] T014 Create Rails migration for matches table (UUID PK, game_type_id FK, room_id FK, status enum, matched_at) in api-server/db/migrate/
- [x] T015 Create Rails migration for match_players table (UUID PK, match_id FK, user_id FK, queued_at) in api-server/db/migrate/
- [x] T016 Create Rails migration for cards table (UUID PK, game_type_id FK, name, effect, value, cost, active) in api-server/db/migrate/
- [x] T017 Create Rails migration for announcements table (UUID PK, admin_id FK, title, body, active, published_at, expires_at) in api-server/db/migrate/
- [x] T018 Create Rails migration for audit_logs table (BIGINT PK, actor_id FK, actor_type, action, target_type, target_id, metadata JSON, ip_address) in api-server/db/migrate/
- [x] T019 [P] Implement User model with validations and has_secure_password in api-server/app/models/user.rb
- [x] T020 [P] Implement GameType model with validations in api-server/app/models/game_type.rb
- [x] T021 [P] Implement Room model with status enum and associations in api-server/app/models/room.rb
- [x] T022 [P] Implement RoomPlayer model with associations in api-server/app/models/room_player.rb
- [x] T023 [P] Implement GameResult model with associations in api-server/app/models/game_result.rb
- [x] T024 [P] Implement Match and MatchPlayer models in api-server/app/models/match.rb and api-server/app/models/match_player.rb
- [x] T025 [P] Implement Card model in api-server/app/models/card.rb
- [x] T026 [P] Implement Announcement model in api-server/app/models/announcement.rb
- [x] T027 [P] Implement AuditLog model in api-server/app/models/audit_log.rb

### Base Controllers (Rails)

- [x] T028 [P] Implement Api::V1::ApplicationController inheriting ActionController::API (JSON-only, JWT auth) in api-server/app/controllers/api/v1/application_controller.rb
- [x] T029 [P] Implement Internal::ApplicationController inheriting ActionController::API (JSON-only, API key auth) in api-server/app/controllers/internal/application_controller.rb
- [x] T030 [P] Implement Admin::ApplicationController inheriting ActionController::Base (sessions, CSRF, ERB, Turbo) in api-server/app/controllers/admin/application_controller.rb

### Authentication (Rails)

- [x] T031 Implement JwtService for token encoding/decoding (HS256) in api-server/app/services/jwt_service.rb
- [x] T032 Implement API authentication concern (before_action, current_user) in api-server/app/controllers/concerns/authenticatable.rb
- [x] T033 Implement internal API key authentication concern in api-server/app/controllers/concerns/internal_authenticatable.rb

### Authentication Endpoints (Rails)

- [x] T034 Implement POST /api/v1/auth/register endpoint in api-server/app/controllers/api/v1/auth_controller.rb
- [x] T035 Implement POST /api/v1/auth/login endpoint (with frozen account check) in api-server/app/controllers/api/v1/auth_controller.rb
- [x] T036 Implement POST /api/v1/auth/refresh endpoint in api-server/app/controllers/api/v1/auth_controller.rb
- [x] T037 Implement GET /api/v1/profile endpoint in api-server/app/controllers/api/v1/profiles_controller.rb

### Rate Limiting & Security (Rails)

- [x] T038 Configure rack-attack with per-endpoint rate limits (auth, matchmaking, rooms, admin) in api-server/config/initializers/rack_attack.rb

### Health Check Endpoints

- [x] T039 [P] Implement GET /api/v1/health endpoint (DB + Redis check) in api-server/app/controllers/api/v1/health_controller.rb
- [x] T040 [P] Implement GET /internal/health endpoint for Phoenix in game-server/lib/game_server_web/controllers/health_controller.ex

### Routes

- [x] T041 [P] Configure Rails routes (api/v1 namespace, internal namespace, admin namespace) in api-server/config/routes.rb
- [x] T042 [P] Configure Phoenix router with socket endpoint and internal health route in game-server/lib/game_server_web/router.ex

### Phoenix Socket & JWT

- [x] T043 Implement JWT verification module (HS256 shared secret) in game-server/lib/game_server/auth/jwt.ex
- [x] T044 Implement UserSocket with JWT authentication and protocol version check in game-server/lib/game_server_web/channels/user_socket.ex

### Redis Connection

- [x] T045 [P] Configure Redis connection for Rails (connection pool) in api-server/config/initializers/redis.rb
- [x] T046 [P] Configure Redix connection pool for Phoenix in game-server/lib/game_server/redis.ex

### Seed Data

- [x] T047 Create seed script with admin user, 2 test players, game type (simple_card_battle), and card definitions in api-server/db/seeds.rb

### Audit Logging

- [x] T048 Implement AuditLogService for recording security events in api-server/app/services/audit_log_service.rb

### Shared Types (Client)

- [x] T049 Define shared TypeScript types (User, Room, GameType, GameState, ChatMessage, API responses) in client/src/types/index.ts
- [x] T050 Implement API client service (axios/fetch wrapper with JWT handling) in client/src/services/api.ts

### Foundation Tests

- [x] T050a [P] Write RSpec request specs for auth endpoints (register, login, refresh, profile) verifying contracts/rails-api.md shapes in api-server/spec/requests/api/v1/auth_spec.rb
- [x] T050b [P] Write RSpec request specs for internal auth/verify endpoint verifying contracts/internal-api.md in api-server/spec/requests/internal/auth_spec.rb
- [x] T050c [P] Write RSpec model specs for User, GameType, Room, RoomPlayer models (validations, associations, enums) in api-server/spec/models/
- [x] T050d [P] Write ExUnit tests for JWT verification module in game-server/test/game_server/auth/jwt_test.exs

**Checkpoint**: Foundation ready — all services can build, connect to DB/Redis, authenticate users. Contract tests pass. User story implementation can now begin.

---

## Phase 3: User Story 1 — Match and Play a Game (Priority: P1) 🎯 MVP

**Goal**: A player logs in, requests a match, gets placed in a room, takes turns playing cards, and completes a game with server-driven progression.

**Independent Test**: 2 players log in → request match → get placed in room → take turns playing cards → game completes with winner/loser.

### Rails: Matchmaking

- [x] T051 [US1] Implement MatchmakingService with Redis Lua atomic pop, queue join, queue check in api-server/app/services/matchmaking_service.rb
- [x] T052 [US1] Implement RoomCreationService (create room record, push to Redis room_creation_queue, generate room tokens) in api-server/app/services/room_creation_service.rb
- [x] T053 [US1] Implement POST /api/v1/matchmaking/join endpoint in api-server/app/controllers/api/v1/matchmaking_controller.rb
- [x] T054 [US1] Implement GET /api/v1/matchmaking/status endpoint (polling) in api-server/app/controllers/api/v1/matchmaking_controller.rb
- [x] T055 [US1] Implement GET /api/v1/game_types endpoint in api-server/app/controllers/api/v1/game_types_controller.rb

### Rails: Internal API (Phoenix → Rails callbacks)

- [x] T056 [P] [US1] Implement POST /internal/rooms (room ready callback) in api-server/app/controllers/internal/rooms_controller.rb
- [x] T057 [P] [US1] Implement PUT /internal/rooms/:room_id/started callback in api-server/app/controllers/internal/rooms_controller.rb
- [x] T058 [P] [US1] Implement PUT /internal/rooms/:room_id/finished callback (create GameResult, update room_players) in api-server/app/controllers/internal/rooms_controller.rb
- [x] T059 [P] [US1] Implement PUT /internal/rooms/:room_id/aborted callback in api-server/app/controllers/internal/rooms_controller.rb
- [x] T060 [P] [US1] Implement POST /internal/auth/verify endpoint in api-server/app/controllers/internal/auth_controller.rb

### Rails: Room Creation Timeout

- [x] T061 [US1] Implement room creation timeout checker (15s deadline, mark failed, cleanup active_game keys) in api-server/app/services/room_creation_service.rb

### Phoenix: Room Creation Consumer

- [x] T062 [US1] Implement RoomCreationConsumer GenServer (BRPOP loop on room_creation_queue) in game-server/lib/game_server/consumers/room_creation_consumer.ex

### Phoenix: Game Behaviour

- [x] T063 [US1] Define Game Behaviour callbacks (init_state, validate_action, apply_action, check_end_condition, on_player_removed) in game-server/lib/game_server/games/game_behaviour.ex

### Phoenix: Sample Card Battle Game

- [x] T064 [US1] Implement SimpleCardBattle module (Behaviour implementation: init with 20HP/5 cards, validate play_card, apply damage/heal/draw, check HP=0 or deck empty) in game-server/lib/game_server/games/simple_card_battle.ex

### Phoenix: Room GenServer

- [x] T065 [US1] Implement Room GenServer (state management, player tracking, join/leave, status transitions) in game-server/lib/game_server/rooms/room.ex
- [x] T066 [US1] Implement Room DynamicSupervisor in game-server/lib/game_server/rooms/room_supervisor.ex
- [x] T067 [US1] Implement turn management (turn timer, auto-skip on timeout with game:turn_skipped broadcast, turn progression) in game-server/lib/game_server/rooms/room.ex
- [x] T068 [US1] Implement nonce cache for replay attack protection (per-player, max 50, LRU eviction) in game-server/lib/game_server/rooms/room.ex
- [x] T069 [US1] Implement game end detection and result persistence callback (POST /internal/rooms/:room_id/finished with retry and persist_failed fallback) in game-server/lib/game_server/rooms/room.ex

### Phoenix: Room Channel

- [x] T070 [US1] Implement RoomChannel join with room_token verification (Redis lookup, mark used) in game-server/lib/game_server_web/channels/room_channel.ex
- [x] T071 [US1] Implement game:action handler (validate turn, nonce check, delegate to Behaviour, broadcast action_applied + turn_changed) in game-server/lib/game_server_web/channels/room_channel.ex
- [x] T072 [US1] Implement game:started broadcast (triggered when all players join) in game-server/lib/game_server_web/channels/room_channel.ex
- [x] T073 [US1] Implement game:ended and game:aborted broadcasts in game-server/lib/game_server_web/channels/room_channel.ex
- [x] T074 [US1] Implement player:joined broadcast in game-server/lib/game_server_web/channels/room_channel.ex

### Phoenix: Internal API Client

- [x] T075 [US1] Implement Rails internal API HTTP client (POST /internal/rooms, PUT started/finished/aborted, POST auth/verify) with retry and exponential backoff in game-server/lib/game_server/api/rails_client.ex

### Phoenix: Rate Limiting

- [x] T076 [US1] Implement channel-level rate limiting for game:action (1/sec) in game-server/lib/game_server_web/channels/room_channel.ex

### Client: Auth Flow

- [x] T077 [P] [US1] Implement auth store (login, register, token management, auto-refresh) with Zustand in client/src/stores/authStore.ts
- [x] T078 [P] [US1] Implement Login/Register UI components in client/src/components/Auth.tsx

### Client: Lobby & Matchmaking

- [x] T079 [P] [US1] Implement lobby store (game types, matchmaking state, polling) with Zustand in client/src/stores/lobbyStore.ts
- [x] T080 [P] [US1] Implement Lobby UI component (game type list, match button, searching status) in client/src/components/Lobby.tsx

### Client: WebSocket & Game

- [x] T081 [US1] Implement Phoenix WebSocket manager (socket connect, channel join, event handlers) in client/src/services/socket.ts
- [x] T082 [US1] Implement game store (game state, turn management, action submission with nonce) with Zustand in client/src/stores/gameStore.ts
- [x] T083 [US1] Implement PixiJS game renderer (board layout, player HP, hand display, card play interaction) in client/src/game/GameRenderer.ts
- [x] T084 [US1] Implement Game UI component (PixiJS canvas wrapper, game status, turn indicator) in client/src/components/Game.tsx

### Client: App Router

- [x] T085 [US1] Implement App.tsx with screen routing (auth → lobby → matchmaking → game) in client/src/App.tsx

### US1 Tests

- [x] T085a [P] [US1] Write RSpec request specs for matchmaking endpoints (join, status, contracts verification) in api-server/spec/requests/api/v1/matchmaking_spec.rb
- [x] T085b [P] [US1] Write RSpec request specs for internal room callbacks (ready, started, finished, aborted) in api-server/spec/requests/internal/rooms_spec.rb
- [x] T085c [P] [US1] Write ExUnit tests for Game Behaviour (SimpleCardBattle: init, validate, apply, end condition) in game-server/test/game_server/games/simple_card_battle_test.exs
- [ ] T085d [P] [US1] Write ExUnit tests for Room GenServer (join, turn management, turn skip, game end) in game-server/test/game_server/rooms/room_test.exs
- [ ] T085e [US1] Write ExUnit channel tests for RoomChannel (join with token, game:action, broadcasts) in game-server/test/game_server_web/channels/room_channel_test.exs

**Checkpoint**: User Story 1 complete — 2 players can log in, match, play a full card battle game, and see results. Contract and unit tests pass. This is the MVP.

---

## Phase 4: User Story 2 — Reconnect to an Ongoing Game (Priority: P2)

**Goal**: A disconnected player can reconnect and resume playing with the current game state.

**Independent Test**: Player disconnects mid-game → reconnects within timeout → sees current game state → can resume playing.

### Phoenix: Reconnection Logic

- [x] T086 [US2] Implement reconnect token generation and Redis storage (reconnect:{room_id}:{user_id}) in game-server/lib/game_server/rooms/room.ex
- [x] T087 [US2] Implement RoomChannel rejoin with reconnect_token verification in game-server/lib/game_server_web/channels/room_channel.ex
- [x] T088 [US2] Implement player disconnect detection (channel terminate callback) and player:disconnected broadcast in game-server/lib/game_server_web/channels/room_channel.ex
- [x] T089 [US2] Implement reconnect timeout handling (on_player_removed callback delegation to Behaviour) in game-server/lib/game_server/rooms/room.ex
- [x] T090 [US2] Implement full game state serialization for reconnecting player (your_hand, all player states, turn info) in game-server/lib/game_server/rooms/room.ex
- [x] T091 [US2] Implement player:reconnected and player:left broadcasts in game-server/lib/game_server_web/channels/room_channel.ex
- [x] T092 [US2] Implement duplicate connection prevention (disconnect older session on same player rejoin) in game-server/lib/game_server/rooms/room.ex

### Rails: Reconnection Support

- [x] T093 [US2] Implement GET /api/v1/rooms/:room_id/ws_endpoint for reconnection URL lookup in api-server/app/controllers/api/v1/rooms_controller.rb

### Client: Reconnection

- [x] T094 [US2] Implement reconnection flow in socket manager (detect disconnect, retrieve ws_endpoint, rejoin with reconnect_token) in client/src/services/socket.ts
- [x] T095 [US2] Implement reconnection UI (disconnected indicator, reconnecting status, state restoration) in client/src/components/Game.tsx
- [x] T096 [US2] Persist reconnect_token and room_id in localStorage for page-refresh reconnection in client/src/stores/gameStore.ts

### US2 Tests

- [ ] T096a [P] [US2] Write ExUnit tests for reconnection flow (rejoin with token, full state delivery, duplicate connection, timeout removal) in game-server/test/game_server/rooms/room_reconnect_test.exs
- [ ] T096b [P] [US2] Write RSpec request spec for GET /api/v1/rooms/:room_id/ws_endpoint in api-server/spec/requests/api/v1/rooms_spec.rb

**Checkpoint**: User Story 2 complete — players can disconnect and reconnect seamlessly during gameplay. Reconnection tests pass.

---

## Phase 5: User Story 3 — Chat with Other Players in a Room (Priority: P3)

**Goal**: Players in a game room can send and receive real-time text messages.

**Independent Test**: Multiple players in a room send messages → all room members receive them in real-time.

### Phoenix: Chat

- [x] T097 [US3] Implement chat:send handler with validation (500 char limit, empty check, rate limit 5/10s) in game-server/lib/game_server_web/channels/room_channel.ex
- [x] T098 [US3] Implement chat message ring buffer (max 100 messages, ephemeral) in game-server/lib/game_server/rooms/room.ex
- [x] T099 [US3] Implement chat:new_message broadcast in game-server/lib/game_server_web/channels/room_channel.ex

### Client: Chat

- [x] T100 [P] [US3] Implement chat store (message list, send message) with Zustand in client/src/stores/chatStore.ts
- [x] T101 [US3] Implement Chat UI component (message list, input field, send button) in client/src/components/Chat.tsx
- [x] T102 [US3] Integrate chat component into Game screen in client/src/components/Game.tsx

### US3 Tests

- [ ] T102a [US3] Write ExUnit channel tests for chat:send (validation, rate limit, broadcast) in game-server/test/game_server_web/channels/room_channel_chat_test.exs

**Checkpoint**: User Story 3 complete — players can chat in real-time during gameplay. Chat tests pass.

---

## Phase 6: User Story 4 — Cancel Matchmaking (Priority: P3)

**Goal**: A player waiting in the matchmaking queue can cancel and return to the lobby.

**Independent Test**: Player enters queue → cancels → is removed from queue → returns to lobby.

### Rails: Cancel Matchmaking

- [x] T103 [US4] Implement DELETE /api/v1/matchmaking/cancel endpoint (LREM from Redis queue) in api-server/app/controllers/api/v1/matchmaking_controller.rb
- [x] T104 [US4] Implement matchmaking timeout detection (60s default, cleanup expired entries) as background job in api-server/app/jobs/matchmaking_cleanup_job.rb

### Client: Cancel Matchmaking

- [x] T105 [US4] Add cancel matchmaking action to lobby store in client/src/stores/lobbyStore.ts
- [x] T106 [US4] Add cancel button and timeout handling to matchmaking UI in client/src/components/Lobby.tsx

### US4 Tests

- [ ] T106a [US4] Write RSpec request spec for DELETE /api/v1/matchmaking/cancel in api-server/spec/requests/api/v1/matchmaking_cancel_spec.rb

**Checkpoint**: User Story 4 complete — players can cancel matchmaking. Cancel tests pass.

---

## Phase 7: User Story 5 — Admin Manages Users and Rooms (Priority: P4)

**Goal**: Administrators can search users, freeze/unfreeze accounts, view rooms, force-terminate rooms, and manage announcements.

**Independent Test**: Admin logs in → searches user → freezes account → views room list → force-terminates a room → creates announcement.

### Rails: Admin Authentication

- [x] T107 [US5] Implement admin authentication concern (admin role check) in api-server/app/controllers/concerns/admin_authenticatable.rb
- [x] T108 [US5] Implement admin session management (login form, session controller) in api-server/app/controllers/admin/sessions_controller.rb

### Rails: Admin Views

- [x] T109 [P] [US5] Implement admin layout template in api-server/app/views/layouts/admin.html.erb
- [x] T110 [P] [US5] Implement admin dashboard (overview stats) in api-server/app/controllers/admin/dashboard_controller.rb and api-server/app/views/admin/dashboard/
- [x] T111 [US5] Implement admin users controller (search by name/ID, list, show, freeze/unfreeze) in api-server/app/controllers/admin/users_controller.rb and api-server/app/views/admin/users/
- [x] T112 [US5] Implement admin rooms controller (list active/completed, show, force-terminate via Redis PubSub) in api-server/app/controllers/admin/rooms_controller.rb and api-server/app/views/admin/rooms/
- [x] T113 [US5] Implement admin announcements controller (CRUD, publish/unpublish) in api-server/app/controllers/admin/announcements_controller.rb and api-server/app/views/admin/announcements/

### Phoenix: Room Commands Subscriber

- [x] T114 [US5] Implement RoomCommandsSubscriber GenServer (subscribe to room_commands PubSub, dispatch terminate to local Room) in game-server/lib/game_server_web/subscribers/room_commands_subscriber.ex

### Rails: Announcements API

- [x] T115 [US5] Implement GET /api/v1/announcements endpoint (active announcements for players) in api-server/app/controllers/api/v1/announcements_controller.rb

### Client: Announcements

- [x] T116 [US5] Implement announcement display in lobby UI in client/src/components/Lobby.tsx

### Rails: Persist Failed Recovery

- [x] T117 [US5] Implement PersistRecoveryJob (SCAN persist_failed:*, import results, alert on stale) in api-server/app/jobs/persist_recovery_job.rb

### US5 Tests

- [ ] T117a [P] [US5] Write RSpec request specs for admin controllers (users search/freeze, rooms list/terminate, announcements CRUD) in api-server/spec/requests/admin/
- [ ] T117b [P] [US5] Write RSpec request spec for GET /api/v1/announcements in api-server/spec/requests/api/v1/announcements_spec.rb

**Checkpoint**: User Story 5 complete — admin panel is functional with all management capabilities. Admin tests pass.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [x] T118 [P] Integrate audit logging into all security-relevant actions (login, freeze, force-terminate, failed auth) across api-server/app/controllers/
- [x] T119 [P] Add error handling middleware for consistent JSON error responses in api-server/app/controllers/application_controller.rb
- [x] T120 [P] Add plug_attack rate limiting to Phoenix socket in game-server/lib/game_server_web/channels/user_socket.ex
- [ ] T121 Run quickstart.md full flow validation (Docker up, seed, 2-player login, match, play, reconnect, chat, admin)
- [ ] T122 Final Docker Compose integration test (all services start, health checks pass)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 completion — BLOCKS all user stories
- **User Stories (Phase 3–7)**: All depend on Phase 2 completion
  - US1 (Phase 3): No dependencies on other stories — **start here**
  - US2 (Phase 4): Depends on US1 (needs room/game infrastructure)
  - US3 (Phase 5): Depends on US1 (needs room channel infrastructure)
  - US4 (Phase 6): Depends on US1 matchmaking implementation (T051–T054)
  - US5 (Phase 7): Can start after Phase 2 (admin is independent), but room terminate depends on US1 room infra
- **Polish (Phase 8)**: Depends on all desired user stories being complete

### User Story Dependencies

- **US1 (P1)**: Independent after Phase 2 — the core MVP
- **US2 (P2)**: Requires US1 room GenServer and channel (T065–T074)
- **US3 (P3)**: Requires US1 room channel (T070–T074)
- **US4 (P3)**: Requires US1 matchmaking service (T051–T054)
- **US5 (P4)**: Admin views independent of game flow; room terminate requires US1 room GenServer + Phase 2

### Within Each User Story

- Models before services
- Services before endpoints/controllers
- Server before client
- Core implementation before integration

### Parallel Opportunities

- All Setup tasks T002–T008 marked [P] can run in parallel
- All model tasks T019–T027 in Phase 2 can run in parallel
- T036/T037 health checks can run in parallel
- T038/T039 routes can run in parallel
- T042/T043 Redis config can run in parallel
- Within US1: Rails internal API callbacks T056–T060 can run in parallel
- Within US1: Client auth/lobby stores T077–T080 can run in parallel
- Within US3: Chat store T100 can run in parallel with Phoenix chat implementation
- Within US5: Admin layout and dashboard T109–T110 can run in parallel
- US4 and US5 can be worked on in parallel once US1 is complete

---

## Parallel Example: User Story 1

```bash
# After Phase 2 foundational is complete, launch Rails internal API callbacks in parallel:
Task T056: "POST /internal/rooms callback in api-server/app/controllers/internal/rooms_controller.rb"
Task T057: "PUT /internal/rooms/:room_id/started callback"
Task T058: "PUT /internal/rooms/:room_id/finished callback"
Task T059: "PUT /internal/rooms/:room_id/aborted callback"
Task T060: "POST /internal/auth/verify endpoint"

# Launch client stores in parallel:
Task T077: "Auth store in client/src/stores/authStore.ts"
Task T078: "Login/Register UI in client/src/components/Auth.tsx"
Task T079: "Lobby store in client/src/stores/lobbyStore.ts"
Task T080: "Lobby UI in client/src/components/Lobby.tsx"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (Docker, scaffolding)
2. Complete Phase 2: Foundational (DB, auth, Redis, routes, seed)
3. Complete Phase 3: User Story 1 — Match and Play
4. **STOP and VALIDATE**: 2 players can log in, match, play cards, game ends
5. Deploy/demo the core game loop

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. Add US1 (Match & Play) → MVP! Core game loop works
3. Add US2 (Reconnect) → Resilient gameplay
4. Add US3 (Chat) + US4 (Cancel Match) → Better UX (can be parallel)
5. Add US5 (Admin) → Operational management
6. Polish → Production-ready

### Suggested Implementation Cadence

| Phase | Scope | Cumulative Value |
|-------|-------|------------------|
| Phase 1–2 | Infrastructure | Services boot, auth works |
| Phase 3 | US1: Match & Play | **MVP — core game loop** |
| Phase 4 | US2: Reconnect | Resilient multiplayer |
| Phase 5–6 | US3: Chat + US4: Cancel | Social + UX polish |
| Phase 7 | US5: Admin | Operational tools |
| Phase 8 | Polish | Production-ready |

---

## Summary

| Metric | Value |
|--------|-------|
| Total tasks | 137 |
| Phase 1 (Setup) | 8 tasks |
| Phase 2 (Foundational) | 46 tasks (T009–T050d, incl. 3 base controllers + 4 foundation tests) |
| Phase 3 (US1: Match & Play) | 40 tasks (incl. 5 test tasks) |
| Phase 4 (US2: Reconnect) | 13 tasks (incl. 2 test tasks) |
| Phase 5 (US3: Chat) | 7 tasks (incl. 1 test task) |
| Phase 6 (US4: Cancel Match) | 5 tasks (incl. 1 test task) |
| Phase 7 (US5: Admin) | 13 tasks (incl. 2 test tasks) |
| Phase 8 (Polish) | 5 tasks |
| Test tasks total | 15 tasks |
| Parallel opportunities | 30+ tasks marked [P] |
| MVP scope | Phase 1 + Phase 2 + Phase 3 (94 tasks) |
| Format validated | All 137 tasks follow `- [ ] [ID] [P?] [Story?] Description with file path` |

---

## Notes

- [P] tasks = different files, no dependencies — can run in parallel
- [Story] label maps task to specific user story for traceability
- Each user story is independently completable and testable after Phase 2
- Commit after each task or logical group
- Stop at any checkpoint to validate the story independently
- Test tasks are included per Constitution Principle IV (Test-First for Contracts and Critical Paths)
- Test tasks use suffix IDs (e.g., T050a, T085c) to maintain original task numbering stability
