# EKA Remaining Work Plan

**Status date:** 2026-11-03  
**Scope:** Close the remaining integration, evaluation, and release-readiness gaps in [backlog.md](./backlog.md). Existing backend and frontend implementations are treated as the baseline; this plan does not authorize new product scope or silently approve pending decisions.

## Goals

1. Reconcile automated test failures against the actual code and approved behavior.
2. Complete the manual checks that need a live identity provider or visual design reference.
3. Produce defensible evaluation evidence using authorized data and human review.
4. Close T18/T19 only when their evidence and prerequisites are satisfied.

## Execution sequence

### Phase 1 — Establish the current state and stabilize tests (complete)

**Backlog:** B01–B03  
**Repositories:** Backend, Frontend, Specification

1. Preserve existing worktree changes. The backend CRAG test assertion now checks the current prompt's evidence and safety requirements.
2. Align Documents unit and Playwright assertions with the responsive page, safe user-facing failure messages, and explicit delete confirmation.
3. Add mandatory configured OIDC audience validation and tests, following the owner's OI-3 decision.
4. Keep the approved 1,000-page runtime default and explicitly configure the page-limit integration test to 500.
5. Run focused and full checks with the local embedding model/provider configured, and record exact results.

**Exit criteria:** Backend 125-test suite, frontend 60-test suite, frontend production build, Playwright E2E, and focused OIDC/CRAG checks pass. Frontend lint exits successfully with warnings recorded.

### Phase 2 — Complete live and visual verification

**Backlog:** B04–B05  
**Repositories:** Backend, Frontend, Specification

1. With an approved Keycloak test realm and test user, verify SSO start/callback, backend bearer authentication, configured audience validation, `/api/v1/me`, first-login provisioning, no-grant behavior, token/session expiry handling where practical, and sign-out.
2. **Complete:** Compared the Sign in, Ask, and Documents desktop/mobile Figma frames with browser renders. Adjusted the sign-in split, shared application shell, mobile navigation, Ask source-panel order, and Documents mobile layout. Preserved API role labels and collection IDs per owner decision DEC-011.
3. Do not record either check as complete without actual execution evidence.

**Exit criteria:** Figma review and visual refinements are recorded. Live OIDC completion remains blocked until the actual realm configuration and test identities are provided and exercised.

### Phase 3 — Generate evaluation evidence

**Backlog:** B06–B07 (B07 complete)  
**Repositories:** Product / QA / Specification; Backend as needed

1. DEC-009, DEC-011, OIDC OI-2/OI-3, and the PDF page-limit choice were approved by the owner on 2026-11-03; their records have been updated.
2. Obtain an authorized representative question/chunk dataset with labels and human-review participation. Keep the JSONL outside source control and follow the schema and runner instructions in the backend evaluation guide.
3. Run the existing versioned evaluator, record dataset/configuration/model identity and actual metrics, inspect failures, and document methodology limitations.
4. Do not invent evaluation scores, infer approval from silence, or treat synthetic/test fixtures as a representative enterprise evaluation.

**Exit criteria:** Evaluation evidence is reproducible and based on authorized labelled data and human review. If inputs are unavailable, B06/T18 stay blocked.

### Phase 4 — Refresh project status and release gate

**Backlog:** B08–B09  
**Repositories:** Specification and both application repositories

1. The specification README and foundation task register have been updated to reflect current status.
2. Re-run any required checks affected by the documentation/status changes.
3. Review the T18/T19 completion criteria, local setup evidence, unresolved decisions, and known limitations.
4. Close T18 and T19 only if every applicable criterion is supported by recorded evidence; otherwise leave them blocked and state exactly what remains.

**Exit criteria:** Canonical project records agree, checks are reported accurately, and release readiness is either supported by evidence or explicitly remains blocked.

## Dependencies and constraints

- B01 and B02 can proceed independently; B03 depends on their outcomes.
- B04 depends on the actual Keycloak issuer, API audience, public client ID, and authorized test identities; credentials should be configured locally, not shared in chat.
- B05 is complete; DEC-011 resolves B11–B12 by retaining API role labels and collection IDs.
- B06 depends on authorization to use a representative corpus, labelled relevance judgments, and human reviewers. The owner has requested guidance for preparing these inputs.
- The approved OIDC audience value itself is deployment configuration: set `EKA_OIDC_AUDIENCE` to match the Keycloak access token. Do not commit credentials.
- B09 depends on all required evidence and status updates; it cannot be completed just by editing documentation.
- Preserve existing uncommitted work in all repositories. Do not commit or discard user changes.

## Verification record

Verification on 2026-11-03: backend `./gradlew test` passed with 125 tests when run with explicit local Ollama-compatible test settings (`EKA_CHAT_PROVIDER=ollama`, `EKA_CHAT_MODEL=llama3.2:latest`, `EKA_EMBEDDING_PROVIDER=ollama`, `EKA_EMBEDDING_MODEL=nomic-embed-text`, `EKA_VECTOR_TABLE=vector_store_ollama`, `EKA_EMBEDDING_DIMENSIONS=768`). Frontend `npm test` passed 60 tests across 11 files; `npm run build` passed; `npm run test:e2e` passed 1 Playwright test, including the responsive menu check; `npm run lint` exited 0 with five warnings (two auth and three Documents page warnings). Desktop/mobile Figma review was completed in the browser. `git diff --check` passed in all three repositories. Live Keycloak verification, representative dataset/human review, and final release-readiness evidence remain pending.
