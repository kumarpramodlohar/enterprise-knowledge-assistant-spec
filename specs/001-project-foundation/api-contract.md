# API Contract v1 (MVP)

**Status:** Approved by project owner 2026-10-11 (T05), with the Documents API amendments approved under DEC-012 on 2026-11-07. Backend DTOs (`org.enterpriseknowledgeassitance.api`) and frontend types (`src/api/types.ts`) must match this file. Feedback and conversation-history APIs are out of MVP (DEC-008).

## Conventions

- Base path `/api/v1`; JSON except upload (`multipart/form-data`). All endpoints except `/actuator/health` require authentication.
- Every response carries `X-Correlation-Id`. A client-supplied value matching `[A-Za-z0-9._-]{1,64}` is echoed; otherwise one is generated.
- Authorization is resolved server-side from the authenticated subject. Inaccessible and non-existent resources both return `404` so existence is not disclosed.
- Rate limits are deferred (not part of this contract).

## Error envelope

```json
{ "code": "NOT_FOUND", "message": "Resource not found", "correlationId": "…" }
```

| HTTP | `code` | When |
|---|---|---|
| 400 | `VALIDATION_FAILED` | Malformed JSON, failed validation, out-of-range paging |
| 401 | `UNAUTHENTICATED` | Missing/invalid credentials |
| 403 | `FORBIDDEN` | Authenticated but the operation is not allowed at all |
| 404 | `NOT_FOUND` | Missing or inaccessible resource |
| 409 | `DUPLICATE_DOCUMENT` | Same checksum already exists in the collection (DEC-004) |
| 409 | `DOCUMENT_BUSY` | Authorized re-index/delete attempt targets a document in `QUEUED` or `PROCESSING` state (DEC-012) |
| 413 | `FILE_TOO_LARGE` | Uploaded file bytes exceed the configured upload limit (10 MiB by default) |
| 413 | `PDF_PAGE_LIMIT_EXCEEDED` | PDF page count exceeds the configured extraction page limit |
| 413 | `EXTRACTED_CONTENT_TOO_LARGE` | Extracted text exceeds the configured character limit |
| 415 | `UNSUPPORTED_TYPE` | Extension/content not PDF, DOCX, TXT, Markdown |
| 422 | `UNPROCESSABLE_DOCUMENT` | Corrupt or encrypted file detected during upload-time extraction |
| 503 | `CHAT_PROVIDER_FAILED`, `CHAT_PROVIDER_TIMEOUT`, or `EMBEDDING_PROVIDER_FAILED` | A configured AI provider fails or times out; response contains a safe message |
| 500 | `INTERNAL_ERROR` | Unexpected failure; no internal detail disclosed |

All codes above are implemented in the backend (T04, T09, T11).

## Endpoints

| Method and path | Request | Success | Errors |
|---|---|---|---|
| `GET /api/v1/me` | — | `200` `{subject, role, readableCollectionIds[], manageableCollectionIds[]}` | 401 |
| `POST /api/v1/documents` | multipart `file`, `collectionId`, optional `version`, `documentType`, `tags` | `202` `UploadAcceptedResponse` | 400, 401, 404, 409, 413 (`FILE_TOO_LARGE`, `PDF_PAGE_LIMIT_EXCEEDED`, `EXTRACTED_CONTENT_TOO_LARGE`), 415, 422 |
| `GET /api/v1/documents` | query `collectionId?`, `status?`, `documentType?`, `tag?`, `search?` (case-insensitive literal filename substring, max 200 chars), `page` (default 0), `size` (default 20, 1–100) | `200` `DocumentPage` (permitted documents only) | 400, 401 |
| `GET /api/v1/documents/{id}` | — | `200` `DocumentResponse` | 401, 404 |
| `POST /api/v1/documents/{id}/reindex` | — | `202` `DocumentResponse` when current state is `INDEXED` or `FAILED` | 401, 404, 409 `DOCUMENT_BUSY` when queued/processing |
| `DELETE /api/v1/documents/{id}` | — | `204`; content is excluded from retrieval immediately, purge after 7 days (DEC-006) | 401, 404, 409 `DOCUMENT_BUSY` when queued/processing |
| `POST /api/v1/chat/query` | `ChatQueryRequest` | `200` `ChatQueryResponse` | 400, 401, 503 |

## Types

- `DocumentStatus`: `QUEUED | PROCESSING | INDEXED | FAILED`.
- `DocumentResponse`: `id, collectionId, fileName, contentType, sizeBytes, status, failureReason?, version?, documentType?, tags[], createdAt, updatedAt`. `failureReason` is a stable code (for example `CORRUPT`, `EMPTY`, `TOO_LARGE`, `ENCRYPTED`), never document content.
- `UploadAcceptedResponse`: `documentId, status, statusUrl`.
- `DocumentPage`: `items[], page, size, totalItems`.
- `ChatQueryRequest`: `question` (required, not blank, max 2000 chars), optional `filters {collectionIds[≤50], version, documentType, tags[≤20]}`, and optional `allowExternalSearch` (boolean, default false). Filters only narrow results and never widen access. External search requires explicit request consent and server enablement.
- `ChatQueryResponse`: `answer` (null when insufficient evidence), `insufficientEvidence`, `citations[]`, `correlationId`, `timingMs` (end-to-end), `retrievalMs` (embedding and vector retrieval).
- `Citation`: includes `sourceType` (`INTERNAL` or `EXTERNAL`). Internal citations include `documentId, fileName, chunkId, pageNumber?, section?, snippet` built from trusted stored metadata. External citations include `title, url, snippet`; `url` must use HTTPS and external citations do not contain internal document identifiers.
- `Me.manageableCollectionIds`: collection IDs for which the authenticated identity has server-side `MANAGE` permission. This is a UI affordance only; every write is independently authorized by the API.

## Open items

- Planned auth-service extraction: when the new policy source is integrated, inability to obtain authorization will use a safe `503` with code `AUTHORIZATION_SERVICE_UNAVAILABLE` and message `Authorization service is temporarily unavailable`, using the existing error envelope. This is not yet implemented; detailed design and cutover remain pending. See [specification 013](../013-auth-service-extraction/spec.md).
- Planned auth-service extraction: a genuine mid-request chat authorization denial will return `403 FORBIDDEN` with message `Request cannot be completed` and no source, collection, or existence details, answer, or citations; it will not be presented as insufficient evidence or automatically rerun. A user-initiated new request authenticates and authorizes afresh without reusing protected context or the discarded answer. This is not yet implemented and requires coordinated backend and UI changes. See [specification 013](../013-auth-service-extraction/spec.md).
- Upload extracts and validates synchronously (empty → 400, corrupt → 422, renamed/spoofed → 415); chunking and embedding happen later in the worker (T10). Metadata limits: version/type ≤100 chars, ≤20 tags of ≤50 chars (T09, implemented).
- During re-indexing, a document is excluded from retrieval while `QUEUED`, `PROCESSING` or `FAILED`, even if previous chunk records are retained; it becomes eligible again only after successful indexing. Failed documents are retried through `reindex`. This behavior was approved by the owner on 2026-11-06; verification is tracked in backlog G13.
- DEC-012 (2026-11-07): `search` is optional, trimmed, and blank values are treated as absent; matching is a case-insensitive literal substring over `file_name`, with `%`, `_`, and the escape character treated literally. It composes with the collection/status/type/tag filters and never widens the authorized collection set. Search strings longer than 200 characters are rejected with `400 VALIDATION_FAILED`.
- DEC-012 (2026-11-07): re-index and delete are allowed only when the current document status is not `QUEUED` or `PROCESSING`. After authorization, attempts in those states return `409 DOCUMENT_BUSY` without changing document state, jobs, or audit history. Re-index creates one queued job when accepted; another request after the document becomes queued returns `DOCUMENT_BUSY`.
- Rate limiting and idempotency keys are deferred to API design follow-up.
- Approved: page size default 20 (max 100) and question length max 2000.
- Scanned (image-only) PDFs without extractable text are rejected at upload with a safe validation error; no document/job or `failureReason` is created. OCR is deferred.
- Chat does not persist questions or answers. Provider failures return safe `503` errors.
