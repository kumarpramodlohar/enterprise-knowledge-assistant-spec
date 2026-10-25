# Product and Architecture Decisions

Decisions that unblock the [Implementation Backlog](Implementation_Backlog_v1.md). Date: 2026-10-09. Owner: Product owner.

If a decision changes, update this file first, then the affected spec or task.

| ID      | Topic                                | Decision                                                    | Status                      |
| ------- | ------------------------------------ | ----------------------------------------------------------- | --------------------------- |
| DEC-001 | Authentication                       | Local dev mode + OIDC                                       | Approved                    |
| DEC-002 | AI providers                         | Ollama/OpenAI independently selectable for chat and embeddings in local/dev; Ollama defaults locally, OpenAI when deployed | Approved |
| DEC-003 | Upload limits                        | 10 MB, extension + content check                            | Approved                    |
| DEC-004 | Duplicate uploads                    | Reject with 409                                             | Approved                    |
| DEC-005 | Original files                       | Not stored                                                  | Approved                    |
| DEC-006 | Deletion                             | Soft delete, purge after 7 days                             | Approved                    |
| DEC-007 | RAG tuning values                    | Starting values below                                       | Approved                    |
| DEC-008 | MVP scope                            | Optional features deferred                                  | Approved                    |
| DEC-009 | Document extraction libraries        | Apache PDFBox (PDF), Apache POI (DOCX), plain read (TXT/MD) | Proposed (pending approval) |
| DEC-010 | Corrective RAG (CRAG) and web search | P1–P4 approved; external search has dual opt-in and defaults off | Approved |

---

## DEC-001: EKA-01 - Authentication

**Decision:** Support two modes through Spring Security.

- **Local dev mode:** simple local users for development and tests only.
- **Deployed environments:** OIDC provider (Spring Security OAuth2 resource server validating tokens).

**Notes**

- Local dev mode must be disabled by default outside the `local` profile.
- Roles and collection permissions are stored in PostgreSQL and mapped from the user's identity subject.
- **OIDC provider: Keycloak** (owner instruction, 2026-10-16). The backend still uses standard OIDC, so the provider stays replaceable.
- **Frontend flow:** Authorization Code with PKCE for a public client (no client secret), using `oidc-client-ts`; tokens are kept in memory only. Details: [specs/004-oidc-authentication](../../specs/004-oidc-authentication/spec.md).

**Affects:** EKA-04, EKA-06, EKA-20

## DEC-002: EKA-01 - Chat and embedding providers

**Decision:** Both Ollama and OpenAI are supported in local and development environments. Chat and embedding providers are independently selectable through backend configuration, so either provider can be used for each capability, including a mixed setup. Deployed environments default to OpenAI. Selection is made at backend startup; changing providers does not require source edits, but does require a restart.

**Notes**

- Ollama and OpenAI embedding models may have different dimensions. The active embedding configuration uses its matching isolated vector table/index; changing embedding provider or model requires re-indexing all documents into that index before they are searchable there. Chat-provider changes do not require re-indexing.
- A single running backend uses one configured chat provider and one configured embedding provider. Both integrations may be configured in the same environment, but this decision does not promise automatic failover or simultaneous fan-out to both providers for one request.
- Similarity scores differ per model, so the evidence threshold (DEC-007) is set per profile and tuned during evaluation.
- Remove unused starters (Anthropic, Pinecone) from `build.gradle` in EKA-02.
- Specific model names are set in configuration during EKA-02.

**Affects:** EKA-02, EKA-11, EKA-16, EKA-20

## DEC-003: EKA-01 - Upload limits and validation

**Decision:**

- Maximum file size: **10 MB** per file.
- Allowed types: PDF, DOCX, TXT, Markdown.
- Validation: file extension **and** server-side content check. Client-supplied content type is never trusted alone.

**Affects:** EKA-07, EKA-08, EKA-09

## DEC-004: EKA-01 - Duplicate uploads

**Decision:** Reject a duplicate with **409 Conflict** when the same file checksum already exists in the same collection.

**Notes**

- Soft-deleted documents (DEC-006) do not count as duplicates, so a deleted file can be uploaded again.
- The error message tells the user which document already exists, only if they can access it.

**Affects:** EKA-03, EKA-05, EKA-07, EKA-08

## DEC-005: EKA-01 - Original file retention

**Decision:** Original files are **not stored**. Only extracted text, chunks, vectors and metadata are kept. Temporary upload files are deleted after processing, on success or failure.

**Notes**

- Re-indexing therefore needs the stored chunk text (or a new upload) because the original file is gone. For the MVP, re-index reuses stored extracted text.
- Changing the extraction logic requires re-uploading the file.

**Affects:** EKA-07, EKA-09, EKA-12, EKA-13

## DEC-006: EKA-01 - Deletion

**Decision:** **Soft delete.**

1. Deletion marks the document as deleted. It is excluded from retrieval, listings and citations immediately.
2. Records are kept for **7 days**.
3. After 7 days, a purge job permanently removes chunks, vectors and derived records.
4. Each deletion and purge is written to the audit log.

**Notes**

- Deleted content still exists in the database for up to 7 days but is not reachable through the API.
- Purge failures are retried and logged.

**Affects:** EKA-03, EKA-13, EKA-14

## DEC-007: EKA-01 - Initial RAG tuning values

All values are configurable and will be tuned during evaluation (EKA-19).

| Setting                                 | Initial value |
| --------------------------------------- | ------------- |
| Chunk size                              | 800 tokens    |
| Chunk overlap                           | 100 tokens    |
| Top-K                                   | 5             |
| Context budget                          | 4000 tokens   |
| Minimum similarity (evidence threshold) | 0.70          |
| Ingestion worker concurrency            | 2             |

**Affects:** EKA-02, EKA-10, EKA-12, EKA-15, EKA-16

## DEC-008: EKA-01 - MVP scope of optional features

**Decision:** The following are **deferred** (not in MVP):

- Hybrid (keyword + vector) retrieval
- Reranking
- Answer feedback
- Conversation history
- Kafka or other message broker for ingestion (use the bounded executor with persisted jobs)

**Notes**

- Without conversation history, questions and answers are not stored.
- These can be added after the MVP baseline evaluation.
- CRAG-style corrective retrieval (evaluator, refinement, query rewrite, web search) is also not in the MVP; see DEC-010.

**Affects:** EKA-17, EKA-19

## DEC-009: Document extraction libraries

**Status:** Proposed. Not approved; requires explicit human approval.

**Proposal:** Keep the existing extraction libraries: Apache PDFBox for PDF, Apache POI (`poi-ooxml`) for DOCX, and plain text reading for TXT and MD. Do not add LangChain Community (Python/JavaScript only, not usable in the Java backend) or LangChain4j.

**Rationale**

- Already implemented with the page/character limits and DOCX zip-bomb guards.
- Gives the page and section data needed for citations.
- Smaller attack surface than a multi-format parser such as Apache Tika, for untrusted uploads.
- Avoids a second AI framework alongside Spring AI.
- Approved MVP formats (PDF, DOCX, TXT, MD) are fully covered.

**Reconsider when:** formats such as PPTX, XLSX, HTML or scanned PDFs (OCR) are added. Then evaluate Apache Tika or a dedicated parser for those formats only; a spec update is required first.

**Notes:** Spring AI `Document` may be used as the in-memory type for extracted text and metadata.

**Affects:** EKA-02, EKA-10

## DEC-010: Corrective RAG (CRAG) and web search

**Status:** P1–P4 approved by product owner on 2026-10-22. Owner authorized proceeding despite incomplete MVP baseline evaluation; T18/T19 remain blocked.

**Baseline (MVP):** retrieve, apply the similarity evidence threshold (DEC-007), then generate or return insufficient evidence. No per-document evaluator, refinement, query rewrite, or web search.

**Approved phases and defaults:**

- P1 prompted evaluator using configured chat model; ambiguous results abstain.
- P2 refine correct passages by selecting validated source strips.
- P3 allow at most one query rewrite and re-retrieve with the same authorization scope and metadata filters.
- CRAG disabled by default; evaluate up to five passages; 60-second CRAG-stage timeout; stage failures fall back to MVP behavior.
- Do not add corrective-action API/UI messaging.

**P4 web search:** Approved as a bounded Tavily Search API fallback only after internal corrective retrieval fails. Requires both `EKA_WEB_SEARCH_ENABLED=true` with a server-side API key and request `allowExternalSearch=true` (frontend unchecked by default). Sends only the user's question and fixed search options; no passages, filenames, collection/user identifiers, or conversation history. Do not log or persist question/provider bodies. Search result snippets are untrusted; no raw-page extraction/provider answer. Citations are typed INTERNAL/EXTERNAL; external sources expose validated HTTPS URL, title, and snippet. P4 does not run on ambiguous or initial no-hit branches. Search failures abstain. Existing CRAG remains disabled by default.

**Baseline limitation:** Existing 30-case reports are not human reviewed and show zero Recall@5 at threshold 0.70. This is not representative quality evidence and does not complete T18/T19. See [specs/005-corrective-rag](../../specs/005-corrective-rag/spec.md).

**Affects:** EKA-15, EKA-17, EKA-19 (future)
