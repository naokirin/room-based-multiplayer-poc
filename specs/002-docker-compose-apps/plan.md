# Implementation Plan: One-Command App Stack Startup (Docker Compose Apps)

**Branch**: `002-docker-compose-apps` | **Date**: 2026-02-12 | **Spec**: [spec.md](./spec.md)  
**Input**: Feature specification from `/specs/002-docker-compose-apps/spec.md`

## Summary

Enable developers to start the full stack (infra + API server, game server, client) with one command using the same Docker Compose approach as existing infra. Definitions may live in one file or split (e.g. infra + app override); client runs as a dev server with hot reload; startup failures visible via CLI and a documented log file; required config listed in an example file and docs; ports documented in both the compose definition and README.

## Technical Context

**Language/Version**: No new application language; orchestration uses Docker Compose (Compose Spec v3). Existing services: Ruby 3.3+ (Rails), Elixir 1.17+ (Phoenix), Node 20+ (Vite/React client).  
**Primary Dependencies**: Docker Engine, Docker Compose v2; existing stack (Rails, Phoenix, Vite) unchanged.  
**Storage**: N/A for this feature (MySQL/Redis remain as in 001).  
**Testing**: Manual and CI verification that one command brings up all services; existing per-service tests (RSpec, ExUnit, Vitest) unchanged.  
**Target Platform**: Local development and CI (Linux/macOS with Docker).  
**Project Type**: Multi-service (api-server, game-server, client) plus infra; single repo, compose from `infra/` or repo root.  
**Performance Goals**: Full stack up within 5 minutes (SC-001).  
**Constraints**: Single start command; client must be dev server with hot reload; log file at documented path; ports and env vars documented.  
**Scale/Scope**: Development and verification only; production deployment out of scope.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Server-Authoritative | Pass | No change to game logic or client/server roles. |
| II. Platform-First, Game-Agnostic | Pass | Orchestration only; no game-specific code. |
| III. Clear Service Boundaries | Pass | Same boundaries; compose only wires existing services. |
| IV. Test-First for Contracts | Pass | No new API contracts; existing contract tests unchanged. |
| V. Simplicity and MVP Discipline | Pass | Minimal additions: compose entries, Dockerfiles where missing, .env.example, docs. |
| Technology & Architecture | Pass | Docker / Docker Compose for local development (constitution). |

No violations. Complexity Tracking table left empty.

## Project Structure

### Documentation (this feature)

```text
specs/002-docker-compose-apps/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output (orchestration/config only)
├── quickstart.md       # Phase 1 output
├── contracts/           # Phase 1 output (no new APIs; see README)
└── tasks.md             # Phase 2 output (/speckit.tasks — not created by plan)
```

### Source Code (repository root)

```text
infra/
├── docker-compose.yml   # May be single file or split (infra + app)
├── .env.example         # Key-only; required env vars listed
├── logs/                # Documented path for compose/startup log file (optional dir)
├── mysql/
│   └── init.sql
└── redis/
    └── redis.conf

api-server/
├── Dockerfile           # Exists
└── ...

game-server/
├── Dockerfile           # To add or verify for compose build
└── ...

client/
├── Dockerfile           # To add: dev server (npm run dev) with hot reload
└── ...
```

**Structure Decision**: Keep orchestration under `infra/`; single entry point from repo root (e.g. `docker compose -f infra/docker-compose.yml up` or script in root). Optional wrapper or documented command writes startup output to a log file at a documented path (e.g. `infra/logs/startup.log` or `./logs/compose.log`).

## Complexity Tracking

> No constitution violations. Table left empty.
