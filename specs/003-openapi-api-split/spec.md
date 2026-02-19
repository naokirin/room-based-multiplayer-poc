# Feature Specification: OpenAPI Support (Internal/External API Split)

**Feature Branch**: `003-openapi-api-split`
**Created**: 2026-02-19
**Status**: Draft
**Input**: User description: "Split api-server APIs into internal/external and add OpenAPI support"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Reviewing External API Definition File (Priority: P1)

Client developers (frontend or mobile app developers) can reference the external API OpenAPI definition file in the repository and review the full list of external API endpoints (auth, matchmaking, profile, game types, rooms, announcements, health check), including request/response formats and authentication methods.

**Why this priority**: The external API is essential for client application integration, and auto-generated definition files contribute the most to development efficiency.

**Independent Test**: Open the external API definition file in the repository and verify that all external API endpoint information is accurately documented.

**Acceptance Scenarios**:

1. **Given** the external API definition file exists in the repository, **When** a developer opens the file, **Then** all external API endpoints are listed by category
2. **Given** the developer is viewing the external API definition file, **When** they check a specific endpoint definition, **Then** request parameters, request body, and response body type definitions with examples are documented
3. **Given** the developer is viewing the external API definition file, **When** they check the authentication section, **Then** JWT Bearer Token authentication is described
4. **Given** the external API definition file exists, **When** a developer views it with an OpenAPI preview extension in VSCode or similar IDE, **Then** the endpoint list is visually rendered

---

### User Story 2 - Reviewing Internal API Definition File (Priority: P2)

Game server (Phoenix) developers can reference the internal API OpenAPI definition file in the repository and review the internal API specifications (auth verification, room management callbacks). The internal API definition file is separate from the external API, allowing developers to accurately understand internal communication contracts.

**Why this priority**: The internal API is used for Phoenix server communication, and managing it separately from the external API improves security and maintainability.

**Independent Test**: Open the internal API definition file in the repository and verify that only internal API endpoints are documented.

**Acceptance Scenarios**:

1. **Given** the internal API definition file exists in the repository, **When** a developer opens the file, **Then** only internal API endpoints are listed by category
2. **Given** the developer is viewing the internal API definition file, **When** they check the authentication section, **Then** API key header authentication is described
3. **Given** both internal and external API definition files exist, **When** comparing the endpoint lists, **Then** internal API endpoints do not appear in the external API definition and vice versa

---

### User Story 3 - Synchronization with Source Code (Priority: P3)

When developers add or modify API endpoints, the OpenAPI definition files are automatically updated in sync with the source code. No manual maintenance of definition files is required, and they always reflect the latest state.

**Why this priority**: If definition files drift from the source code, they lose reliability as documentation, making an auto-sync mechanism critical.

**Independent Test**: Add a test endpoint and run the definition file generation command to verify the new endpoint is reflected.

**Acceptance Scenarios**:

1. **Given** a new API endpoint has been added, **When** the definition file generation command is executed, **Then** the new endpoint is reflected in the definition file
2. **Given** a generated definition file exists, **When** validated with an OpenAPI validation tool, **Then** zero validation errors are reported

---

### Edge Cases

- If there is a discrepancy between the actual API response format and the definition file, the actual API response is treated as the source of truth and the definition file is updated accordingly
- If a new API version is added, the definition file structure supports version-based separation
- If endpoint coverage gaps occur during generation, tests verify completeness across all endpoints

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST document all external API endpoints (under `/api/v1/`) in OpenAPI specification format
- **FR-002**: The system MUST document all internal API endpoints (under `/internal/`) in OpenAPI specification format
- **FR-003**: External API and internal API definition files MUST be provided as completely separate files
- **FR-004**: Each endpoint MUST include type definitions for request parameters, request body, and response body
- **FR-005**: Each endpoint MUST document success and error response status codes with their formats
- **FR-006**: The external API definition file MUST describe the JWT Bearer Token authentication scheme
- **FR-007**: The internal API definition file MUST describe the API key header authentication scheme
- **FR-008**: OpenAPI definition files MUST be placed in the repository and version-controlled
- **FR-009**: OpenAPI definitions MUST be automatically generated and updated in sync with source code
- **FR-010**: Generated definition files MUST conform to OpenAPI specification version 3.0 or higher

### Key Entities

- **External API Definition File**: Full endpoint definitions for the external API. Includes categories: auth, matchmaking, profile, game types, rooms, announcements, and health check
- **Internal API Definition File**: Full endpoint definitions for the internal API. Includes categories: auth verification and room management callbacks

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of all external API endpoints (currently 11 endpoints) are documented in the OpenAPI definition file
- **SC-002**: 100% of all internal API endpoints (currently 5 endpoints) are documented in the OpenAPI definition file
- **SC-003**: Generated OpenAPI definition files pass validation with zero errors using an OpenAPI validation tool
- **SC-004**: Time for developers to review API specs and start using a new endpoint is reduced by 50% or more compared to reading source code directly
- **SC-005**: When a new endpoint is added, running the generation command automatically updates the definition files

## Assumptions

- Admin UI (under `/admin/`) serves HTML pages for browsers and is out of scope for this OpenAPI effort
- OpenAPI specification version 3.0 or higher will be adopted
- Definition files are reviewed via repository file browsing or OpenAPI preview extensions in VSCode/similar IDEs (no dedicated browser UI is provided)
- Existing API response formats (already defined via Alba serializers) are reflected as-is in the OpenAPI definitions
- Definition files are auto-generated from the api-server codebase (no manually maintained YAML/JSON files)

## Out of Scope

- API documentation for Admin UI (`/admin/`)
- Interactive browser-based API documentation UI (Swagger UI, etc.)
- Automatic client SDK generation (scope ends at providing definition files)
- CI/CD pipeline integration for API spec validation automation
- Changes to API versioning strategy
