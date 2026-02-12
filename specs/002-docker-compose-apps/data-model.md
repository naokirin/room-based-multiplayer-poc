# Data Model: 002-docker-compose-apps

**Branch**: `002-docker-compose-apps`  
**Date**: 2026-02-12

## Overview

This feature does not introduce new domain entities or persistent data. It only adds orchestration and configuration so that the existing services (api-server, game-server, client) and infrastructure (MySQL, Redis) can be started with one command.

## Logical “Configuration” Entities (for documentation)

| Name | Purpose |
|------|---------|
| **Orchestration definition** | Compose file(s) describing services, networks, volumes, and startup order. |
| **Environment config** | Key-only example (e.g. `.env.example`) and docs listing required env vars (e.g. `JWT_SECRET`, `INTERNAL_API_KEY`). |
| **Port mapping** | Service name → host port, documented in compose (comments) and in README/quickstart. |
| **Log path** | Single documented path (e.g. `infra/logs/compose.log`) where startup output is written for failure visibility. |

No database schema changes, no new APIs, no new domain models. Data models for users, rooms, matches, etc. remain as in [001-room-match-platform/data-model.md](../001-room-match-platform/data-model.md).
