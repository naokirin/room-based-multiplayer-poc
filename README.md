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

- Docker & Docker Compose (for one-command stack), or
- Ruby 3.3+ (rbenv), Elixir 1.17+ / Erlang 27+ (asdf), Node.js 20+ (for running services locally)

### Start full stack with one command (recommended)

From the **repository root**:

```bash
cp infra/.env.example infra/.env   # optional: set JWT_SECRET, INTERNAL_API_KEY if not using defaults
docker compose -f infra/docker-compose.yml up
```

- **Client**: http://localhost:3000  
- **API**: http://localhost:3001  
- **Game Server (WebSocket)**: ws://localhost:4000/socket  

Startup failure or partial service failure is visible on CLI (stdout/stderr, exit code). To also capture output to a log file, run `bin/start-stack` (writes to `infra/logs/compose.log`), or `docker compose -f infra/docker-compose.yml up 2>&1 | tee infra/logs/compose.log` (ensure `infra/logs/` exists). Required env vars: see `infra/.env.example` (JWT_SECRET, INTERNAL_API_KEY). Startup order: MySQL/Redis start first (with healthchecks); then API server and game server; then client. Connection targets and ports are documented in [specs/002-docker-compose-apps/quickstart.md](specs/002-docker-compose-apps/quickstart.md) and in the Ports table below.

### Ports (service → host)

| Service      | Host port | Purpose              |
|-------------|-----------|----------------------|
| Client      | 3000      | Web UI (Vite dev)    |
| API Server  | 3001      | REST API, admin     |
| Game Server | 4000      | WebSocket (Phoenix)  |
| MySQL       | 3306      | DB (internal)        |
| Redis       | 6379      | Cache/queue (internal) |

### Volume Mounts (source code live reload)

All three application services mount host source directories into their containers, so code changes on the host are reflected without rebuilding images:

| Service     | Host path      | Container path | Protected (anonymous volume) |
|-------------|---------------|----------------|------------------------------|
| api-server  | `api-server/` | `/rails`       | `/usr/local/bundle` (named: `bundle_gems`) |
| game-server | `game-server/`| `/app`         | `/app/deps`, `/app/_build` |
| client      | `client/`     | `/app`         | `/app/node_modules` |

**Notes and caveats:**

- **api-server – first run with empty `bundle_gems` volume**: On the very first `docker compose up`, the `bundle_gems` named volume is empty and Gem binaries are not yet available. Run bundle install inside the container before starting the server:
  ```bash
  docker compose -f infra/docker-compose.yml run --rm api-server bundle install
  docker compose -f infra/docker-compose.yml up
  ```
- **api-server – code changes**: Rails does **not** auto-reload in production mode. Since `RAILS_ENV=development` is set, code changes are reloaded automatically (Rails development mode reloader).
- **game-server – deps/_build are anonymous volumes**: These volumes are tied to the container lifecycle. If you remove the container (`docker compose down`), the compiled artifacts are lost and Mix will recompile on next start. This is expected behavior for development.
- **game-server – code changes**: Phoenix reloads Elixir modules automatically in development via the code reloader.
- **client – code changes**: Vite HMR (hot module replacement) reflects changes instantly in the browser.
- **node_modules / bundle / deps are never overwritten by host mounts**: The anonymous/named volumes take precedence over the host directory for those paths, keeping container-installed packages isolated from the host.

### Start Infrastructure only (then run apps locally)

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

## Documentation

See the [docs/](docs/) directory for detailed documentation.

| Document | Description |
|----------|-------------|
| [Architecture](docs/architecture.md) | System overview, service connections, data flow, ER diagram, directory structure |
| [Sequences](docs/sequences.md) | Sequence diagrams for auth, matchmaking, game rooms, reconnection, chat, etc. |
| [Tech Stack](docs/tech-stack.md) | Technology stack per service, versions, security |

## Key Design Decisions

- **Server-authoritative**: All game actions validated on the game server
- **Redis as glue**: BRPOP for room creation queue, PubSub for room commands, ephemeral data storage
- **JWT shared secret**: Rails issues tokens, Phoenix verifies them
- **String UUIDs**: All primary keys are 36-char UUID strings
- **Phoenix Channels**: WebSocket transport for real-time game communication
- **Game server internal routes**: Only `/internal/health` is exposed under `/internal` and it has no authentication. When adding other internal endpoints, add API key auth to the internal pipeline.
