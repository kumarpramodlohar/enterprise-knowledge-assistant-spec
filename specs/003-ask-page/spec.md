# 003 Ask Page — Specification

**Status:** Draft for review (implementation already delivered; written retroactively)
**Design source:** Figma file "EKA · Ask" frame (node `2508:23117`)
**Related:** specs/001-project-foundation (FR-06, FR-07, AC-08–AC-12), DEC-005, DEC-008

## Content rule
Visual design (layout, colour, typography) comes from Figma. All user-facing text is decided by the specifications and approved project documents, so copy may differ from Figma. Terms not defined in the specs (for example "workspace") are avoided.

## Problem
Users need to ask natural-language questions and receive grounded answers with verifiable citations, or a clear insufficient-evidence response.

## Users
Authenticated users with readable collections.

## Functional requirements
- FR-1: Page at `/assistant` (default after sign-in) with heading "Ask your knowledge".
- FR-2: "Search in" selects one readable collection or all accessible ones; optional version, document type and tags filters are under "More filters".
- FR-3: Submitting sends `POST /chat/query`; Enter sends, Shift+Enter inserts a new line; no second submit while pending.
- FR-4: The asked question is shown above the answer.
- FR-5: A grounded answer shows numbered citations (file, section, page where available).
- FR-6: "Verify and view source" re-checks access via `GET /documents/{id}` and shows the extracted passage in the "Extracted source" panel; a missing or non-indexed document shows "This source is no longer available."
- FR-7: Insufficient evidence shows a distinct amber "Insufficient evidence" state with no invented answer or citations.
- FR-8: Errors use fixed safe messages with the correlation ID.
- FR-9: Layout shell: sidebar with Ask and Documents navigation, role from `/me`, signed-in subject and Sign out.

## Non-functional requirements
Accessible (labelled controls, live region for the answer, no axe violations); responsive (panel stacks on small screens).

## Acceptance criteria
- AC-1: Question, answer and citations render as inert text (no HTML injection).
- AC-2: Filters are sent as specified in the API contract.
- AC-3: Insufficient evidence is visually and textually distinct.
- AC-4: A second submit while pending is ignored.
- AC-5: An inaccessible source never shows its excerpt.

## Security
Authorization is enforced server-side before retrieval, citations and AI calls. The UI shows nothing it was not returned. Original files are not stored (DEC-005), so the panel shows extracted text only.

## Out of scope
Conversation history, follow-up threads and feedback (DEC-008); document preview or download; collection display names (the API returns IDs only).

## Open items
- OI-1: Collection display names need an API change (names in `/me` or a collections endpoint).
- OI-2: Role display label uses the API role (Administrator or Member); whether to show persona names such as "Knowledge Seeker" needs a decision.
