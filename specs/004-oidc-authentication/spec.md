# 004 OIDC Authentication (Keycloak) — Specification

**Status:** Draft for review. Provider choice recorded in DEC-001 on the owner's instruction (2026-10-16). Implementation delivered in the frontend; end-to-end verification against a live Keycloak login is pending (see tasks).
**Related decisions:** DEC-001, DEC-006 audit expectations; specs/001 FR-01, AC-01; specs/002 login page.

## Problem
Deployed environments must authenticate users through the company identity provider instead of local passwords.

## Users
All roles. Identity comes from Keycloak; roles and collection grants stay in PostgreSQL (DEC-001).

## Functional requirements
- FR-1: The login page's "Continue with company SSO" starts Authorization Code flow with PKCE (S256) against the configured Keycloak realm.
- FR-2: The redirect callback `/auth/callback` exchanges the code, loads the identity from `GET /api/v1/me`, and opens the Ask page.
- FR-3: API requests carry the access token as `Authorization: Bearer`; the backend validates the token (issuer, signature, expiry) and resolves roles and grants from the token `sub`.
- FR-4: On first login the backend creates the user as `MEMBER` with no grants (T20). A user with no readable collections sees "You do not have access to any collections yet. Contact your administrator."
- FR-5: Access tokens are renewed silently with the refresh token. If renewal fails, or any call returns 401, the session ends, the user returns to `/login`, and a notice says the session expired.
- FR-6: Sign-out clears in-memory tokens and ends the Keycloak session, returning to `/login`.
- FR-7: SSO is enabled only when `VITE_OIDC_AUTHORITY` and `VITE_OIDC_CLIENT_ID` are both set; setting only one is a configuration error.
- FR-9: Authentication configuration is independent of AI provider selection: `local` uses HTTP Basic; adding `oidc` uses Keycloak tokens only and disables Basic. AI providers are selected separately as defined by DEC-002. `local` and `deployed` remain mutually exclusive where both names are used as profiles.
- FR-8: The local username/password form remains for development; production builds with OIDC configured hide it.

## Non-functional and security requirements
- No client secret in the browser; the Keycloak client is public with PKCE S256, standard flow only, direct access grants and implicit flow off.
- Tokens are held in memory only. Only the transient redirect state (no tokens) uses sessionStorage. A page reload therefore requires signing in again (the Keycloak session makes this quick).
- Provider and server error details are never rendered; fixed messages only.
- The UI grants nothing; every request is authorized server-side. Inaccessible resources return 404.
- Failed-login lockout and token lifetimes are Keycloak realm settings (suggested: access token 5 min, brute-force lockout after 5 failures). These are proposals, not approved values.

## Keycloak configuration (realm `eka`)
- Client `eka-frontend`: public, standard flow on, PKCE S256, valid redirect URIs `<frontend origin>/*`, post-logout redirect `<frontend origin>/login`, web origins `<frontend origin>`.
- Backend: profile with `EKA_OIDC_ISSUER_URI=<keycloak>/realms/eka`.
- Frontend: `VITE_OIDC_AUTHORITY=<keycloak>/realms/eka`, `VITE_OIDC_CLIENT_ID=eka-frontend`.
- Use one host spelling (`127.0.0.1` or `localhost`) everywhere; the issuer must match the token `iss` exactly.

## Acceptance criteria
- AC-1: With OIDC configured, the SSO button starts the provider redirect; without it, the button is disabled with an explanatory note.
- AC-2: A successful callback results in an authenticated session and bearer-authenticated API calls.
- AC-3: A failed callback shows a fixed message and a link back to sign in, with no provider detail.
- AC-4: Token renewal failure returns the user to `/login` with an expiry notice.
- AC-5: Sign-out calls the provider sign-out.
- AC-6: A user with no grants sees the no-access notice.
- AC-7: A real login against Keycloak yields `GET /me` success and `MEMBER` provisioning (manual verification, pending).

## Out of scope
Admin UI for roles and grants, mapping Keycloak roles to EKA roles, social login, multi-realm or multi-tenant support, rate limiting in EKA.

## Open items
- OI-1: Resolved. The backend `oidc` profile adds Keycloak token validation to any profile. AI provider selection is independent of authentication. See DEC-002 for supported local/development provider combinations and embedding re-indexing requirements.
- OI-2: Approve the suggested token lifetime and lockout values.
- OI-3: Whether the `aud` claim should be validated by the backend.
