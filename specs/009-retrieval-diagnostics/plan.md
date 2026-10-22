# 009 Retrieval Diagnostics — Plan

**Specification:** [spec.md](./spec.md)

## Architecture
Extend the backend retrieval configuration with a diagnostic candidate count. `ChunkIndexer` will query that many authorized, eligible vector rows, log rank and score metadata before threshold filtering, and then apply the existing top-K window and threshold in the same order as today. Correlation ID is obtained from the existing request context. Logs must omit query and passage text.

## Components
- Backend `EkaProperties.Retrieval`: validated diagnostic candidate count.
- Backend `ChunkIndexer`: candidate query, safe structured diagnostics, unchanged selection semantics.
- Backend tests: verify ordering, score/threshold logging, and that only the configured top-K reaches results.

## Security and privacy
Authorization, lifecycle, model, and metadata filters remain inside the SQL query before candidates are logged. Log only identifiers, page, rank, score, and threshold outcome.

## Verification
Run targeted backend tests and the backend build; inspect test evidence against AC-1–AC-4.
