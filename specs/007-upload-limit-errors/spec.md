# 007 Upload Limit Error Detail — Specification

**Status:** Implemented and verified on 2026-10-21.
**Related:** `specs/001-project-foundation` (API Contract v1, T09, DEC-003), `specs/006-documents-page`.

## Problem

The upload API currently maps the configured file-byte limit and extraction limits to the same `FILE_TOO_LARGE` response. Users cannot tell whether a PDF exceeded the 10 MiB upload limit or the 500-page extraction limit.

## Scope

- Distinguish upload-byte limit failures from PDF page-count failures.
- Give extracted-text limits a separate API and UI error as well, so each configured limit has a useful explanation.
- Preserve the existing limits, authentication, collection authorization, and upload behavior for accepted files.

## Requirements

- FR-1: A file whose byte size exceeds `eka.upload.max-file-size-bytes` returns HTTP 413, code `FILE_TOO_LARGE`, and the existing safe message `File exceeds the maximum allowed size`.
- FR-2: A PDF whose page count exceeds `eka.extraction.max-pages` returns HTTP 413, code `PDF_PAGE_LIMIT_EXCEEDED`, and a safe message that identifies the PDF page-count limit.
- FR-3: Extracted text exceeding `eka.extraction.max-characters` returns HTTP 413, code `EXTRACTED_CONTENT_TOO_LARGE`, and a safe message that identifies the extracted-content limit.
- FR-4: The frontend maps the two new error codes to distinct user-facing messages while continuing to show the correlation ID.
- FR-5: Rejected uploads create no document, ingestion job, or staged extraction segments.
- FR-6: Messages and logs must not include document content.

## Acceptance criteria

- AC-1: An upload above the byte limit returns `FILE_TOO_LARGE`.
- AC-2: A PDF within the byte limit but above the page limit returns `PDF_PAGE_LIMIT_EXCEEDED`.
- AC-3: A supported file within the byte limit but above the extracted-character limit returns `EXTRACTED_CONTENT_TOO_LARGE`.
- AC-4: The frontend shows separate safe messages for AC-1 through AC-3 and includes the response correlation ID.
- AC-5: Each rejection leaves no persisted document, ingestion job, or extraction segment.
- AC-6: Existing successful uploads, authorization checks, and other validation responses retain their current behavior.

## Security and privacy

Authorization remains checked before file validation. Error text is fixed and safe; it must not expose extracted text, filenames, or parser internals.

## Out of scope

Changing upload or extraction thresholds, OCR, parser behavior beyond reporting which limit was exceeded, and user-configurable per-account limits.
