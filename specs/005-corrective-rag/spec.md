# 005 Corrective RAG (CRAG) — Specification

**Status:** Proposed — post-MVP. Not approved; not implemented. Do not start planning-to-implementation until the decisions in DEC-010 are approved after MVP evaluation.
**Related:** specs/001-project-foundation (FR-06, FR-07, AC-09–AC-11), DEC-007, DEC-008, DEC-010 (proposed)
**Reference:** CRAG paper figure ("Corrective Retrieval Augmented Generation", retrieval evaluator with Correct / Ambiguous / Incorrect actions) and the derived flow diagram `start → retrieve → eval_each_doc → {ambiguous | refine → generate | rewrite_query → web_search → refine} → end`.

## 1. Purpose

Record how EKA's current retrieval pipeline compares with the CRAG design, and define the post-MVP change needed to close the gaps, so the MVP baseline and later CRAG decisions can be told apart.

## 2. Current baseline (MVP, implemented per 001 T14–T16)

| CRAG stage                                 | EKA today                                                                            | Gap                                                           |
| ------------------------------------------ | ------------------------------------------------------------------------------------ | ------------------------------------------------------------- |
| `retrieve`                                 | Authorization-scoped pgvector top-K (5), filters applied in the vector query.        | None.                                                         |
| `eval_each_doc`                            | One global minimum-similarity threshold (0.70). Similarity is not correctness.       | No per-document relevance evaluator; no 3-way verdict.        |
| Correct → `refine`                         | Passages passed whole, within the 4000-token budget.                                 | No strip decomposition, filtering or recomposition.           |
| Incorrect → `rewrite_query` → `web_search` | Not present. Public web is out of scope (001 §4).                                    | Missing, and conflicts with scope and privacy rules (see §5). |
| Ambiguous                                  | Not present.                                                                         | Missing.                                                      |
| `generate`                                 | Model call only when evidence passes the threshold; citations from trusted metadata. | None.                                                         |
| `end` / insufficient                       | `insufficientEvidence=true`, no model call.                                          | Maps to CRAG "ambiguous/incorrect with no fallback".          |

Conclusion: the MVP implements `retrieve → threshold gate → generate | insufficient evidence`. This is a deliberate subset of CRAG, consistent with DEC-007/DEC-008 and the 001 acceptance criteria. It does not contradict CRAG, but it does not implement the corrective actions.

## 3. Problem

When retrieval is partly or wholly irrelevant, the MVP can only answer or abstain. CRAG-style correction could (a) filter noise from relevant passages, (b) retry with a rewritten query, and (c) optionally use an external source, improving answer rate without weakening grounding.

## 4. Proposed phases (each needs its own approval)

| Phase | Capability                                                                                               | Depends on external data egress?                                     |
| ----- | -------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| P1    | Per-document retrieval evaluator producing `CORRECT / AMBIGUOUS / INCORRECT`                             | Only if an LLM judge is a different provider than the chat provider. |
| P2    | Knowledge refinement: decompose passages into strips, score, filter, recompose within the context budget | No                                                                   |
| P3    | Internal corrective action: rewrite query and re-retrieve from authorized internal content only          | No                                                                   |
| P4    | External web search fallback                                                                             | Yes — requires explicit approval (see §5)                            |

P1–P3 are internal and can be adopted without changing the out-of-scope public-web rule. P4 is the only phase that changes scope.

## 5. Constraints and risks (must be resolved before P4)

- 001 §4 lists unrestricted crawling of the public web as out of scope. P4 must be approved as a scope change, not assumed.
- A rewritten query is derived from user questions that may contain confidential terms. Sending it to a web search provider is external disclosure; it needs authorization, redaction rules and a decision on logging.
- Web results are untrusted content: prompt injection, unreliable facts, no authorized-collection ownership. Citations for web sources cannot be "authorized indexed sources" as required by AC-10; the contract and UI must distinguish them.
- 001 AC-10/AC-11 and the "never invent citations" rule must be re-stated for mixed internal + external evidence.
- Extra LLM calls (evaluator per document, rewrite, refine) raise latency and cost; the evaluator is not itself calibrated and must be evaluated on the labelled dataset.

## 6. Functional requirements (proposed, apply only after approval)

- FR-1: Evaluate each retrieved passage against the question and assign a verdict; aggregate to a query-level action (`CORRECT`, `AMBIGUOUS`, `INCORRECT`) using configurable thresholds.
- FR-2: On `CORRECT`, refine passages and generate from refined internal evidence.
- FR-3: On `INCORRECT`, rewrite the query and retry internal retrieval within the same authorization scope; abstain with insufficient evidence if still incorrect (P3). External search only if P4 is approved.
- FR-4: On `AMBIGUOUS`, behaviour is an open decision (OD-3): abstain/clarify (as in the supplied flow diagram) or combine internal and corrected evidence (as in the CRAG paper).
- FR-5: Every step runs after server-side authorization; evaluator and rewrite prompts only receive authorized passages and the user question.
- FR-6: Bound extra calls (max evaluated passages, max rewrites = 1, timeouts); fall back to the MVP behaviour on evaluator failure.
- FR-7: Citations are built only from trusted metadata; any external citation is typed `EXTERNAL` and never shown as an internal source.
- FR-8: The MVP pipeline remains available behind configuration (`crag.enabled=false` default) so results can be compared on the same dataset.

## 7. Acceptance criteria (proposed)

- AC-1: With CRAG disabled, behaviour and API responses are identical to the MVP baseline.
- AC-2: Evaluator verdicts and the chosen action are recorded per evaluation run (not per user), with no document bodies in logs.
- AC-3: On the labelled dataset, CRAG-enabled results are compared to the baseline for Recall@5, MRR, citation validity, groundedness, abstention rate, latency and cost; adoption requires measured improvement and no regression in citation validity or isolation tests.
- AC-4: Retrieval after rewrite never returns content outside the caller's authorized scope (adversarial test).
- AC-5: Prompt-injection text inside a passage cannot change the verdict, the rewritten query's scope, or trigger external calls.
- AC-6: Evaluator/provider failure produces the baseline result or a safe error, never a success-shaped unsupported answer.
- AC-7 (P4 only): No external request is made unless approved configuration enables it; the outbound query is redacted per policy and the response marks external citations.

## 8. Out of scope

Hybrid retrieval and reranking (DEC-008, separate decision), conversation history, answer caching, fine-tuning the evaluator, autonomous browsing.

## 9. Planning queries and open decisions

Questions to put to the product owner before approval (recorded in DEC-010):

- OD-1: Is MVP baseline evaluation complete, and what retrieval failure rate justifies CRAG over simple reranking/hybrid?
- OD-2: Evaluator type: prompted LLM judge using the configured chat model, a small fine-tuned classifier, or a cross-encoder/reranker score?
- OD-3: Should AMBIGUOUS abstain (diagram) or combine evidence (paper)?
- OD-4: Is any external web search allowed? If yes: provider, redaction policy, data-sharing authorization, per-collection opt-in, allow-listed domains, citation labelling.
- OD-5: Latency and cost budget per question (extra LLM calls).
- OD-6: Verdict thresholds and whether they are per provider (like the 0.70 evidence threshold).
- OD-7: Should the user see the corrective action taken (e.g. "searched again with a refined query")?
- OD-8: Implementation approach in Spring AI (custom orchestration vs. an agent/graph library) — to be recorded as an architecture decision.

Sample query-rewrite behaviour to evaluate (illustrative, not approved): question "Who owns the refund policy?" → rewritten internal query "refund policy owner responsible team" (no personal data, no collection names).
