# Enterprise Knowledge Assistant MVP Tasks

**Document ID:** EKA-TASKS-001
**Version / status:** 0.1 / Draft for review
**Prepared date:** 2026-10-10
**Target release:** MVP v1
**Specification:** [spec.md](./spec.md)
**Implementation plan:** [plan.md](./plan.md)

> T01–T17 and T20 are done (2026-10-11). T18 and T19 are blocked; their implementation and verification evidence, along with the outstanding blockers, are recorded below. Target paths describe likely areas based on the repositories inspected; confirm exact file locations and conventions before implementation. Do not mark a task complete until its implementation, tests, and acceptance evidence are verified.

## Status and Task Rules

- **Not started:** no implementation work has begun.
- **In progress:** implementation is underway.
- **Blocked:** a listed decision or dependency prevents safe progress; record the reason.
- **Done:** implementation, required tests, and acceptance evidence are complete.
- Complete dependencies before starting a task. Tasks with no dependency path between them may proceed in parallel.
- Keep behavior aligned with [spec.md](./spec.md) and approved decisions DEC-001–DEC-008. Raise conflicts rather than silently choosing a resolution.

## Dependency-Ordered Task Summary

| ID | Task | Repository | Depends on | Specification trace | Status |
|---|---|---|---|---|---|
| T01 | Resolve technical baseline and repository ownership | Specification | — | Plan §2, §6, §10 | Done |
| T02 | Align backend dependencies and externalized configuration | Backend | T01 | FR-08, AC-12 | Done |
| T03 | Establish local PostgreSQL/pgvector and migrations | Backend / Platform | T01, T02 | FR-03, FR-06, AC-05, AC-09 | Done |
| T04 | Implement authentication, authorization, and safe API foundations | Backend | T02, T03 | FR-01, AC-01 | Done |
| T05 | Define and verify API contracts | Specification / Backend / Frontend | T01, T04 | FR-02–FR-07, AC-02–AC-12 | Done |
| T06 | Implement supported document extraction | Backend | T02 | FR-03, AC-05 | Done |
| T07 | Implement stable chunking and source metadata | Backend | T03, T06 | FR-03, AC-05 | Done |
| T08 | Implement embedding and pgvector persistence | Backend | T02, T03, T07 | FR-03, FR-06, AC-05, AC-09 | Done |
| T09 | Implement upload API, validation, and duplicate detection | Backend | T03–T05 | FR-02, AC-02–AC-04 | Done |
| T10 | Implement durable ingestion processing and recovery | Backend | T06–T09 | FR-03, FR-04, AC-05, AC-06 | Done |
| T11 | Implement document status, retry, re-index, deletion, and purge APIs | Backend | T04, T05, T10 | FR-04, FR-05, AC-06–AC-07 | Done |
| T12 | Build frontend foundation and typed API integration | Frontend | T05 | FR-01–FR-07, AC-14 | Done |
| T13 | Build upload and document-management UI | Frontend | T11, T12 | FR-02, FR-04, FR-05, AC-02–AC-07, AC-14 | Done |
| T14 | Implement authorization-scoped semantic retrieval | Backend | T03–T05, T08, T10 | FR-06, AC-08–AC-09 | Done |
| T15 | Implement evidence policy and grounded answer orchestration | Backend | T02, T14 | FR-07, AC-10–AC-11 | Done |
| T16 | Implement chat API and validated citations | Backend | T04, T05, T14, T15 | FR-06–FR-07, AC-08–AC-12 | Done |
| T17 | Build assistant, answer, and citation UI | Frontend | T12, T16 | FR-06–FR-07, AC-08–AC-11, AC-14 | Done |
| T18 | Add cross-cutting security, evaluation, and end-to-end coverage | Backend / Frontend / QA | T09–T17 | AC-01–AC-14 | Blocked |
| T19 | Document and verify local setup and release readiness | Specification / Backend / Frontend | T02–T18 | FR-08, AC-12–AC-14 | Blocked |
| T20 | Bootstrap collections, users and grants; OIDC user provisioning | Backend | T04 | FR-01, FR-02, AC-01 | Done |

## Task Details

### T01 — Resolve technical baseline and repository ownership

- **Repository:** Specification
- **Depends on:** None
- **Target areas:** `docs/implementation/product-decisions.md`, `docs/Enterprise_Knowledge_Assistant_Architecture_v1.md`, `specs/001-project-foundation/plan.md`
- **Work:**
  - Confirm Spring Boot and Spring AI versions that are compatible with Java 21 and the selected starters. The intended stack says Spring Boot 3.x; the inspected backend currently uses 4.1.1.
  - Confirm supported PostgreSQL and pgvector versions, migration approach, and vector table strategy for distinct embedding dimensions.
  - Confirm which repository owns local Compose orchestration and whether it runs PostgreSQL alone or the application services too.
  - Identify unresolved API, identity-provider, and model-name choices that block implementation. Record proposed choices as proposals and obtain human approval where required; do not change approved decisions without authorization.
- **Completion criteria:** Blocking technical choices and repository ownership are recorded with status and rationale; conflicts are resolved or explicitly marked as blockers.
- **Verification:** Review the decision/architecture record with the relevant repository owners; no implementation assumptions remain hidden.
- **Status:** Done — baseline recorded in [plan.md](./plan.md) §10a. Proposed (not yet approved) items: PostgreSQL 17 image, per-provider vector tables, Ollama and OpenAI model names. `product-decisions.md` was not changed; approval is required to promote them.

### T02 — Align backend dependencies and externalized configuration

- **Repository:** Backend
- **Depends on:** T01
- **Target areas:** `build.gradle`, `src/main/resources/application.properties`, profile-specific configuration, configuration classes and tests
- **Work:**
  - Align Spring Boot, Spring AI, Java 21, PostgreSQL driver, migration, security, and test dependencies to the approved compatible baseline.
  - Retain only the approved local/deployed chat and embedding providers and PostgreSQL/pgvector integration; remove unused providers/vector stores as authorized by the approved baseline.
  - Add validated external configuration for database connectivity, profiles, provider/model settings, dimensions, upload limits, chunking, retrieval, worker concurrency, timeouts, and retries.
  - Configure local Ollama/local authentication and deployed OpenAI/OIDC profiles without committing secrets.
- **Completion criteria:** The backend resolves/builds using the approved dependency set; configuration is externalized, validated, and has safe placeholder examples only.
- **Tests:** Dependency/build check; configuration binding and validation tests, including clear failure for missing required deployed settings and local-profile startup configuration.
- **Status:** Done — backend `build.gradle` trimmed to Ollama, OpenAI, pgvector, Flyway, PostgreSQL, validation, actuator (Anthropic and Pinecone removed); validated `EkaProperties`, `local` and `deployed` profiles, `.env.example`. `EkaPropertiesTest` passes and `./gradlew test` succeeds.

### T03 — Establish local PostgreSQL/pgvector and migrations

- **Repository:** Backend / Platform (Compose owner confirmed in T01)
- **Depends on:** T01, T02
- **Target areas:** Confirmed Compose file location, migration resources, database configuration, persistence integration tests
- **Work:**
  - Add a reproducible local PostgreSQL service with the approved pgvector image/version and readiness health check.
  - Configure a local database and least-privilege application user using environment variables or ignored local configuration.
  - Add versioned migrations for the vector extension, application tables, constraints, indexes, and required vector-store schema.
  - Ensure application chunk/document IDs link vector entries to trusted application metadata and access scope.
- **Completion criteria:** A clean local database starts, reports ready, and migrations create the expected schema; restarting does not duplicate or corrupt schema state.
- **Tests:** Migration tests against PostgreSQL; integration test for pgvector extension availability, vector insert/search, and stable metadata linkage. No production credentials in tracked files.
- **Status:** Done — backend `compose.yaml` (pgvector pg17, healthcheck), Flyway V1–V3 (extensions, core schema, per-provider vector tables). `MigrationIntegrationTest` (Testcontainers) passes; manual run confirmed health UP, migrations applied once and `Schema is up to date` on restart. Limitation: the local app user owns the database for simplicity; a separate least-privilege runtime role is not yet created.

### T04 — Implement authentication, authorization, and safe API foundations

- **Repository:** Backend
- **Depends on:** T02, T03
- **Target areas:** Security configuration, identity/permission persistence, API error handling, correlation filter/interceptor, security tests
- **Work:**
  - Implement local development authentication restricted to the `local` profile and OIDC resource-server authentication for deployed configuration.
  - Resolve roles and collection grants from server-side identity/permission data.
  - Add reusable authorization checks for document management, retrieval, and citation resolution.
  - Add safe, consistent error responses and request correlation IDs without disclosing protected resource content.
- **Completion criteria:** Protected endpoints require authentication; permissions are resolved and checked server-side; local auth cannot be enabled accidentally in deployed configuration.
- **Tests:** Unauthenticated requests return 401; unauthorized operations are denied without content leakage; local profile isolation and correlation/error behavior are covered.
- **Status:** Done — Spring Security: HTTP Basic restricted to the `local` profile, OIDC resource server otherwise; `ProfileGuard` blocks `local`+`deployed` together. Roles/grants in Flyway V4 (`app_users`, `collection_grants`) resolved by `AccessService` (read, manage, readable collections, citation document check; denials return 404). Error envelope, `X-Correlation-Id` filter, `GET /api/v1/me`. 16 tests cover 401, denial without leakage, local isolation and correlation. Limitation: OIDC subject-to-user provisioning and a Keycloak realm are not yet set up, so the deployed path is verified only for rejecting unauthenticated requests; no real token flow was tested.

### T05 — Define and verify API contracts

- **Repository:** Specification / Backend / Frontend
- **Depends on:** T01, T04
- **Target areas:** Architecture/API documentation, backend request/response DTOs and API tests, frontend `src/api/types.ts` and `src/api/client.ts`
- **Work:**
  - Finalize request/response and error contracts for upload, document list/detail, re-index, delete, and chat query.
  - Define supported filters, pagination bounds, status values, safe authorization disclosure behavior, citation fields, and correlation/timing fields.
  - Keep optional feedback and conversation-history APIs out of MVP (DEC-008).
  - Document the contract in the canonical location and align backend and frontend types.
- **Completion criteria:** Each required endpoint has a documented contract and matching client/server types; open decisions are explicit and approved as needed.
- **Tests:** Contract/API tests cover valid requests, validation failures, status/error mapping, and authorization outcomes.
- **Status:** Done — contract in [api-contract.md](./api-contract.md); backend DTOs in `org.enterpriseknowledgeassitance.api` and frontend `src/api/types.ts` and `client.ts` aligned. `ApiContractTest` (validation, paging bounds, 400 mapping, auth) and `client.test.ts` pass, plus frontend typecheck, lint and build. Limitation: upload/list/detail/reindex/delete/chat endpoints are not implemented yet (T09, T11, T16), so the contract is not yet verified end to end. Values for paging (20/100), question length (2000) and metadata limits are proposed and awaiting approval.

### T06 — Implement supported document extraction

- **Repository:** Backend
- **Depends on:** T02
- **Target areas:** Extraction service/adapters, parser dependencies, unit and integration test fixtures
- **Work:**
  - Extract text from PDF, DOCX, TXT, and Markdown and preserve available page, section, and source-offset metadata.
  - Reject corrupt, empty, unsupported, and resource-exhausting content safely.
  - Keep temporary upload content out of permanent original-file storage and clean it after processing on both success and failure.
- **Completion criteria:** Each supported format yields non-empty searchable text and available metadata, or a safe recorded processing failure.
- **Tests:** Format corpus integration tests; corrupt/empty/unsupported input tests; temporary-file cleanup tests.
- **Status:** Done — PDF (PDFBox, per-page metadata), DOCX (POI, heading sections), TXT and Markdown (heading sections, offsets) in `ExtractionService`. Rejects unsupported, empty, corrupt, mislabelled, encrypted and over-limit content with safe reason codes; temp files are deleted on success and failure; limits via `eka.extraction.*`. 10 tests pass using generated fixtures. Limitations: no OCR (scanned PDFs are rejected as empty), DOCX tables/headers are not extracted, and fixtures are synthetic rather than real-world documents.

### T07 — Implement stable chunking and source metadata

- **Repository:** Backend
- **Depends on:** T03, T06
- **Target areas:** Chunking service, chunk persistence model/migration, unit tests
- **Work:**
  - Implement configurable chunk size and overlap using approved DEC-007 defaults.
  - Generate stable chunk identifiers and preserve document identity, order, and available source locations.
  - Avoid empty chunks and ensure the configured settings are externally changeable.
- **Completion criteria:** Chunks are non-empty, repeatable for identical input/configuration, and traceable to source document metadata.
- **Tests:** Unit tests for boundaries, overlap, short/empty text, source metadata, and stable identifiers.
- **Status:** Done — `Chunker` (word-token windows, configurable size/overlap validated, deterministic chunk ids, page/section/start offset metadata). `ChunkerTest` (8) passes. Limitation: a token is a whitespace-delimited word, an approximation of model tokens.

### T08 — Implement embedding and pgvector persistence

- **Repository:** Backend
- **Depends on:** T02, T03, T07
- **Target areas:** Spring AI embedding/vector-store configuration, persistence adapters, index/version metadata, integration tests
- **Work:**
  - Generate chunk embeddings via the active profile's approved provider.
  - Persist vectors with stable document/chunk linkage and model/version/dimension metadata.
  - Prevent incompatible embedding dimensions or model profiles from sharing an index; support re-indexing after configuration changes.
  - Bound provider batch sizes and surface failures to the ingestion job.
- **Completion criteria:** Successful chunks can be written and searched in pgvector with source metadata; provider/model configuration is externalized.
- **Tests:** Integration tests for vector persistence/search, metadata filters, dimension/profile isolation, and provider failure handling.
- **Status:** Done — `ChunkIndexer` embeds in batches with finite/dimension checks, replaces a document's chunks transactionally, stores vectors in `vector_store_ollama|openai` (FK cascade to `document_chunks`), and searches scoped to collections with version/type/tag filters, threshold, soft-delete exclusion and model match. Uses own JDBC rather than the Spring AI `VectorStore` bean. Integration test with Testcontainers and a fake embedding model passes. Limitation: provider timeouts/retries are not enforced yet (T10).

### T09 — Implement upload API, validation, and duplicate detection

- **Repository:** Backend
- **Depends on:** T03–T05
- **Target areas:** Document upload endpoint/application service, persistence, upload tests
- **Work:**
  - Enforce caller authentication and collection create permission before accepting the upload.
  - Validate 10 MB limit, extension and actual content, supported format, empty/corrupt files, and safe temporary handling.
  - Calculate checksum and reject a duplicate non-deleted document in the same collection with `409 Conflict`.
  - Persist document and ingestion-job records and return `202 Accepted` with identifier and status reference only after valid acceptance.
- **Completion criteria:** Valid uploads create a document/job; rejected files and duplicates do not create searchable or duplicate records.
- **Tests:** Supported file acceptance; exactly-at-limit and over-limit cases; spoofed extension/content; authorization; duplicate and soft-deleted duplicate cases; safe errors.
- **Status:** Done — `POST /api/v1/documents` (multipart, 202 QUEUED + status URL), manage-permission check (404 otherwise), size/type/content-signature/empty/corrupt validation, SHA-256 duplicate detection (409, soft-deleted allowed), metadata validation, file-name sanitising. Design deviation: extraction runs synchronously at upload and text is staged in `document_extraction_segments` (migration V5), so no original file is stored (DEC-005); T10 only chunks/embeds/indexes from staged segments. `DocumentUploadIntegrationTest` (PDF/DOCX/TXT/MD, exact 10 MB, over-limit, spoofed, empty, corrupt, auth, duplicates, validation) passes; full suite 61 tests green. Limitations: OCR deferred (scanned PDFs rejected as empty); DOCX tables not extracted; 413 from container-level multipart limits untested in a real servlet container.

### T10 — Implement durable ingestion processing and recovery

- **Repository:** Backend
- **Depends on:** T06–T09
- **Target areas:** Ingestion worker/executor, durable job repository, document/job state model, recovery and integration tests
- **Work:**
  - Process persisted jobs through extraction, chunking, embedding, vector persistence, and index activation using the approved bounded worker.
  - Persist state transitions and safe error summaries; implement bounded transient retries and startup reconciliation for queued/stale jobs.
  - Make processing idempotent and mark documents searchable only after required writes complete.
- **Completion criteria:** Jobs survive process restart/recovery; success and terminal failure are visible; retries do not create duplicate active chunks.
- **Tests:** State-transition tests, restart/recovery integration, retry/idempotency tests, provider outage/timeout tests.
- **Status:** Done — `IngestionService` (claim with `FOR UPDATE SKIP LOCKED`, chunk/embed/index from staged segments, state transitions persisted on job and document) and `IngestionWorker` (scheduled poller, bounded by `eka.ingestion.concurrency`). Transient provider failures retry with backoff (`available_at`, migration V6) up to `eka.ingestion.max-retries`; dimension mismatch and empty content fail immediately; failure reasons are stable codes only. Provider calls are bounded by `eka.ingestion.provider-timeout` (`EMBEDDING_TIMEOUT`). RUNNING jobs not updated for `eka.ingestion.stale-after` (default 15m) are re-queued or failed (restart recovery). Documents become INDEXED only after the atomic chunk+vector replacement, so retries leave no duplicate chunks. `IngestionServiceIntegrationTest` (9) and `IngestionWorkerIntegrationTest` pass. Limitation: recovery relies on the stale threshold, so after a crash a job resumes only after that interval; no heartbeat for jobs longer than it.

### T11 — Implement document status, retry, re-index, deletion, and purge APIs

- **Repository:** Backend
- **Depends on:** T04, T05, T10
- **Target areas:** Document management endpoints/services, lifecycle persistence, scheduled purge, audit, integration tests
- **Work:**
  - Provide authorized document list/detail and status endpoints.
  - Add authorized idempotent retry/re-index operations and ensure replacement index activation does not leave duplicate active chunks.
  - Implement immediate soft-delete exclusion from listing, retrieval, and citations; persist the seven-day purge deadline and purge/audit outcomes.
- **Completion criteria:** Only permitted metadata is returned; retry/re-index are safe; deleted content is immediately inaccessible and permanently purged after retention.
- **Tests:** Permission and direct-ID access tests; state/status API tests; retry/re-index; deletion exclusion; purge timing and retry/audit tests.
- **Status:** Done — `GET /api/v1/documents` (permitted only, filters, bounded paging), `GET /{id}`, `POST /{id}/reindex` (manage permission, idempotent while queued/processing, FAILED documents retried this way, old chunks stay searchable until the atomic replacement), `DELETE /{id}` (manage permission, immediate exclusion from list/detail/search, pending jobs cancelled, `purge_after` persisted = deletion + `eka.retention.purge-after-days`). `PurgeService` (scheduled, batched) deletes the row and cascades to jobs, staged text, chunks and vectors; every reindex/delete/purge is recorded in content-free `document_audit`; failed purges are audited and retried next run. `DocumentManagementIntegrationTest` (12) covers permissions, direct-ID 404s, filters/paging, reindex idempotency, delete exclusion, purge timing and failed-purge retry. Full backend suite: 82 tests green. Limitations: a second DELETE returns 404; admin-triggered retry/purge endpoints and audit read API are not provided.

### T12 — Build frontend foundation and typed API integration

- **Repository:** Frontend
- **Depends on:** T05
- **Target areas:** `src/api/types.ts`, `src/api/client.ts`, `src/auth/`, `src/app/`, UI/API tests
- **Work:**
  - Implement typed client operations and error mapping for approved backend contracts.
  - Connect authentication state to API requests without treating client identity as authorization.
  - Configure API base URL through browser-safe environment configuration; keep secrets out of `VITE_` variables.
  - Establish reusable loading, empty, validation, authorization, provider, and service-error patterns.
- **Completion criteria:** Client/server types agree and API errors are represented as distinct UI states without exposing sensitive payloads.
- **Tests:** Client unit tests for request/response and error mapping; auth/API configuration tests.
- **Status:** Done — `parseConfig` validates `VITE_API_BASE_URL` (http/https, no credentials, trailing slash stripped); `toUiError` maps API errors to distinct safe UI kinds with fixed text and the correlation id; client wraps network failures and signals 401 via `onUnauthorized`; `AuthProvider`/`useAuth` keep credentials in memory only, take identity from `/me`, and end the session on 401 (Basic for the local profile, generic Authorization-header source for OIDC); `useApiQuery`, `LoadingState`, `EmptyState`, and `ErrorState` provide reusable patterns. The frontend now has 44 passing Vitest tests, typecheck and production build pass. Limitation: a real Keycloak/OIDC login flow remains unimplemented; lint reports two React heuristic warnings in `AuthProvider.test.tsx` and `AuthProvider.tsx`.

### T13 — Build upload and document-management UI

- **Repository:** Frontend
- **Depends on:** T11, T12
- **Target areas:** `src/pages/DocumentsPage.tsx`, document feature components, API client, UI tests
- **Work:**
  - Implement authorized collection selection, upload progress, accepted status, safe validation/duplicate feedback, and recovery actions.
  - Display permitted document metadata and queued/processing/indexed/failed status with safe error summaries.
  - Expose retry, re-index, and deletion controls only where allowed by API permissions; refresh status without treating timeout as success.
- **Completion criteria:** Knowledge Manager can complete supported upload and lifecycle flows; users cannot mistake pending/failed work for indexed success.
- **Tests:** Component/E2E tests for upload states, validation, duplicate response, status refresh, retry, and delete behavior.
- **Status:** Done — Implemented readable-collection listing, upload, lifecycle/status refresh, retry/re-index and delete controls, gated by manageable collection grants; safe UI errors and component coverage are in place. Frontend typecheck, 40 Vitest tests, production build, lint, and the browser workflow test passed. Lint retains two pre-existing React heuristic warnings in `AuthProvider.test.tsx` and `AuthProvider.tsx`.

### T14 — Implement authorization-scoped semantic retrieval

- **Repository:** Backend
- **Depends on:** T03–T05, T08, T10
- **Target areas:** Retrieval service, vector query/filter construction, authorization integration tests
- **Work:**
  - Validate non-empty questions and supported filter schema; bound top-K and query size.
  - Derive authorized scope from the authenticated principal and combine it with user filters inside the vector query.
  - Exclude non-indexed, failed, deleting, and deleted content; return no more than configured top-K authorized passages and trusted metadata.
- **Completion criteria:** Retrieval cannot broaden server authorization and filters are applied before passage text is exposed to answer construction.
- **Tests:** Integration/adversarial tests for direct-ID and tampered filters, collection isolation, lifecycle exclusions, fewer-than-top-K results, and empty query short-circuit.
- **Status:** Done — Vector retrieval derives scope from server-side grants, intersects caller filters with authorized collections, applies document lifecycle and metadata filters before returning passages, and skips embedding when no eligible indexed chunks exist. Backend tests passed, including retrieval authorization/lifecycle coverage.

### T15 — Implement evidence policy and grounded answer orchestration

- **Repository:** Backend
- **Depends on:** T02, T14
- **Target areas:** Answer/RAG service, prompt/context construction, model configuration, unit/integration tests
- **Work:**
  - Apply the configured minimum-evidence policy and bounded context budget before calling the model.
  - Do not call the model when evidence is insufficient; return the defined insufficient-evidence result.
  - Instruct the model to answer from authorized evidence only and treat retrieved text as untrusted data.
  - Build citation references from trusted retrieval metadata, not unvalidated model-generated IDs.
- **Completion criteria:** Insufficient evidence does not produce an unsupported model answer; sufficient-evidence output is grounded in retrieved context.
- **Tests:** Evidence threshold/budget unit tests, no-model-call test for insufficient evidence, prompt-injection and citation mapping tests.
- **Status:** Done — Chat orchestration enforces evidence threshold and bounded context, avoids model calls for insufficient evidence, treats retrieved passages as untrusted prompt data, and constructs citations from trusted retrieval metadata. Backend tests passed for evidence policy, prompt containment, citation mapping, and provider timeout behavior.

### T16 — Implement chat API and validated citations

- **Repository:** Backend
- **Depends on:** T04, T05, T14, T15
- **Target areas:** Chat query endpoint/service, response DTOs, citation authorization, API integration tests
- **Work:**
  - Expose the approved query contract with answer/insufficient-evidence status, validated citations, and correlation ID.
  - Bound provider timeout/retries and return safe, distinct errors for validation, authorization, provider, and internal failures.
  - Ensure citation details resolve only through authorized application metadata and do not persist conversations.
- **Completion criteria:** API returns only valid authorized citations or a clear insufficient-evidence result; no secrets, raw prompts, or provider payloads are exposed.
- **Tests:** API integration for answerable/unanswerable queries, unknown/unauthorized citation rejection, provider timeout, safe error envelope, and no conversation persistence.
- **Status:** Done — Added the validated chat endpoint, safe provider errors/timeouts, correlation IDs, trusted authorized citations, and retrieval/end-to-end timing fields; no conversation persistence was added. Backend contract and integration tests passed.

### T17 — Build assistant, answer, and citation UI

- **Repository:** Frontend
- **Depends on:** T12, T16
- **Target areas:** `src/pages/AssistantPage.tsx`, assistant/citation feature components, API types/client, component and E2E tests
- **Work:**
  - Implement question input, supported collection/metadata filters, pending/duplicate-submit prevention, and safe query errors.
  - Render answer and insufficient-evidence states distinctly, with citations resolved by backend-provided trusted metadata.
  - Render content safely as inert text/sanitized formatting; show stale or inaccessible citations as unavailable.
  - Keep controls keyboard-operable and do not imply chat history persists.
- **Completion criteria:** User can ask, review, and verify supported answers and understand insufficient evidence and failure states.
- **Tests:** Component/E2E tests for query flow, filters, answer states, safe citation rendering, unavailable citations, and accessibility.
- **Status:** Done — Added question/filter UI, pending/error and insufficient-evidence states, inert citation rendering, and citation access rechecks. Frontend typecheck, 44 Vitest tests, production build, lint, and the Playwright browser workflow passed. Lint retains two pre-existing React heuristic warnings in `AuthProvider.test.tsx` and `AuthProvider.tsx`.

### T18 — Add cross-cutting security, evaluation, and end-to-end coverage

- **Repository:** Backend / Frontend / QA
- **Depends on:** T09–T17
- **Target areas:** Backend security/integration tests, frontend tests, E2E suite, versioned evaluation dataset and reports
- **Work:**
  - Cover specification acceptance criteria AC-01–AC-14 across unit, integration, security, UI, and E2E tests.
  - Build a versioned labelled question/relevant-chunk dataset and reproducible evaluation runner.
  - Record Recall@5/MRR, citation validity, human-reviewed groundedness/usefulness, latency separated into retrieval and end-to-end, and provider usage/cost when available.
  - Treat proposed thresholds as evaluation targets only until formally approved.
- **Completion criteria:** Each applicable acceptance criterion maps to automated or explicit verification evidence; evaluation output records dataset and configuration/model versions.
- **Tests:** Full relevant backend/frontend test suites, adversarial authorization/prompt tests, and repeatable evaluation run.
- **Status:** Blocked — Automated backend and frontend suites, adversarial authorization/prompt tests, and the Playwright workflow pass; a reproducible evaluation runner records dataset/configuration/model versions, Recall@5, MRR, citation completeness, latency, and optional human-review scores. A representative, access-authorized labelled evaluation dataset and human review data were not supplied, so quality evaluation and its acceptance evidence cannot be produced without inventing results. Backend `./gradlew test`, frontend typecheck/tests/build/lint/E2E, evaluation script syntax, and all three repositories' `git diff --check` passed; lint has the two warnings noted under T13/T17.

### T19 — Document and verify local setup and release readiness

- **Repository:** Specification / Backend / Frontend
- **Depends on:** T02–T18
- **Target areas:** Backend and frontend READMEs, Compose/configuration examples, specification/backlog status, release documentation
- **Work:**
  - Document prerequisites, environment placeholders, PostgreSQL/pgvector readiness and migration behavior, Ollama configuration, backend/frontend startup, health checks, tests, and common failure recovery.
  - Verify startup from a clean local environment and ensure no secrets are required from tracked files.
  - Record remaining limitations, unresolved decisions, evaluation results, and verified task status in canonical project records.
- **Completion criteria:** A developer can reproduce documented local setup; release readiness evidence and unresolved blockers are accurately recorded.
- **Tests:** Follow setup instructions on a clean environment; run required checks; inspect tracked examples and logs for secrets or sensitive content.
- **Status:** Blocked — Backend and frontend setup, model, seed, health-check, test, and recovery instructions were updated. A fresh isolated PostgreSQL 17 verification applied all migrations; the SQL seed was verified idempotent; backend health and `/api/v1/me` were verified. Release-readiness completion depends on T18's unavailable labelled-dataset evaluation and review evidence.

### T20 — Bootstrap collections, users and grants; OIDC user provisioning

- **Repository:** Backend
- **Depends on:** T04
- **Target areas:** Security/identity services, migration or seed script, setup documentation, tests
- **Work:**
  - Provide a documented way to create collections and grant `READ`/`MANAGE` without an admin UI (SQL seed script or admin-only API; choose one and record it).
  - On first OIDC login, create the `app_users` row as `MEMBER` with no grants; admins grant access afterwards.
  - Provide a local-profile seed for the development user.
- **Completion criteria:** A new deployment can create a collection, grant a user access, and upload without manual undocumented steps; new OIDC users get no access by default.
- **Tests:** First-login provisioning creates `MEMBER` with no grants; seeded grants are honored; unprovisioned users see nothing.
- **Status:** Done — Chose and documented the local SQL seed approach. The seed creates the local user/collection/grant and is idempotent; first OIDC login provisions a `MEMBER` with no grants. Provisioning, grant behavior, and no-access behavior are covered by backend tests; full backend tests passed.
