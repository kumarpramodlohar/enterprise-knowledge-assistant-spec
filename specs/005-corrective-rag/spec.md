# 005 Corrective RAG (CRAG) — Specification

**Status:** P1–P4 approved for implementation (2026-10-22). P4 is opt-in at both deployment and request level.
**Related:** specs/001-project-foundation (FR-06, FR-07, AC-09–AC-11), DEC-007, DEC-008, DEC-010
**Reference:** CRAG paper figure ("Corrective Retrieval Augmented Generation", retrieval evaluator with Correct / Ambiguous / Incorrect actions) and its derived flow.

## 1. Purpose

Add bounded, internal retrieval evaluation, evidence refinement, one same-scope query rewrite, and an explicitly opted-in public web fallback while retaining the MVP baseline behind a disabled-by-default configuration. The owner approved proceeding despite incomplete quality evaluation; this approval does not close 001 T18/T19.

## 2. Retained baseline (MVP behavior when CRAG is disabled)

| CRAG stage                                 | EKA today                                                                            | Gap                                                           |
| ------------------------------------------ | ------------------------------------------------------------------------------------ | ------------------------------------------------------------- |
| `retrieve`                                 | Authorization-scoped pgvector top-K (5), filters applied in the vector query.        | None.                                                         |
| `eval_each_doc`                            | One global minimum-similarity threshold (0.70). Similarity is not correctness.       | No per-document relevance evaluator; no 3-way verdict.        |
| Correct → `refine`                         | Passages passed whole, within the 4000-token budget.                                 | No strip decomposition, filtering or recomposition.           |
| Incorrect → `rewrite_query` → `web_search` | Not present in the retained MVP baseline; public search is now a bounded P4 exception. | Missing from baseline; supplied by P4. |
| Ambiguous                                  | Not present.                                                                         | Missing.                                                      |
| `generate`                                 | Model call only when evidence passes the threshold; citations from trusted metadata. | None.                                                         |
| `end` / insufficient                       | `insufficientEvidence=true`, no model call.                                          | Maps to CRAG "ambiguous/incorrect with no fallback".          |

Conclusion: the CRAG-disabled path retains `retrieve → threshold gate → generate | insufficient evidence`, consistent with DEC-007/DEC-008 and 001 acceptance criteria. CRAG-enabled behavior is specified below.

## 3. Problem

When retrieval is partly or wholly irrelevant, the MVP can only answer or abstain. CRAG-style correction could (a) filter noise from relevant passages, (b) retry with a rewritten query, and (c) optionally use an external source, improving answer rate without weakening grounding.

## 4. Approved implementation scope

| Phase | Capability                                                                                               | Depends on external data egress?                                     |
| ----- | -------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| P1    | Per-passage retrieval evaluator producing `CORRECT / AMBIGUOUS / INCORRECT`                              | Uses configured chat model; no separate provider.                   |
| P2    | Knowledge refinement: decompose passages into strips, score, filter, recompose within the context budget | No                                                                   |
| P3    | Internal corrective action: rewrite query and re-retrieve from authorized internal content only          | No                                                                   |
| P4    | Explicitly requested external web search fallback after internal corrective retrieval fails               | Yes — requires both deployment enablement and per-query user opt-in   |

P1–P4 are approved. P4 changes the out-of-scope public-web rule only for the bounded, opt-in search flow specified below; autonomous browsing remains out of scope.

## 5. Constraints and risks

- 001 §4 lists unrestricted crawling of the public web as out of scope. P4 is a limited exception: one search request after internal corrective retrieval fails, with provider configuration and explicit per-query user consent.
- The user question is sent verbatim to the configured Tavily Search API only when both `EKA_WEB_SEARCH_ENABLED=true` and request `allowExternalSearch=true`. No document passages, filenames, collection IDs, user IDs, credentials, or conversation history are sent. Do not log or persist the question or provider request/response body. The API key remains server-side.
- Web results are untrusted content: prompt injection, unreliable facts, no authorized-collection ownership. Citations for web sources cannot be "authorized indexed sources" as required by AC-10; the contract and UI must distinguish them.
- 001 AC-10/AC-11 and the "never invent citations" rule must be re-stated for mixed internal + external evidence. Every citation is typed `INTERNAL` or `EXTERNAL`; external citations have a validated HTTPS URL and title, while internal citations retain document metadata.
- Extra LLM calls (evaluator per document, rewrite, refine) raise latency and cost; the evaluator is not itself calibrated and must be evaluated on the labelled dataset.

## 6. Functional requirements

- FR-1: When enabled, evaluate at most five authorized top-K passages against the question. Aggregate passage verdicts deterministically: any `CORRECT` passage makes the action `CORRECT`; otherwise any `AMBIGUOUS` passage makes it `AMBIGUOUS`; otherwise it is `INCORRECT`.
- FR-2: On `CORRECT`, refine passages and generate from refined internal evidence.
- FR-3: On `INCORRECT`, rewrite the query at most once and retry internal retrieval with the exact same server-authorized collection scope and metadata filters. Re-evaluate; if no `CORRECT` passage results, return insufficient evidence. No external search is performed.
- FR-4: On `AMBIGUOUS`, return insufficient evidence without generation.
- FR-5: Every step runs after server-side authorization; evaluator and rewrite prompts only receive authorized passages and the user question.
- FR-6: Bound processing to five evaluated passages, one rewrite, and a configurable 60-second total CRAG-stage timeout. On evaluator, refiner, or rewrite provider/format failure, use the original MVP threshold-selected passages and original question.
- FR-7: Refined text must be selected from exact source strips returned by the model; validate every strip identifier against the source chunk. Citations are built only from trusted internal retrieval metadata.
- FR-8: The MVP pipeline remains available behind configuration (`crag.enabled=false` default) so results can be compared on the same dataset.
- FR-9: Log per-request verdicts and chosen action with correlation ID and trusted chunk IDs only; never log questions, passages, or model prompts. Do not persist user queries or answers.
- FR-10: Use the configured chat model for evaluator, refiner, and rewrite calls. The P1–P3 flow never calls an external search service.
- FR-11: External search is eligible only when CRAG is enabled, the service is configured with `EKA_WEB_SEARCH_ENABLED=true` and a Tavily API key, and the request explicitly sets `allowExternalSearch=true`. All defaults are disabled.
- FR-12: Invoke Tavily once, only after the initial and single internal corrective retrieval both produce no `CORRECT` evidence. Do not search externally after an `AMBIGUOUS` verdict, on an initial no-hit retrieval, or on a provider failure. Search receives only the original user question; do not include internal evidence, document metadata, or identities.
- FR-13: Search at most five results with basic search depth; do not request raw page content or provider-generated answers. Bound each result snippet and total evidence to the configured CRAG context budget. Treat results as untrusted data and isolate them from instruction text in the answer prompt.
- FR-14: If external results exist, generate an answer grounded only in those results and return their trusted provider metadata as `EXTERNAL` citations. If no usable results exist, return insufficient evidence. Do not mix passages judged `INCORRECT` or `AMBIGUOUS` into generation.
- FR-15: External citations expose title, HTTPS URL, and snippet; they do not expose internal document IDs. Validate URL scheme and reject malformed URLs. The frontend labels these citations as web sources and opens them with safe external-link attributes. Internal citation behavior remains unchanged.
- FR-16: Provider errors, timeout, missing key, malformed results, or invalid URLs fail closed to insufficient evidence (or the existing baseline fallback where a prior CRAG stage itself fails); never convert a search failure into an unsupported answer. Log only correlation ID, stage, result count, and status; never log query text, snippets, or API key.
- FR-17: API request `allowExternalSearch` is optional and defaults to false. Omitting it preserves existing internal-only behavior and response semantics. The operator can disable the integration immediately through configuration.

## 7. Acceptance criteria

- AC-1: With CRAG disabled, behaviour and API responses are identical to the MVP baseline.
- AC-2: Evaluator verdicts and the chosen action are logged per request using correlation ID and chunk IDs; no question or passage body is logged or persisted.
- AC-3: The paired evaluation runner reports baseline and CRAG metrics on the same dataset for Recall@5, MRR, citation validity, evidence classification, latency, human review when available, and cost when available. CRAG remains disabled by default until a representative reviewed evaluation establishes quality and isolation results.
- AC-4: Retrieval after rewrite never returns content outside the caller's authorized scope (adversarial test).
- AC-5: Prompt-injection text inside a passage cannot change the verdict, the rewritten query's scope, or trigger external calls.
- AC-6: Evaluator/provider failure produces the baseline result or a safe error, never a success-shaped unsupported answer.
- AC-7: When either server configuration or per-query consent is false, no external request is made and no external citation is returned.
- AC-8: With both gates enabled, an external search is made at most once and only after an unsuccessful internal retry; ambiguous evidence and initial no-hit cases abstain without egress.
- AC-9: The outgoing provider request contains only the user question and fixed search options. Logs contain no question, result text, URL query secrets, or API key.
- AC-10: External citations are typed, validated HTTPS sources with title and snippet; internal citations remain typed internal sources with existing trusted document metadata. The UI visibly distinguishes them and does not call the internal document verification endpoint for external citations.
- AC-11: Provider timeout/error/empty/invalid responses return insufficient evidence without generating an answer from failed or untrusted internal candidates.

## 8. Out of scope

Hybrid retrieval and reranking (DEC-008, separate decision), conversation history, answer caching, fine-tuning the evaluator, autonomous browsing, multiple provider support, raw-page extraction, and search on ambiguous evidence or initial no-hit retrieval.

## 9. Decisions

Approved defaults (owner instruction, 2026-10-22):

- Evaluator: prompted judge using the configured chat model; custom Spring AI orchestration.
- Ambiguous action: abstain.
- Bounds: five passages, one rewrite, and a 60-second CRAG-stage timeout.
- Stage failure: fall back to baseline MVP behavior.
- User visibility: no corrective-action API or UI field in this implementation.
- Baseline gate: the owner authorized P1–P3 after reviewing the existing 30-case reports despite absent human review and poor Recall@5 at threshold 0.70. The data is not representative and this does not complete MVP evaluation.
- P4 web search: approved by owner request (2026-10-22), limited to Tavily Search API, with two opt-in gates, no raw page extraction, no content logging/persistence, and typed external citations. Deployment-level default remains disabled.

Hybrid retrieval/reranking, unrestricted/autonomous external browsing, and corrective-action UI remain out of scope.
