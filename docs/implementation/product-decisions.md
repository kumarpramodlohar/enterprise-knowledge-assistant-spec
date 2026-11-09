# Product and Architecture Decisions

Decisions that unblock the [Implementation Backlog](Implementation_Backlog_v1.md). Date: 2026-10-09. Owner: Product owner.

If a decision changes, update this file first, then the affected spec or task.

| ID      | Topic                                | Decision                                                    | Status                      |
| ------- | ------------------------------------ | ----------------------------------------------------------- | --------------------------- |
| DEC-001 | Authentication                       | Local dev mode + OIDC                                       | Approved                    |
| DEC-002 | AI providers                         | Ollama/OpenAI independently selectable for chat and embeddings in local/dev; Ollama defaults locally, OpenAI when deployed | Approved |
| DEC-003 | Upload limits                        | 10 MB, extension + content check                            | Approved                    |
| DEC-004 | Duplicate uploads                    | Reject with 409                                             | Approved                    |
| DEC-005 | Original files                       | Not stored                                                  | Approved                    |
| DEC-006 | Deletion                             | Soft delete, purge after 7 days                             | Approved                    |
| DEC-007 | RAG tuning values                    | Starting values below                                       | Approved                    |
| DEC-008 | MVP scope                            | Optional features deferred                                  | Approved                    |
| DEC-009 | Document extraction libraries        | Apache PDFBox (PDF), Apache POI (DOCX), plain read (TXT/MD) | Approved                    |
| DEC-010 | Corrective RAG (CRAG) and web search | P1–P4 approved; external search has dual opt-in and defaults off | Approved |
| DEC-011 | Ask-page labels and collection display | Keep API role labels and collection IDs; no persona mapping or display-name API change | Approved |
| DEC-012 | Documents-page search, pagination, upload navigation and processing actions | Add case-insensitive literal filename-substring search; show 20 documents per page; make Upload navigation open the existing Documents upload form; reject re-index/delete while ingestion is queued or processing | Approved |
| DEC-013 | Authentication and authorization service boundary | Plan a separate Go auth service owning identity provisioning, roles, grants, and policy decisions; retain Keycloak and backend-side identity validation and enforcement | Owner-selected direction; detailed design pending |
| DEC-014 | EKA application-evaluation framework | Use DeepEval as the selected framework for future application evals; preserve the current runner until an integration pilot confirms runtime and metric coverage | Owner-selected direction; pilot and spec approval pending |
| DEC-015 | EKA evaluation automation and experiment tracking | Use GitHub Actions to orchestrate evaluation runs and MLflow to track run parameters, metrics, lineage, and report artifacts; keep logs for diagnostics, not as the experiment record | Owner-selected direction; spec approval and hosting/data controls pending |
| DEC-016 | Live deployment evaluation gate | Gate live deployments on approved thresholds and no unacceptable regressions against an accepted compatible baseline; do not gate local development | Owner-selected direction; gate policy and implementation pending |

---

## DEC-001: EKA-01 - Authentication

**Decision:** Support two modes through Spring Security.

- **Local dev mode:** simple local users for development and tests only.
- **Deployed environments:** OIDC provider (Spring Security OAuth2 resource server validating tokens).

**Notes**

- Local dev mode must be disabled by default outside the `local` profile.
- Roles and collection permissions are stored in PostgreSQL and mapped from the user's identity subject.
- **OIDC provider: Keycloak** (owner instruction, 2026-10-16). The backend still uses standard OIDC, so the provider stays replaceable.
- **OIDC token policy:** Access-token lifetime is 5 minutes; Keycloak brute-force lockout begins after 5 failed attempts (owner approval, 2026-11-03).
- **OIDC audience:** The backend requires a configured `EKA_OIDC_AUDIENCE` and rejects tokens whose `aud` claim does not contain it (owner approval, 2026-11-03). Keycloak must issue the configured API audience.
- **Frontend flow:** Authorization Code with PKCE for a public client (no client secret), using `oidc-client-ts`; tokens are kept in memory only. Details: [specs/004-oidc-authentication](../../specs/004-oidc-authentication/spec.md).
- **Future direction:** DEC-013 selects a separate Go auth service boundary. The current DEC-001 implementation remains in force until migration is verified and cutover is separately approved.

**Affects:** EKA-04, EKA-06, EKA-20

## DEC-002: EKA-01 - Chat and embedding providers

**Decision:** Both Ollama and OpenAI are supported in local and development environments. Chat and embedding providers are independently selectable through backend configuration, so either provider can be used for each capability, including a mixed setup. Deployed environments default to OpenAI. Selection is made at backend startup; changing providers does not require source edits, but does require a restart.

**Notes**

- Ollama and OpenAI embedding models may have different dimensions. The active embedding configuration uses its matching isolated vector table/index; changing embedding provider or model requires re-indexing all documents into that index before they are searchable there. Chat-provider changes do not require re-indexing.
- A single running backend uses one configured chat provider and one configured embedding provider. Both integrations may be configured in the same environment, but this decision does not promise automatic failover or simultaneous fan-out to both providers for one request.
- Similarity scores differ per model, so the evidence threshold (DEC-007) is set per profile and tuned during evaluation.
- Remove unused starters (Anthropic, Pinecone) from `build.gradle` in EKA-02.
- Specific model names are set in configuration during EKA-02.

**Affects:** EKA-02, EKA-11, EKA-16, EKA-20

## DEC-003: EKA-01 - Upload limits and validation

**Decision:**

- Maximum file size: **10 MB** per file.
- Allowed types: PDF, DOCX, TXT, Markdown.
- Validation: file extension **and** server-side content check. Client-supplied content type is never trusted alone.

**Affects:** EKA-07, EKA-08, EKA-09

## DEC-004: EKA-01 - Duplicate uploads

**Decision:** Reject a duplicate with **409 Conflict** when the same file checksum already exists in the same collection.

**Notes**

- Soft-deleted documents (DEC-006) do not count as duplicates, so a deleted file can be uploaded again.
- The error message tells the user which document already exists, only if they can access it.

**Affects:** EKA-03, EKA-05, EKA-07, EKA-08

## DEC-005: EKA-01 - Original file retention

**Decision:** Original files are **not stored**. Only extracted text, chunks, vectors and metadata are kept. Temporary upload files are deleted after processing, on success or failure.

**Notes**

- Re-indexing therefore needs the stored chunk text (or a new upload) because the original file is gone. For the MVP, re-index reuses stored extracted text.
- Changing the extraction logic requires re-uploading the file.

**Affects:** EKA-07, EKA-09, EKA-12, EKA-13

## DEC-006: EKA-01 - Deletion

**Decision:** **Soft delete.**

1. Deletion marks the document as deleted. It is excluded from retrieval, listings and citations immediately.
2. Records are kept for **7 days**.
3. After 7 days, a purge job permanently removes chunks, vectors and derived records.
4. Each deletion and purge is written to the audit log.

**Notes**

- Deleted content still exists in the database for up to 7 days but is not reachable through the API.
- Purge failures are retried and logged.

**Affects:** EKA-03, EKA-13, EKA-14

## DEC-007: EKA-01 - Initial RAG tuning values

All values are configurable and will be tuned during evaluation (EKA-19).

| Setting                                 | Initial value |
| --------------------------------------- | ------------- |
| Chunk size                              | 800 tokens    |
| Chunk overlap                           | 100 tokens    |
| Top-K                                   | 5             |
| Context budget                          | 4000 tokens   |
| Minimum similarity (evidence threshold) | 0.70          |
| Ingestion worker concurrency            | 2             |

**Affects:** EKA-02, EKA-10, EKA-12, EKA-15, EKA-16

## DEC-008: EKA-01 - MVP scope of optional features

**Decision:** The following are **deferred** (not in MVP):

- Hybrid (keyword + vector) retrieval
- Reranking
- Answer feedback
- Conversation history
- Kafka or other message broker for ingestion (use the bounded executor with persisted jobs)

**Notes**

- Without conversation history, questions and answers are not stored.
- These can be added after the MVP baseline evaluation.
- CRAG-style corrective retrieval (evaluator, refinement, query rewrite, web search) is also not in the MVP; see DEC-010.

**Affects:** EKA-17, EKA-19

## DEC-009: Document extraction libraries

**Status:** Approved by product owner on 2026-11-03.

**Proposal:** Keep the existing extraction libraries: Apache PDFBox for PDF, Apache POI (`poi-ooxml`) for DOCX, and plain text reading for TXT and MD. Do not add LangChain Community (Python/JavaScript only, not usable in the Java backend) or LangChain4j.

**Rationale**

- Already implemented with the page/character limits and DOCX zip-bomb guards.
- Gives the page and section data needed for citations.
- Smaller attack surface than a multi-format parser such as Apache Tika, for untrusted uploads.
- Avoids a second AI framework alongside Spring AI.
- Approved MVP formats (PDF, DOCX, TXT, MD) are fully covered.

**Reconsider when:** formats such as PPTX, XLSX, HTML or scanned PDFs (OCR) are added. Then evaluate Apache Tika or a dedicated parser for those formats only; a spec update is required first.

**Notes:** Spring AI `Document` may be used as the in-memory type for extracted text and metadata.

**Affects:** EKA-02, EKA-10

## DEC-010: Corrective RAG (CRAG) and web search

**Status:** P1–P4 approved by product owner on 2026-10-22. Owner authorized proceeding despite incomplete MVP baseline evaluation; T18/T19 remain blocked.

**Baseline (MVP):** retrieve, apply the similarity evidence threshold (DEC-007), then generate or return insufficient evidence. No per-document evaluator, refinement, query rewrite, or web search.

**Approved phases and defaults:**

- P1 prompted evaluator using configured chat model; ambiguous results abstain.
- P2 refine correct passages by selecting validated source strips.
- P3 allow at most one query rewrite and re-retrieve with the same authorization scope and metadata filters.
- CRAG disabled by default; evaluate up to five passages; 60-second CRAG-stage timeout; stage failures fall back to MVP behavior.
- Do not add corrective-action API/UI messaging.

**P4 web search:** Approved as a bounded Tavily Search API fallback only after internal corrective retrieval fails. Requires both `EKA_WEB_SEARCH_ENABLED=true` with a server-side API key and request `allowExternalSearch=true` (frontend unchecked by default). Sends only the user's question and fixed search options; no passages, filenames, collection/user identifiers, or conversation history. Do not log or persist question/provider bodies. Search result snippets are untrusted; no raw-page extraction/provider answer. Citations are typed INTERNAL/EXTERNAL; external sources expose validated HTTPS URL, title, and snippet. P4 does not run on ambiguous or initial no-hit branches. Search failures abstain. Existing CRAG remains disabled by default.

**Baseline limitation:** Existing 30-case reports are not human reviewed and show zero Recall@5 at threshold 0.70. This is not representative quality evidence and does not complete T18/T19. See [specs/005-corrective-rag](../../specs/005-corrective-rag/spec.md).

**Affects:** EKA-15, EKA-17, EKA-19 (future)

## DEC-011: Ask-page labels and collection display

**Status:** Approved by the product owner on 2026-11-03.

**Decision:** Continue displaying the API-authoritative role labels (Administrator or Member) and collection IDs. Do not map roles to Figma persona names or add collection display names to the API in the current scope.

**Affects:** Ask-page copy and collection selection; no backend API change.

## DEC-012: Documents-page management flow

**Status:** Approved by the product owner on 2026-11-07.

**Decision:**

- Add server-side, case-insensitive literal substring search over permitted document filenames. Search narrows results and composes with the existing collection and status filters; it never broadens authorization.
- Add Documents-page pagination controls using 20 results per page. The API's existing maximum page size remains 100.
- Add an Upload navigation item that opens the existing upload form on the Documents page; do not create a separate upload page.
- Disable re-index/retry and delete controls while a document is `QUEUED` or `PROCESSING`, and enforce the same restriction in the backend. Requests in those states return HTTP 409 with `DOCUMENT_BUSY`. Existing authorization checks remain mandatory.
- Preserve the current EKA visual design, collection IDs, upload validation, and all other document lifecycle behavior.

**Rationale:** These changes make the Documents UI's available actions, search scope, and result navigation explicit while keeping the existing single-workspace product and backend-authoritative authorization model.

**Affects:** Documents-page specification 006, API Contract v1, frontend and backend document-list/lifecycle behavior.

## DEC-013: Authentication and authorization service boundary

**Status:** Owner-selected direction (2026-11-07); detailed design and cutover pending review and approval.

**Direction:** Create a separate Go service to own identity provisioning, application roles, collection grants, and authorization policy decisions. Retain Keycloak. The Java knowledge backend continues to validate caller identity and enforce authorization before accessing protected content, returning citations, or supplying context to an AI provider. Preserve existing authentication and authorization behavior throughout migration.

**Backlog treatment:** Transfer ownership of auth-only pending work, split mixed work, and retain historical records and dependencies. See [specification 013](../../specs/013-auth-service-extraction/spec.md).

**Design directions approved by the owner (2026-11-07):**

- Use an internal HTTPS/JSON API supporting permission checks and bounded authorized-collection lists. Authenticate backend-to-auth calls with mutual TLS.
- Permit only authorized, mTLS-authenticated Java backend callers to assert a user subject after validating that user's authentication. The auth service must not trust a subject asserted by a browser or other unauthorized caller; the local Basic trust path requires the same protections.
- Initially use an auth-owned schema in the existing PostgreSQL deployment with separate least-privilege access. The collection-reference integrity mechanism remains to be designed.
- Prefer a cross-schema foreign key for grants referencing backend-owned collections; approve its privileges and collection creation/deletion lifecycle before implementation.
- Request fresh authorization for each protected operation without an authorization-decision cache. Recheck before sending protected context to an AI provider and before returning protected citations or content. These checks reduce, but do not by themselves eliminate, in-flight revocation races; define the remaining guarantee before implementation.
- Initially retain local Basic sign-in, direct Keycloak PKCE browser sign-in, and the Java `/api/v1/me` contract. The backend obtains target-architecture policy from the auth service; do not remove local Basic until a safe replacement is separately approved and verified.
- Migrate with a single policy authority at each stage, reconciliation, a rollback rehearsal, and separate cutover approval. Defer new administration UI/API and expanded audit-event features; retain existing required audit behavior.

**Additional design directions approved by the owner (2026-11-07):**

- Use versioned internal JSON APIs for provisioning, permission checks, and paged authorized scopes. Require complete, consistent scope results and fail closed if limits are exceeded; preserve the complete `/api/v1/me` contract.
- Allow subject assertions only from explicitly configured backend mTLS client identities after Java authenticates the user. Reject unknown, expired, or untrusted certificates; do not trust browser-supplied identity headers.
- Use deployment-managed CA and client/server certificates with rotation and expiry rejection. Use a separate local-development CA and keep private keys outside Git; never fall back to unauthenticated production transport.
- Accept point-in-time authorization checks and the remaining race after each check as an initial limitation; define and test the check boundaries. Data already sent cannot be recalled.
- Fail closed with a safe 503 for auth-service timeout, unavailability, or invalid responses. Start with a configurable two-second total deadline and at most one retry for explicitly idempotent reads; retain non-disclosing 404 for resource denials.
- Use separate least-privilege runtime and migration database roles and preserve the cross-schema collection foreign key with cascading grant deletion. Test collection lifecycle and privilege boundaries.
- Freeze policy writes during migration and cutover, reconcile users and grants, and rehearse rollback. Before rollback, freeze writes and reverse-reconcile all post-cutover changes so revoked grants are not restored. Cutover still needs separate approval.
- For paged authorized scopes, return a global policy revision on the first page and atomically check it against scope-affecting changes on subsequent pages. Changes to roles, grants, or collection lifecycle that affect scopes, including cascading grant deletion, invalidate ongoing reads for all users. Discard accumulated pages on mismatch; restart only within the existing deadline and retry limit, otherwise return a safe 503. Each protected operation starts a fresh read.
- Start with a configurable maximum of 10,000 distinct authorized collection IDs per user across readable and manageable scopes; count an ID present in both only once. Exceeding the limit fails closed with a safe 503 rather than returning a truncated scope.
- Use separate internal operations to provision or resolve an authenticated user, check a requested collection permission, and read the user's role and paged collection scopes. Selected paths, field shapes, pagination and error categories are recorded below; remaining contract details require review.
- Return one scope entry per authorized collection with its effective `READ` or `MANAGE` permission, plus role, global revision and a continuation cursor when more pages exist. Java reconstructs the unchanged `/api/v1/me` lists; `MANAGE` implies `READ`, and `ADMIN` scopes include all applicable collections subject to the limit.
- Successful permission evaluations return explicit `ALLOW` or `DENY`; malformed requests and failed or invalid evaluations are errors and fail closed. Denials for protected resources remain non-disclosing 404s. Java independently establishes resource existence and collection ownership; `ALLOW` alone does not do so.
- Use stateless integrity-protected continuation cursors bound to the authenticated backend caller, asserted user, query and global revision. Verify each cursor and independently check the current revision atomically; invalid or mismatched cursors fail closed. Cursors do not cache or grant authorization, and signing does not encrypt their contents.
- Maintain the global revision in PostgreSQL with triggers on scope-affecting role, grant and collection changes, including cascading grant deletion. The change and revision update commit or roll back together; each scope page reads its revision, role and data from one consistent snapshot. Trigger privileges, migration, concurrency and lifecycle mechanics require security review.
- Authorize authenticated backend client certificates by exact match of their URI SAN against a deployment-configured allowlist; the backend validates the auth server certificate and expected server identity. Certificate issuance, revocation and local setup remain open.
- Distinguish OIDC identities by validated issuer and subject and local identities by a separately configured local namespace and username. Preserve the public `/api/v1/me` subject and require verified migration mappings; ambiguous mappings stop migration without silently merging accounts or transferring grants. This does not approve additional issuers or multi-tenancy.
- Use freeze-and-copy migration: pause policy writes, take a consistent users/grants snapshot, explicitly map identities, copy to the auth-owned schema, and reconcile every role and grant. Stop on ambiguous mappings, missing collections, conflicts or mismatches. Java remains authoritative until verification and separate cutover approval; resume writes only after a single authority is established. The runbook, rollback and outage plan remain open.
- During the migration freeze, block first-time user provisioning, policy writes and scope-affecting collection changes. Existing authenticated users may continue read-only access only while the current authority can enforce fresh authorization; otherwise fail closed. Blocked writes receive a safe temporary service-unavailable response without partial changes. Exact operations and messages remain open.
- Initially respond to a compromised backend client certificate by removing its URI SAN from the allowlist and terminating existing connections for that identity. This blocks all certificates sharing the identity. Restore service with a new URI SAN and certificate while keeping the compromised identity blocked; re-enable the old identity only after separately verifying the compromised certificate cannot authenticate. Lifetimes, propagation deadlines, in-flight requests, the procedure and server-certificate compromise handling remain open.
- Block rollback on identity collisions, unmappable users, missing collections, or role/grant mismatches. Keep policy writes frozen, resolve conflicts and rerun reverse reconciliation before switching authority, except when invoking the controlled emergency abort described below. Fail closed when operations cannot be safely authorized; do not drop or broaden grants to complete rollback.
- Give the auth runtime database role read-only access to the backend-owned collection ID column for complete `ADMIN` scopes, not document content or other collection fields. Keep migration privileges separate; exact grants, trigger privileges and ownership require security review.
- Use backend-only `POST /internal/v1/users/resolve`, `POST /internal/v1/permissions/check`, and `POST /internal/v1/scopes/page` with identity information in request bodies. Scope pages are logically read-only; user resolution may write and must not be automatically retried under the current retry policy. Detailed validation and transaction mechanics remain open.
- Each operation carries a typed identity assertion: validated issuer and subject for OIDC, or configured local namespace and authenticated username for local Basic. Reject malformed or unsupported assertions and untrusted callers; do not send passwords or bearer tokens. Issuer and namespace configuration remain open.
- Preserve existing user resolution: provision missing OIDC users as `MEMBER` without grants and do not change existing roles or grants; do not automatically provision local users. An unknown local user retains `NONE`, empty scopes and denied protected access. First-time OIDC provisioning remains blocked during the migration freeze.
- Start with a configurable scope-page default of 100 entries and maximum of 500; reject invalid or oversized requests. Retain the total scope limit and deadline, and measure large-scope behavior with integration and load tests.
- Approve the internal identity, user-resolution, permission-check and scope-page JSON field shapes in [specification 013 FR-37](../../specs/013-auth-service-extraction/spec.md); validation limits and key-management details remain open.
- Approve the internal HTTP error categories and public fail-closed mapping in [specification 013 FR-38](../../specs/013-auth-service-extraction/spec.md); specific status-to-code mappings are recorded in FR-58.
- Use deployment-managed cursor signing keys outside Git and logs, with one active key and bounded previous-key verification overlap accounting for clock skew. Start with a configurable 60-second maximum lifetime; reject expired, tampered, unsigned or unknown-key cursors and fail closed on unusable key configuration. The selected algorithm is recorded below; secret-management product and rotation procedure remain open.
- Order scope entries by PostgreSQL native UUID order and use keyset pagination based on the last returned collection ID, with revision checks and consistent snapshots. Exact SQL and indexes remain open.
- A complete scope read shares one retry allowance: retry one explicitly idempotent failed page or restart once after a revision change, not both. All pages and the retry must fit the configured total deadline; otherwise discard partial pages and return a safe 503. User resolution remains non-retried.
- OIDC resolution is idempotent at the data level with a unique issuer-and-subject identity. Concurrent or later resolution must not alter existing roles or grants; the write freeze blocks first-time creation. This does not authorize automatic retries. Exact transaction and constraint mechanics remain open.
- Approve the internal error-envelope direction and codes in [specification 013 FR-43](../../specs/013-auth-service-extraction/spec.md), including the planned public `AUTHORIZATION_SERVICE_UNAVAILABLE` 503. Validation limits remain open; the public addition is not yet implemented.
- Independently allowlist asserted OIDC issuers; accept local assertions only in an explicitly configured local-development deployment for its configured local namespace, never in production. Java still authenticates each user first. This does not approve additional issuers or multi-tenancy.
- Enforce the migration write freeze with a database guard and application handling. Block affected writes from ordinary runtime roles, limit a controlled migration role to approved copy and reconciliation work, and verify the freeze and drain or finish in-flight writes before the snapshot. Exact roles, guard mechanism, privileges and recovery procedures require design, tests and security review.
- Sign continuation cursors with HMAC-SHA-256 using a dedicated cryptographically random secret of at least 256 bits securely shared among auth-service instances. Follow the approved key-rotation overlap and keep the secret outside Git and logs. Signing does not encrypt cursor contents; exclude raw sensitive identity information and review privacy-safe binding.
- Use deployment-managed automatic issuance and renewal of mTLS certificates before expiry, with controlled overlap during routine rotation and removal of the old certificate. Failed renewal or validation must fail closed without disabling mTLS or accepting expired certificates. Provider, lifetime, compromise-response deadlines and exact procedures remain open.
- The backend validates the auth-server certificate against its trusted CA and the deployment-configured hostname via a DNS SAN. Reject expired, untrusted or hostname-mismatched certificates without a production hostname-verification bypass. Local development uses its separate CA and a matching hostname.
- Initially terminate backend-to-auth mTLS at the auth service itself, which validates the client certificate and allowlisted URI SAN. A proxy may pass encrypted traffic through but may not terminate TLS or supply the backend identity in an HTTP header; changing this trust boundary requires separate design and approval.
- On cursor-key compromise, immediately remove the key from signing and verification across all auth-service instances, replace it and reject its cursors rather than retaining it for routine overlap. Discard partial reads and fail closed; a fresh read is allowed only within the approved deadline and retry budget. Verify propagation to every instance and account for delay in the incident procedure.
- Recheck all protected model-context sources, not only final citations. A pre-submission denial prevents sending affected context; a denial after submission but before the response discards the entire generated answer and citations. Return a generic `403 FORBIDDEN` without source or existence details for a genuine mid-request chat denial, not insufficient evidence; failed checks return a safe 503. Coordinate public-contract and UI changes. Do not automatically rerun chat after a genuine denial; a user-initiated new request authenticates and authorizes afresh without reusing protected context or the discarded answer. Provider data already sent cannot be recalled.
- Apply the configurable two-second authorization deadline to each checkpoint, shared by all its auth-service calls and permitted retries. Later checkpoints get a fresh deadline and fresh policy information. The overall chat-request timeout remains a separate open decision.
- For urgent revocation during a migration or rollback freeze, stop the operation, block protected operations that cannot be safely authorized, and keep the current authority unchanged. Restore writes only to that authority under a controlled procedure and apply and verify the revocation. Discard the snapshot and reconciliation; a later attempt requires a new freeze, snapshot and reconciliation. Operator access and detailed procedures remain subject to security review.
- Document a separate local-development CA issuing server and backend-client certificates. Keep private keys outside Git, validate server hostname and client URI SAN, and prevent production from trusting the local CA or certificates. Exact commands, hostnames, locations and tooling remain open; no unauthenticated transport fallback is permitted.
- Bind cursors to caller, user, query and revision using a keyed digest of their canonical representation rather than raw user identity fields. Recompute it on each page using a key separated from the signing key; do not log cursors or their contents. Key derivation, encoding, rotation and comparison require security review; the digest can reveal equality and does not encrypt.
- Approve the internal status-to-code mappings in [specification 013 FR-58](../../specs/013-auth-service-extraction/spec.md), and safe internal `500 INTERNAL_ERROR` for unexpected failures as specified in FR-59.
- Represent the global revision as an epoch and monotonic counter, opaque to API consumers. Scope-affecting transactions increment the counter; change the epoch before authorization traffic resumes after restore or reinitialization so old cursors cannot become valid again. Guard and trigger atomicity, overflow handling and restore procedure remain open.
- Use a reviewed, evidence-backed migration mapping manifest for every existing policy record, identifying the target OIDC or local identity. Validate completeness and ambiguity; stop on missing or ambiguous mappings and reconcile every role and grant. Protect the manifest and keep it out of Git and logs. Format, evidence, reviewer and secure storage remain open.
- The owner approved consolidated directions for least-privilege database roles and transactional guard testing; managed certificate and secret operations; gated forward and reverse migration; strict API validation; authorization checkpoint inventory; explicit issuer/audience configuration; and preservation of required audit behavior. Details and acceptance requirements are recorded in [specification 013 FR-62–FR-71](../../specs/013-auth-service-extraction/spec.md).
- The owner initially retained a documented independent human security and architecture review before implementation, but subsequently removed that prerequisite on 2026-11-07. The user named Pramod as an architect reviewer; independence, scope, findings and evidence have not been established, and no completed review is claimed. The A03 Go setup direction proposes a module path matching the auth GitHub remote, standard Go checks and platform-appropriate CI; concrete version and tooling remain to be reviewed.
- For rollback reconciliation under freeze, use a separate restricted reverse-migration identity for reviewed old-policy operations. Record forward and reverse privileged migration operations in a protected database-backed audit mechanism, and abort an operation if its required audit record cannot be written. Exact scope, audit integrity, failed-attempt reporting and operational procedures remain open for independent review.
- Enforce both migration directions against protected, reviewed manifests through database procedures rather than direct policy-table writes. Report failed and rolled-back attempts via an independently protected operational audit/log channel with operator alerts and no sensitive policy data. Manifest semantics, delivery failure, ownership and operational controls require detailed design and independent review.
- For each run, check direction, operation, identity and expected old/new values against the activated reviewed manifest and reject replay. If failure-alert delivery cannot be confirmed, stop and surface an explicit operator error; reconcile uncertain commit outcomes before retry. Use the draft strict API and cursor defaults only after existing-data compatibility is verified. For the Go service, select a supported patched Go release, standard-library HTTP/TLS/crypto, reviewed pinned PostgreSQL driver and forward-only migrations, with formatting, vet, tests, vulnerability checks and build in CI.
- The owner removed the pre-implementation independent human review gate while retaining separate later cutover approval. Production platform, providers, operators and measurable operational thresholds remain deployment prerequisites rather than invented selections; no production database work is authorized by these design choices.

These are approved choices, not a finished security design: validation limits, configured page-size rules and scope-limit enforcement, trigger and snapshot mechanics, privacy-safe cursor binding, secret management, rotation and error mapping, identity mapping mechanics, certificate and incident procedures, schema privileges, operational deadlines and the migration/rollback runbook remain to be specified and reviewed. A02 remains pending.

**Current baseline:** DEC-001, the existing OIDC specification and current API contract remain authoritative until changes are explicitly approved and implemented.

## DEC-014: EKA application-evaluation framework

**Status:** Owner-selected direction (2026-11-09); integration pilot and spec 011 approval pending.

**Decision:** Use DeepEval as the selected framework for future EKA application evals, including RAG chatbot evaluation and, if separately specified, future agent-workflow evaluation. Retain the current Node.js evaluation runner and its CLI/output compatibility until a bounded integration pilot confirms the supported DeepEval runtime, required metric coverage, and fit with the versioned EKA dataset and report contracts. Do not start implementation of the new pipeline until spec 011 and its blocking decisions are approved.

**Constraints:**

- DeepEval supplements, but does not replace, EKA's deterministic checks, human review, authorization tests, safety cases, or operational measurements. Add custom checks where framework metrics do not satisfy approved EKA criteria; do not duplicate the same metric in multiple scoring paths.
- LLM-judge results remain advisory until calibrated against human labels under spec 011 FR-13.
- Do not send confidential questions, answers, or retrieved passages to external judges or hosted services without explicit data-egress approval. Dataset and report formats remain versioned and language-neutral.
- The integration pilot must verify any TypeScript/JavaScript SDK path against the needed metrics and existing Node.js runner. Use a separate Python component only if the pilot shows the required coverage cannot be delivered cleanly in the current runner; preserve the shared JSON dataset/report contract.

**Affects:** [specification 011](../../specs/011-evaluation-pipeline/spec.md), its plan and tasks, the [evaluation guide](../Enterprise_Knowledge_Assistant_Evaluation_Guide_v1.md), and future backend evaluation tooling.

## DEC-015: EKA evaluation automation and experiment tracking

**Status:** Owner-selected direction (2026-11-09); spec 011 approval and hosting/data controls pending.

**Decision:** Use GitHub Actions to trigger and run approved offline EKA evaluation jobs, and MLflow to track experiment parameters, computed metrics, run lineage, and references to redacted reports. GitHub Actions is the CI/orchestration layer; MLflow is the experiment-tracking layer. Job logs are for execution diagnostics and must not be the canonical metric or experiment record.

**Proposed run flow:**

1. Trigger an evaluation manually, on a schedule, or for an approved configuration/code change. Begin in report-only mode; do not make unapproved metrics block a change.
2. Use a fixed, authorized dataset and corpus/index snapshot, and start EKA with the intended configuration. Capture effective runtime settings rather than inferring them from the diff alone.
3. Run the EKA evaluation runner in the workflow. It computes available scores from test outcomes and captures request latency/errors; it must not treat free-form logs as evaluation measurements.
4. Produce a machine-readable, redacted report and a concise Actions job summary. Record a stable run ID, source commit, dataset/corpus/index identity, configuration, runner versions, and all measured/unavailable metrics.
5. Log parameters, metrics, run lineage, and safe report/artifact references to MLflow. Never store credentials or confidential questions, answers, passages, or equivalent content in Actions logs, artifacts, or MLflow.
6. Compare the trial with the explicitly accepted compatible baseline. A reviewer decides whether to accept/promote a run; Actions must not silently replace the baseline.

**Constraints and unresolved deployment details:**

- Start with a non-confidential dataset or an appropriately controlled runner/provider path. GitHub-hosted runner access, dataset movement, model-provider egress, MLflow hosting, artifact storage, access control, and retention require explicit review before confidential evaluation data is used.
- MLflow stores experiment metadata and approved artifacts; it does not calculate EKA quality scores. The evaluation runner/framework computes them. Dashboards visualize tracked runs; production dashboards/telemetry are a separate operational-monitoring concern.
- The MLflow deployment mode (self-hosted or managed), artifact backend, retention, access policy, and network placement remain to be decided under spec 011 OI-16.
- This direction does not authorize implementation of the evaluation pipeline before spec 011 approval.

**Affects:** [specification 011](../../specs/011-evaluation-pipeline/spec.md), its plan and tasks, the [evaluation guide](../Enterprise_Knowledge_Assistant_Evaluation_Guide_v1.md), and future backend CI/evaluation tooling.

## DEC-016: Live deployment evaluation gate

**Status:** Owner-selected direction (2026-11-09); spec 011 approval, measurable gate policy and implementation pending.

**Decision:** For live application deployment, require an evaluation of the candidate against the accepted compatible baseline. Deployment may proceed only when every required approved threshold is met and no required metric or case has an unacceptable regression under approved rules. Equal results may pass; a strict improvement is not required. Improvement in one metric cannot offset a failure in another required metric. This gate does not apply to local development, local application startup or local evaluation runs.

The gate must fail closed for absent, failed, untrusted or incomparable required evidence, and must bind its decision to the candidate artifact and effective deployment-relevant configuration. Baseline acceptance or promotion remains an explicit reviewed action; passing a deployment gate does not automatically promote a baseline. No automatic exception is authorized: bootstrap, emergency and rollback procedures, if needed, require a separately approved policy. Existing release and security requirements still apply.

Approved metrics, thresholds, regression margins, evidence freshness, minimum samples, variability treatment, deployment scope and exception governance remain open under spec 011 OI-7 and OI-17. This selection neither establishes numeric thresholds nor claims that a gate is implemented or authorizes implementation before spec 011 approval.

**Affects:** [specification 011](../../specs/011-evaluation-pipeline/spec.md), its plan and tasks, the [evaluation guide](../Enterprise_Knowledge_Assistant_Evaluation_Guide_v1.md), and future deployment automation.
