# 006 Documents Page — Specification

**Status:** Draft for review; implementation completed, visual verification pending.
**Design source:** Figma file `Car Rental Company Dashboard UI` — EKA · Documents frame (`2508:23218`) and EKA · Mobile Documents frame (`2508:24558`).
**Related:** `specs/001-project-foundation` (FR-01–FR-05, AC-01–AC-07, AC-14), DEC-003–DEC-006, DEC-008, API Contract v1, backlog EKA-14.

## 1. Purpose

Give authorized users a clear, responsive place to upload documents and review their ingestion state, while preserving the existing API and server-side authorization model.

## 2. Scope and constraints

- Frontend-only page redesign in the existing `/documents` route.
- Keep existing supported upload metadata, collection scoping, retry/re-index, delete, and status refresh behavior.
- Use only permitted documents and manageable collection IDs returned by `/me`; the backend remains authoritative for every operation.
- Do not add global filename search, collection names, or aggregate status APIs. The current contract does not provide them.
- Show status counts for the currently displayed result set and label them accordingly; show the server's `totalItems` separately.
- Do not add document preview/download or conversation/history behavior.

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

## 6. Out of scope and open decisions

- Global filename search, collection display names, bulk actions, server-side summary counts, and pagination controls beyond the existing first 100 results.
- Polling uses a 5-second interval with a maximum of 12 attempts per selected collection/status filter; users can continue with manual refresh after the automatic window ends.
- Exact visual content values shown in Figma are illustrative; the UI must use API data and specification-approved copy.
