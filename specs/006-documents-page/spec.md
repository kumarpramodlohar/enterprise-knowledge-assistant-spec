# 006 Documents Page — Specification

**Status:** Implemented and verified for DEC-012 additions (2026-11-07).
**Design source:** Figma file `Car Rental Company Dashboard UI` — EKA · Documents frame (`2508:23218`) and EKA · Mobile Documents frame (`2508:24558`).
**Related:** `specs/001-project-foundation` (FR-01–FR-05, AC-01–AC-07, AC-14), DEC-003–DEC-006, DEC-008, API Contract v1, backlog EKA-14.

## 1. Purpose

Give authorized users a clear, responsive place to upload documents and review their ingestion state, while preserving the existing API and server-side authorization model.

## 2. Scope and constraints

- Extend the existing `/documents` UI and document-list API, keeping the route and established EKA design.
- Keep existing supported upload metadata, collection scoping, retry/re-index, delete, and status refresh behavior.
- Use only permitted documents and manageable collection IDs returned by `/me`; the backend remains authoritative for every operation.
- Do not add global cross-collection filename search, collection names, or aggregate status APIs. Search remains constrained to documents the caller can read.
- Show status counts for the currently displayed result set and label them accordingly; show the server's `totalItems` separately.
- Do not add document preview/download or conversation/history behavior.
- Preserve the approved single-workspace product, existing EKA visual design, and collection-ID display (DEC-011).

## 3. Functional requirements

- FR-1: Keep the `/documents` route and display a page title, supporting text, and a prominent upload action for users with a manageable collection.
- FR-2: Provide an accessible collection filter over readable collection IDs and a status filter using `QUEUED`, `PROCESSING`, `INDEXED`, and `FAILED`; requests use supported list query parameters.
- FR-3: Show document rows/cards with filename, content type/size, collection ID, lifecycle status, updated timestamp, and authorized actions. A Details action exposes available document metadata to users who can read that document. Missing values are omitted or shown with safe neutral copy.
- FR-4: Show total result count from `DocumentPage.totalItems`; any status summaries describe only the displayed result set.
- FR-5: Keep upload validation and metadata behavior unchanged. Accepted uploads are described as queued/processing, not indexed.
- FR-6: Re-index failed documents as Retry; show lifecycle actions only when the current user has MANAGE permission. Prevent destructive action until the user confirms it.
- FR-7: Refresh after upload/re-index/delete and keep clear loading, empty, success, and safe error states.
- FR-8: Preserve keyboard operation and responsive behavior; on narrow screens, present each document as a readable card rather than a compressed table.
- FR-9: Automatically refresh while listed documents are queued or processing, at a bounded cadence; stop automatic refresh after a bounded window and leave manual refresh available.
- FR-10: Provide a server-side filename search that matches a literal substring case-insensitively. Combine it with collection/status filters and apply authorization before returning results. Ignore a blank search value and reject search strings longer than 200 characters.
- FR-11: Provide pagination controls using 20 results per page. Use the API's `page`, `size`, and `totalItems` values; reset to page 0 when search or filters change.
- FR-12: Provide an Upload navigation item that opens the existing upload form on the Documents route; do not create a separate upload page.
- FR-13: Disable Retry/Re-index and Delete for documents in `QUEUED` or `PROCESSING` state. The backend must enforce the same restriction and return HTTP 409 `DOCUMENT_BUSY` for an authorized attempt while processing. Authorization checks must happen before the current-state response so inaccessible resources remain indistinguishable from missing resources.

## 4. Security and privacy

- The UI's readable/manageable collection data is an affordance only; backend authorization remains authoritative.
- Never display raw server exception details or document contents in status/error messages.
- Do not imply original-file preview or download; original uploads are not retained (DEC-005).

## 5. Acceptance criteria

- AC-1: The page uses the existing documents API and retains the `/documents` route.
- AC-2: Collection and status filters send only contract-supported query parameters and reset to page 0.
- AC-3: The result count uses `totalItems`; visible status counts are clearly scoped to displayed results.
- AC-4: Users without manageable collections do not see upload controls; users without per-document management permission do not see write actions.
- AC-5: Upload, retry/re-index, and delete show pending/success/failure feedback; delete requires explicit confirmation.
- AC-6: Loading, empty, error, queued, processing, indexed, and failed states remain understandable at desktop and mobile widths.
- AC-7: The Figma hierarchy and visual language are reflected without using temporary Figma asset URLs at runtime.
- AC-8: Pending ingestion states trigger refreshes at most every five seconds for no more than twelve attempts; polling stops when no visible document is queued/processing, and manual refresh remains available.
- AC-9: Details show only metadata from the authorized document list response and do not expose original file contents or download actions.
- AC-10: Filename search is a case-insensitive literal substring match, composed with collection/status filters and restricted to the caller's readable collections. SQL wildcard characters in input are treated literally. Blank search returns unfiltered results; values over 200 characters return `400 VALIDATION_FAILED`.
- AC-11: The list requests 20 items per page by default from the UI; Previous/Next controls reflect `page`, `size`, and `totalItems`, and changing the search or filters returns to page 0.
- AC-12: The Upload navigation item opens the existing upload form on `/documents`; closing the form or completing an upload returns to the Documents view without leaving the upload form unintentionally open.
- AC-13: Retry/Re-index and Delete are disabled for queued/processing documents in both responsive layouts. Direct authorized API calls in those states return `409 DOCUMENT_BUSY` and do not change document/job state or audit history. Inaccessible resources still return 404.

## 6. Out of scope and open decisions

- Collection display names, bulk actions, and server-side summary counts remain out of scope. Search and pagination are included by DEC-012.
- Polling uses a 5-second interval with a maximum of 12 attempts per selected collection/status filter; users can continue with manual refresh after the automatic window ends.
- Exact visual content values shown in Figma are illustrative; the UI must use API data and specification-approved copy.
