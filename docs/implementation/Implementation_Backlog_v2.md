# EKA Implementation Backlog v2

**Status date:** 2026-11-06

**Purpose:** Consolidate outstanding MVP verification, release-readiness work, and proposed product gaps previously tracked in the root backlog. The [v1 backlog](Implementation_Backlog_v1.md) remains the historical record of the original tasks; the [foundation task register](../../specs/001-project-foundation/tasks.md) and feature task files remain the detailed implementation and verification records.

**Transition:** V2 does not mean that v1 is complete. The owner authorized consolidation while v1 still has unfinished acceptance and release gates. Preserve the existing IDs and statuses below, and carry unfinished v1 work into B04, B06, B09 and the gap items.

## Current summary

The core MVP flows are implemented in the backend and frontend. Desktop/mobile Figma review is complete and the main layout differences were corrected. The project is not yet release-ready: live Keycloak verification and representative evaluation evidence are still blocked, so foundation tasks T18 and T19 remain blocked. The owner has resolved the non-release Ask-page label and collection display decisions (B11–B12).

The B items record completed and outstanding work; the gap analysis contains proposed items as well as a cross-reference. Proposed decisions remain proposals until explicitly approved. Manual checks and evaluation evidence must not be recorded as complete until actually performed.

## V1 implementation reconciliation

The following is a high-level code and documentation inspection on 2026-11-06, not a fresh test run or a criterion-by-criterion certification. "Implemented" describes the presence of the main implementation, not proof that every v1 acceptance criterion is satisfied. Historical test results and limitations are in the [foundation task register](../../specs/001-project-foundation/tasks.md).

| V1 tasks | Implementation evidence | Remaining work or qualification |
|---|---|---|
| EKA-01–03: decisions, configuration and database | Approved decisions, backend configuration, Flyway migrations and pgvector schema exist. | Provider-specific evidence thresholds still need representative evaluation; configuration and deployment choices must not be treated as new approvals. |
| EKA-04–06: security, API and frontend foundation | Backend security and access services, API contracts, frontend authentication, routing and typed client exist. | Live Keycloak verification remains B04; accessibility and complete contract evidence require review. |
| EKA-07–14: upload, extraction, ingestion and document management | Backend upload/extraction, chunking, indexing, worker and lifecycle services, plus the frontend Documents page, exist. | Re-embedding across changed models needs a safe path (P7); end-to-end and accessibility evidence remain incomplete. |
| EKA-15–18: retrieval, answers, citations and assistant UI | Scoped retrieval, chat orchestration, citation handling and the frontend Assistant page exist. Optional CRAG is implemented behind configuration. | Representative retrieval and answer quality remain unverified; adversarial and live end-to-end coverage need further work. |
| EKA-19: end-to-end, security and evaluation | Backend integration tests, a frontend browser test and an evaluation runner exist. | **Incomplete:** the browser test mocks the API; representative labelled data, human review, a reproducible evaluation and complete E2E/security evidence are pending (B06, G9, G10). The runner's retrieval-like scores use returned citations, not raw retrieval candidates. |
| EKA-20: local deployment and release readiness | Compose, Dockerfiles, configuration examples and setup documentation exist. | **Incomplete:** release readiness depends on EKA-19 and the remaining T18/T19 evidence, including a live end-to-end smoke check and Keycloak verification (B04, B09, G10). |

This reconciliation does not supersede approved requirements or decisions. It does not certify every acceptance criterion or authorize the proposed capabilities below.

**Evidence inspected:** [product decisions](product-decisions.md), [feature specifications](../Enterprise_Knowledge_Assistant_Feature_Specifications_v1.md), [API contract](../../specs/001-project-foundation/api-contract.md), backend [security](../../../enterprise-knowledge-assistant-backend/src/main/java/org/enterpriseknowledgeassitance/security/), [document](../../../enterprise-knowledge-assistant-backend/src/main/java/org/enterpriseknowledgeassitance/documents/), [ingestion](../../../enterprise-knowledge-assistant-backend/src/main/java/org/enterpriseknowledgeassitance/ingestion/) and [chat](../../../enterprise-knowledge-assistant-backend/src/main/java/org/enterpriseknowledgeassitance/chat/) code, the [evaluation runner](../../../enterprise-knowledge-assistant-backend/evaluation/evaluate.mjs), and frontend [pages](../../../enterprise-knowledge-assistant-frontend/src/pages/), [authentication](../../../enterprise-knowledge-assistant-frontend/src/auth/) and [browser test](../../../enterprise-knowledge-assistant-frontend/e2e/assistant-and-documents.spec.ts). These application paths refer to sibling repositories when available in the workspace.

## Ordered backlog

| ID | Work item | Owner / repository | Status | Depends on |
|---|---|---|---|---|
| B01 | Reconcile the focused backend CRAG test failure with the current evaluator prompt and behavior; update code or assertion only after checking the CRAG specification. | Backend | Done: assertion now covers current prompt requirements; focused CRAG/chat tests pass | — |
| B02 | Reconcile frontend Documents unit and browser tests with the current page and approved UI requirements. Keep assertions aligned with safe user-facing failure messages; do not expose internal failure codes merely to satisfy tests. | Frontend | Done: 60 unit tests, production build, and 1 Playwright test pass; lint exits 0 with warnings | — |
| B03 | Run focused and full backend/frontend validation after B01–B02; record actual results in the implementation task records. | Backend / Frontend / Specification | Done: backend 125 tests pass; frontend 60 unit tests, build, and 1 Playwright test pass; lint exits 0 with five warnings | B01, B02, B10 |
| B04 | Complete a live Keycloak sign-in check: callback, bearer API request, `/api/v1/me`, first-login provisioning, no-grant behavior, and sign-out. | Backend / Frontend | Blocked: owner says a test realm is available; actual issuer, audience, public client ID, and test-account setup are still needed. The default local `/realms/eka` endpoint returned 404. Configure passwords locally; do not send them in chat. | Test realm configuration |
| B05 | Visually compare Login, Ask, and Documents pages with their approved Figma frames at desktop and mobile sizes; record discrepancies and results. | Frontend / Specification | Done: reviewed desktop/mobile frames; aligned the sign-in split, shared app shell, mobile navigation, source-panel order, and Documents mobile layout. Preserved API role labels and collection IDs per DEC-011. | Figma access and browser |
| B06 | Obtain an access-authorized, representative labelled evaluation dataset and human review; run a versioned evaluation and record retrieval, citation, answer-quality, and latency results. Identify and resolve measurement limitations before treating results as release evidence. | QA / Product / Backend | Blocked: no representative dataset or reviewers are available. The current runner reports citation-based Recall@5/MRR, citation field completeness and mean latencies, not raw-candidate retrieval, full citation validity or latency percentiles. Use the backend evaluation guide; keep confidential JSONL outside source control. | Authorized corpus, labels, human review; suitable measurement method |
| B07 | Resolve the previously identified owner decisions and update their decision/specification records. | Product / Security / Specification | Done for DEC-009, DEC-011, OIDC OI-2/OI-3, and the PDF page limit; later decisions, including B13, remain open | Owner responses |
| B08 | Update the specification repository README’s stale current-status section to point to this backlog and the current task register. | Specification | Done | — |
| B09 | Close T18 and T19 only after required test, evaluation, live/manual verification, and clean-setup evidence is recorded; publish an accurate release-readiness summary. | All | Blocked on B04, B06 and remaining release evidence | B03–B08, G10 and applicable T18/T19 criteria |
| B10 | Resolve the configured PDF page-limit discrepancy (runtime default is 1,000 pages; an integration test expects 500) and align the test and documentation with the approved value. | Product / Backend / Specification | Done: owner retained 1,000-page runtime default; test explicitly configures 500 | Owner response |
| B11 | Decide whether to replace API role labels with the persona names shown in Figma (for example, Knowledge Seeker/Knowledge Manager). | Product / Specification / Frontend | Done: owner chose API-authoritative role labels; recorded in DEC-011 | Owner response |
| B12 | Decide whether collection display names should be added through an API change or whether the UI should continue displaying collection IDs. | Product / Backend / Frontend / Specification | Done: owner chose to retain collection IDs; no API expansion; recorded in DEC-011 | Owner response |
| B13 | Review and approve the draft evaluation pipeline specification ([011](../../specs/011-evaluation-pipeline/spec.md)), including open items OI-1–OI-12; implementation follows only after approval. | Product / Backend / Specification | Pending owner review: spec, plan, tasks, and [developer guide](../Enterprise_Knowledge_Assistant_Evaluation_Guide_v1.md) drafted; no implementation of spec 011 started | Owner decisions; B06 for representative results |

## Gap analysis backlog (2026-11-05)

Source: comparison of the specifications, plan and tasks against the backend, frontend and `infra/` code (evaluation implementation excluded from the original analysis). G10–G13 and P11 were added during the 2026-11-06 reconciliation. Each row states its status: proposed capabilities and implementation approaches are not approved, while verification of existing requirements remains outstanding. Items in group P need an approved specification before implementation. Findings come from code and documentation inspection; no tests were run for these analyses.

### Group G: gaps against existing requirements

| ID | Work item | Requirement trace | Owner / repository | Status | Depends on |
|---|---|---|---|---|---|
| G1 | Extend the audit trail beyond re-index, delete and purge: record uploads, login failures, permission changes, administrative actions and denied access. Keep it content-free. | FR-023 | Backend | Proposed | — |
| G2 | Add metrics (request counts, errors, latency, provider usage) through an actuator/Micrometer registry; keep exposure restricted and redacted. | NFR-007 | Backend / Platform | Proposed | — |
| G3 | Capture AI provider usage (tokens, calls) and add configurable per-request limits for cost control. | NFR-012 | Backend | Proposed | G2 |
| G4 | Add CI for backend and frontend: build, tests, lint and type-check on every change. | Supports NFR-008 and T18 verification | Backend / Frontend | Proposed | — |
| G5 | Live Keycloak sign-in check (same as B04). | FR-001, T18 | Backend / Frontend | Tracked as B04 | B04 |
| G6 | Put `infra/` (Compose, Kubernetes manifests, Caddyfile) under version control. Keep `.env` and TLS keys/certificates out of the repository. | NFR-004, NFR-009 | Platform | Proposed | — |
| G7 | Verify accessibility: keyboard-only walkthrough of login, ask and documents flows, labels and focus handling; extend automated accessibility checks; record results. | NFR-010 | Frontend / QA | Proposed; Login has an automated axe check, but full-flow coverage is unverified | — |
| G8 | Measure p95 retrieval latency on a documented dataset of up to 10,000 chunks against the NFR-001 target of 1.5 seconds; report p50/p95 end-to-end latency and propose an end-to-end target after a baseline. | NFR-001, NFR-002 | Backend / QA | Proposed | Documented test environment |
| G9 | Extend prompt-injection and adversarial tests (document content that tries to override rules, tampered filters, cross-collection access) and document applicable data-retention policies. Existing tests and the seven-day deletion policy cover part of this work. | Requirements §13, NFR-006 | Backend / Security | Proposed | — |
| G10 | Verify the real frontend-to-backend flow with a supported document: upload, indexing, answer and authorized citation inspection; map E2E-01–E2E-07 to automated tests or repeatable manual evidence. Existing Playwright coverage mocks API responses. | EKA-19, EKA-20, E2E-01–E2E-07 | Backend / Frontend / QA | Outstanding verification | Working test environment and authorized fixtures |
| G11 | Restore the checked-in backend retrieval defaults to the DEC-007 values: top-K 5 and similarity threshold 0.70. Test default and environment override behavior, update backend documentation and record results. The owner confirmed keeping the approved defaults on 2026-11-06. | DEC-007; foundation spec §7 | Backend / QA | Outstanding implementation; current checked-in defaults are 10 and 0.30, subject to environment overrides | Backend change and verification |
| G12 | Verify the approved pg18 local baseline with clean setup, Flyway migrations, pgvector and relevant integration tests; document a safe major-version upgrade path before reusing pg17 data. The owner approved pg18 on 2026-11-06; Compose already specifies it. | Foundation plan §10a, T19, NFR-009 | Backend / Platform / QA | Outstanding verification; previous T19 evidence used pg17 | Suitable isolated pg18 environment |
| G13 | Verify that a re-indexed document is excluded from retrieval while queued, processing and failed, and becomes eligible after successful indexing, even if old chunk records remain. Test each state and authorized access. | API contract; feature spec IN-01, IN-06 and RT-05 | Backend / QA | Owner approved exclusion on 2026-11-06; code inspection indicates the state filter enforces it, but lifecycle verification is outstanding | Suitable test fixtures |

### Group P: product capabilities and implementation approaches

Proposed capabilities and designs need an approved specification before implementation. P7 also supports an existing re-indexing requirement, although its coordinated migration approach is not yet approved.

| ID | Capability | Current state | Owner | Status | Depends on |
|---|---|---|---|---|---|
| P1 | Administration API and UI for collections, users, roles and grants. | Done only by SQL seed; no API exists. | Product / Backend / Frontend | Proposed, needs spec | — |
| P2 | Rate limiting and abuse protection for chat and upload. | Deferred in the API contract. | Product / Backend | Proposed, needs spec | G2 |
| P3 | Answer feedback and conversation history. | Deferred by DEC-008; also affects OI-12 of spec 011. | Product / Security | Deferred; needs privacy decision | — |
| P4 | Hybrid (keyword) retrieval and reranking. | Deferred by DEC-008 (FR-012, FR-013). | Product / Backend | Deferred | Evaluation evidence |
| P5 | OCR for scanned PDFs. | PDFs with no extractable text are rejected at upload with a validation error; no document/job is created. | Product / Backend | Deferred | — |
| P6 | Revisit original-file storage (DEC-005) for re-extraction and download. | Original files are not stored. | Product / Security | Proposed, needs decision | — |
| P7 | Safe full re-embedding when the embedding model or dimensions change, with appropriate model/version safeguards. | Individual re-index is implemented and retrieval filters on model name; vector tables are per provider and no coordinated full migration job was found. Re-indexing after configuration changes is already required by FR-008 and IN-08; the migration design needs specification and verification. | Backend / Product | Outstanding requirement; migration approach proposed | — |
| P8 | Production hardening: assess explicit CORS policy, security headers (CSP, HSTS), non-root containers, service health checks, secrets management, backup and restore. | Local deployment files exist; PostgreSQL has a Compose health check and local Kubernetes has backend and PostgreSQL probes. Production readiness and remaining controls are unverified. | Platform / Backend / Frontend | Proposed, needs spec | G4, G6 |
| P9 | Document updates: upload a new version of a document, and optional connectors or sync. | Manual upload and re-index only. | Product / Backend | Proposed, needs spec | P6 |
| P10 | Streaming answers. | Synchronous responses only. | Product / Backend / Frontend | Proposed, needs spec | — |
| P11 | Document-library pagination or another approved way to access all permitted results. | The UI requests up to 100 records and has no page navigation. | Product / Frontend | Proposed, needs scope and spec | — |

### Documentation fixes from the analysis

| ID | Work item | Owner | Status |
|---|---|---|---|
| D1 | Update the requirements "Open decisions" table (LLM provider, embedding model) to reflect DEC-002 and later decisions. | Specification | Done: decision statuses and remaining questions aligned on 2026-11-06 |
| D2 | Record the limitations not yet documented (no `infra/` version control, no re-embedding path, no document versioning, no security-header or container hardening) in the backend README. | Backend / Specification | Proposed |
| D3 | Update the "no CI found" README notes once G4 is done. | Backend / Frontend | Proposed |
| D4 | Reconcile upload-time rejection and re-index visibility in the feature/API documentation, and clarify spec 005 FR-3 against its approved P4 exception. | Specification / Product | Done: owner approved immediate rejection and exclusion during re-index on 2026-11-06; G13 separately tracks lifecycle verification |

### Suggested order

1. Make it releasable: G11, G12, G13, G6, G4, G5 (B04), G10, B06 and B09; B09 remains blocked until its required evidence is complete.
2. Make it operable: G1, G2, G3, then P8.
3. Make it administrable and safe: P1, P2, G9.
4. Make it better: P5, P7, P6, P4, P3, P9, P10 and P11. G7 and G8 run in parallel with these.

## Owner decisions recorded (2026-11-03)

1. **DEC-009:** Approve PDFBox (PDF), Apache POI (DOCX), and plain-text extraction (TXT/Markdown); the decision record is now approved.
2. **OIDC OI-2:** Approve a 5-minute Keycloak access-token lifetime and lockout after 5 failed attempts. Lockout duration follows the configured realm policy.
3. **OIDC OI-3:** Require backend validation of a configured API audience. OIDC deployments must set `EKA_OIDC_AUDIENCE` and configure Keycloak to issue it in access-token `aud`.
4. **PDF page limit:** Retain the 1,000-page runtime default. The integration test configures 500 pages to verify the configured limit and error response.
5. **DEC-011:** Keep API-authoritative role labels and collection IDs; do not map roles to Figma personas or add collection display names via API in the current scope.

## Owner decisions recorded (2026-11-06)

1. **DEC-007 retrieval defaults:** Keep top-K 5 and similarity threshold 0.70. Restore the backend defaults rather than approving the currently checked-in 10 and 0.30 (G11). No backend change or test was performed during this documentation review.
2. **Local PostgreSQL/pgvector:** Approve `pgvector/pgvector:pg18` as the new local starting baseline, replacing pg17 in the [foundation plan](../../specs/001-project-foundation/plan.md#10a-technical-baseline-decisions-t01). Approval does not establish pg18 test or upgrade evidence (G12).
3. **Re-index visibility:** Exclude documents from retrieval while queued, processing or failed, even when prior chunks remain stored. Verify the complete lifecycle under G13.
4. **Invalid uploads:** Reject empty, corrupt or unextractable files during upload with a safe error and create no document or job.

## Completion policy

- “Implemented” is not equivalent to “verified”; record test/manual evidence separately.
- Never add confidential production questions or document text to the repository. Evaluation data must remain in an authorized, access-controlled location as described in the backend evaluation guide.
- Do not mark T18/T19 done while their required evidence is missing.
- Any newly discovered feature or architectural change needs its own approved scope before implementation.
