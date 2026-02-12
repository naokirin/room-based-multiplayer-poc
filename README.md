# Room-Based Multiplayer Game Platform (MVP)

A proof-of-concept room-based multiplayer game platform with three services: a Rails API server, a Phoenix game server, and a React/PixiJS client.

## Architecture

```
Client (React/PixiJS)  <--WebSocket-->  Game Server (Phoenix)
        |                                      |
        |--REST API-->  API Server (Rails)  <--HTTP callbacks--
                              |
                     MySQL + Redis
```

- **Client** (`client/`): TypeScript, React 19, PixiJS 8, Zustand. Display only — no game logic.
- **API Server** (`api-server/`): Ruby on Rails 8. Auth (JWT), matchmaking, persistence, admin panel.
- **Game Server** (`game-server/`): Elixir/Phoenix 1.7. Real-time rooms, game state, chat, reconnection.
- **Infrastructure** (`infra/`): Docker Compose with MySQL 8 and Redis 7.

## Features

- JWT-based authentication with auto-refresh
- Matchmaking queue with Redis BRPOP room creation
- Real-time game rooms via Phoenix Channels (WebSocket)
- Simple Card Battle game with turn-based play
- Reconnection support with reconnect tokens (60s timeout)
- In-game chat
- Matchmaking cancellation with timeout
- Admin panel (user management, room monitoring, announcements)
- Audit logging for security-relevant actions
- Rate limiting (Rack::Attack for Rails, PlugAttack for Phoenix)

## Quick Start

### Prerequisites

- Docker & Docker Compose
- Ruby 3.3+ (rbenv)
- Elixir 1.17+ / Erlang 27+ (asdf)
- Node.js 20+ (for client)

### Start Infrastructure

```bash
cd infra && docker compose up -d
```

### API Server (Rails)

```bash
cd api-server
bundle install
bin/rails db:create db:migrate db:seed
bin/rails server -p 3001
```

### Game Server (Phoenix)

```bash
cd game-server
mix deps.get
mix phx.server  # runs on port 4000
```

### Client

```bash
cd client
npm install
npm run dev  # runs on port 5173
```

## Testing

```bash
# Rails (61 examples)
cd api-server && bundle exec rspec

# Phoenix
cd game-server && mix test

# Client
cd client && npx tsc --noEmit
```

## Project Structure

```
client/                     # React/PixiJS web client
  src/
    components/             # Auth, Lobby, Game, Chat screens
    stores/                 # Zustand stores (auth, lobby, game, chat)
    services/               # WebSocket manager
api-server/                 # Rails API + Admin
  app/
    controllers/
      api/v1/               # REST API endpoints
      admin/                # Admin panel controllers
      internal/             # Phoenix callback endpoints
    models/                 # User, Room, GameType, etc.
    services/               # JwtService, MatchmakingService, RoomCreationService
    jobs/                   # MatchmakingCleanupJob, PersistRecoveryJob
game-server/                # Phoenix game server
  lib/
    game_server/
      rooms/                # Room GenServer, RoomSupervisor
      games/                # Game behaviour, SimpleCardBattle
      consumers/            # RoomCreationConsumer (Redis BRPOP)
      subscribers/          # RoomCommandsSubscriber (Redis PubSub)
    game_server_web/
      channels/             # RoomChannel (WebSocket)
      plugs/                # RateLimiter (PlugAttack)
infra/                      # Docker Compose, MySQL/Redis config
specs/                      # Feature specifications and task plans
```

## Key Design Decisions

- **Server-authoritative**: All game actions validated on the game server
- **Redis as glue**: BRPOP for room creation queue, PubSub for room commands, ephemeral data storage
- **JWT shared secret**: Rails issues tokens, Phoenix verifies them
- **String UUIDs**: All primary keys are 36-char UUID strings
- **Phoenix Channels**: WebSocket transport for real-time game communication
