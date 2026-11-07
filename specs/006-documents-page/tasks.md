# 006 Documents Page — Tasks

**Specification:** [spec.md](./spec.md) · **Plan:** [plan.md](./plan.md)

| ID | Task | Repository | Status |
|---|---|---|---|
| D01 | Record scope, API constraints, and acceptance criteria | Specification | Done |
| D02 | Implement responsive Documents page layout and Figma visual hierarchy | Frontend | Done |
| D03 | Add supported collection/status filters and accurate result summaries | Frontend | Done |
| D04 | Preserve upload and lifecycle actions with safe confirmation/feedback | Frontend | Done |
| D05 | Compare desktop/mobile rendering with Figma and record verification | Frontend / Specification | Done (desktop and mobile; mobile summary, filters, and upload action aligned) |
| D06 | Add bounded polling while visible ingestion is queued/processing | Frontend | Done |
| D07 | Approve and document filename search, pagination, Upload navigation shortcut, and busy-state lifecycle rules (DEC-012) | Specification | Done |
| D08 | Extend the document-list API with bounded case-insensitive literal filename search and verify filter/authorization composition | Backend | Done: integration tests cover literal wildcard handling, composed filters, and authorized results |
| D09 | Enforce `DOCUMENT_BUSY` for re-index/delete while ingestion is queued or processing; add integration coverage | Backend | Done: integration tests cover both actions and queued/processing states without mutation |
| D10 | Add debounced filename search, 20-item pagination, and API error handling to the Documents UI | Frontend | Done: focused UI/API tests and typecheck pass |
| D11 | Add Upload navigation shortcut to the existing upload form and disable busy-state lifecycle actions in desktop/mobile layouts | Frontend | Done: focused navigation and lifecycle-state tests pass |
| D12 | Run focused backend/frontend checks and verify the Documents flow at desktop/mobile sizes; update backlog with evidence | Backend / Frontend / Specification | Done: targeted backend tests, all 65 frontend unit tests, 1 Playwright test, typecheck, production build, and lint pass; five existing lint warnings remain |
