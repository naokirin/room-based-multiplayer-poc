# Research: Room-Based Multiplayer Game Platform (MVP)

**Feature Branch**: `001-room-match-platform`
**Date**: 2026-02-10

## R-001: WebSocket Protocol Format (Client ↔ Phoenix)

**Decision**: Use Phoenix Channels' built-in protocol format.

**Rationale**: Phoenix Channels provide topic-based routing, heartbeat, automatic reconnection, and presence tracking out of the box. The `phoenix.js` client library handles serialization, transport fallback, and connection lifecycle. Building a custom protocol would duplicate these features without added benefit for MVP.

**Alternatives considered**:
- Custom JSON-over-WebSocket: More control but requires implementing heartbeat, reconnection, topic routing manually. Rejected for MVP.
- Socket.io: Not compatible with Elixir ecosystem. Rejected.

**Channel structure**:
- `room:{room_id}` — game events + room chat (single channel per room, multiplexed)
- Client joins channel after receiving `room_token` from Rails matchmaking

## R-002: Internal API Protocol (Phoenix ↔ Rails)

**Decision**: REST over HTTP with JSON payloads, authenticated via API Key in headers.

**Rationale**: The project design document specifies REST. Both Rails and Phoenix have excellent HTTP client/server support. The internal API has low call frequency (room lifecycle events) so the overhead of HTTP vs. gRPC is negligible. Simplicity and debugging transparency outweigh performance gains.

**Alternatives considered**:
- gRPC: Better performance and type safety, but adds protobuf compilation step and learning curve. Rejected for MVP simplicity.
- Direct Erlang distribution: Would tightly couple the services and prevent independent deployment. Rejected per architecture design.

**Security note**: MVP uses a single shared API key (`INTERNAL_API_KEY` env var). This is acceptable because both services run on a private Docker network. The key must be rotatable via environment variable changes without code deployment. Production hardening: consider mTLS or per-service signed requests.

## R-003: JWT Token Strategy (Rails ↔ Phoenix shared secret)

**Decision**: HMAC-SHA256 (HS256) JWT with a shared secret stored in environment variables.

**Rationale**: Both Rails and Phoenix need to sign/verify the same JWT tokens. HS256 with a shared secret is the simplest approach that satisfies security requirements. The shared secret is injected via Docker environment variables (or Docker secrets in production).

**Token types**:
| Token | Issuer | Verifier | Algorithm | TTL |
|-------|--------|----------|-----------|-----|
| access_token | Rails | Rails, Phoenix | HS256 | 1 hour |
| room_token | Rails | Phoenix (via Redis) | HS256 + Redis lookup | 5 minutes |
| reconnect_token | Phoenix | Phoenix (via Redis) | Opaque UUID + Redis | Game session duration |

**Alternatives considered**:
- RS256 (asymmetric): More secure for public verification but adds key management complexity for internal services behind a private network. Deferred to production hardening.
- Separate secrets per service: Increases complexity without clear benefit when services are on the same private network.

## R-004: MVP Game Type Selection

**Decision**: Simple 2-player card battle game with minimal rules.

**Rationale**: The project document specifies "PvP card game / board game" and the MVP needs "one hardcoded game type" (spec A-004). A 2-player card battle with simple mechanics (play card → deal damage, heal, draw) validates all platform features: matchmaking (2 players), turn-based progression, action validation, game end detection, result persistence.

**Game rules (hardcoded)**:
- 2 players
- Each player starts with 20 HP and a deck of 5 pre-defined cards
- Players draw 1 card per turn, play 1 card per turn
- Card effects: deal_damage (3), heal (2), draw_card (1 extra)
- Game ends when a player reaches 0 HP or all cards are exhausted
- Turn time limit: 60 seconds

**Alternatives considered**:
- Tic-tac-toe: Too simple, doesn't exercise card/resource mechanics.
- Full card game with deck building: Too complex for MVP, premature when DSL is out of scope.

## R-005: Client State Management

**Decision**: Zustand for client-side state management.

**Rationale**: Lightweight, TypeScript-first, minimal boilerplate. Works well with React and doesn't require providers/context wrappers. Suitable for managing connection state, game state snapshots from server, and UI state.

**Alternatives considered**:
- Redux Toolkit: More structured but heavier boilerplate for a game client.
- React Context: Sufficient for small apps but leads to performance issues with frequent game state updates.
- Jotai/Recoil: Atomic state model, but Zustand is simpler for the action-based game state pattern.

## R-006: Matchmaking Queue Implementation

**Decision**: Redis List with BRPOPLPUSH pattern for atomic queue operations.

**Rationale**: The design document specifies Rails manages the matchmaking queue using Redis. Redis List operations are atomic and support blocking pop, which is ideal for queue processing. Rails checks the queue length after each push; when N players accumulate for a game type, it atomically pops them and triggers room creation.

**Key design**:
- Queue key: `match_queue:{game_type_id}`
- Entry value: JSON `{ user_id, queued_at }`
- TTL cleanup: Background job removes expired entries (> 60s)
- Cancel: LREM to remove specific user from queue

## R-007: Admin Interface Approach

**Decision**: Rails server-rendered views (ERB) with standard Rails admin patterns.

**Rationale**: The admin interface is a separate authenticated web application (spec A-006). Rails' built-in view layer is sufficient for the MVP admin features (user search, freeze, room list, force-terminate, announcements). No need for a SPA admin panel at this stage.

**Alternatives considered**:
- Active Admin / Administrate gem: Adds dependency for features we may not need. Rejected for MVP; consider post-MVP.
- React admin SPA: Over-engineering for 5 CRUD screens. Rejected.

## R-008: Docker Compose Service Topology

**Decision**: docker-compose.yml with 5 services: client, api-server, game-server, mysql, redis.

**Rationale**: All services need to communicate on a shared private network. Docker Compose provides simple orchestration for development and initial deployment. Services communicate via internal DNS names.

**Network layout**:
- `app-network` (bridge): all services
- Client: exposed port 3000 (Vite dev server or nginx for production)
- API Server: exposed port 3001 (Rails)
- Game Server: exposed port 4000 (Phoenix)
- MySQL: internal only (port 3306)
- Redis: internal only (port 6379)
