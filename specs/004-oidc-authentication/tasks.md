# 004 OIDC Authentication (Keycloak) — Tasks

**Specification:** [spec.md](./spec.md) · **Plan:** [plan.md](./plan.md)

| ID | Task | Repository | Files | Status |
|---|---|---|---|---|
| K01 | Record Keycloak in DEC-001 and related docs | Specification | `docs/implementation/product-decisions.md` and linked docs | Done |
| K02 | OIDC config parsing and client wrapper | Frontend | `src/app/config.ts`, `src/auth/oidcClient.ts` | Done |
| K03 | Auth provider, callback page, login SSO button | Frontend | `AuthProvider.tsx`, `AuthContext.ts`, `AuthCallbackPage.tsx`, `LoginPage.tsx`, `App.tsx`, `main.tsx` | Done |
| K04 | No-access notice and session-expired notice | Frontend | `AssistantPage.tsx`, `LoginPage.tsx` | Done |
| K05 | Dev proxy and environment example | Frontend | `vite.config.ts`, `.env.example` | Done |
| K06 | Automated tests | Frontend | `src/auth/oidc.test.tsx`, `src/app/config.test.ts` | Done (56 unit tests, e2e and build pass) |
| K07 | Manual end-to-end login against Keycloak | Frontend / Backend / Auth (planned) | — | Not started; tracked as B04 and future extraction task [A09](../013-auth-service-extraction/tasks.md). Current implementation needs test-realm configuration; target verification additionally needs the integrated service. |
| K08 | Backend `oidc` profile for Keycloak with local Ollama and configured API audience validation | Backend | `SecurityConfig.java`, `OidcAudienceValidator.java`, `application-oidc.properties`, security tests | Done (audience validator and OIDC profile tests pass; live Keycloak check remains K07) |
| K09 | Approve token lifetime and lockout values | Specification | — | Done — owner approved 5-minute token lifetime and lockout after 5 failed attempts (2026-11-03) |
