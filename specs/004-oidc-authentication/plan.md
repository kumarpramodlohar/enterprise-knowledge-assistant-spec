# 004 OIDC Authentication (Keycloak) — Plan

**Specification:** [spec.md](./spec.md)

## Architecture
The SPA signs in with Authorization Code + PKCE through `oidc-client-ts` and sends the access token as a bearer token. The existing Spring Security OAuth2 resource server (non-`local` profiles) validates it and `OidcUserProvisioningFilter` provisions the user. No API contract changes.

## Components (frontend)
- `src/app/config.ts`: parses and validates `VITE_OIDC_AUTHORITY` and `VITE_OIDC_CLIENT_ID`.
- `src/auth/oidcClient.ts`: wraps `UserManager` (in-memory user store, sessionStorage redirect state, silent renew).
- `src/auth/AuthProvider.tsx` and `AuthContext.ts`: `signInWithOidc`, `completeOidcSignIn`, session-end handling, sign-out.
- `src/pages/AuthCallbackPage.tsx`: handles `/auth/callback` exactly once.
- `src/pages/LoginPage.tsx`: SSO button, expiry notice, local form visibility.
- `src/pages/AssistantPage.tsx`: no-access notice.
- `vite.config.ts`: dev proxy for `/api` so no CORS is needed locally.

## Dependencies
`oidc-client-ts`; Keycloak realm `eka` with client `eka-frontend`.

## Security considerations
Public client with PKCE; tokens in memory; fixed error text; server authorization unchanged; backend validates the issuer and signature. Cross-origin deployments would need backend CORS (not added; proxy or same-origin hosting is assumed).

## Testing strategy
- Vitest: config validation, SSO button states, callback success and failure, expiry, sign-out, no-access notice (all with a fake OIDC client).
- Manual: real Keycloak login, `/me`, first-login provisioning, token renewal, sign-out.
