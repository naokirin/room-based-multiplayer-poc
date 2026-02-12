# Quickstart: One-Command App Stack (002-docker-compose-apps)

**Branch**: `002-docker-compose-apps`  
**Date**: 2026-02-12

## Prerequisites

- Docker Engine and Docker Compose v2
- Git (for clone)

## One Command (from repository root)

```bash
# Clone and go to repo root
git clone <repo-url>
cd room-based-multiplayer-poc
git checkout 002-docker-compose-apps

# Copy env example and set values (see below)
cp infra/.env.example infra/.env
# Edit infra/.env with your JWT_SECRET, INTERNAL_API_KEY if not using defaults

# Start full stack (infra + api-server + game-server + client)
docker compose -f infra/docker-compose.yml up
```

To run and write output to the documented log path:

```bash
bin/start-stack
```

Or redirect manually: `docker compose -f infra/docker-compose.yml up > infra/logs/compose.log 2>&1 &`

Ensure `infra/logs/` exists (e.g. `mkdir -p infra/logs`) so the log file can be written.

## Ports (service → host)

| Service      | Host port | Purpose                    |
|-------------|-----------|----------------------------|
| Client      | 3000      | Web UI (dev server)        |
| API Server  | 3001      | REST API, admin            |
| Game Server | 4000      | WebSocket (Phoenix)        |
| MySQL       | 3306      | DB (internal)              |
| Redis       | 6379      | Cache / queue (internal)   |

Ports are also noted in `infra/docker-compose.yml` (comments) and in the main README.

## Required configuration

Listed in `infra/.env.example` (keys only) and below. Set values in `infra/.env` or export before running compose.

| Variable          | Example / default        | Used by        |
|-------------------|--------------------------|----------------|
| JWT_SECRET        | dev-jwt-secret-change-me | api-server, game-server |
| INTERNAL_API_KEY  | dev-internal-api-key     | api-server, game-server |

If a required value is missing, startup should fail with a clear error (see spec FR-005, SC-003).

## Verify

- **Client**: http://localhost:3000  
- **API**: http://localhost:3001  
- **WebSocket**: ws://localhost:4000/socket  

After startup, open the client in a browser and complete login (SC-001).

## Startup failure visibility

- **CLI**: stdout/stderr and process exit code when running `docker compose ... up`.
- **Log file**: Documented path `infra/logs/compose.log` when redirecting or using a wrapper script (FR-008).

When only some services fail, the overall run is still considered failed (non-zero exit, message in log).
