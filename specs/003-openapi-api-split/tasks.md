# Tasks: OpenAPI Support (Internal/External API Split)

**Input**: Design documents from `/specs/003-openapi-api-split/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/, quickstart.md

**Tests**: Tests are NOT explicitly requested. Existing RSpec request specs are the source of truth for OpenAPI generation. No new test tasks are needed.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Add rspec-openapi gem and create base configuration

- [x] T001 Add `rspec-openapi` gem to `api-server/Gemfile` (development/test group) and run `bundle install`
- [x] T002 Create `api-server/doc/openapi/` directory and add `.gitkeep`
- [x] T003 Create rspec-openapi configuration in `api-server/spec/openapi_helper.rb` with lambda-based path routing (internal → `doc/openapi/internal.yaml`, external → `doc/openapi/external.yaml`), per-API titles, security schemes (bearerAuth + apiKeyAuth), and per-API info blocks
- [x] T004 Update `api-server/spec/rails_helper.rb` to conditionally require `openapi_helper` when `ENV["OPENAPI"]` is set

**Checkpoint**: rspec-openapi is installed and configured. Running `OPENAPI=1 bundle exec rspec` should generate YAML files (may have issues to fix in subsequent phases).

---

## Phase 2: User Story 1 - Reviewing External API Definition File (Priority: P1) — MVP

**Goal**: Generate a complete external API OpenAPI definition file covering all 11 endpoints under `/api/v1/` with request/response schemas, examples, and JWT Bearer Token auth.

**Independent Test**: Open `api-server/doc/openapi/external.yaml` and verify all 11 external API endpoints are documented with correct request parameters, response schemas, and JWT auth scheme.

### Implementation for User Story 1

- [ ] T005 [US1] Run `OPENAPI=1 bundle exec rspec spec/requests/api/v1/` to generate initial `api-server/doc/openapi/external.yaml`
- [ ] T006 [US1] Review generated `api-server/doc/openapi/external.yaml` and verify all 11 endpoints are present: auth/register, auth/login, auth/refresh, profile, matchmaking/join, matchmaking/status, matchmaking/cancel, game_types, rooms/:id/ws_endpoint, announcements, health. For each endpoint, confirm request parameters, request body (where applicable), and response body type definitions are included (FR-004)
- [ ] T007 [US1] If any endpoints are missing or incomplete, ensure the corresponding `api-server/spec/requests/api/v1/*_spec.rb` test examples actually make the HTTP request (rspec-openapi captures from real requests); add or fix test examples as needed
- [ ] T008 [US1] Verify JWT Bearer Token security scheme is documented in `components/securitySchemes` of `api-server/doc/openapi/external.yaml`, and public endpoints (register, login, game_types, announcements, health) correctly show no auth required
- [ ] T009 [US1] Verify response schemas include both success (2xx) and error (4xx) response formats with examples in `api-server/doc/openapi/external.yaml`
- [ ] T010 [US1] Commit generated `api-server/doc/openapi/external.yaml` to the repository

**Checkpoint**: External API definition file is complete and committed. All 11 endpoints documented with schemas and auth. SC-001 satisfied.

---

## Phase 3: User Story 2 - Reviewing Internal API Definition File (Priority: P2)

**Goal**: Generate a complete internal API OpenAPI definition file covering all 5 endpoints under `/internal/` with API key header auth, fully separated from the external API file.

**Independent Test**: Open `api-server/doc/openapi/internal.yaml` and verify only internal API endpoints are documented, with API key auth scheme. Confirm no external endpoints appear and vice versa.

### Implementation for User Story 2

- [ ] T011 [US2] Run `OPENAPI=1 bundle exec rspec spec/requests/internal/` to generate initial `api-server/doc/openapi/internal.yaml`
- [ ] T012 [US2] Review generated `api-server/doc/openapi/internal.yaml` and verify all 5 endpoints are present: auth/verify, rooms (create), rooms/:room_id/started, rooms/:room_id/finished, rooms/:room_id/aborted
- [ ] T013 [US2] If any endpoints are missing or incomplete, adjust request spec assertions in `api-server/spec/requests/internal/*_spec.rb` files to ensure rspec-openapi captures them
- [ ] T014 [US2] Verify API Key header security scheme (`X-Internal-Api-Key`) is documented in `components/securitySchemes` of `api-server/doc/openapi/internal.yaml`
- [ ] T015 [US2] Verify separation: confirm no external API endpoints appear in `internal.yaml` and no internal API endpoints appear in `external.yaml`
- [ ] T016 [US2] Commit generated `api-server/doc/openapi/internal.yaml` to the repository

**Checkpoint**: Internal API definition file is complete and committed. All 5 endpoints documented. Separation verified. SC-002 satisfied.

---

## Phase 4: User Story 3 - Synchronization with Source Code (Priority: P3)

**Goal**: Verify the regeneration workflow works correctly — running the generation command produces up-to-date definition files. Validate generated files against OpenAPI spec.

**Independent Test**: Run `OPENAPI=1 bundle exec rspec` and validate the output with an OpenAPI linting tool. Zero validation errors.

### Implementation for User Story 3

- [ ] T017 [US3] Run full `OPENAPI=1 bundle exec rspec` in `api-server/` and verify both `doc/openapi/external.yaml` and `doc/openapi/internal.yaml` are regenerated correctly
- [ ] T018 [US3] Validate generated files with `npx @redocly/cli lint api-server/doc/openapi/external.yaml` and `npx @redocly/cli lint api-server/doc/openapi/internal.yaml` — fix any validation errors
- [ ] T019 [US3] Document the generation command (`OPENAPI=1 bundle exec rspec`) in `api-server/README.md` under a new "OpenAPI Documentation" section

**Checkpoint**: Regeneration workflow verified. Validation passes with zero errors. SC-003 and SC-005 satisfied.

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Documentation updates and final cleanup

- [ ] T020 [P] Add `OPENAPI=1 bundle exec rspec` to the Commands section in project `CLAUDE.md`
- [ ] T021 [P] Update project `CLAUDE.md` Active Technologies section to include `rspec-openapi` gem
- [ ] T022 Verify all existing tests still pass with `bundle exec rspec` (without OPENAPI flag) — no regressions

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **US1 (Phase 2)**: Depends on Setup (Phase 1) completion
- **US2 (Phase 3)**: Depends on Setup (Phase 1) completion — can run in parallel with US1
- **US3 (Phase 4)**: Depends on US1 and US2 completion (needs both files generated)
- **Polish (Phase 5)**: Depends on US3 completion

### User Story Dependencies

- **User Story 1 (P1)**: Depends on Phase 1 only. Generates external.yaml independently.
- **User Story 2 (P2)**: Depends on Phase 1 only. Generates internal.yaml independently. Can run in parallel with US1.
- **User Story 3 (P3)**: Depends on US1 + US2 (needs both files to validate full regeneration workflow).

### Parallel Opportunities

- T002 and T003 can run in parallel (different files)
- US1 (Phase 2) and US2 (Phase 3) can run in parallel after Phase 1 completes
- T020 and T021 can run in parallel (different files)

---

## Parallel Example: User Story 1 + User Story 2

```bash
# After Phase 1 (Setup) completes, launch both user stories in parallel:
# Developer A: User Story 1 (external API)
OPENAPI=1 bundle exec rspec spec/requests/api/v1/

# Developer B: User Story 2 (internal API)
OPENAPI=1 bundle exec rspec spec/requests/internal/
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001–T004)
2. Complete Phase 2: User Story 1 — External API (T005–T010)
3. **STOP and VALIDATE**: Open `doc/openapi/external.yaml`, verify 11 endpoints, preview in VSCode
4. External API documentation is immediately useful to client developers

### Incremental Delivery

1. Setup (Phase 1) → Foundation ready
2. US1: External API → 11 endpoints documented → Commit (MVP!)
3. US2: Internal API → 5 endpoints documented → Commit
4. US3: Validation + docs → Workflow verified → Commit
5. Polish → CLAUDE.md/README updated → Commit

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- No new test files needed — existing RSpec request specs drive OpenAPI generation
- Commit after each phase checkpoint
- The `OPENAPI` environment variable toggle ensures normal test runs are not slowed by generation
- If rspec-openapi doesn't capture certain endpoints, the fix is in the request spec (ensure the test actually makes the HTTP request)
