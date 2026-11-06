# Enterprise Knowledge Assistant

## Software Requirements Specification (SRS)

**Document ID:** EKA-SRS-001\
**Version / status:** 1.2 / Requirements alignment reviewed 2026-11-06\
**Prepared date:** 2026-10-09\
**Audience:** Product owner, backend/frontend engineering, AI
engineering, QA, security, operations\
**Target release:** MVP v1

**Normative language:** "Shall" means mandatory; "Should" means
recommended; "May" means optional.

> **Important note:** This is the aligned working baseline for the
> portfolio project. Approved [product decisions](implementation/product-decisions.md)
> take precedence; proposed targets remain non-commitments until reviewed
> and approved. Requirements describe intended behavior, not proof of
> implementation or verification. See the [PRD](Enterprise_Knowledge_Assistant_PRD_v1.md)
> and [implementation backlog](implementation/Implementation_Backlog_v2.md)
> for current status and outstanding work.

------------------------------------------------------------------------

## 1. Executive Summary

Enterprise Knowledge Assistant (EKA) enables authenticated users to
upload and manage technical documents, ask natural-language questions,
and receive answers grounded in retrieved source passages. The
application uses retrieval-augmented generation (RAG) to retrieve
relevant chunks before asking a language model to answer. Answers must
include citations to supporting sources and must communicate when
available evidence is insufficient. Internal citations identify
authorized documents; the separately approved external-search exception
has typed external citations under DEC-010.

The project is intended to demonstrate production-minded AI engineering:
ingestion pipelines, chunking and embeddings, authorization-scoped vector
retrieval, corrective retrieval behind configuration, access control,
evaluation, observability and cost awareness. Hybrid retrieval and reranking
remain deferred by DEC-008.

The core document and question-answering flows are implemented, but
release readiness has not been demonstrated. Live Keycloak verification,
representative human-reviewed evaluation and complete live end-to-end
evidence remain outstanding; foundation tasks T18 and T19 are blocked.
See the [foundation tasks](../specs/001-project-foundation/tasks.md) and
the implementation backlog for evidence and limitations.

## 2. Goals and Success Measures

  -----------------------------------------------------------------------
  ID                      Goal                    Proposed success
                                                  measure for MVP
  ----------------------- ----------------------- -----------------------
  G-01                    Answer questions from   At least 80% of a
                          an approved knowledge   curated 50-question
                          base                    test set receives a
                                                  supported, relevant
                                                  answer.

  G-02                    Make answers verifiable At least 95% of factual
                                                  answers in the
                                                  evaluation set include
                                                  valid source citations.

  G-03                    Prevent cross-user data All authorization and
                          exposure                tenant-isolation tests
                                                  pass.

  G-04                    Provide useful          Measure Recall@5 and
                          retrieval               MRR on a labelled
                                                  retrieval dataset;
                                                  establish baseline
                                                  before tuning.

  G-05                    Keep operations         Request correlation
                          observable              IDs, error logs,
                                                  latency and token-usage
                                                  metrics are available
                                                  for the MVP.
  -----------------------------------------------------------------------

## 3. Scope

### 3.1 In scope

-   User authentication and role-based authorization.
-   Upload PDF, DOCX, TXT and Markdown documents within configured size
    limits.
-   Extract text, attach metadata, split content into chunks, create
    embeddings and index the chunks.
-   Track ingestion status: queued, processing, indexed, failed.
-   Ask questions through a React UI and receive answers with source
    citations.
-   Semantic similarity search with configurable top-K and metadata
    filters.
-   Document listing, status viewing, deletion and re-indexing.
-   Repeatable evaluation and authorized retrieval diagnostics.
-   Corrective RAG behind disabled-by-default configuration: bounded passage
    evaluation, refinement, one same-scope rewrite/retrieval, and the
    approved dual-opt-in external-search exception in DEC-010.
-   Docker-based local development and automated tests.

### 3.2 Out of scope for MVP

-   Autonomous agents that execute actions in enterprise systems.
-   Training or fine-tuning a foundation model.
-   Unrestricted crawling of company systems or the public web.
-   Real-time voice, image understanding or video transcription.
-   Formal regulatory certification or a claim of production compliance.
-   Guaranteed correctness for every question or use as the sole basis
    for high-impact decisions.
-   Complex workflow approvals, billing and multi-region disaster
    recovery.
-   Hybrid retrieval, reranking, answer feedback, conversation history, and
    broker-based ingestion are deferred by DEC-008.

## 4. Users and Roles

  -----------------------------------------------------------------------
  Role                                Capabilities
  ----------------------------------- -----------------------------------
  Administrator                       Manage users/roles, configure
                                      system settings, inspect ingestion
                                      failures and audit events.

  Knowledge Manager                   Upload, view, delete and re-index
                                      documents within authorized
                                      collections; review ingestion
                                      status.

  End User                            Search and ask questions against
                                      collections they are authorized to
                                      access; view citations.

  Operator / Developer                View service health and redacted
                                      diagnostics; no implicit permission
                                      to read restricted document
                                      content.
  -----------------------------------------------------------------------

These are product responsibilities, not a claim that every administrative
interface exists. There is currently no administration UI or API for
managing users, collections and grants, or an audit-viewing API; local
setup uses SQL seed data. Security-event audit coverage is incomplete.
These limitations do not remove FR-023 or other requirements below.

## 5. Assumptions and Constraints

-   Initial deployment is a single environment for a portfolio/MVP
    project.
-   Java 21, Spring Boot 4.1.1, Spring AI 2.0.1, React + TypeScript and
    PostgreSQL with pgvector are the preferred implementation stack.
-   Keycloak is the OIDC provider for deployed authentication. Ollama and
    OpenAI are independently selectable for chat and embeddings; provider
    configuration remains externalized.
-   Broker-based ingestion, including Kafka, is deferred by DEC-008.
    The MVP uses a bounded background worker with persisted jobs.
-   The system must not assume that similarity scores are calibrated
    probabilities of correctness.
-   Document access permissions must be enforced during retrieval, not
    only in the UI.
-   Performance targets below are initial engineering targets and must
    be validated on defined hardware and representative data.

## 6. High-Level System Context

**Question-answer flow:**\
User → React web application → Spring Boot REST API →
authentication/authorization → RAG orchestration → retriever (metadata
filter + semantic vector search) → prompt/context
builder → LLM → answer with citations.

Corrective RAG and its bounded external-search exception are described
in §12. Hybrid retrieval and reranking remain deferred.

**Document-ingestion flow:**\
Upload → validation → text extraction → chunking → embeddings →
PostgreSQL/pgvector indexing.

PostgreSQL stores document metadata, extracted text, chunks, permissions
and operational status. Original files are not retained (DEC-005).
Conversation history and answer feedback are deferred (DEC-008); questions
and answers are not persisted as conversation history in the MVP.

**External dependencies:** identity provider or Spring Security
authentication, LLM provider, embedding provider, PostgreSQL/pgvector,
and an observability backend where configured.

## 7. Functional Requirements

FR-012 (hybrid retrieval), FR-013 (reranking), FR-019 (feedback), and
FR-020 (conversation history) are retained for future consideration
but deferred by DEC-008. They are not current MVP behavior or API
commitments.

  -------------------------------------------------------------------------------------------------------------
  ID          Requirement      Statement               Priority    Acceptance criteria   Verification
  ----------- ---------------- ----------------------- ----------- --------------------- ----------------------
  FR-001      Authentication   The system shall        Must        Unauthenticated       Integration test
                               require an                          requests to protected 
                               authenticated identity              endpoints return 401; 
                               before allowing a user              authenticated         
                               to access protected                 requests are          
                               collections or ask                  evaluated against     
                               questions.                          permissions.          

  FR-002      Role             The system shall        Must        An end user cannot    Security test
              authorization    authorize                           delete a document     
                               document-management                 unless explicitly     
                               actions according to                granted that          
                               the user's assigned                 permission.           
                               role and collection                                       
                               permissions.                                              

  FR-003      Document upload  The system shall accept Must        Valid files are       API test
                               configured supported                accepted; invalid     
                               file types and reject               files produce a       
                               unsupported, empty,                 user-readable reason  
                               corrupt or oversized                and are not indexed.  
                               files with a clear                                        
                               error.                                                    

  FR-004      Ingestion status The system shall expose Must        The UI can            E2E test
                               each document's                     distinguish queued,   
                               ingestion state and a               processing, indexed   
                               safe error summary when             and failed documents. 
                               processing fails.                                         

  FR-005      Text extraction  The system shall        Must        A test corpus of      Integration test
                               extract searchable text             supported files       
                               from supported document             produces non-empty    
                               formats and retain                  extracted text or a   
                               source metadata needed              recorded failure.     
                               for citations.                                            

  FR-006      Chunking         The system shall split  Must        Chunk size and        Unit/integration test
                               extracted text into                 overlap settings are  
                               configurable chunks                 applied and chunk IDs 
                               with configurable                   map to their parent   
                               overlap and stable                  document.             
                               chunk identifiers.                                        

  FR-007      Embedding        The system shall        Must        Successful chunks     Integration test
              generation       generate embeddings for             have vectors and      
                               chunks using a                      model metadata;       
                               configured embedding                provider failures are 
                               model and store                     retried or marked     
                               model/version metadata.             failed.               

  FR-008      Indexing and     The system shall index  Must        Re-indexing does not  Integration test
              re-indexing      chunks and support                  leave duplicate       
                               re-indexing after a                 active chunks for the 
                               document or indexing                same document         
                               configuration changes.              version.              

  FR-009      Question         The system shall accept Must        Empty questions are   API/E2E test
              submission       a natural-language                  rejected; questions   
                               question and return an              with no relevant      
                               answer or an explicit               evidence do not       
                               insufficient-evidence               receive a fabricated  
                               response.                           factual answer.       

  FR-010      Similarity       The system shall        Must        Returned candidate    Integration test
              retrieval        retrieve candidate                  count does not exceed 
                               chunks using vector                 configured K, subject 
                               similarity and a                    to available          
                               configurable top-K                  authorized results.   
                               value.                                                    

  FR-011      Metadata         The system shall        Must        Only documents        Security/integration
              filtering        support filters for                 satisfying both       test
                               collection, document                access policy and     
                               type, tags, version and             supplied filters can  
                               other approved metadata             be retrieved.         
                               fields.                                                   

  FR-012      Hybrid retrieval The system should       Should      On an                 Evaluation
                               combine vector                      exact-identifier test 
                               retrieval with                      set, hybrid retrieval 
                               keyword/full-text                   is compared with      
                               retrieval using a                   vector-only retrieval 
                               configurable fusion                 and results are       
                               strategy.                           recorded.             

  FR-013      Reranking        The system should       Should      Reranking can be      Evaluation
                               support reranking an                enabled/disabled and  
                               initial candidate set               its effect on         
                               and selecting a smaller             labelled relevance is 
                               final context set.                  measured.             

  FR-014      Context          The system shall        Must        Prompt construction   Unit/security test
              construction     construct the model                 includes retrieved    
                               context from authorized             text and source       
                               retrieved chunks and                identifiers but       
                               include instructions to             excludes unauthorized 
                               ground answers in that              chunks.               
                               context.                                                  

  FR-015      Source citations The system shall return Must        Each citation         Integration/E2E test
                               citations that identify             resolves to an        
                               the source document                 accessible source and 
                               and, where available,               a real indexed chunk. 
                               page/section and                                          
                               supporting excerpt.                                       

  FR-016      Insufficient     The system shall        Must        A set of              Evaluation
              evidence         indicate when retrieved             out-of-domain         
                               evidence is absent or               questions receives a  
                               below a configured                  refusal/uncertainty   
                               relevance threshold                 response.             
                               instead of presenting                                     
                               unsupported claims as                                     
                               established facts.                                        

  FR-017      Document         Authorized users shall  Must        Users only see        E2E/security test
              management       be able to list                     documents permitted   
                               documents and view                  by their collection   
                               metadata, indexing                  access.               
                               status, upload date and                                   
                               failure state.                                            

  FR-018      Deletion         The system shall remove Must        Deleted content is    Integration test
                               a deleted document's                not retrievable after 
                               chunks from retrieval               deletion completes;   
                               and schedule deletion               deletion outcome is   
                               of associated vectors               auditable.            
                               and derived records                                       
                               according to retention                                    
                               policy.                                                   

  FR-019      Feedback         The system should allow Should      Feedback is           API test
                               users to mark an answer             associated with the   
                               helpful or not helpful              answer, user/tenant   
                               and optionally provide              scope and system      
                               a reason.                           version without       
                                                                   exposing secrets.     

  FR-020      Conversation     The system may retain   Could       Retention expiry      Integration test
              history          conversation history                removes or anonymizes 
                               for a configurable                  records according to  
                               period and shall apply              the configured        
                               the same access and                 policy.               
                               retention controls as                                     
                               other user data.                                          

  FR-021      Ingestion retry  The system shall        Must        Retrying the same     Integration test
                               support safe retries                ingestion job is      
                               for transient                       idempotent.           
                               ingestion/provider                                        
                               failures without                                          
                               creating duplicate                                        
                               active records.                                           

  FR-022      Evaluation       The system shall        Must        A test run records    Test/demo
                               provide a repeatable                dataset version,      
                               way to run a fixed                  model/configuration   
                               question set and record             version and metric    
                               retrieval and                       results.              
                               answer-quality metrics.                                   

  FR-023      Audit events     The system shall record Must        Audit records include Inspection/test
                               security-relevant                   timestamp, actor,     
                               events such as login                action and outcome,   
                               failures, document                  without storing raw   
                               deletion, permission                secrets.              
                               changes and                                               
                               administrative actions.                                   

  FR-024      Configuration    The system shall        Must        Settings can be       Configuration test
                               externalize model                   changed per           
                               provider, model names,              environment without   
                               top-K, chunking,                    source changes.       
                               retrieval and timeout                                     
                               settings from source                                      
                               code.                                                     
  -------------------------------------------------------------------------------------------------------------

FR-014 and FR-015 describe the internal-evidence path. DEC-010 also
permits a separate, dual-opt-in external-search fallback with typed
external citations; its scope and safeguards in §12 and
[specification 005](../specs/005-corrective-rag/spec.md) apply.
Internal citation and authorization requirements still apply to internal
sources and are not replaced by the external-source rules.

## 8. User Stories and Core Workflows

### US-01: Upload knowledge

As a Knowledge Manager, I want to upload a technical document and see
its indexing status so that it becomes searchable.

-   Given an authorized manager and a supported file, when upload
    completes, then the system creates a document record and starts
    ingestion.
-   Given ingestion succeeds, when status is refreshed, then the
    document is shown as Indexed.
-   If upload-time extraction rejects a file, the user receives a safe
    error and no searchable document is created. If processing of an
    accepted document fails, the document is marked Failed with a safe
    diagnostic.

### US-02: Ask a question with evidence

As an End User, I want to ask a natural-language question and inspect
the sources so that I can verify the answer.

-   Given authorized indexed documents, when I submit a question and
    sufficient internal evidence is found, the system returns an answer
    with citations to the retrieved sources.
-   When evidence is insufficient, then the answer clearly communicates
    uncertainty rather than inventing a specific fact.
-   When I open a citation, then I see the corresponding source metadata
    and permitted excerpt.

### US-03: Filter by product/version

As an End User, I want to restrict a search to a product and version so
that outdated documents do not dominate the answer.

-   Given documents tagged with multiple versions, when I filter to
    version 3.0, then only authorized version 3.0 chunks are eligible
    for retrieval.
-   The backend enforces filters even if a client tampers with request
    parameters.

## 9. Non-Functional Requirements

  ---------------------------------------------------------------------------------
  ID                Category                  Requirement         Verification
  ----------------- ------------------------- ------------------- -----------------
  NFR-001           Performance               For a local/demo    Measure
                                              dataset of up to    
                                              10,000 indexed      
                                              chunks, target p95  
                                              retrieval latency ≤ 
                                              1.5 seconds         
                                              excluding LLM       
                                              generation; measure 
                                              on documented       
                                              hardware.           

  NFR-002           End-to-end latency        For the selected    Measure
                                              model and test      
                                              dataset, report     
                                              p50/p95 end-to-end  
                                              answer latency; set 
                                              a target after a    
                                              baseline run.       

  NFR-003           Reliability               Transient           Test
                                              LLM/embedding       
                                              provider failures   
                                              shall produce       
                                              bounded retries,    
                                              timeouts and a      
                                              user-safe error; no 
                                              unbounded retry     
                                              loops.              

  NFR-004           Security                  All protected APIs  Security test
                                              shall enforce       
                                              authentication and  
                                              server-side         
                                              authorization;      
                                              secrets shall be    
                                              stored outside      
                                              source control.     

  NFR-005           Tenant isolation          If multi-tenancy is Adversarial
                                              enabled, every      security test
                                              retrieval query     
                                              shall enforce       
                                              tenant/collection   
                                              permissions before  
                                              context reaches the 
                                              LLM.                

  NFR-006           Privacy                   Logs shall not      Inspection/test
                                              record raw          
                                              credentials, API    
                                              keys or full        
                                              document content by 
                                              default;            
                                              configurable        
                                              retention shall be  
                                              documented.         

  NFR-007           Observability             The application     Demo/inspection
                                              shall expose health 
                                              checks and          
                                              structured logs     
                                              with correlation    
                                              IDs; metrics shall  
                                              include request     
                                              counts, errors,     
                                              latency and         
                                              provider usage      
                                              where available.    

  NFR-008           Maintainability           Business logic,     Code review
                                              ingestion,          
                                              retrieval and       
                                              model-provider      
                                              integration shall   
                                              be separated into   
                                              testable modules.   

  NFR-009           Portability               A developer shall   Demonstration
                                              be able to start    
                                              the application and 
                                              dependencies using  
                                              documented Docker   
                                              Compose             
                                              instructions.       

  NFR-010           Accessibility/usability   Core flows shall be Manual/E2E test
                                              keyboard-operable   
                                              and expose clear    
                                              loading, empty,     
                                              success and failure 
                                              states.             

  NFR-011           Evaluation quality        The project shall   Evaluation
                                              report retrieval    
                                              metrics such as     
                                              Recall@K/MRR and    
                                              answer metrics such 
                                              as citation         
                                              validity and        
                                              groundedness on a   
                                              versioned dataset.  

  NFR-012           Cost control              The system shall    Test/inspection
                                              capture             
                                              model/provider      
                                              usage when          
                                              available and       
                                              permit              
                                              limits/timeouts to  
                                              be configured.      
  ---------------------------------------------------------------------------------

## 10. Data Requirements

  -------------------------------------------------------------------------
  Entity                  Key fields                Notes
  ----------------------- ------------------------- -----------------------
  User                    id, identity_subject,     Prefer
                          roles, status             identity-provider
                                                    subject; do not store
                                                    passwords if external
                                                    identity is used.

  Collection              id, name, tenant_id,      Logical boundary for
                          access policy             document access.

  Document                id, collection_id,        Original file is not
                          filename, content_type,   stored (DEC-005).
                          checksum, version,
                          status, created_by,       
                          created_at                

  Chunk                   id, document_id,          Chunk must be traceable
                          chunk_index, text,        to its source
                          metadata, embedding,      document/page/section
                          embedding_model_version   when available.

  IngestionJob            id, document_id, status,  Errors should be safe
                          attempt_count,            and actionable; avoid
                          error_code, timestamps    sensitive payload
                                                    dumps.

  Query/Answer            id, user_id, collection   Persist only if
                          scope, question, answer,  conversation/audit
                          retrieved chunk IDs,      policy enables it.
                          model/config version,     
                          latency                   

  Feedback                id, answer_id, rating,    Used for evaluation and
                          reason, created_at        product improvement.

  AuditEvent              id, actor, action,        Append-only access
                          resource, outcome,        policy recommended.
                          timestamp, correlation_id 
  -------------------------------------------------------------------------

Data entries above describe the logical requirements, not a promise that
every entity is stored today. Under DEC-005 original uploads are not
stored; re-indexing uses stored extracted text. Query/Answer history and
Feedback are deferred under DEC-008. Any future change to retention or
conversation storage requires the appropriate decision and privacy review.

## 11. API Requirements (Proposed)

  ---------------------------------------------------------------------------------------
  Method and path                         Purpose                 Authorization
  --------------------------------------- ----------------------- -----------------------
  `POST /api/v1/documents`                Upload document and     Knowledge Manager
                                          initiate ingestion      

  `GET /api/v1/documents`                 List permitted          Authenticated user;
                                          documents with          scope-filtered
                                          pagination and filters  

  `GET /api/v1/documents/{id}`            Get document            Permission on
                                          metadata/status         document/collection

  `DELETE /api/v1/documents/{id}`         Soft-delete document    Knowledge Manager with
                                          and schedule purge      delete permission

  `POST /api/v1/documents/{id}/reindex`   Re-index document       Knowledge Manager

  `POST /api/v1/chat/query`               Submit question,        Authenticated user
                                          optional filters and    
                                          collection scope        

  `GET /actuator/health`                  Health status           Public only if
                                                                  deliberately safe;
                                                                  otherwise
                                                                  operations-only
  ---------------------------------------------------------------------------------------

The approved [API contract](../specs/001-project-foundation/api-contract.md)
defines current schemas, pagination limits, error codes and re-index
semantics. Rate limiting and idempotency keys remain deferred. The
frontend currently requests up to 100 documents without page navigation;
the API supports pagination. See backlog P11.

## 12. Retrieval and RAG Behavior

-   **Baseline:** semantic vector retrieval with configurable top-K.
-   **Metadata:** enforce collection and access-control filters before
    any retrieved text is placed in an LLM prompt.
-   **Corrective RAG:** when `crag.enabled=true`, evaluate at most five
    authorized passages. Correct evidence is refined from validated source
    strips; incorrect evidence may receive one same-scope internal rewrite
    and retrieval; ambiguous evidence abstains. Stage failures fall back to
    the baseline path.
-   **External search:** only after an unsuccessful corrective internal
    retrieval, and only when deployment enablement plus
    `allowExternalSearch=true` are both present, one Tavily request may use
    the original user question and fixed search options. No internal
    passages, filenames, collection or user identifiers, or conversation
    history are sent; question and provider bodies must not be logged or
    persisted. Results are untrusted; citations are typed
    `EXTERNAL` with validated HTTPS URL, title, and snippet. Initial no-hit
    and ambiguous branches do not cause external egress; search failures
    lead to insufficient evidence. See DEC-010 for the full safeguards.
-   **Hybrid search and reranking:** deferred by DEC-008.
-   **Context budget:** cap the number of chunks and total context
    tokens; prioritize relevant and non-duplicative passages.
-   **Citations:** for internal sources, preserve document ID, title,
    chunk ID and page/section metadata through retrieval and generation.
    External citations are separately typed and do not contain internal
    document identifiers.
-   **Grounding:** instruct the model to answer from supplied evidence,
    cite claims and state when evidence is insufficient.
-   **Prompt-injection resistance:** treat document text as untrusted
    data, not as instructions to override system policies.
-   **Evaluation:** evaluate the current vector-only baseline on a
    labelled query set. Comparison with hybrid and reranked retrieval is
    deferred with those capabilities (DEC-008).

## 13. Security and Abuse Cases

-   Unauthorized retrieval: a user guesses another document ID or
    tampers with a collection filter.
-   Prompt injection inside a document: an uploaded file asks the model
    to reveal secrets or ignore system rules.
-   Malicious or malformed upload: oversized file, decompression bomb,
    corrupt PDF or unexpected content type.
-   Sensitive data leakage through logs, traces, citations, conversation
    history or provider requests.
-   Model/provider outage, rate limit or malformed model response.
-   Cross-tenant leakage through cached answers or improperly scoped
    retrieval.

**Required controls:** server-side authorization, upload limits and
validation, output escaping, provider timeouts, scoped cache keys,
secret management, audit logging, prompt-injection tests and a
documented data-retention policy.

## 14. Acceptance Test Scenarios

  -----------------------------------------------------------------------
  Test ID                 Scenario                Expected result
  ----------------------- ----------------------- -----------------------
  AT-01                   Upload a valid PDF      Document record
                                                  created; status
                                                  transitions to Indexed;
                                                  chunks and embeddings
                                                  are queryable.

  AT-02                   Upload unsupported file Request is rejected
                                                  with a clear message;
                                                  no chunks are indexed.

  AT-03                   Ask an answerable       Answer includes at
                          question                least one valid
                                                  citation to a
                                                  retrieved, authorized
                                                  chunk.

  AT-04                   Ask an unanswerable     System reports
                          question                insufficient evidence
                                                  and does not invent a
                                                  specific answer.

  AT-05                   Filter to a specific    No chunk from other
                          version                 versions appears in
                                                  retrieved context or
                                                  citations.

  AT-06                   Attempt unauthorized    API denies access; no
                          document access         document text leaks
                                                  through response, logs
                                                  or model context.

  AT-07                   Retry failed ingestion  Retry is safe and does
                                                  not create duplicate
                                                  active chunks.

  AT-08                   Delete a document       Its chunks are excluded
                                                  from retrieval after
                                                  deletion completes.

  AT-09                   Compare retrieval       Evaluation report
                          strategies              records metrics for
                                                  vector-only, hybrid and
                                                  reranked retrieval.

  AT-10                   Simulate provider       Request terminates
                          timeout                 within configured
                                                  timeout and returns a
                                                  safe error.
  -----------------------------------------------------------------------

AT-09 is deferred for the MVP under DEC-008 and the
[foundation plan](../specs/001-project-foundation/plan.md#10a-technical-baseline-decisions-t01).
The other scenarios remain applicable; their presence here does not mean
they have all been verified.

## 15. Evaluation Plan

  -----------------------------------------------------------------------
  Dimension               Metric / method         Initial approach
  ----------------------- ----------------------- -----------------------
  Retrieval               Recall@5, MRR or nDCG@5 Create 30--50 questions
                                                  with known relevant
                                                  source chunks.

  Citation validity       Percentage of citations Automated validation
                          resolving to real       against stored chunk
                          authorized chunks       IDs.

  Groundedness            Human review or a       Review a representative
                          documented              answer sample; do not
                          model-assisted rubric   rely on an LLM judge
                                                  alone.

  Answer usefulness       Human rating: correct,  Use a fixed rubric and
                          partially correct,      retain examples of
                          incorrect               failure.

  Latency                 p50/p95 API and         Separate retrieval time
                          retrieval latency       from generation time.

  Cost                    Tokens and provider     Compare configurations
                          cost per query when     on the same query set.
                          available               
  -----------------------------------------------------------------------

The existing runner computes its Recall@5 and MRR from returned citation
IDs, not raw retrieval candidates; citation field completeness is not
full citation validity. It reports mean latencies rather than the
percentiles above. Representative labelled data and human review remain
outstanding. These limitations do not change the evaluation requirements
or establish that targets have been met. The expanded evaluation
pipeline in [specification 011](../specs/011-evaluation-pipeline/spec.md)
is a draft, not approved for implementation.

The proposed G-02 target uses factual answers as its denominator, while
the citation-validity measurement above uses individual citations. Report
them separately and review their methods before using either as a release
threshold.

## 16. Proposed Delivery Plan

  -----------------------------------------------------------------------
  Milestone               Deliverable             Definition of done
  ----------------------- ----------------------- -----------------------
  M1 --- Thin slice       Upload one document and A supported file can be
                          ask a question          ingested and a cited
                                                  answer returned
                                                  end-to-end.

  M2 --- Core product     Document library,       Core acceptance tests
                          status, access control, pass.
                          citations               

  M3 --- Retrieval        Metadata filters,       Baseline comparison
  quality                 hybrid search, optional report is committed.
                          reranking               

  M4 ---                  Retries, deletion,      Failure/security
  Production-minded       observability,          scenarios pass and
  hardening               timeouts, evaluation    setup is reproducible.

  M5 --- Portfolio        React UX, architecture  A reviewer can run the
  release                 diagram, README, demo   app from documented
                          dataset                 instructions.
  -----------------------------------------------------------------------

This is a historical proposed plan, not an implementation-status
register. M3's hybrid and reranking comparison is deferred by DEC-008;
baseline retrieval evaluation remains outstanding. Consult the current
backlog and foundation task register for status.

## 17. Definition of Done

-   Every Must requirement has at least one test or explicit
    verification artifact.
-   No known critical authorization or tenant-isolation defect remains.
-   The app handles ingestion and provider failures without silently
    claiming success.
-   Answers show citations and support an insufficient-evidence path.
-   Evaluation datasets and results are versioned and reproducible.
    Confidential data must remain in an authorized, access-controlled
    location outside source control; only non-sensitive material may be
    committed.
-   Secrets are excluded from source control; configuration examples use
    placeholders.
-   Docker-based setup and teardown are documented and tested.
-   Known limitations and out-of-scope capabilities are documented in
    the README.

## 18. Decisions and Remaining Questions

| Topic | Current status |
|---|---|
| Chat and embedding providers | DEC-002 approves independently selectable Ollama and OpenAI providers, with Ollama local and OpenAI deployed defaults. Models are configured per environment; changes to embedding provider or model require re-indexing. |
| Models and vector store | The [foundation plan](../specs/001-project-foundation/plan.md#10a-technical-baseline-decisions-t01) records the approved starting models and isolated vector indexes. The owner approved the pg18 local image on 2026-11-06; compatibility and upgrade evidence remain pending (G12). Model choices are configurable; compatible dimensions and re-indexing remain necessary. |
| Authentication | DEC-001 approves local development authentication and Keycloak OIDC for deployed use, including configured audience validation. Live Keycloak verification remains blocked (B04). |
| Upload and retention | DEC-003, DEC-005 and DEC-006 approve the 10 MiB limit, no original-file storage, soft deletion and seven-day purge. |
| Hybrid retrieval, reranking, feedback, conversation history and broker-based ingestion | Deferred by DEC-008. |
| Corrective RAG and external search | DEC-010 approves P1–P4 with CRAG disabled by default and external search subject to dual opt-in and its safeguards. |
| Retrieval defaults | DEC-007 specifies top-K 5 and similarity threshold 0.70; the owner confirmed retaining them on 2026-11-06. The backend currently defaults to 10 and 0.30 when not overridden; restoration and verification are tracked in G11. |
| Performance and quality targets | Initial targets remain provisional; benchmark on representative data and documented hardware and review methodology before approving release or service-level thresholds. |
| Evaluation pipeline | [Specification 011](../specs/011-evaluation-pipeline/spec.md) and OI-1–OI-12 await owner review; online evaluation requires a separate privacy decision. |
| Product improvements | Administration UI/API, OCR, pagination and other proposed work require appropriate scope and approval; see the implementation backlog. |

These summaries do not replace the decision records. Deployment-specific
model and realm settings, and remaining evaluation questions, must not be
treated as resolved simply because the baseline is recorded.
On 2026-11-06 the owner approved immediate rejection of empty, corrupt or
unextractable uploads without creating a document/job, and exclusion of
re-indexed documents from retrieval while queued, processing or failed.
The feature and API documents have been aligned; re-index lifecycle
verification remains outstanding in backlog G13.

## 19. References and Further Reading

-   [Spring AI --- Retrieval Augmented
    Generation](https://docs.spring.io/spring-ai/reference/api/retrieval-augmented-generation.html)
-   [Spring AI ---
    Advisors](https://docs.spring.io/spring-ai/reference/api/advisors.html)
-   [ISO/IEC/IEEE 29148 SRS template
    example](https://github.com/DIN-DKE/ISO_IEC_IEEE_29148__SRS-Template)

------------------------------------------------------------------------

**END OF DOCUMENT --- Requirements and decisions remain subject to their recorded approval and verification status.**
