<!--
  SYNC IMPACT REPORT
  Version change: 0.0.0 → 1.0.0 (MAJOR — initial ratification)
  Modified principles: N/A (initial creation)
  Added sections:
    - Core Principles (5 principles)
    - Technology & Architecture Constraints
    - Development Workflow
    - Governance
  Removed sections: N/A
  Templates requiring updates:
    - .specify/templates/plan-template.md — ✅ no update needed
      (Constitution Check section is generic; principles apply at review time)
    - .specify/templates/spec-template.md — ✅ no update needed
      (template is generic; spec authors apply principles during drafting)
    - .specify/templates/tasks-template.md — ✅ no update needed
      (task structure aligns with phased delivery and test-first guidance)
    - .specify/templates/agent-file-template.md — ✅ no update needed
      (auto-generated from plans; no constitutional references)
  Follow-up TODOs: None
-->

# Room-Based Multiplayer Platform Constitution

## Core Principles

### I. Server-Authoritative (NON-NEGOTIABLE)

All game logic and state mutations MUST be validated and applied
server-side. The client is a display and input layer only; it MUST
NOT make game logic decisions, compute state transitions, or trust
local calculations.

- Every player action MUST be validated against game rules on the
  server before being applied.
- Invalid actions MUST be rejected with a clear reason sent to
  the client.
- The client MUST render state received from the server as the
  single source of truth.

**Rationale**: Cheat resistance and fairness in multiplayer games
require a single authoritative source of truth. Client-side logic
creates exploitable attack surfaces.

### II. Platform-First, Game-Agnostic

The platform MUST remain game-agnostic. Game-specific logic MUST
be encapsulated behind an Elixir Behaviour callback interface
(e.g., `init_state/1`, `validate_action/2`, `apply_action/2`,
`check_end_condition/1`). Platform code MUST NOT contain
game-specific rules or assumptions.

- Adding a new game type MUST require only implementing a new
  Behaviour module — no platform code changes.
- Configuration that varies by game type (player count, turn
  timer, etc.) MUST be driven by the game type definition, not
  hardcoded in platform code.

**Rationale**: The project is a reusable infrastructure for
hosting room-based multiplayer games. Coupling platform to a
specific game destroys reusability.

### III. Clear Service Boundaries

Each service has a single responsibility. Cross-service concerns
MUST follow defined contracts.

- **Rails (api-server)**: Authentication, matchmaking,
  persistence, administration. Owns user accounts and game
  results.
- **Phoenix (game-server)**: Game runtime — rooms, real-time
  state, chat, reconnection. Owns in-memory game state during
  play.
- **Client**: Display and user input only.
- Inter-service communication MUST use documented API contracts
  (REST, WebSocket). Services MUST NOT share databases or
  bypass contracts.

**Rationale**: Separation of concerns enables independent
deployment, scaling, and technology evolution per service.

### IV. Test-First for Contracts and Critical Paths

Tests for API contracts (Rails endpoints, Phoenix channels) and
critical game flows (matchmaking, room lifecycle, reconnection)
MUST be written before or alongside implementation.

- Contract tests MUST verify request/response shapes against
  documented API contracts.
- Integration tests MUST cover cross-service flows (e.g.,
  match → room creation → game start).
- Each user story MUST be independently testable.

**Rationale**: In a multi-service architecture, contract drift
is the primary source of integration failures. Tests catch
drift early.

### V. Simplicity and MVP Discipline

Features MUST be scoped to the defined MVP. Defer complexity
that is not required for the current iteration.

- YAGNI: Do not build features, abstractions, or
  infrastructure for hypothetical future needs.
- Prefer the simplest implementation that satisfies the
  acceptance criteria in the spec.
- Complexity MUST be justified in the plan's Complexity
  Tracking table if it exceeds the simplest viable approach.

**Rationale**: This is a proof-of-concept. Over-engineering
delays validation of the core architecture. Premature
abstraction creates maintenance burden without proven value.

## Technology & Architecture Constraints

- **Client**: TypeScript 5.x, React 18+, PixiJS 8+
  (web browser only for MVP).
- **API Server**: Ruby 3.3+, Rails 8.0+ (full mode with
  server-rendered admin views).
- **Game Server**: Elixir 1.17+, Phoenix 1.7+
  (WebSocket channels for real-time communication).
- **Datastores**: MySQL 8.0+ (persistent data), Redis 7+
  (matchmaking queue, ephemeral state).
- **Infrastructure**: Docker / Docker Compose for local
  development.
- **Authentication**: JWT issued by Rails, validated
  independently by Phoenix. Authorization requires Phoenix
  to call Rails API on WebSocket connect.
- Technology stack changes MUST be approved by the project
  owner before implementation.

## Development Workflow

- Follow conventional commits:
  `type: short description` (feat, fix, refactor, docs, test,
  chore, perf, ci).
- Commit after each completed task (one task = one commit).
- Run the relevant test suite and linter before committing:
  - Rails: `bundle exec rspec`, `bundle exec rubocop`
  - Phoenix: `mix test`, `mix credo`, `mix format`
  - Client: `npm test`, `npm run lint`
- Code review MUST check: service boundary compliance,
  server-authoritative enforcement, contract alignment, test
  coverage for critical paths, and MVP scope adherence.
- Use `/code-review` before committing non-trivial changes.

## Governance

This constitution is the highest-authority document for
architectural and process decisions in this project. When
conflicts arise between this constitution and other documents
(plans, specs, task lists), this constitution takes precedence.

- **Amendments**: Any change to this constitution MUST be
  documented with a version bump, rationale, and updated
  Sync Impact Report.
- **Versioning**: Semantic versioning (MAJOR.MINOR.PATCH).
  MAJOR for principle changes, MINOR for new sections,
  PATCH for clarifications.
- **Compliance review**: Every plan MUST include a
  Constitution Check section verifying alignment with these
  principles before implementation begins.

**Version**: 1.0.0 | **Ratified**: 2026-02-12 | **Last Amended**: 2026-02-12
