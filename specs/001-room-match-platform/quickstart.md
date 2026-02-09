# Quickstart: Room-Based Multiplayer Game Platform (MVP)

**Feature Branch**: `001-room-match-platform`
**Date**: 2026-02-10

## Prerequisites

- Docker & Docker Compose
- Node.js 20+ (for client development)
- Ruby 3.3+ (for api-server development outside Docker)
- Elixir 1.17+ / Erlang 26+ (for game-server development outside Docker)

## Quick Start (Docker)

```bash
# Clone and checkout
git clone <repo-url>
cd room-based-multiplayer-poc
git checkout 001-room-match-platform

# Start all services
docker compose up -d

# Verify all services are running
docker compose ps
```

Services will be available at:
- **Client**: http://localhost:3000
- **API Server (Rails)**: http://localhost:3001
- **Game Server (Phoenix)**: ws://localhost:4000/socket
- **MySQL**: localhost:3306 (internal)
- **Redis**: localhost:6379 (internal)

## Service Setup (Development)

### API Server (Rails)

```bash
cd api-server

# Install dependencies
bundle install

# Setup database
bin/rails db:create db:migrate db:seed

# Run tests
bundle exec rspec

# Start server
bin/rails server -p 3001
```

**Environment variables** (`.env` or Docker):
```
DATABASE_URL=mysql2://root:password@localhost:3306/game_platform_dev
REDIS_URL=redis://localhost:6379/0
JWT_SECRET=your-shared-jwt-secret-key
INTERNAL_API_KEY=your-internal-api-key
PHOENIX_NODES=http://localhost:4000
```

### Game Server (Phoenix)

```bash
cd game-server

# Install dependencies
mix deps.get

# Run tests
mix test

# Start server
mix phx.server
```

**Environment variables**:
```
REDIS_URL=redis://localhost:6379/0
JWT_SECRET=your-shared-jwt-secret-key  # Must match Rails
INTERNAL_API_KEY=your-internal-api-key  # Must match Rails
RAILS_INTERNAL_URL=http://localhost:3001/internal
NODE_NAME=game-server-1
PORT=4000
```

### Client

```bash
cd client

# Install dependencies
npm install

# Run tests
npm test

# Start dev server
npm run dev
```

**Environment variables** (`.env`):
```
VITE_API_URL=http://localhost:3001/api/v1
VITE_WS_URL=ws://localhost:4000/socket
```

## Seed Data

The Rails seed script creates:
- 1 admin user (admin@example.com / password)
- 2 test players (player1@example.com, player2@example.com / password)
- 1 game type (simple_card_battle, 2 players)

## Testing the Full Flow

1. **Start all services** (Docker or individually)

2. **Register/Login** (2 browser windows):
   ```bash
   # Player 1
   curl -X POST http://localhost:3001/api/v1/auth/login \
     -H "Content-Type: application/json" \
     -d '{"email":"player1@example.com","password":"password"}'

   # Player 2
   curl -X POST http://localhost:3001/api/v1/auth/login \
     -H "Content-Type: application/json" \
     -d '{"email":"player2@example.com","password":"password"}'
   ```

3. **Join matchmaking** (both players):
   ```bash
   curl -X POST http://localhost:3001/api/v1/matchmaking/join \
     -H "Authorization: Bearer <token>" \
     -H "Content-Type: application/json" \
     -d '{"game_type_id":"<game_type_uuid>"}'
   ```

4. **Connect to room** (use the `room_token` and `ws_url` from match response)

5. **Play game** (send `game:action` messages via WebSocket)

6. **Verify result** (check `game:ended` event and Rails game_results table)

## Admin Panel

Access: http://localhost:3001/admin (login with admin@example.com / password)

Available operations:
- Search users by name/email
- Freeze/unfreeze accounts
- View room list and statuses
- Force-terminate active rooms
- Create/manage announcements

## Useful Commands

```bash
# View logs for a specific service
docker compose logs -f api-server
docker compose logs -f game-server

# Access Rails console
docker compose exec api-server bin/rails console

# Access Elixir shell
docker compose exec game-server iex -S mix

# Reset database
docker compose exec api-server bin/rails db:reset

# Run specific test
docker compose exec api-server bundle exec rspec spec/services/matchmaking_service_spec.rb
docker compose exec game-server mix test test/game_server/room_test.exs
```
