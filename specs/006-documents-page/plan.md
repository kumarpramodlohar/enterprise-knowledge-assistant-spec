# 006 Documents Page — Plan

**Status:** Implemented and verified for DEC-012 additions (2026-11-07).
**Specification:** [spec.md](./spec.md)

## 1. Approach

Extend the existing React Documents page and Spring Boot document API in their respective repositories. Preserve the existing auth context, API client, error mapper, shared state views, PostgreSQL/pgvector architecture, and server-side authorization model.

## 2. UI structure

- Page introduction with title, supporting text, and permission-gated upload action.
- Upload form presented in an expandable panel, retaining collection, file, version, type, and tags fields.
- Summary cards whose lifecycle counts explicitly apply to the currently displayed result set.
- Case-insensitive literal filename-substring search plus collection and status filters, all backed by `GET /api/v1/documents`.
- Twenty-item pagination using the existing paginated response and request contract.
- An Upload navigation item that opens the existing upload form on the Documents route.
- Desktop document table and responsive mobile document cards.
- Status badges, safe failure reason labels, a metadata details dialog, and permission-gated retry/re-index/delete controls. Disable lifecycle controls while queued/processing and enforce this rule in the backend.
- Accessible confirmation before delete; refresh list after successful mutations.
- Poll every five seconds while visible documents are queued/processing, capped at twelve attempts per collection/status filter.

## 3. Data and security

- Use `DocumentPage.totalItems` for the overall result count and the returned `items` for visible status summaries.
- The list endpoint caps page size at 100; the UI requests 20. Use `totalItems` and page response data to render accurate navigation and counts.
- Use `manageableCollectionIds` only to gate affordances. All writes still go through existing authorized API calls.
- Backend search must escape SQL wildcard characters, use only server-authorized readable collections, and compose with existing filters.
- Backend lifecycle checks must occur after authorization and prevent direct API requests from bypassing the UI's busy-state restrictions with a stable 409 `DOCUMENT_BUSY` response.
- Keep server failure details mapped through `toUiError`; display safe `failureReason` codes as friendly labels rather than raw exception text.

## 4. Responsive and accessibility design

- Follow the Figma EKA Documents desktop hierarchy and mobile document-card layout.
- Keep forms labelled, controls keyboard reachable, focus visible, status updates announced, and destructive confirmation explicit.
- The Upload navigation item links to the existing upload form; do not create a standalone Upload route.
- Preserve collection IDs and the existing design system; do not copy unrelated screenshot styling.

## 5. Verification strategy

- Reconcile implementation against AC-1–AC-13; test backend search/filter/authorization and busy-state semantics, frontend pagination/search/navigation/action states, and compare the requested page at desktop/mobile sizes.
- DEC-012 validation: backend `DocumentManagementIntegrationTest` and `ApiContractTest` passed with the local Ollama-compatible test settings recorded in the root implementation plan. Frontend typecheck, production build, all 65 unit tests, and the 1-test Playwright suite passed; lint exited 0 with five warnings (two auth and three Documents page warnings). The existing desktop/mobile visual verification remains applicable because these additions preserve the EKA design and responsive layouts.
