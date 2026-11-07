# 013 Authentication and Authorization Service Extraction — Tasks

**Specification:** [spec.md](./spec.md) · **Plan:** [plan.md](./plan.md)

| ID | Task | Repository / target | Status | Depends on |
|---|---|---|---|---|
| A01 | Record the selected service boundary, current ownership, security invariants, and backlog traceability. | Specification: spec 013, decisions, backlog | Done: documentation only | Owner's boundary selection |
| A02 | Specify and approve detailed service API, caller and user identity trust, mTLS lifecycle, revocation/consistency, schema integrity, failure handling and migration/rollback mechanics. | Product / Security / Architecture / Specification: spec 013 and API contracts | Pending: owner selected consolidated directions; detailed design, named independent human reviewer and documented security/architecture review remain. Platform and operational owners are undecided. | A01 |
| A03 | Make the new `enterprise-knowledge-auth` repository available and agree its Go build, configuration and CI conventions. | Auth / Platform | Partially complete: sibling Git repository and README available; owner selected setup direction, but Go version, module plan, dependencies, layout and CI details remain to be documented and reviewed. | A02 for approved design; repository availability is independent |
| A04 | Implement Go identity provisioning, role/grant policy ownership and secure policy interfaces with tests. | Auth repository; exact paths to be established after repository setup | Pending | A02, A03 |
| A05 | Implement and rehearse forward data migration, grant/collection consistency, reconciliation and rollback. Preserve existing Flyway history. | Auth / Backend / Platform; migrations and operational scripts per approved design | Pending | A02, A04 |
| A06 | Integrate the backend with the new policy source while retaining identity validation, resource ownership checks and fail-closed enforcement for document, retrieval and citation paths. | Backend: `security/`, `documents/`, `chat/`, associated tests | Pending | A02, A04 |
| A07 | Adapt frontend auth and `/me` integration only as required by the approved contract; preserve login, session and no-access UX. | Frontend: `src/auth/`, `src/api/`, login/callback and tests | Pending | A02, A04 |
| A08 | Verify role/grant parity, revoked access, non-disclosure, service failures, provider-context isolation, migration and rollback across services. | Auth / Backend / Frontend / QA | Pending | A05, A06, A07 |
| A09 | Verify actual Keycloak login, audience, provisioning, renewal, no-grant behavior and sign-out. Carries the outstanding B04 / 004 K07 work. | Auth / Backend / Frontend / QA | Blocked: test realm/client/account configuration and integrated service required | A06, A07, A08 |
| A10 | Obtain explicit cutover approval; remove only superseded auth implementation, preserve enforcement, update contracts, setup docs, and backlog with evidence. | Auth / Backend / Frontend / Specification | Pending | A08, A09 |

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
