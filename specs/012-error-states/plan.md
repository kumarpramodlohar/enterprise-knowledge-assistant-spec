# Error and Recovery States — Plan

**Status:** Implemented and verified by frontend tests, typecheck, build, and lint (2026-11-07).
**Specification:** [spec.md](./spec.md)

## 1. Approach

Use the existing frontend React Router routes and shared `Layout`. Add an explicit access-denied route, upgrade the existing not-found component, and wrap application route rendering in a React error boundary with a safe recovery fallback. Do not change backend APIs: existing API error mapping already provides fixed user-safe messages and optional correlation IDs.

## 2. UI behavior

- Keep the shared shell, current EKA navigation, and server-provided role label; do not replicate the Figma sample workspace name or persona.
- Present each state in the route content area with centered icon, status label, heading, concise safe message, and the specified navigation/retry action.
- The recovery boundary hides the caught exception and provides reload and Ask navigation.
- A reference identifier is optional and is never fabricated. Existing inline request errors continue to use their current safe mapping.
- Reuse local Figma SVG assets for the page-specific status and privacy icons; do not reference temporary asset URLs at runtime.

## 3. Security

- Keep the backend's non-disclosing 404 policy unchanged.
- The access-denied screen does not identify a denied document, collection, operation, or permission.
- The boundary's fallback renders fixed copy only and does not display exception content.

## 4. Verification

- Unit-test unknown route and access-denied route content, links, error boundary fallback/retry, and exception-message redaction.
- Run the frontend test suite, typecheck, production build, and lint.
- Compare the implementation with the three Figma frames; verify responsive layout classes, local asset dimensions/usage, and automated accessibility checks.
- Confirm no backend files changed and the repository API/error contract remains untouched.

## 5. Verification results

- Frontend tests: all 69 tests passed across 12 files, including error-state route, recovery, redaction, and axe checks.
- Typecheck and production build passed.
- Lint exited 0 with five warnings in existing authentication and Documents-page code.
- The five local Figma SVGs have non-empty files and are used at their exported 32px or 16px dimensions. No temporary Figma URLs remain in application code.
- No backend changes were needed; existing safe error envelopes and authorization behavior remain in place.
