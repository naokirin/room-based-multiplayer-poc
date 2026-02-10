# Implementation Plan: Room-Based Multiplayer Game Platform (MVP)

**Branch**: `001-room-match-platform` | **Date**: 2026-02-10 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-room-match-platform/spec.md`

## Summary

Build a room-based multiplayer game platform MVP consisting of three services: a Rails API server for authentication, matchmaking, and administration; an Elixir/Phoenix game server for real-time room management, game state, chat, and reconnection via WebSocket; and a TypeScript/React web client with PixiJS for game rendering. The architecture follows a strict responsibility separation: client handles display only, Rails manages operations and persistence, Phoenix manages game logic and real-time state. A single hardcoded card game type validates the platform.

## Technical Context

**Language/Version**:
- Client: TypeScript 5.x
- API Server: Ruby 3.3+, Rails 7.2+
- Game Server: Elixir 1.17+, Phoenix 1.7+

**Primary Dependencies**:
- Client: React 18+, PixiJS 8+, phoenix.js (WebSocket client)
- API Server: Rails (API mode), bcrypt (auth), jwt gem, redis-rb
- Game Server: Phoenix, Phoenix.PubSub, Jason (JSON)

**Storage**:
- MySQL 8.0+ (Rails - users, rooms, matches, game results, audit logs)
- Redis 7+ (shared - matchmaking queue, room tokens, reconnect tokens, cache)
- Elixir Process memory (game state, player state during active games)

**Testing**:
- Client: Vitest + React Testing Library
- API Server: RSpec + FactoryBot
- Game Server: ExUnit

**Target Platform**: Web browser (desktop/mobile), Docker containers for all services

**Project Type**: Multi-service web application (3 services + infra)

**Performance Goals**:
- Login to game start: < 90 seconds
- Player action response: < 2 seconds (95th percentile)
- Chat message delivery: < 1 second
- Reconnection with state sync: < 5 seconds
- 100 concurrent game rooms with 4 players each

**Constraints**:
- Server-authoritative: zero game logic on client
- Single Phoenix node for MVP (cluster design deferred)
- Single Redis instance for MVP
- One hardcoded game type for MVP

**Scale/Scope**:
- MVP: ~400 concurrent users, 100 concurrent rooms
- 3 services + 2 datastores in Docker

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

The project constitution has not been configured (template placeholders only). No project-specific gates apply. Proceeding with standard engineering practices:

| Principle | Status | Notes |
|-----------|--------|-------|
| Separation of concerns | PASS | 3-service architecture with clear responsibility boundaries |
| Server-authoritative security | PASS | All game logic validated server-side |
| Test coverage | PASS | Testing frameworks specified for all 3 services |
| Infrastructure reproducibility | PASS | Docker-based, all services containerized |

**Recommendation**: Run `/speckit.constitution` to define project-specific principles before starting implementation.

## Project Structure

### Documentation (this feature)

```text
specs/001-room-match-platform/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   ├── rails-api.md     # Client ↔ Rails REST API
│   ├── phoenix-ws.md    # Client ↔ Phoenix WebSocket protocol
│   └── internal-api.md  # Phoenix ↔ Rails Internal API
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
client/
├── src/
│   ├── components/      # React UI components (lobby, chat, admin)
│   ├── game/            # PixiJS game rendering
│   ├── services/        # API client, WebSocket client
│   ├── stores/          # State management
│   └── types/           # Shared TypeScript types
├── public/
└── tests/

api-server/
├── app/
│   ├── models/          # User, Room, Match, GameResult, etc.
│   ├── controllers/
│   │   ├── api/v1/      # External API (auth, match, profile)
│   │   ├── internal/    # Internal API (Phoenix → Rails)
│   │   └── admin/       # Admin UI controllers
│   ├── services/        # Matchmaking, token management
│   └── views/           # Admin UI views
├── config/
├── db/
│   └── migrate/
└── spec/

game-server/
├── lib/
│   ├── game_server/
│   │   ├── room/        # Room GenServer, supervisor, state
│   │   ├── game/        # Game logic, turn management, validation
│   │   ├── chat/        # Room chat handler
│   │   └── auth/        # Token verification
│   └── game_server_web/
│       ├── channels/    # Phoenix channels (room, chat)
│       └── controllers/ # Health check
├── config/
└── test/

infra/
├── docker-compose.yml
├── docker-compose.dev.yml
├── mysql/
│   └── init.sql
└── redis/
    └── redis.conf
```

**Structure Decision**: Multi-service architecture with 3 independently deployable services (`client`, `api-server`, `game-server`) plus shared infrastructure configuration (`infra`). This mirrors the architectural design where Rails is the "office" (operations), Phoenix is the "field" (game runtime), and the Client is display-only.

## Operational Considerations

Design decisions and known trade-offs from the original design document (解消事項) that affect implementation and operations.

### Reconnect SPOF Risk (解消3 追記)

Reconnection requires Rails API (`GET /rooms/:room_id/ws_endpoint`) to resolve the Phoenix node. If Rails is down, players cannot reconnect to active games even if Phoenix is healthy.

| Phase | Mitigation |
|-------|------------|
| MVP | Accept the risk. Prioritize Rails uptime (health checks, restart policies) |
| Future | Client caches the last-connected node URL locally. On Rails failure, client attempts direct reconnect to cached node |

### Persist Failed Recovery (解消4 追記)

When Phoenix cannot persist game results to Rails after retries, results are written to Redis `persist_failed:{room_id}` with 7-day TTL.

| Component | Responsibility |
|-----------|---------------|
| Phoenix | Write result JSON to `persist_failed:{room_id}` on persist failure. Emit structured log `persist_failed` event |
| Rails | Background job polls `persist_failed:*` keys periodically (e.g., every 5 minutes) and imports results |
| Monitoring | Alert on `persist_failed` log events exceeding threshold |

### Supervisor / Crash Policy (解消8)

For MVP, room process crashes are treated as unrecoverable:

- Supervisor strategy: **do not restart** crashed room processes
- On crash: notify players with `game:aborted`, report `room_aborted(reason: process_error)` to Rails
- Future: periodic state snapshots to Redis for crash recovery

> **Design principle**: "初期はプロセスクラッシュ = ゲーム終了。状態復元は将来の拡張とし、まずはクラッシュしないコードを書くことに集中する。"

### Deploy Strategy (解消18)

| Component | Strategy |
|-----------|----------|
| Rails | Rolling deploy. Run migrations before switching to new instances |
| Phoenix | **Drain mode**: (1) Rails marks node as "no new rooms", (2) wait for existing rooms to finish (max 30 min), (3) force-abort remaining rooms, (4) stop/update/restart node, (5) Rails re-enables node |
| Client | Version check API. No forced update during active game; prompt on next lobby transition |

### Structured Logging (解消11)

All services use structured JSON logging with consistent fields for observability:

| Field | Required | Description |
|-------|----------|-------------|
| `timestamp` | Yes | ISO 8601 |
| `level` | Yes | debug/info/warn/error |
| `service` | Yes | api-server / game-server / client |
| `event` | Yes | Event name (e.g., `room_created`, `persist_failed`, `action_rejected`) |
| `room_id` | When applicable | Room context |
| `user_id` | When applicable | Actor context |
| `metadata` | Optional | Additional event-specific data |

## Complexity Tracking

No constitution violations to justify. The 3-service split is inherent to the architectural requirement of separating REST API management from real-time game server concerns, using different language ecosystems (Ruby vs Elixir) optimized for their respective roles.
