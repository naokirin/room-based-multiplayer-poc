# Data Model: OpenAPI Support (Internal/External API Split)

**Date**: 2026-02-19
**Feature**: [spec.md](spec.md)

## Overview

This feature does not introduce new database entities. It generates static OpenAPI definition files from existing API contracts. The "data model" here describes the structure of the generated OpenAPI documents.

## Generated Artifacts

### External API Definition (`doc/openapi/external.yaml`)

| Section | Content |
|---------|---------|
| `info` | Title: "Room-Based Multiplayer Platform — External API", version: "v1" |
| `servers` | Base URL: `/api/v1` |
| `security` | JWT Bearer Token (global default) |
| `paths` | 11 endpoints (see Endpoint Catalog below) |
| `components/schemas` | Response schemas derived from Alba serializers |
| `components/securitySchemes` | `bearerAuth: { type: http, scheme: bearer, bearerFormat: JWT }` |

### Internal API Definition (`doc/openapi/internal.yaml`)

| Section | Content |
|---------|---------|
| `info` | Title: "Room-Based Multiplayer Platform — Internal API", version: "v1" |
| `servers` | Base URL: `/internal` |
| `security` | API Key header (global default) |
| `paths` | 5 endpoints (see Endpoint Catalog below) |
| `components/schemas` | Response schemas derived from controller responses |
| `components/securitySchemes` | `apiKeyAuth: { type: apiKey, in: header, name: X-Internal-Api-Key }` |

## Endpoint Catalog

### External API Endpoints (11)

| Method | Path | Controller | Auth |
|--------|------|------------|------|
| POST | `/api/v1/auth/register` | AuthController#register | None |
| POST | `/api/v1/auth/login` | AuthController#login | None |
| POST | `/api/v1/auth/refresh` | AuthController#refresh | Bearer |
| GET | `/api/v1/profile` | ProfilesController#show | Bearer |
| POST | `/api/v1/matchmaking/join` | MatchmakingController#join | Bearer |
| GET | `/api/v1/matchmaking/status` | MatchmakingController#status | Bearer |
| DELETE | `/api/v1/matchmaking/cancel` | MatchmakingController#cancel | Bearer |
| GET | `/api/v1/game_types` | GameTypesController#index | None |
| GET | `/api/v1/rooms/:id/ws_endpoint` | RoomsController#ws_endpoint | Bearer |
| GET | `/api/v1/announcements` | AnnouncementsController#index | None |
| GET | `/api/v1/health` | HealthController#show | None |

### Internal API Endpoints (5)

| Method | Path | Controller | Auth |
|--------|------|------------|------|
| POST | `/internal/auth/verify` | AuthController#verify | API Key |
| POST | `/internal/rooms` | RoomsController#create | API Key |
| PUT | `/internal/rooms/:room_id/started` | RoomsController#started | API Key |
| PUT | `/internal/rooms/:room_id/finished` | RoomsController#finished | API Key |
| PUT | `/internal/rooms/:room_id/aborted` | RoomsController#aborted | API Key |

## Key Schema Entities (from Alba Serializers)

These are the response schemas that `rspec-openapi` will auto-generate from test execution:

- **User**: id (string), email (string), display_name (string)
- **AuthLogin**: user (User), access_token (string), expires_at (string)
- **AuthRegister**: user (User), access_token (string), expires_at (string)
- **Profile**: id (string), email (string), display_name (string), role (string)
- **GameType**: id (string), name (string), description (string), min_players (integer), max_players (integer)
- **Announcement**: id (string), title (string), body (string), published_at (string)
- **RoomWsEndpoint**: ws_url (string), room_token (string)
- **MatchmakingJoinQueued**: status ("queued"), position (integer)
- **MatchmakingJoinMatched**: status ("matched"), room_id (string), room_token (string), ws_url (string)
- **Error**: error (string), message (string)
- **Health**: status (string), timestamp (string)
