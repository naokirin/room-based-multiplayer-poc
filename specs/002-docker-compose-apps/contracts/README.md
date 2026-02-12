# Contracts: 002-docker-compose-apps

**Branch**: `002-docker-compose-apps`  
**Date**: 2026-02-12

This feature does not define new API or WebSocket contracts. It only adds orchestration (Docker Compose) and documentation so that the full stack can be started with one command.

Existing contracts remain in [001-room-match-platform/contracts/](../001-room-match-platform/contracts/):

- **internal-api.md** — Rails internal API used by Phoenix
- **phoenix-ws.md** — Phoenix channel/WebSocket contract
- **rails-api.md** — Rails public API (auth, matchmaking, etc.)

No new endpoints, request/response shapes, or channel events are introduced by 002.
