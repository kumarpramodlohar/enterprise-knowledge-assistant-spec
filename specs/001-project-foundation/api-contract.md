# API Contract v1 (MVP)

**Status:** Approved by project owner 2026-10-11 (T05). Backend DTOs (`org.enterpriseknowledgeassitance.api`) and frontend types (`src/api/types.ts`) must match this file. Feedback and conversation-history APIs are out of MVP (DEC-008).

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
| `GET /api/v1/documents` | query `collectionId?`, `status?`, `documentType?`, `tag?`, `page` (default 0), `size` (default 20, 1–100) | `200` `DocumentPage` (permitted documents only) | 400, 401 |
| `GET /api/v1/documents/{id}` | — | `200` `DocumentResponse` | 401, 404 |
| `POST /api/v1/documents/{id}/reindex` | — | `202` `DocumentResponse`; idempotent while already queued/processing | 401, 404 |
| `DELETE /api/v1/documents/{id}` | — | `204`; content is excluded from retrieval immediately, purge after 7 days (DEC-006) | 401, 404 |
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

- Upload extracts and validates synchronously (empty → 400, corrupt → 422, renamed/spoofed → 415); chunking and embedding happen later in the worker (T10). Metadata limits: version/type ≤100 chars, ≤20 tags of ≤50 chars (T09, implemented).
- Re-indexing keeps the previous chunks searchable until the replacement is committed; failed documents are retried through `reindex`. A repeated `DELETE` returns 404.
- Rate limiting and idempotency keys are deferred to API design follow-up.
- Approved: page size default 20 (max 100) and question length max 2000.
- Scanned (image-only) PDFs fail with `failureReason` `EMPTY` because OCR is deferred.
- Chat does not persist questions or answers. Provider failures return safe `503` errors.
