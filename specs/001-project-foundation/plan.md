# Enterprise Knowledge Assistant MVP Implementation Plan

**Document ID:** EKA-PLAN-001
**Version / status:** 0.1 / Draft for review
**Prepared date:** 2026-10-10
**Target release:** MVP v1
**Specification:** [spec.md](./spec.md)

> This plan describes a proposed implementation approach for the MVP specification. It does not claim that planned components are implemented or approve unresolved product or architecture decisions.

## 1. Purpose and Scope

Plan the cross-repository implementation of the end-to-end MVP: local development foundation, secure document ingestion, authorization-scoped semantic retrieval, evidence-grounded answers with citations, and verification. Implementation tasks will be recorded separately in `tasks.md`.

The specification and approved decisions define behavior. This plan uses the architecture document and implementation backlog for technical context and sequencing. If a plan detail conflicts with an approved decision or the specification, the approved source takes precedence.

## 2. Repositories and Inspected Starting State

| Repository | Planned responsibility | Inspected state relevant to this plan |
|---|---|---|
| Specification | Requirements, decisions, architecture, plans, tasks, and status. | Holds the source documents and this plan. |
| Backend | Spring Boot API, authentication/authorization, persistence, ingestion, retrieval, and RAG orchestration. | Contains a Java 21 Gradle starter and `application.properties`; no API, security, persistence, migrations, or Compose setup was found. `build.gradle` currently uses Spring Boot 4.1.1 and Spring AI 2.0.1 with Anthropic, Ollama, OpenAI, pgvector, and Pinecone starters. |
| Frontend | React/TypeScript UI, authentication integration, API client, document flows, assistant, and citations. | Contains a Vite/React application shell with placeholder assistant and document pages; product functionality is not yet implemented. |

The application repositories are separate. Keep specification changes here and implement application behavior in the corresponding repository. Confirm the owner/location of any cross-repository Compose setup before adding it.

## 3. Architecture Approach

Run the React client, Spring Boot API, and PostgreSQL/pgvector as separate local services. The API is the trust boundary and coordinates identity, permissions, ingestion jobs, authorized retrieval, and answer generation. PostgreSQL stores application metadata, access scope, job/audit state, extracted text/chunks, and vectors. Ollama and OpenAI are independently configurable for chat and embeddings; local defaults to Ollama/Ollama and deployed to OpenAI/OpenAI. Provider credentials and database credentials come from environment-specific secret configuration, not source control.

### Backend responsibilities

- **API and application services:** validate requests and coordinate document operations, queries, deletion, and retries.
- **Security:** authenticate requests, resolve the principal and server-side grants, and enforce operation and collection/document authorization.
- **Persistence:** use versioned schema migrations for relational metadata and job state; use pgvector for semantic search with application-owned identifiers and source metadata.
- **Ingestion:** validate and temporarily handle uploads, extract supported formats, chunk with source metadata, create embeddings, persist vectors, and update durable status.
- **Retrieval and answer orchestration:** combine server-derived access filters with caller-selected filters in the retrieval query; bound top-K and context; enforce the evidence policy; return validated citations or insufficient evidence.
- **Operations:** use bounded retries/timeouts, safe errors, correlation IDs, health checks, audit events, and redacted structured diagnostics.

Keep transport, use-case/domain logic, provider integration, and persistence separable and testable. Spring AI advisors may assist RAG orchestration but must not be the only authorization enforcement point.

### Frontend responsibilities

- Provide authentication/sign-in integration consistent with the selected local or deployed mode.
- Provide assistant, answer, citation-detail, document-library, upload, and ingestion-status experiences.
- Send queries and user-selected filters to the API; never make client-side identity or filtering a security control.
- Present loading, empty, insufficient-evidence, validation, authorization, provider, and service-error states distinctly.
- Render model output and document excerpts safely and keep core flows keyboard-operable.

### Local PostgreSQL and pgvector setup

1. Provide a local PostgreSQL service with pgvector enabled through a reproducible Docker Compose configuration.
2. Add a readiness/health check that verifies PostgreSQL can accept connections before dependent backend startup.
3. Configure a local database, application user, and connection settings through environment variables. Commit only non-secret examples/placeholders; do not commit live passwords.
4. Apply versioned database migrations to create required extensions, application tables, constraints/indexes, and vector-store schema. Fail visibly if required migration or extension setup fails.
5. Keep application-owned `document_id` and `chunk_id` linked to vector records. Apply authorization and metadata filters within the database/vector retrieval path before passage text reaches prompt construction.
6. Verify migrations and vector operations against a real local PostgreSQL/pgvector instance, including empty database startup and repeatable startup.

Do not select a PostgreSQL/pgvector image tag, database name, schema ownership model, or exact Compose file location in this plan without checking compatibility and agreeing the shared-repository ownership.

## 4. Data and Lifecycle Design

Use PostgreSQL as the source of truth. The logical model includes:

- **Identity and authorization:** identity subject, roles/status, collections, and user/role-to-collection grants. Do not store external-identity passwords.
- **Document:** collection, filename, content type, checksum, metadata/tags/version, creator/timestamps, active index version, and soft-delete/purge timestamps. Original files are not retained.
- **Ingestion job:** document/version, state, attempt count, idempotency key, safe error code/summary, and timestamps.
- **Chunk/vector:** stable chunk and document IDs, ordering, extracted text, embedding and model/version/dimension metadata, plus available page/section/source offsets.
- **Audit event:** actor, action, resource, outcome, timestamp, and correlation ID without raw credentials or document bodies.

Persist job progress around external extraction/model calls; do not assume one transaction spans PostgreSQL and an AI provider. Make stages retry-safe. Mark an index version searchable only after required writes succeed. Re-index by preparing a replacement index version and activating it without duplicate active chunks. Soft-delete content from listings, retrieval, and citations immediately, and purge derived records after seven days with an audited, retryable purge job.

Embedding dimensions differ by provider. Use an index/schema arrangement that prevents incompatible dimensions from being mixed; changing embedding provider/model requires re-indexing in the corresponding environment.

## 5. API and Integration Boundaries

Use versioned `/api/v1` REST endpoints. Final request/response schemas, pagination bounds, rate limits, and detailed error envelopes must be established and verified before dependent UI implementation.

| Endpoint | Responsibility |
|---|---|
| `POST /api/v1/documents` | Authorize and validate upload, detect duplicates, create document/job, return `202 Accepted` and status reference. |
| `GET /api/v1/documents` | List only permitted document metadata with bounded pagination and supported filters. |
| `GET /api/v1/documents/{id}` | Return permitted metadata and ingestion status. |
| `POST /api/v1/documents/{id}/reindex` | Request authorized, idempotent re-indexing. |
| `DELETE /api/v1/documents/{id}` | Authorize deletion, immediately exclude content, and schedule/persist purge lifecycle. |
| `POST /api/v1/chat/query` | Validate question and filters, retrieve authorized context, apply evidence policy, and return answer or insufficient evidence with validated citations and correlation ID. |
| `GET /actuator/health` | Expose deliberately safe health information; restrict detailed component status as appropriate. |

Do not implement feedback or conversation-history endpoints for MVP; they are deferred by DEC-008. Map backend response and error contracts into typed frontend API operations. Cited source details must be authorized by the backend and resolved from trusted stored metadata, not accepted from model-generated identifiers.

## 6. Configuration and Local Development

### Backend configuration

Externalize and validate database URL/credentials, active Spring profile, identity/issuer settings, chat and embedding provider/model/endpoints/credentials, embedding dimensions, upload limits, chunking and retrieval values, worker concurrency, timeouts/retry limits, and logging/metrics settings.

- **Local profile:** local development authentication and Ollama for chat and embeddings by default; either capability may select OpenAI through configuration. Local PostgreSQL/pgvector.
- **Deployed profile:** OIDC token validation and OpenAI chat/embedding configuration by default.
- Keep local authentication disabled outside the `local` profile. Fail startup clearly when required configuration is missing; never silently use credentials or settings intended for local development.
- Use the approved initial configuration values in DEC-007 as configurable defaults; evaluate and tune the evidence threshold per provider.

### Frontend configuration

Use the existing frontend environment configuration to set the API base URL for local development. Do not place provider or database secrets in frontend environment variables; browser-exposed variables are not secret storage.

### Local startup

Document a reproducible order to start PostgreSQL/pgvector, verify readiness and migrations, start the backend with its local profile and selected AI providers, and run the frontend against the backend. Document required local environment variables using placeholders, health checks, test commands, and common startup/provider/database failures. Do not report the whole stack as running merely because an individual service starts.

## 7. Implementation Phases

Phases are ordered by dependency; they are planning stages, not completion claims or a replacement for task-level dependencies.

1. **Resolve technical baseline:** settle Spring Boot/Spring AI compatibility, provider starter set, migration technology, PostgreSQL/pgvector versions, and Compose ownership. Preserve DEC-001–DEC-008.
2. **Establish persistence and local environment:** configure compatible dependencies and profiles; provide PostgreSQL/pgvector startup, readiness, migrations, schema, and vector-store connectivity.
3. **Establish API and security foundation:** agree API/error contracts; implement identity modes, server-side authorization, collection scope, and safe correlation/error handling.
4. **Implement document ingestion:** upload validation and duplicate detection; extraction, stable chunking, embeddings, persisted jobs, recovery, status, retry, re-index, deletion, and purge.
5. **Implement retrieval and answer API:** authorization-scoped semantic retrieval, metadata filtering, configurable evidence policy/context, grounded answers, insufficient-evidence behavior, and citation validation.
6. **Implement frontend flows:** authentication integration, API client, upload/document library/status, assistant, answer/citation display, and accessible error/loading states.
7. **Verify end-to-end and release readiness:** security and isolation tests, provider/database failure tests, evaluation runs, local setup verification, observability checks, and documentation.

Hybrid retrieval, reranking, answer feedback, conversation history, and Kafka remain outside these phases unless their approved scope changes.

## 8. Security and Privacy Design

- Authenticate protected API calls and authorize every document operation and citation against server-side principal/collection grants.
- Construct mandatory authorization predicates in retrieval before any passage text is returned to the answer pipeline or sent to an AI provider.
- Treat uploaded/retrieved text and model output as untrusted. Test prompt injection as defense in depth; never rely on prompting instead of access control.
- Enforce upload size/type/content checks, safe temporary-file cleanup, bounded parser/provider/database resource use, and safe errors.
- Keep database/model credentials out of source control, browser bundles, logs, and error responses. Do not log full document bodies by default.
- Avoid storing questions/answers in the MVP. Record security-relevant actions without secrets or unnecessary content.
- Protect local-development authentication from use outside the local profile and distinguish safe liveness/readiness output from operator-only details.

## 9. Verification Strategy

Map automated checks and evidence to the acceptance criteria in [spec.md](./spec.md) and detailed source feature criteria.

- **Backend unit tests:** validation, chunking/source metadata, state transitions, retry/idempotency, evidence policy, citation mapping, and configuration validation.
- **Backend integration tests:** migrations and PostgreSQL/pgvector persistence; upload and document lifecycle; authorization-filtered retrieval; API contracts; provider timeout/failure behavior.
- **Security tests:** unauthenticated and unauthorized access, cross-collection/tenant isolation, direct-ID access, tampered filters, citation access, and prompt-injection cases.
- **Frontend tests:** accessible loading/error/empty states, upload and status behavior, query submission, insufficient evidence, and citation rendering.
- **End-to-end tests:** upload supported content, wait for indexed status, ask an answerable and an unanswerable question, validate citations, and verify deletion removes content from retrieval.
- **Evaluation:** use a versioned human-labelled question/chunk set; record Recall@5 and MRR, citation validity, human-reviewed groundedness/usefulness, retrieval and end-to-end latency separately, and provider usage/cost where available.
- **Operational checks:** local Compose startup, health/readiness, migrations on a clean database, safe logs/correlation IDs, and documented recovery from database or provider failure.

Do not treat the proposed answer-quality, citation, or latency values in the source documents as approved release gates until the evaluation method and target are reviewed.

## 10. Dependencies, Risks, and Open Decisions

| Item | Impact / handling |
|---|---|
| Spring Boot version mismatch | The intended stack in README describes Spring Boot 3.x, while the existing backend build uses 4.1.1. Confirm the supported version and Spring AI compatibility before modifying dependencies or writing version-specific setup instructions. |
| Provider/model and vector dimensions | DEC-002 supports independent Ollama/OpenAI provider selection for chat and embeddings; exact models remain configurable. Choose compatible embedding dimensions and keep indexes isolated; re-index when changing embedding model/provider. |
| Local PostgreSQL/pgvector image and Compose ownership | Choose compatible versions and identify the repository owning shared local orchestration before adding configuration. |
| Identity provider and local users | OIDC product remains open. Keep local mode isolated and test backend authorization independently of UI behavior. |
| API contracts and error policy | Final schemas, pagination, quotas, idempotency details, and resource disclosure behavior need technical design before UI/backend integration. |
| Original-file retention | Original files are not stored. Verify that derived extracted text/chunks and temporary files comply with DEC-005 and cleanup behavior. |
| Evaluation target methodology | Targets are proposed; establish baseline dataset and hardware before adopting quality or latency thresholds. |

## 10a. Technical Baseline Decisions (T01)

Recorded 2026-10-11. All rows below are approved by the project owner (models, PostgreSQL version and API limits approved 2026-10-11).

| Topic | Status | Baseline |
|---|---|---|
| Spring Boot / Spring AI | Decided | Keep Spring Boot 4.1.1 and Spring AI 2.0.1 with Java 21 (the README's "3.x" is outdated). |
| Compose ownership | Decided | Backend repository owns `compose.yaml`; it runs PostgreSQL/pgvector only. |
| Migrations | Decided | Flyway, versioned SQL in `src/main/resources/db/migration`. |
| PostgreSQL / pgvector | Decided | `pgvector/pgvector:pg17`; default host port 5433 to avoid clashing with a local PostgreSQL. |
| Vector tables | Decided | Isolated embedding indexes: `vector_store_ollama` (768) and `vector_store_openai` (1536); entry id equals `document_chunks.id`. |
| Local models | Decided | Ollama `llama3.1:8b` chat, `nomic-embed-text` embeddings. |
| Deployed models | Decided | OpenAI `gpt-4o-mini` chat, `text-embedding-3-small` embeddings. |
| Identity provider | Decided | Keycloak (OIDC) for deployed mode; local-profile authentication for development (T04). |
| Disclosure policy | Decided | Inaccessible documents return 404. |
| Admin scope | Decided | Admin user/role/settings UIs are deferred; server-side authorization is still required. |
| SRS AT-09 | Decided | Deferred for MVP (conflicts with DEC-008). |
| Rate limits / pagination | Decided | Deferred to API design (T05). |
| Quality and latency targets | Decided | 80% / 95% and p95 1.5s remain provisional. |
| API limits | Decided | List page size default 20, max 100; chat question max 2000 characters. |
| Keycloak user provisioning | Decided | First login creates the user row as `MEMBER` with no grants; an admin grants access in the database. |
| Collection/user bootstrap | Decided | A bootstrap task (T20) creates collections and grants without an admin UI. |
| OCR | Decided | Deferred; scanned PDFs are rejected with a clear reason code. |
| Hosting | Decided | Environment-specific; out of MVP scope. |

## 11. Plan Exit Criteria

This plan is ready to guide task creation when:

- Material open decisions that block dependency, database, identity, or API work are resolved or explicitly recorded as non-blocking.
- The technical design is consistent with the specification and approved decisions.
- Each phase can be broken into tasks with repository ownership, dependencies, acceptance evidence, and relevant automated tests.
- PostgreSQL/pgvector local setup, security enforcement points, and cross-repository API boundaries are clear enough to implement without inventing product behavior.
