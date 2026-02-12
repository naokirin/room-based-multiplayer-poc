# Tasks: One-Command App Stack Startup (Docker Compose Apps)

**Input**: Design documents from `/specs/002-docker-compose-apps/`  
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md, contracts/README

**Tests**: Not requested in spec; no test tasks included.

**Organization**: Tasks grouped by user story for independent implementation and validation.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: User story (US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Infra**: `infra/` (docker-compose.yml, .env.example, logs/)
- **Services**: `api-server/`, `game-server/`, `client/` (Dockerfiles, existing code)
- **Docs**: `README.md` at repo root, `specs/002-docker-compose-apps/quickstart.md`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Config and log path so one-command startup and failure visibility are possible.

- [x] T001 Create `infra/logs/` directory and add `infra/logs/*.log` to `.gitignore` (or create `infra/.gitignore` with `logs/*.log`)
- [x] T002 [P] Add `infra/.env.example` with key-only entries: `JWT_SECRET`, `INTERNAL_API_KEY` (no values; document in README/quickstart)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: All five services (mysql, redis, api-server, game-server, client) are defined in compose and buildable; client runs as dev server with hot reload; startup order respects dependencies.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [x] T003 Ensure `infra/docker-compose.yml` defines mysql, redis, api-server, game-server, client with shared network and correct `depends_on` and healthchecks (API after mysql/redis; game-server after redis; client after api-server, game-server)
- [x] T004 [P] Add or verify `game-server/Dockerfile` so `docker compose -f infra/docker-compose.yml build game-server` succeeds
- [x] T005 [P] Add `client/Dockerfile` that runs Vite dev server (`npm run dev`) and exposes port 3000, with working directory and install step per plan/research
- [x] T006 Update `infra/docker-compose.yml` client service: use build context `../client`, Dockerfile, volume mount for `../client/src` (and any other source needed for hot reload) so changes on host apply in container without rebuild; ensure port 3000 and env VITE_API_URL / VITE_WS_URL point to host-accessible URLs (e.g. localhost) for browser

**Checkpoint**: `docker compose -f infra/docker-compose.yml up` from repo root brings up all services; client is dev server with hot reload.

---

## Phase 3: User Story 1 - Developers Can Start the Full Stack with One Command (Priority: P1) 🎯 MVP

**Goal**: One command from repo root starts infra + API + game server + client; developer can open client in browser and complete login.

**Independent Test**: From a fresh clone, run the documented single command; API, game server, and client are available; open client and complete login (SC-001).

### Implementation for User Story 1

- [x] T007 [US1] Document in `README.md` the single start command from repo root: `docker compose -f infra/docker-compose.yml up` and document log file path `infra/logs/compose.log` for startup failure visibility (FR-006, FR-008)
- [x] T008 [US1] Add short comments in `infra/docker-compose.yml` per service for host port (e.g. `# Host port 3001` for api-server) (FR-004)
- [x] T009 [US1] Add a "Ports" table in `README.md` (service name, host port, purpose) matching quickstart and compose (FR-004)

**Checkpoint**: User Story 1 is done; one command starts full stack; ports documented in compose and README; log path documented.

---

## Phase 4: User Story 2 - Infra and Apps Run on Same Network and Dependencies (Priority: P2)

**Goal**: Same orchestration, one network, dependency order clear; connection targets and ports documented in definition and docs.

**Independent Test**: After startup, each service can resolve and connect to others; dependents start only after dependencies are ready (e.g. API after DB healthy).

### Implementation for User Story 2

- [x] T010 [US2] Verify in `infra/docker-compose.yml` that `depends_on` and healthchecks enforce order (mysql/redis healthy before api-server; redis before game-server; api-server and game-server before client) and add brief comments if needed (FR-003)
- [x] T011 [US2] Document connection targets (host names and ports) and startup order in `README.md` or link to `specs/002-docker-compose-apps/quickstart.md` so both orchestration and docs describe ports (FR-004)

**Checkpoint**: User Story 2 is done; dependency order and connection targets are clear in compose and docs.

---

## Phase 5: User Story 3 - Reproducible Environment for CI and Verification (Priority: P3)

**Goal**: Config as code; same procedure works for any developer or CI; required config listed in example file and documentation; optional script for log file.

**Independent Test**: Run documented procedure on another machine or in CI; all services start without extra manual config; optional script writes output to documented log path.

### Implementation for User Story 3

- [x] T012 [US3] Ensure `infra/.env.example` lists all required variables (JWT_SECRET, INTERNAL_API_KEY) and that `README.md` documents required configuration and procedure (copy env example, set values, then run compose) (FR-005, SC-003)
- [x] T013 [US3] Add optional wrapper script at repo root (e.g. `bin/start-stack` or `script/start-stack`) that runs `docker compose -f infra/docker-compose.yml up` and tees output to `infra/logs/compose.log` so FR-008 is satisfied; document script in README and quickstart
- [x] T014 [US3] Update README "Quick Start" (or equivalent) to use the one-command flow and reference `specs/002-docker-compose-apps/quickstart.md` for full procedure (FR-006)

**Checkpoint**: User Story 3 is done; config and procedure are documented; optional script supports log file at documented path.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final hygiene and validation.

- [x] T015 [P] Ensure `infra/logs/` is ignored by git (e.g. `infra/logs/*.log` or `infra/logs/` in `.gitignore` or `infra/.gitignore`) so log files are not committed
- [ ] T016 Run quickstart validation: from clean clone, follow `specs/002-docker-compose-apps/quickstart.md` and confirm full stack up within 5 minutes and login possible (SC-001). *Manual step: run `docker compose -f infra/docker-compose.yml up` and verify client login.*

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — start immediately.
- **Phase 2 (Foundational)**: Depends on Phase 1 — BLOCKS all user stories.
- **Phase 3 (US1)**: Depends on Phase 2 — MVP.
- **Phase 4 (US2)**: Depends on Phase 2 (can overlap with US1 if needed).
- **Phase 5 (US3)**: Depends on Phase 2 (can overlap with US1/US2).
- **Phase 6 (Polish)**: Depends on Phases 3–5 being complete for full validation.

### User Story Dependencies

- **US1 (P1)**: After Foundational only — one command, ports and log path docs.
- **US2 (P2)**: After Foundational — dependency order and connection docs; can follow US1.
- **US3 (P3)**: After Foundational — env example + docs, optional script, README quick start; can follow US1/US2.

### Parallel Opportunities

- T002 can run in parallel with T001.
- T004 and T005 can run in parallel (different Dockerfiles).
- T007, T008, T009 can be done in any order within Phase 3.
- T015 can run in parallel with other Polish tasks.

---

## Parallel Example: Phase 2

```text
# Parallel:
T004: Add or verify game-server/Dockerfile
T005: Add client/Dockerfile (Vite dev server)
# Then:
T003: Ensure compose defines all services and deps
T006: Update compose client service (build + volumes)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 (Setup).
2. Complete Phase 2 (Foundational).
3. Complete Phase 3 (US1).
4. **STOP and VALIDATE**: Run one command from repo root; open client and complete login.
5. Demo if ready.

### Incremental Delivery

1. Setup + Foundational → stack startable.
2. Add US1 → one-command and port/log docs → MVP.
3. Add US2 → dependency and connection docs.
4. Add US3 → config docs and optional script.
5. Polish → .gitignore and quickstart validation.

### Parallel Team Strategy

- After Phase 2: one person can own US1, another US2, another US3 (docs and script), then merge and run Phase 6.

---

## Notes

- [P] tasks use different files and have no ordering dependency within the phase.
- [Story] label maps each task to a user story for traceability.
- No test tasks (spec does not request tests).
- Commit after each task or logical group.
- Validate at each checkpoint before moving on.
