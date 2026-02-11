# Implementation Plan: Room-Based Multiplayer Game Platform (MVP)

**Branch**: `001-room-match-platform` | **Date**: 2026-02-11 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-room-match-platform/spec.md`

## Summary

A game-agnostic multiplayer platform enabling room-based matchmaking and turn-based gameplay. Three-service architecture: Rails API (auth, matchmaking, persistence, admin), Phoenix game server (real-time rooms, game state, chat, reconnection), TypeScript/React/PixiJS web client (display only). JWT-based cross-service auth, Phoenix Channels for WebSocket communication, Redis for ephemeral data (queues, tokens, presence), MySQL for persistence. A minimal 2-player card battle game validates the platform.

## Technical Context

**Languages/Versions**:
- TypeScript 5.x (client)
- Ruby 3.3+ (api-server)
- Elixir 1.17+ / Erlang 26+ (game-server)

**Primary Dependencies**:
- Client: React 18+, PixiJS 8+, Zustand (state), phoenix.js (WebSocket)
- API Server: Rails 7.2+ (API mode + admin views), `jwt` gem, `rack-attack`, `redis` gem
- Game Server: Phoenix 1.7+, Phoenix Channels, `Joken` (JWT verification), Phoenix Presence, `plug_attack`

**Storage**:
- MySQL 8.0+ — persistent entities (users, rooms, game results, admin data)
- Redis 7+ — ephemeral data (matchmaking queues, tokens, active player tracking, PubSub)
- Elixir process memory — runtime game state (GenServer per room)

**Testing**:
- Client: Vitest
- API Server: RSpec
- Game Server: ExUnit

**Target Platform**: Web browser (MVP); future: Unity/C#

**Project Type**: Multi-service web application (3 services + 2 datastores)

**Performance Goals** (from Success Criteria):
- Login-to-playing: < 90 seconds (SC-001)
- Concurrent rooms: ≥ 100 rooms × 4 players (SC-002)
- Reconnect state delivery: < 5 seconds (SC-003)
- Chat delivery: < 1 second (SC-004)
- Action response: < 2 seconds at 95th percentile (SC-005)

**Constraints**:
- Server-authoritative: zero game logic on client (SC-006)
- Single region deployment for MVP (A-007)
- One hardcoded game type only (A-004)

**Scale/Scope**: ~400 concurrent players, 100 concurrent rooms, 5 admin CRUD screens

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Constitution is not yet ratified (template placeholders only). No gates to enforce. Proceeding with standard engineering best practices as defined in CLAUDE.md:

- **Immutability**: Game state transitions are pure (Elixir GenServer pattern) ✅
- **Small units**: Service separation enforces bounded modules ✅
- **Error handling**: Each service handles errors at boundaries (API responses, Channel replies) ✅
- **Input validation**: All game actions validated server-side (FR-060) ✅
- **Security**: JWT auth, rate limiting, audit logging, no client-side logic ✅

**Post-Phase 1 re-check**: All design artifacts (data-model, contracts, quickstart) align with these principles. No violations detected.

## Project Structure

### Documentation (this feature)

```text
specs/001-room-match-platform/
├── plan.md              # This file
├── research.md          # Phase 0 output (completed)
├── data-model.md        # Phase 1 output (completed)
├── quickstart.md        # Phase 1 output (completed)
├── contracts/
│   ├── rails-api.md     # Client ↔ Rails REST API
│   ├── phoenix-ws.md    # Client ↔ Phoenix WebSocket Protocol
│   └── internal-api.md  # Phoenix ↔ Rails Internal API
├── checklists/
│   └── requirements.md  # Requirements checklist
└── tasks.md             # Phase 2 output (via /speckit.tasks)
```

### Source Code (repository root)

```text
client/                          # TypeScript/React/PixiJS web client
├── src/
│   ├── components/              # React UI components
│   ├── game/                    # PixiJS game renderer
│   ├── stores/                  # Zustand state stores
│   ├── services/                # API client, WebSocket manager
│   ├── types/                   # Shared TypeScript types
│   └── App.tsx
├── public/
├── package.json
├── tsconfig.json
├── biome.json
└── vite.config.ts

api-server/                      # Ruby on Rails API + Admin
├── app/
│   ├── controllers/
│   │   ├── api/v1/              # Client-facing REST API
│   │   ├── internal/            # Phoenix → Rails internal API
│   │   └── admin/               # Admin web UI controllers
│   ├── models/                  # ActiveRecord models
│   ├── services/                # Matchmaking, JWT, room orchestration
│   ├── views/admin/             # ERB admin templates
│   └── jobs/                    # Background jobs (queue cleanup, persist recovery)
├── config/
├── db/migrate/
├── spec/                        # RSpec tests
├── Gemfile
└── Dockerfile

game-server/                     # Elixir/Phoenix game server
├── lib/
│   ├── game_server/
│   │   ├── rooms/               # Room GenServer, supervisor
│   │   ├── games/               # Game Behaviour + sample game module
│   │   ├── chat/                # Room chat logic
│   │   └── auth/                # JWT verification, token validation
│   ├── game_server_web/
│   │   ├── channels/            # Room channel, socket
│   │   ├── controllers/         # Internal API controllers
│   │   └── router.ex
│   └── game_server.ex
├── test/                        # ExUnit tests
├── config/
├── mix.exs
└── Dockerfile

infra/                           # Infrastructure
├── docker-compose.yml
├── mysql/
│   └── init.sql
└── redis/
    └── redis.conf
```

**Structure Decision**: Multi-service architecture with `client/`, `api-server/`, `game-server/`, and `infra/` at the repository root. Each service is independently buildable and deployable via Docker. This matches the spec's architectural principles (client=display, Rails=operations, Phoenix=game runtime).

## Complexity Tracking

No constitution violations to justify. Architecture complexity is inherent to the multi-service requirement (spec mandates Rails + Phoenix separation for operational vs game concerns).

## Key Technology Decisions

| Decision | Choice | Rationale | Reference |
|----------|--------|-----------|-----------|
| WebSocket protocol | Phoenix Channels | Built-in topic routing, heartbeat, reconnection, presence | R-001 |
| Internal API | REST/JSON + API key | Simple, debuggable, low call frequency | R-002 |
| JWT strategy | HS256 shared secret | Simple cross-service verification | R-003 |
| JWT library (Rails) | `jwt` gem | Lightweight, framework-agnostic | Gemini research |
| JWT library (Phoenix) | `Joken` | Flexible, Plug-based verification | Gemini research |
| Client state | Zustand | Works with React + PixiJS, minimal boilerplate | R-005 |
| Matchmaking queue | Redis List (BRPOPLPUSH) | Atomic operations, blocking pop | R-006 |
| Admin UI | Rails server-rendered (ERB) | Sufficient for 5 CRUD screens | R-007 |
| Rate limiting | rack-attack (Rails) + plug_attack (Phoenix) | Industry standard, Redis-backed | Gemini research |
| Cross-node PubSub | Phoenix.PubSub + Redis adapter | Proven pattern for horizontal scaling | Gemini research |
| MVP game | 2-player card battle | Validates all platform features with minimal rules | R-004 |

## Artifact Summary

| Artifact | Status | Description |
|----------|--------|-------------|
| [research.md](research.md) | ✅ Complete | 8 research decisions covering all unknowns |
| [data-model.md](data-model.md) | ✅ Complete | MySQL (11 tables), Redis (5 key patterns), Elixir process state |
| [contracts/rails-api.md](contracts/rails-api.md) | ✅ Complete | 11 REST endpoints (auth, matchmaking, rooms, game types, announcements, health) |
| [contracts/phoenix-ws.md](contracts/phoenix-ws.md) | ✅ Complete | Socket connect, channel join/rejoin, 3 push events, 8 broadcast events, rate limits |
| [contracts/internal-api.md](contracts/internal-api.md) | ✅ Complete | 7 internal endpoints (room lifecycle, auth verify, room creation, admin ops, health) |
| [quickstart.md](quickstart.md) | ✅ Complete | Docker setup, per-service dev setup, seed data, full flow test, admin panel |

## Next Step

Run `/speckit.tasks` to generate the implementation task breakdown (Phase 2).
