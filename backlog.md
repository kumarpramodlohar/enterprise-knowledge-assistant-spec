# EKA Remaining Backlog

**Status date:** 2026-11-03  
**Purpose:** Track the remaining implementation verification and release-readiness work. This is not a replacement for the historical [implementation backlog](docs/implementation/Implementation_Backlog_v1.md) or the canonical [foundation task register](specs/001-project-foundation/tasks.md).

## Current summary

The core MVP flows are implemented in the backend and frontend. Desktop/mobile Figma review is complete and the main layout differences were corrected. The project is not yet release-ready: live Keycloak verification and representative evaluation evidence are still blocked, so foundation tasks T18 and T19 remain blocked. The owner has resolved the non-release Ask-page label and collection display decisions (B11–B12).

The items below are limited to confirmed outstanding work. Proposed decisions remain proposals until explicitly approved. Manual checks and evaluation evidence must not be recorded as complete until actually performed.

## Ordered backlog

| ID | Work item | Owner / repository | Status | Depends on |
|---|---|---|---|---|
| B01 | Reconcile the focused backend CRAG test failure with the current evaluator prompt and behavior; update code or assertion only after checking the CRAG specification. | Backend | Done: assertion now covers current prompt requirements; focused CRAG/chat tests pass | — |
| B02 | Reconcile frontend Documents unit and browser tests with the current page and approved UI requirements. Keep assertions aligned with safe user-facing failure messages; do not expose internal failure codes merely to satisfy tests. | Frontend | Done: 60 unit tests, production build, and 1 Playwright test pass; lint exits 0 with warnings | — |
| B03 | Run focused and full backend/frontend validation after B01–B02; record actual results in the implementation task records. | Backend / Frontend / Specification | Done: backend 125 tests pass; frontend 60 unit tests, build, and 1 Playwright test pass; lint exits 0 with five warnings | B01, B02, B10 |
| B04 | Complete a live Keycloak sign-in check: callback, bearer API request, `/api/v1/me`, first-login provisioning, no-grant behavior, and sign-out. | Backend / Frontend | Blocked: owner says a test realm is available; actual issuer, audience, public client ID, and test-account setup are still needed. The default local `/realms/eka` endpoint returned 404. Configure passwords locally; do not send them in chat. | Test realm configuration |
| B05 | Visually compare Login, Ask, and Documents pages with their approved Figma frames at desktop and mobile sizes; record discrepancies and results. | Frontend / Specification | Done: reviewed desktop/mobile frames; aligned the sign-in split, shared app shell, mobile navigation, source-panel order, and Documents mobile layout. Preserved API role labels and collection IDs per DEC-011. | Figma access and browser |
| B06 | Obtain an access-authorized, representative labelled evaluation dataset and human review; run the versioned evaluation and record retrieval, citation, answer-quality, and latency results. | QA / Product / Backend | Blocked: owner can prepare the dataset/review with guidance; no local dataset path or reviewers are available yet. Use the backend evaluation guide; keep JSONL outside source control. | Authorized corpus, labels, human review |
| B07 | Resolve pending owner decisions and update the decision/specification records. | Product / Security / Specification | Done: DEC-009, DEC-011, OIDC OI-2/OI-3, and PDF page-limit choice recorded from owner approval | Owner responses |
| B08 | Update the specification repository README’s stale current-status section to point to this backlog and the current task register. | Specification | Done | — |
| B09 | Close T18 and T19 only after required test, evaluation, live/manual verification, and clean-setup evidence is recorded; publish an accurate release-readiness summary. | All | Blocked on B04–B06 | B03–B08 |
| B10 | Resolve the configured PDF page-limit discrepancy (runtime default is 1,000 pages; an integration test expects 500) and align the test and documentation with the approved value. | Product / Backend / Specification | Done: owner retained 1,000-page runtime default; test explicitly configures 500 | Owner response |
| B11 | Decide whether to replace API role labels with the persona names shown in Figma (for example, Knowledge Seeker/Knowledge Manager). | Product / Specification / Frontend | Done: owner chose API-authoritative role labels; recorded in DEC-011 | Owner response |
| B12 | Decide whether collection display names should be added through an API change or whether the UI should continue displaying collection IDs. | Product / Backend / Frontend / Specification | Done: owner chose to retain collection IDs; no API expansion; recorded in DEC-011 | Owner response |
| B13 | Review and approve the draft evaluation pipeline specification ([011](specs/011-evaluation-pipeline/spec.md)), including open items OI-1–OI-9; implementation follows only after approval. | Product / Backend / Specification | Pending owner review: spec, plan, tasks, and [developer guide](docs/Enterprise_Knowledge_Assistant_Evaluation_Guide_v1.md) drafted; no implementation started | Owner decisions; B06 for representative results |

## Owner decisions recorded (2026-11-03)

1. **DEC-009:** Approve PDFBox (PDF), Apache POI (DOCX), and plain-text extraction (TXT/Markdown); the decision record is now approved.
2. **OIDC OI-2:** Approve a 5-minute Keycloak access-token lifetime and lockout after 5 failed attempts. Lockout duration follows the configured realm policy.
3. **OIDC OI-3:** Require backend validation of a configured API audience. OIDC deployments must set `EKA_OIDC_AUDIENCE` and configure Keycloak to issue it in access-token `aud`.
4. **PDF page limit:** Retain the 1,000-page runtime default. The integration test configures 500 pages to verify the configured limit and error response.
5. **DEC-011:** Keep API-authoritative role labels and collection IDs; do not map roles to Figma personas or add collection display names via API in the current scope.

## Completion policy

- “Implemented” is not equivalent to “verified”; record test/manual evidence separately.
- Never add confidential production questions or document text to the repository. Evaluation data must remain in an authorized, access-controlled location as described in the backend evaluation guide.
- Do not mark T18/T19 done while their required evidence is missing.
- Any newly discovered feature or architectural change needs its own approved scope before implementation.
