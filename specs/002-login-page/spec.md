# 002 Login Page — Specification

**Status:** Draft for review (implementation already delivered; written retroactively)
**Design source:** Figma file "EKA · Sign in" frame (node `2508:23059`)
**Related decisions:** DEC-001 (local dev mode + OIDC)

## Content rule
Visual design (layout, colour, typography) comes from Figma. All user-facing text is decided by this specification and the approved project documents, so copy may differ from Figma. Terms not defined in the specs (for example "workspace", "tools") are avoided.

## Problem
Users need a dedicated, accessible sign-in screen. Previously sign-in was an inline form in the app header.

## Users
All roles. Local sign-in is for development environments only.

## Functional requirements
- FR-1: `/login` shows the Figma layout: product panel and sign-in panel (single column on small screens).
- FR-2: Local sign-in with username and password uses the existing HTTP Basic flow (`signInWithBasic`).
- FR-3: An empty password shows "Enter your password to continue." and sends no request.
- FR-4: A failed sign-in shows a fixed, user-safe message and the correlation ID if present. Server messages are never rendered.
- FR-5: Successful sign-in navigates to `/assistant`; an authenticated user visiting `/login` is redirected there.
- FR-6: Unauthenticated or expired sessions on protected routes redirect to `/login`.
- FR-7: The "Continue with company SSO" button is shown disabled until an OIDC flow is specified (open item OI-1).

## Non-functional requirements
- Accessible: labelled fields, `aria-invalid`/`aria-describedby` on errors, `role="alert"` for failures, visible focus rings, no axe violations.
- Credentials are held in memory only and the password field is cleared after sign-in.

## Acceptance criteria
- AC-1: Form renders with no axe violations.
- AC-2: Empty password shows the validation message and makes no network call.
- AC-3: A 401 shows a safe error alert.
- AC-4: Unauthenticated `/` redirects to `/login`; successful sign-in reaches the Assistant page with primary navigation.

## Security
Authorization remains server-side; the UI grants nothing. No secrets are stored in web storage or logged.

## Out of scope
OIDC redirect implementation, password reset, registration, remember-me.

## Open items
- OI-1: OIDC flow details (provider, redirect/PKCE handling) need an approved decision before the SSO button is enabled.
