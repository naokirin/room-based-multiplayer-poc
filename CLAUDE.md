# room-based-multiplayer-poc Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-02-10

## Active Technologies

- TypeScript 5.x, React 18+, PixiJS 8+ (client)
- Ruby 3.3+, Rails 7.2+ (api-server)
- Elixir 1.17+, Phoenix 1.7+ (game-server)
- MySQL 8.0+, Redis 7+ (datastores)
- Docker / Docker Compose (infra)

## Project Structure

```text
client/              # TypeScript/React/PixiJS web client
api-server/          # Ruby on Rails API + admin UI
game-server/         # Elixir/Phoenix game server (WebSocket)
infra/               # Docker Compose, MySQL/Redis config
specs/               # Feature specifications and plans
docs/                # Project documentation
```

## Commands

```bash
# Start all services
docker compose up -d

# Rails
cd api-server && bin/rails server -p 3001
cd api-server && bundle exec rspec

# Phoenix
cd game-server && mix phx.server
cd game-server && mix test

# Client
cd client && npm run dev
cd client && npm test
```

## Code Style

- Ruby: Standard Rails conventions, RSpec for tests
- Elixir: Standard Elixir/Phoenix conventions, ExUnit for tests
- TypeScript: ESLint + Prettier, Vitest for tests

## Architecture Principles

- **Client**: Display only. No game logic or validation.
- **Rails (api-server)**: Operations — auth, matchmaking, persistence, admin.
- **Phoenix (game-server)**: Game runtime — rooms, game state, chat, reconnect.
- All game actions validated server-side (server-authoritative).

## Recent Changes

- 001-room-match-platform: MVP platform specification and implementation plan

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
