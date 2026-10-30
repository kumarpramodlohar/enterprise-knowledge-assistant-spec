# Enterprise Knowledge Assistant MVP Specification

**Document ID:** EKA-SPEC-001
**Version / status:** 1.0 / Approved baseline behavior; implementation delivered for T01–T17 and T20, release verification remains blocked
**Prepared date:** 2026-10-10
**Target release:** MVP v1
**Scope:** End-to-end knowledge ingestion, retrieval, and answer experience

> This specification consolidates the approved MVP baseline. Detailed feature behavior and implementation status are maintained in the linked feature specifications and task records. Approved decisions in `docs/implementation/product-decisions.md` take precedence over older proposals.

## 1. Source Documents

- [Software Requirements Specification](../../docs/Enterprise_Knowledge_Assistant_Requirements_v1.md)
- [Product Requirements Document](../../docs/Enterprise_Knowledge_Assistant_PRD_v1.md)
- [Feature Specifications](../../docs/Enterprise_Knowledge_Assistant_Feature_Specifications_v1.md)
- [Approved product decisions](../../docs/implementation/product-decisions.md)

## 2. Problem and Product Outcome

Users need to find trustworthy answers in technical documents without manually searching through files. Knowledge managers need to add documents and understand whether they are searchable. The system shall retrieve only content the current user is authorized to access, provide answers grounded in that evidence with verifiable citations, and clearly report when evidence is insufficient.

This document defines approved behavior. T01–T17 and T20 are delivered; T18/T19 remain blocked by representative evaluation and release-readiness evidence.

## 3. Users

- **End User:** asks questions and inspects citations in authorized collections.
- **Knowledge Manager:** uploads, views, retries, re-indexes, and deletes documents within permitted collections.
- **Administrator:** manages roles and system settings and reviews permitted audit and ingestion information.
- **Operator / Developer:** monitors health and redacted diagnostics, without implicit access to restricted document content.

## 4. MVP Scope

### In scope

- Authentication and server-side role, collection, and document authorization.
- Upload and processing of PDF, DOCX, TXT, and Markdown documents.
- Text extraction, source metadata, configurable chunking, embeddings, vector indexing, and ingestion status.
- Authorized document listing, retry, re-indexing, and deletion.
- Natural-language questions, semantic retrieval, server-enforced metadata filters, evidence-grounded answers, and citations.
- Explicit insufficient-evidence responses.
- Safe failure handling, operational diagnostics, repeatable quality evaluation, automated tests, and documented local development.

### Deferred by approved decision DEC-008

- Hybrid keyword/vector retrieval, reranking, answer feedback, conversation history, and Kafka or another message broker for ingestion.
- Questions and answers are not persisted for conversation history in the MVP. Use the approved bounded worker with persisted ingestion jobs.

Some source material proposes or describes these deferred capabilities. This specification follows DEC-008.

Corrective RAG is not part of the MVP baseline. Phases P1–P4 are approved behind disabled-by-default configuration; external web search also requires per-question user consent. See [specs/005-corrective-rag](../005-corrective-rag/spec.md) and DEC-010.

### Out of scope

- Autonomous actions in enterprise systems; foundation-model training or fine-tuning.
- Unrestricted crawling of internal systems or the public web.
- Voice, image understanding, or video transcription.
- Formal regulatory certification or guaranteed correctness.
- Complex workflow approvals, billing, and multi-region disaster recovery.
- Production latency or quality commitments before representative evaluation.

## 5. Functional Requirements

| ID    | Requirement                                                                                                                                                                                                                                                                                                            |
| ----- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| FR-01 | Protected operations shall require an authenticated identity. The backend shall authorize each operation using the caller's roles and collection/document permissions; frontend visibility is not an authorization control.                                                                                            |
| FR-02 | Authorized Knowledge Managers shall be able to upload supported documents to permitted collections. The server shall validate file size, extension, and content; reject empty, corrupt, unsupported, or oversized files with a safe error; and not index rejected content.                                             |
| FR-03 | Accepted uploads shall create a document record and ingestion job. Ingestion shall extract searchable text, preserve available page/section/source metadata, create stable source-linked chunks, generate embeddings using the configured provider, and make content searchable only after indexing succeeds.          |
| FR-04 | The system shall expose `queued`, `processing`, `indexed`, and `failed` status with a safe failure summary. Authorized users shall be able to retry or re-index safely without duplicate active chunks.                                                                                                                |
| FR-05 | Authorized users shall be able to list and inspect permitted document metadata and manage documents according to their permissions. Deleted documents shall immediately be excluded from listings, retrieval, and citations, then be purged according to the approved retention decision.                              |
| FR-06 | The system shall accept non-empty natural-language questions and perform bounded semantic retrieval using configurable top-K. Server-derived authorization and approved metadata filters shall be applied in retrieval before passage text enters answer context. Only eligible indexed content may be retrieved.      |
| FR-07 | With sufficient authorized evidence, the system shall return an evidence-grounded answer and citations mapped to real, accessible source chunks. When evidence is absent or below the configured evidence policy, it shall return an explicit insufficient-evidence response instead of an unsupported factual answer. |
| FR-08 | The system shall provide safe, bounded handling of ingestion and AI-provider failures, plus correlation IDs and operational/evaluation information where available. Sensitive content and credentials shall not be exposed in errors or logged by default.                                                             |

## 6. Acceptance Criteria

| ID    | Given / when                                                                                                                                 | Expected result                                                                                                                                                                      | Verification                                     |
| ----- | -------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------ |
| AC-01 | A caller accesses a protected operation without authentication or without the required permission.                                           | The request is rejected; no unauthorized document metadata or content is disclosed through the response, citations, logs, or model context.                                          | API security and adversarial authorization tests |
| AC-02 | An authorized manager uploads a supported, non-empty file of at most 10 MB.                                                                  | The upload is accepted for asynchronous processing and returns a document identifier and status.                                                                                     | API integration test                             |
| AC-03 | A file is unsupported, empty, corrupt, over 10 MB, or has misleading client-supplied type information.                                       | The server rejects it with a safe, clear error and creates no searchable content. A file exactly 10 MB is accepted if otherwise valid.                                               | Upload validation tests                          |
| AC-04 | A file checksum duplicates a non-deleted document in the same collection.                                                                    | The server returns `409 Conflict` and does not create another document or job. A soft-deleted file may be uploaded again.                                                            | Upload integration test                          |
| AC-05 | An accepted document is processed successfully or processing fails.                                                                          | Status progresses to `indexed` only after searchable content is ready, or to `failed` with a safe summary; available source metadata remains linked to its chunks.                   | Ingestion integration test                       |
| AC-06 | A transient ingestion failure is retried, or a document is re-indexed.                                                                       | Processing is idempotent and leaves no duplicate active chunks; failures terminate with a safe state after bounded retries.                                                          | Retry and re-index integration tests             |
| AC-07 | A user lists documents, retrieves a document, or requests deletion.                                                                          | Only permitted metadata is exposed; deletion excludes content from retrieval and citations immediately and is auditable. Purge occurs after the approved retention period.           | API authorization and lifecycle tests            |
| AC-08 | A user submits an empty question, tampers with filters, or requests unauthorized content.                                                    | Empty input is rejected without model calls; unauthorized content is never retrieved or passed to the model. User filters can narrow but never expand server-authorized scope.       | API and adversarial retrieval tests              |
| AC-09 | A valid question has fewer eligible results than top-K or includes non-indexed, failed, deleting, or deleted content among possible matches. | The answer pipeline receives no more than top-K eligible authorized passages and excludes ineligible content without padding from unauthorized sources.                              | Retrieval integration test                       |
| AC-10 | Sufficient evidence supports an answer.                                                                                                      | The answer is grounded in retrieved passages and includes at least one citation that resolves to an authorized indexed source and available source metadata.                         | Chat integration and citation validation         |
| AC-11 | No adequate evidence exists, or retrieved content includes prompt-injection instructions.                                                    | The system communicates insufficient evidence without fabricating a factual answer; document instructions cannot override system policy or access control.                           | Evaluation and adversarial prompt tests          |
| AC-12 | An AI provider or ingestion dependency times out or fails.                                                                                   | Retries and timeouts are bounded; users receive a safe failure outcome, not a success-shaped response or raw provider details.                                                       | Failure and timeout tests                        |
| AC-13 | A release evaluation is run.                                                                                                                 | Results record dataset and model/configuration versions and include retrieval quality, citation validity, groundedness/usefulness, latency, and provider usage/cost where available. | Reproducible evaluation run                      |
| AC-14 | A developer follows the documented local setup and a user operates core flows.                                                               | The documented Docker-based setup is reproducible; core UI flows are keyboard-operable and expose clear loading, empty, success, and failure states.                                 | Setup check and accessibility/E2E tests          |

## 7. Approved Constraints and Configurable Starting Values

The following values and behaviors come from approved decisions DEC-001–DEC-008:

- Authentication: local development mode plus OIDC for deployed environments; local mode is limited to the `local` profile.
- AI providers: Ollama and OpenAI are independently configurable for chat and embeddings; local defaults to Ollama/Ollama and deployed defaults to OpenAI/OpenAI. Embedding indexes remain isolated by compatible model and dimensions; see DEC-002 and [008-ai-provider-selection](../008-ai-provider-selection/spec.md). Exact model names and the OIDC provider product remain open.
- Upload limit: 10 MB per file; accept PDF, DOCX, TXT, and Markdown; check extension and server-side content.
- Duplicate detection: reject a matching checksum in the same collection with `409 Conflict`, excluding soft-deleted documents.
- Original files: do not retain them; delete temporary uploads after processing. Retain derived extracted text/chunks as specified by the approved design.
- Deletion: soft-delete immediately from user-visible operations and retrieval; purge derived records after 7 days and audit deletion and purge.
- Configurable initial RAG settings: chunk size 800 tokens, overlap 100 tokens, top-K 5, context budget 4,000 tokens, minimum similarity 0.70, and ingestion worker concurrency 2. Tune per provider and evaluation; similarity is not a correctness probability.
- Deferred: hybrid retrieval, reranking, answer feedback, conversation history, and a message broker.

## 8. Security, Privacy, and Quality Requirements

- Enforce authorization on the server before retrieving protected content, constructing model context, or returning citations. Apply tenant/collection restrictions on every relevant retrieval path.
- Treat uploaded and retrieved text as untrusted data. Render model output and excerpts safely; do not execute document/model-provided markup or instructions.
- Keep secrets outside source control and avoid logging credentials, full document bodies, or other sensitive content by default.
- Use safe errors, bounded provider timeouts/retries, and auditable security-relevant actions.
- Separate business logic, ingestion, retrieval, and model-provider integration into testable components.
- Provide health checks, structured logs with correlation IDs, and request/error/latency/provider-usage metrics where available.
- Keep core UI flows keyboard-operable with visible loading, empty, success, and failure states.

## 9. Evaluation Targets and Open Items

The source documents propose, but do not approve as commitments, at least 80% supported and relevant answers on a curated 50-question set and valid citations for at least 95% of factual answers. Evaluate these targets against a versioned dataset and documented methodology before treating them as acceptance thresholds.

The requirements document also proposes p95 retrieval latency of at most 1.5 seconds for up to 10,000 chunks on documented local/demo hardware. Measure retrieval separately from end-to-end model latency before setting a service commitment.

Open configuration and product details include the OIDC provider, exact chat and embedding model names, request quotas, and benchmark environment. Resolve material choices before implementation; do not infer approval from this draft.

## 10. Traceability

This specification consolidates rather than replaces the detailed source requirements:

- Authentication, upload, ingestion, retrieval, chat, and operational requirements: SRS FR-001–FR-024 and NFR-001–NFR-012.
- Core user outcomes: SRS US-01–US-03 and PRD core user journeys.
- Feature acceptance detail: Feature Specifications UP-01–UP-08, IN-01–IN-11, RT-01–RT-09, CH-01–CH-10, and cross-feature scenarios.
- Approved constraints: DEC-001–DEC-008 in `docs/implementation/product-decisions.md`.
