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

## Complexity Tracking

No constitution violations to justify. The 3-service split is inherent to the architectural requirement of separating REST API management from real-time game server concerns, using different language ecosystems (Ruby vs Elixir) optimized for their respective roles.
