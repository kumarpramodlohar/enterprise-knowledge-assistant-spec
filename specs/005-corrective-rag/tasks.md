# 005 Corrective RAG (CRAG) — Tasks

**Specification:** [spec.md](./spec.md) · **Plan:** [plan.md](./plan.md)

> All tasks are blocked until the MVP baseline evaluation is complete and DEC-010 is approved per phase. No task has started.

| ID  | Task                                                                              | Repository                         | Phase | Depends on           | Status                                |
| --- | --------------------------------------------------------------------------------- | ---------------------------------- | ----- | -------------------- | ------------------------------------- |
| C01 | Review MVP baseline evaluation and record retrieval gaps                          | Specification                      | Gate  | 001 T18, T19         | Blocked (MVP evaluation not complete) |
| C02 | Owner decision on DEC-010 and OD-1–OD-8; update decision status                   | Specification                      | Gate  | C01                  | Blocked                               |
| C03 | Update spec, plan, api-contract for approved phases                               | Specification                      | Gate  | C02                  | Blocked                               |
| C04 | `crag.*` configuration, default off; baseline parity test                         | Backend                            | P1    | C03                  | Blocked                               |
| C05 | `RetrievalEvaluator` and `ActionSelector` with unit tests                         | Backend                            | P1    | C04                  | Blocked                               |
| C06 | Add CRAG mode to evaluation runner; compare to baseline                           | Backend / QA                       | P1    | C05                  | Blocked                               |
| C07 | `KnowledgeRefiner` with citation-preserving tests                                 | Backend                            | P2    | C06                  | Blocked                               |
| C08 | `QueryRewriter` and scoped re-retrieval; adversarial scope tests                  | Backend                            | P3    | C06                  | Blocked                               |
| C09 | Frontend: show corrective action if OD-7 approved                                 | Frontend                           | P3    | C03, C08             | Blocked                               |
| C10 | Web search: separate approval, privacy/redaction design, `EXTERNAL` citation type | Specification / Backend / Frontend | P4    | OD-4 approved        | Blocked (not planned)                 |
| C11 | Verification summary and record updates                                           | Specification                      | All   | Approved phases done | Blocked                               |
