# Error and Recovery States

**Status:** Implemented; frontend automated verification completed (2026-11-07).
**Design source:** Figma frames [EKA · Access denied](https://www.figma.com/design/3tjKloHKgcNXsp5IBQ9CJq/Car-Rental-Company-Dashboard-UI--Community-?node-id=2508-23798), [EKA · Page not found](https://www.figma.com/design/3tjKloHKgcNXsp5IBQ9CJq/Car-Rental-Company-Dashboard-UI--Community-?node-id=2508-23849), and [EKA · Recoverable error](https://www.figma.com/design/3tjKloHKgcNXsp5IBQ9CJq/Car-Rental-Company-Dashboard-UI--Community-?node-id=2508-23900).
**Related decisions:** DEC-001 (authentication), DEC-011 (API role labels and collection IDs), API contract authorization and error envelope.

## 1. Purpose

Give signed-in users clear, safe recovery screens for denied routes, unknown routes, and unexpected frontend rendering failures.

## 2. Scope and constraints

- Implement the three states in the existing React application and shared layout. Preserve the current EKA visual design system and navigation.
- Use the existing authenticated shell, identity display, and API role labels. Do not introduce screenshot-only tenant/workspace names or persona labels.
- No backend API or schema changes are required. The backend already returns safe error envelopes and correlation IDs for HTTP errors.
- Keep inaccessible or nonexistent protected resources indistinguishable as 404. The access-denied route is for known route-level access denial only; it must not expose which resource or permission was denied.
- Existing request-specific API errors remain in their current inline flow. An unexpected React render failure uses the recoverable page.
- Show a support reference only when a genuine correlation ID is available; never hardcode the illustrative Figma value or generate a misleading reference.

## 3. Functional requirements

- FR-1: A signed-in user visiting an unknown application route sees a Page not found state within the existing application shell.
- FR-2: A signed-in user visiting the explicit `/access-denied` route sees a generic access-denied state with a link back to Ask. Do not include resource identifiers, document names, or authorization details.
- FR-3: Unexpected errors thrown while rendering the application route content are caught by a React error boundary and show a recoverable error state instead of a blank page.
- FR-4: The recoverable state provides a retry action that reloads the current route and a link back to Ask. It displays a correlation ID only when one is available from a trusted error envelope.
- FR-5: All actions are keyboard accessible and have accessible names; error headings and alerts are announced appropriately.
- FR-6: Error states fit the existing responsive shell at desktop and mobile widths without horizontal overflow.

## 4. Security and privacy

- Never render exception messages, stack traces, raw API messages, credentials, or protected document details.
- Keep existing backend 404 behavior for inaccessible resources; do not convert it to 403 or reveal the denied resource on the client.
- Treat the Figma example tenant name, persona, and reference identifier as illustrative, not production data.
- The backend error contract remains unchanged; backend authorization stays authoritative.

## 5. Acceptance criteria

- AC-1: An unknown route shows a descriptive Page not found heading and a working navigation action to Ask.
- AC-2: `/access-denied` displays generic safe copy and a working action to Ask, without protected-resource details.
- AC-3: A child render exception is caught and displays the recoverable error screen; retry reloads the current route and the Ask link navigates to `/assistant`.
- AC-4: The recoverable screen never displays exception text and omits the support-reference row when no genuine correlation ID is present.
- AC-5: No backend API changes are introduced, and current protected-resource 404 behavior is preserved.
- AC-6: The three screens have no automated accessibility violations and remain usable on narrow viewports.

## 6. Out of scope

- Replacing inline feedback for expected API errors with full-page errors.
- Changing backend error status codes, authorization, error envelopes, or correlation-ID generation.
- Adding role-to-persona mapping, tenant selection, or workspace switching.
- A dedicated monitoring or support-ticket workflow.
