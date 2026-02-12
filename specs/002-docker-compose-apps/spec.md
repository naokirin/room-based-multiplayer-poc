# Feature Specification: One-Command App Stack Startup (Same Approach as Infra)

**Feature Branch**: `002-docker-compose-apps`  
**Created**: 2026-02-12  
**Status**: Draft  
**Input**: User description: "api-server, game-server, clientの配信サーバをinfra以下と同じように docker compose で実行できるようにする" (Enable running api-server, game-server, and client delivery servers via the same docker compose approach as under infra.)

## Clarifications

### Session 2026-02-12

- Q: Should the client run as a production-style static build or as a dev server with hot reload? → A: Dev server only (client runs as dev server with hot reload for local development).
- Q: Must infra and app services live in one orchestration file or may they be split? → A: Multiple files allowed (e.g. infra + app override) as long as one command starts all services.
- Q: Where should startup failure or “overall failed” be visible? → A: CLI + log file (stdout/stderr and exit code, plus a log file at a documented path).
- Q: Should required startup config be listed in an example file, documentation only, or both? → A: Both (example file with keys only plus documentation listing).
- Q: Where must “which service uses which port” be documented? → A: Both (in the orchestration definition and in README/docs).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Developers Can Start the Full Stack with One Command (Priority: P1)

Developers can start the API server, game server, and client delivery services in one go using the same procedure as for infrastructure (database, cache, etc.). They do not need to install each runtime locally; the entire environment can be brought up in a reproducible way using the same orchestration approach.

**Why this priority**: Directly affects onboarding and day-to-day development efficiency. Having everything come up with one command is the top priority.

**Independent Test**: After a fresh clone, run the single command documented; API, game server, and client all become available. This validates the story.

**Acceptance Scenarios**:

1. **Given** a freshly cloned repository, **When** the same procedure used for infra startup is run to execute the start command, **Then** the three services (API server, game server, client) start and become available.
2. **Given** the environment started as above, **When** the client connects to the API and game server, **Then** authentication, matchmaking, and game connection work as expected.

---

### User Story 2 - Infra and Apps Run on the Same Network and Dependencies (Priority: P2)

Infrastructure services (DB, cache, etc.) and application services (API, game, client) are defined in the same orchestration and start with a single network and dependency model. Startup order and connection targets are consistent and defined.

**Why this priority**: Replicates production-like connectivity and reduces issues caused by environment differences.

**Independent Test**: After startup, verify that each service can resolve and connect to the others and that dependency order (e.g. API after DB is ready) is respected.

**Acceptance Scenarios**:

1. **Given** all services are running as defined, **When** each service connects to others, **Then** name resolution and communication succeed.
2. **Given** a startup definition exists, **When** startup is triggered, **Then** dependents start only after their dependencies are ready.

---

### User Story 3 - Reproducible Environment for CI and Verification (Priority: P3)

The same startup approach is used so that CI or manual verification can reproduce the full “infra + app” set. Configuration is managed as code so that anyone running it gets the same setup.

**Why this priority**: Foundation for quality assurance and pre-deploy verification.

**Independent Test**: Run the same procedure on another machine or in CI; all services start and end-to-end verification can be performed.

**Acceptance Scenarios**:

1. **Given** only the repository and documentation, **When** the documented procedure is run, **Then** all services start without extra manual configuration and are ready for verification.
2. **Given** the startup definition has been changed, **When** startup is run again, **Then** services start with the updated configuration.

---

### Edge Cases

- When required environment variables or secrets are missing, startup fails before bringing up services, with a clear error message.
- When port conflicts occur, both the orchestration definition and README/docs state which service uses which port so the cause can be identified easily.
- When only some services fail to start, the overall outcome is still clearly “failed” (via CLI stdout/stderr, exit code, and a log file at a documented path), even if other services are up.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The three delivery services (API server, game server, client) MUST be startable using the same approach as infra orchestration; definitions MAY be in one file or split across files (e.g. infra + app override) provided a single command starts all services.
- **FR-002**: A single start command MUST bring up infrastructure services (DB, cache, etc.) and the above three services together so they can connect to each other.
- **FR-003**: Service startup order MUST respect dependencies (e.g. API starts only after DB is available).
- **FR-004**: Connection targets (host names, ports) between services MUST be specified consistently in the definition and documented in both the orchestration definition (e.g. comments/labels) and in README or other docs.
- **FR-005**: Configuration required for startup (e.g. environment variables) MUST be explicit via both a key-only example file (e.g. `.env.example`) in the repo and documentation (e.g. README); when required values are missing, startup MUST fail or report a clear error.
- **FR-006**: Developers MUST be able to start the full stack from the repository root (or a single infra-equivalent location) using the same procedure.
- **FR-007**: The client service MUST run as a dev server with hot reload (no production static build required for this scope).
- **FR-008**: Startup failure or “overall failed” (e.g. when only some services fail) MUST be visible via CLI (stdout/stderr and process exit code) and via a log file written to a path documented in the repository.

### Assumptions

- Scope is local and CI environments for development and verification; production deployment is out of scope for this phase.
- The existing infra orchestration (under infra) is the reference; the three app services are added into it or follow the same pattern (single or multiple definition files allowed; one command must start all).
- Secrets are supplied via environment variables or local files and are not committed to the repository.
- Client is run as a dev server with hot reload for development and verification (production build is out of scope).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: After a fresh clone, following the documented procedure, the full set (infra + API, game, client) is up within 5 minutes and a user can open the client in a browser and complete login.
- **SC-002**: When two or more developers run the same startup procedure, they get the same configuration, all services start, and the main user scenarios (auth, matchmaking, game connection) work.
- **SC-003**: All configuration needed for startup is listed in an example file (keys only) and in documentation; when a required item is missing, startup fails and a message or log makes the cause clear.
