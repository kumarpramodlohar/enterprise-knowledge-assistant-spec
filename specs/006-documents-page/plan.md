# 006 Documents Page — Plan

**Status:** Draft for review; implementation completed, visual verification pending.
**Specification:** [spec.md](./spec.md)

## 1. Approach

Refactor the existing React page presentation in the frontend repository. Keep API types and backend contracts unchanged. Reuse the existing auth context, API client, error mapper, and shared state views.

## 2. UI structure

- Page introduction with title, supporting text, and permission-gated upload action.
- Upload form presented in an expandable panel, retaining collection, file, version, type, and tags fields.
- Summary cards whose lifecycle counts explicitly apply to the currently displayed result set.
- Collection and status filters backed by `GET /api/v1/documents` parameters.
- Desktop document table and responsive mobile document cards.
- Status badges, safe failure reason labels, a metadata details dialog, and permission-gated retry/re-index/delete controls.
- Accessible confirmation before delete; refresh list after successful mutations.
- Poll every five seconds while visible documents are queued/processing, capped at twelve attempts per collection/status filter.

## 3. Data and security

- Use `DocumentPage.totalItems` for the overall result count and the returned `items` for visible status summaries.
- The list endpoint caps page size at 100. Do not claim the page shows all documents when `totalItems > items.length`.
- Use `manageableCollectionIds` only to gate affordances. All writes still go through existing authorized API calls.
- Keep server failure details mapped through `toUiError`; display safe `failureReason` codes as friendly labels rather than raw exception text.

## 4. Responsive and accessibility design

- Follow the Figma EKA Documents desktop hierarchy and mobile document-card layout.
- Keep forms labelled, controls keyboard reachable, focus visible, status updates announced, and destructive confirmation explicit.
- Do not add a filename search field because the API contract does not support it.

## 5. Verification strategy

- Reconcile implementation against AC-1–AC-9 and visually inspect the page at desktop/mobile widths.
- Existing project test suites are relevant, but test execution is not included in this requested change; report that clearly.
