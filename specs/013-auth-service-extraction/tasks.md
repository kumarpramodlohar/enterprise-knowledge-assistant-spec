# 013 Authentication and Authorization Service Extraction — Tasks

**Specification:** [spec.md](./spec.md) · **Plan:** [plan.md](./plan.md)

**A02 review package:** [design-review.md](./design-review.md) is a draft; A02 remains incomplete. The owner removed independent human review as an implementation prerequisite. No review is claimed.

| ID | Task | Repository / target | Status | Depends on |
|---|---|---|---|---|
| A01 | Record the selected service boundary, current ownership, security invariants, and backlog traceability. | Specification: spec 013, decisions, backlog | Done: documentation only | Owner's boundary selection |
| A02 | Specify and review the service API, identity trust, mTLS, policy consistency, database controls, and migration and rollback mechanics. | Product / Security / Architecture / Specification: spec 013 and API contracts | Partially complete: draft design and synthetic prototype evidence exist; the real migration controls, operational procedures and applicable review evidence remain incomplete. See the breakdown below. | A01 |
| A03 | Make the new `enterprise-knowledge-auth` repository available and agree its Go build, configuration and CI conventions. | Auth / Platform | Partially complete: Go 1.27.3, a pinned pgx driver and a GitHub Actions workflow for formatting, tests, vet and package build exist. The workflow now requires the synthetic PostgreSQL integration test; equivalent local checks passed, but GitHub execution, deployment compatibility, production configuration, vulnerability checks, dependency review and migration tooling remain open. | Repository availability |
| A04 | Implement Go identity provisioning, role/grant policy ownership and secure policy interfaces with tests. | Auth repository: `cmd/auth-local`, `cmd/authd`, `cmd/auth-compat`, `internal/authserver`, `internal/contract`, `internal/cursor`, `internal/policy`, `internal/service`, `internal/httpapi`, `internal/postgres`, `internal/transport`, `internal/localapp`, `internal/compatibility` | Partially complete: the loopback server and deployment-configurable mTLS daemon use synthetic integration tests for policy flows, startup schema verification and fail-closed behavior. A guarded-schema candidate has synthetic tests for legacy and auth writes, freeze/drain, revision, restore epoch, cascades and restricted test logins. The candidate installer uses a non-superuser login and non-login owner; temporary install grants are removed. A read-only compatibility checker tests one candidate interpretation without printing identities; actual data and mappings remain unverified. This is not a deployment migration: reviewed deployment ownership and privileges, integrated migration, environment-specific restore, operational certificate/key procedures and production validation remain open. Backend integration is A06. | A03 setup as applicable |
| A05 | Implement and rehearse forward data migration, grant/collection consistency, reconciliation and rollback. Preserve existing Flyway history. | Auth / Backend / Platform; migrations and operational scripts per independently reviewed design | Pending | Applicable A02 migration design prerequisites; A04 as needed |
| A06 | Integrate the backend with the new policy source while retaining identity validation, resource ownership checks and fail-closed enforcement for document, retrieval and citation paths. | Backend: `security/`, `documents/`, `chat/`, associated tests | Pending | A04; applicable interface design |
| A07 | Adapt frontend auth and `/me` integration only as required by the approved contract; preserve login, session and no-access UX. | Frontend: `src/auth/`, `src/api/`, login/callback and tests | Done: retained the existing sign-in and `/api/v1/me` contract; the UI now maps `AUTHORIZATION_SERVICE_UNAVAILABLE` to a fixed safe message and tests that a mid-chat 403 discards prior answer/citations without retry. Frontend tests, typecheck and production build pass. Live backend/Keycloak verification remains A06/A09. | A04; applicable interface design |
| A08 | Verify role/grant parity, revoked access, non-disclosure, service failures, provider-context isolation, migration and rollback across services. | Auth / Backend / Frontend / QA | Pending | A05, A06, A07 |
| A09 | Verify actual Keycloak login, audience, provisioning, renewal, no-grant behavior and sign-out. Carries the outstanding B04 / 004 K07 work. | Auth / Backend / Frontend / QA | Blocked: test realm/client/account configuration and integrated service required | A06, A07, A08 |
| A10 | Obtain explicit cutover approval; remove only superseded auth implementation, preserve enforcement, update contracts, setup docs, and backlog with evidence. | Auth / Backend / Frontend / Specification | Pending | A08, A09 |

### A02: completion breakdown

The [design review package](./design-review.md) records the current proposals and prototype limitations. A02 is **not complete**, but it does not block general Go service implementation. Independent human review **before implementation** was removed; do not record it as a prerequisite or claim it occurred. Reviews specifically required for migration controls and manifests still apply before those controls are used, and cutover requires separate approval.

| Area | Current evidence | Remaining work and completion evidence |
|---|---|---|
| API, identity and cursor | Draft API and cursor designs; Go validation, cursor, orchestration and HTTP tests, plus a PostgreSQL store tested against a synthetic schema. A read-only checker tests actual request validators for a selected candidate interpretation without printing subjects. | Run compatibility verification with authorized, complete visibility of actual identity data and configured issuers; establish mappings independently. Complete integration tests using the real guarded schema for identity trust, response/error handling and revision-consistent scopes. Revise limits if incompatible; do not truncate. |
| Database freeze and revision | Separate guard and manifest prototypes and an auth-store guarded-schema candidate have disposable-database test evidence; none is production SQL. The candidate tests non-superuser installation and ownership, legacy and auth writes, freeze/drain and queued writes, revisions and overflow, cascade blocking, restricted logins and a frozen restore-epoch change. | Design and implement integrated real-schema controls, including legacy writes, revision updates, freeze/drain, collection changes, cascades, overflow and restore. Verify deployment ownership, privileges and concurrency against representative schema with restricted connections. Preserve existing Flyway history. |
| Migration, rollback and audit | A draft manifest/audit protocol and limited synthetic tests; the prototypes are not integrated. | Implement and review restricted forward and reverse procedures against protected, independently reviewed manifests, with transactional audit and an independent failure-alert channel. Test mismatch, replay, concurrent execution, audit and alert failures, and uncertain commit outcomes. Verify complete reconciliation, not just counts. |
| Identity mapping and legacy freeze | Legacy records are subject-only; the current OIDC provisioning path can attempt a no-op insert during freeze. | Establish trusted, unambiguous mapping evidence and protected manifest storage; test missing, conflicting and colliding identities. Design and test read-only resolution for existing users and guarded creation for new users during freeze. |
| Security operations | Draft mTLS, certificate and cursor-key lifecycle guidance. | Identify the platform, providers and responsible operators; document and test expiry alerts, rotation, compromise response and trust-removal propagation. Keep local CA and keys separate and secrets out of Git and logs. |
| Review and handoff | No independent human design review is documented. | Record actual scope, reviewer independence, findings and resolution evidence for applicable reviews. Complete reviewed, environment-specific migration and rollback procedures, backups and rehearsals before use; obtain separate cutover approval after the required verification. |

Use the [specification requirements and acceptance criteria](./spec.md) and [design review test matrix](./design-review.md#8-go-setup-and-validation-plan) to verify each item. Deployment-specific evidence and human review cannot be inferred from draft documents or synthetic tests. A05 tracks migration implementation and rehearsal: it can proceed as its applicable design prerequisites are met, without waiting for all A02 reviews and deployment evidence. In particular, FR-75 requires the manifest mechanism's design and review before implementing it; FR-73 and FR-77 retain their review requirements for migration use. A08 tracks cross-service verification, and A10 tracks cutover.

### Backend-parity work items

These are scoped substeps of the existing tasks, not completed implementation:

| Parent | Work item and verification | Target |
|---|---|---|
| A02 | Design and test how legacy OIDC resolution avoids its no-op insert for existing users during freeze while first-time creation remains atomic and guarded; cover concurrent freeze/create. | Specification and isolated synthetic database; later backend integration test |
| A02, A05 | Reconcile every subject-only legacy record with trusted issuer/local identity evidence; reject ambiguous mappings and collisions. Inventory historical document uploader/deleter and audit actor fields without rewriting them. | Specification, migration design and backend schema |
| A04, A06 | Carry authenticated typed identity to every auth-service call while retaining the public subject and document actor values. Test identical OIDC/local subject strings without merging permissions. | Auth and backend security, document and chat code |
| A06 | Preserve the Basic/OIDC profile matrix, JWT validation and public health exemption. Map filter-stage auth failures to the safe correlated 503 without assuming MVC advice handles them. Keep resource existence checks in Java, including `ADMIN` and nonexistent collection upload. | Backend security and document tests |
| A06, A08 | Implement and test protected-source rechecks around CRAG evaluator/refiner and final provider paths. Propagate denials and auth errors through asynchronous wrappers without baseline, external-search or insufficient-evidence fallback. | Backend chat and integration tests |
| A08, A09 | Verify current public `/me`, role/grant and actor parity, real Keycloak issuer/audience behavior and end-to-end migration freeze behavior; mock JWT tests alone are insufficient. | Auth, backend and live Keycloak test environment |

## Backlog and historical traceability

| Existing record | Treatment |
|---|---|
| B04, G5, spec 004 K07 | Existing live Keycloak evidence remains outstanding; A09 covers verification of the target architecture. B04 continues to block release evidence. |
| G1 | Authentication/authorization audit events split to G1-A; knowledge-backend audit work remains G1. |
| P1 | User, role and grant administration split to P1-A; collection administration remains P1. Neither is newly approved. |
| G9 | Cross-service identity, authorization, revocation and failure coverage tracked in G9-A/A08; retrieval and injection testing remain G9. |
| G7 | Login/session accessibility split to G7-A; Ask/Documents accessibility remains G7. |
| P8, G4 | Auth-service hardening tracked in P8-A; Go build/CI conventions are covered by A03. Existing platform and application work remains P8/G4. |
| P15 | Conditional multi-tenancy and isolation remain proposed cross-system work, not approved by this extraction. |
| Foundation T04, T20; spec 004 K01–K06, K08–K09; B05 | Historical completed implementation and verification records remain unchanged; they do not prove the future service is implemented or verified. |
| Foundation T18/T19; B09, G10 | Cross-system release/security and end-to-end gates remain outstanding; auth migration does not supersede them. |

See the [backlog](../../docs/implementation/Implementation_Backlog_v2.md). Splitting ownership does not imply the corresponding capability is approved or complete.
