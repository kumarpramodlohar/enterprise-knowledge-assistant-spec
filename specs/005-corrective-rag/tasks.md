# 005 Corrective RAG (CRAG) — Tasks

**Specification:** [spec.md](./spec.md) · **Plan:** [plan.md](./plan.md)

> Owner approved P1–P4 on 2026-10-22 despite the incomplete baseline evaluation. T18/T19 remain blocked. P4 defaults off and requires deployment plus per-request opt-in.

| ID  | Task                                                                              | Repository                         | Phase | Depends on           | Status                                |
| --- | --------------------------------------------------------------------------------- | ---------------------------------- | ----- | -------------------- | ------------------------------------- |
| C01 | Review baseline reports and record their limitations                              | Specification                      | Gate  | 001 T18, T19         | Done — 30 cases; no human review; owner authorized proceeding |
| C02 | Approve phases and record defaults in DEC-010                                      | Specification                      | Gate  | C01                  | Done — P1–P4; P4 dual opt-in           |
| C03 | Update spec, plan, and API contract for approved phases                           | Specification                      | Gate  | C02                  | Done — request and citation contract updated |
| C04 | Add `crag.*` configuration, disabled by default, and baseline parity coverage      | Backend                            | P1    | C03                  | Done                                  |
| C05 | Implement `RetrievalEvaluator` and `ActionSelector` with tests                    | Backend                            | P1    | C04                  | Done                                  |
| C06 | Add CRAG mode to evaluation runner and comparison reporting                       | Backend / QA                       | P1    | C05                  | Done — paired runner; representative live comparison pending reviewed corpus |
| C07 | Implement `KnowledgeRefiner` with citation-preserving tests                       | Backend                            | P2    | C06                  | Done                                  |
| C08 | Implement `QueryRewriter` and same-scope retrieval with adversarial tests         | Backend                            | P3    | C06                  | Done                                  |
| C09 | Frontend corrective-action messaging                                              | Frontend                           | P3    | —                    | Not approved; out of scope            |
| C10 | External web search and `EXTERNAL` citations                                      | Specification / Backend / Frontend | P4    | C03                  | Done — dual opt-in, bounded Tavily search, typed citations |
| C11 | Verification summary and record updates                                           | Specification                      | All   | Approved phases done | Done — backend focused tests and frontend build/tests pass; live provider call not run |
