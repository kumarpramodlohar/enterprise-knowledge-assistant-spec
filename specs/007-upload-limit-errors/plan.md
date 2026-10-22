# 007 Upload Limit Error Detail — Implementation Plan

**Status:** Implemented and verified.

## Architecture

Keep the current API envelope and HTTP 413 status. Make extraction reasons specific at the parser boundary, map them to stable API codes in `UploadService`, and map those codes to fixed frontend messages in the existing UI error mapper. The existing file-byte check remains responsible for `FILE_TOO_LARGE`.

## Components

- **Backend extraction:** distinguish page-count limit and extracted-character limit from generic parser/resource failures.
- **Backend upload service:** map extraction reasons to `PDF_PAGE_LIMIT_EXCEEDED` and `EXTRACTED_CONTENT_TOO_LARGE`; retain `FILE_TOO_LARGE` for file bytes.
- **API contract:** document both new codes and upload endpoint errors.
- **Frontend:** map both codes to distinct safe error kinds/messages and retain correlation IDs.

## Testing strategy

- Unit tests assert PDF page and extracted-text failure reasons.
- Backend integration tests assert the 413 status, code, message, correlation behavior, and absence of persisted records for each limit case.
- Frontend error-mapping tests assert distinct user-facing messages for the new codes.
- Run focused backend and frontend tests plus their builds if available.

## Verification outcome

- Backend: focused extraction and upload integration tests pass (`ExtractionServiceTest`, `DocumentUploadIntegrationTest`).
- Frontend: `src/api/errors.test.ts` passes (16 tests); `npm run build` passes.
- `git diff --check` passes in each changed repository.

## Security

Keep collection authorization before validation. Error messages remain constant and do not contain file content or parser exceptions.

## Dependencies and data model

No schema, dependency, or data-model changes.
