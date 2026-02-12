# Research: 002-docker-compose-apps

**Branch**: `002-docker-compose-apps`  
**Date**: 2026-02-12

## 1. Log file path for startup failure / “overall failed”

**Decision**: Use a dedicated directory under the compose context: `infra/logs/` with a single file e.g. `infra/logs/compose.log`. Document this path in README and quickstart.

**Rationale**: Keeps logs next to the compose definition; `.gitignore` can exclude `infra/logs/*.log` so logs are not committed. One file is enough for “startup failure visible in a log file”; rotation is out of scope.

**Alternatives considered**: Repo-root `./logs/` (chosen location could be either; infra/logs keeps infra self-contained). Writing only to stdout (rejected per spec: CLI + log file required).

---

## 2. Example env file and documentation location

**Decision**: Add `.env.example` in `infra/` (next to `docker-compose.yml`) with key-only entries. Document the same variables and the log path in README (and in `specs/002-docker-compose-apps/quickstart.md`).

**Rationale**: Compose typically loads `.env` from the project directory; placing `.env.example` in `infra/` matches where users run `docker compose`. README is the main entry for “documentation”; quickstart repeats the list for this feature’s flow.

**Alternatives considered**: Repo-root `.env.example` (possible but compose runs from `infra/`; one place is simpler). Documentation only without example file (rejected per spec: both required).

---

## 3. Client as dev server with hot reload in Docker

**Decision**: Add a `client/Dockerfile` that runs the Vite dev server (`npm run dev`). Use a volume mount for `client/src` (and any other source needed for hot reload) so host changes are reflected in the container without rebuild.

**Rationale**: Spec (FR-007) requires client as dev server with hot reload. Vite supports HMR; mounting source is the standard way to get hot reload inside Docker. Production build is out of scope.

**Alternatives considered**: Multi-stage build that only does production build (rejected: spec requires dev server). Running client only on host (rejected: one-command full stack must include client in compose).

---

## 4. Single command from repository root

**Decision**: Document the single command as run from repo root: `docker compose -f infra/docker-compose.yml up` (or equivalent). Optionally provide a small script at repo root (e.g. `bin/up` or `script/start-stack`) that runs this and tees output to the documented log path so FR-008 is satisfied without changing compose itself.

**Rationale**: FR-006 requires starting the full stack from repo root (or a single infra-equivalent location). Using `-f infra/docker-compose.yml` from root keeps one command and avoids `cd infra`. A wrapper script can both set the log path and keep the “one command” experience.

**Alternatives considered**: Require `cd infra && docker compose up` (acceptable “single location” but root is preferred for consistency). Single compose file at repo root (possible; current layout keeps infra in `infra/`; plan allows split files).

---

## 5. Port and connection documentation

**Decision**: (1) In `infra/docker-compose.yml`: add short comments per service listing the host port (e.g. `# Host port 3001`). (2) In README and quickstart: add a “Ports” table (service name, host port, purpose). This satisfies FR-004 and the port-conflict edge case.

**Rationale**: Spec requires ports (and connection targets) in both the orchestration definition and in README/docs. Comments in YAML plus a table in docs is minimal and clear.

**Alternatives considered**: Labels in compose (e.g. `labels: ["port=3001"]`) — comments are simpler and sufficient. Documentation only — rejected per spec (both definition and docs).
