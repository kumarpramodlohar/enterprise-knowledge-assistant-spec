# 011 Evaluation Pipeline — Tasks

**Specification:** [spec.md](./spec.md) · **Plan:** [plan.md](./plan.md)

Status values: `Not started`, `Blocked` (names the blocker), `Done`. Nothing is implemented. Do not start an implementation task until the specification is approved and its dependent open items are decided.

| ID | Task | Repository | Files | Depends on | Verifies | Status |
|---|---|---|---|---|---|---|
| EV01 | Review the spec; record decisions for OI-1–OI-12 in `product-decisions.md` | Specification | `docs/implementation/product-decisions.md`, `specs/011-evaluation-pipeline/spec.md` | — | — | Blocked: owner decisions |
| EV02 | Add the evaluation guide to the documentation index/README | Specification | `README.md` | — | — | Done |
| EV03 | Extract loader/validator into `lib/dataset.mjs`; support v1 and v2 rows; no behavior change | Backend | `evaluation/evaluate.mjs`, `evaluation/lib/dataset.mjs`, `evaluation/test/` | EV01 | AC-1, AC-2 | Blocked: EV01 |
| EV04 | Extract API client with timeout, failure budget, and explicit error counting | Backend | `evaluation/lib/client.mjs`, `evaluation/test/` | EV03 | NFR-3 | Blocked: EV01 |
| EV05 | Move existing retrieval/citation/evidence metrics into `lib/metrics/`; label citation-based Recall@5; unit-test Recall@K with the 2-relevant/1-retrieved example and exclusion of unanswerable cases | Backend | `evaluation/lib/metrics/retrieval.mjs`, `evaluation/test/` | EV03 | AC-1, AC-14, AC-15 | Blocked: EV01 |
| EV06 | Add latency p50/p95/p99, error/timeout rate, and available usage/cost to operational metrics | Backend | `evaluation/lib/metrics/operational.mjs` | EV04 | AC-4 | Blocked: EV01 |
| EV07 | Build report writer: JSON + Markdown, per-case retrieval table (gold/retrieved/found IDs, no text), per-category slices, worst cases, redaction, target status | Backend | `evaluation/lib/report.mjs`, `.gitignore` | EV05 | AC-10, AC-11, AC-17, AC-19 | Blocked: EV01 |
| EV08 | Add baseline storage and run-to-run comparison with dataset-hash warning | Backend | `evaluation/lib/report.mjs` | EV07 | AC-9 | Blocked: EV01 |
| EV09 | Add `referenceAnswer`/abstain correctness metrics and human-review import | Backend | `evaluation/lib/metrics/end-to-end.mjs` | EV03, EV07 | AC-3 | Blocked: EV01 |
| EV10 | Create non-sensitive sample dataset covering categories, including gold-evidence-ranked-low and unanswerable cases | Backend | `evaluation/datasets/` | EV03 | AC-3 | Blocked: EV01 |
| EV11 | Implement safety metrics and adversarial cases (document-embedded injection, unauthorized collection, sensitive data) | Backend | `evaluation/lib/metrics/safety.mjs`, `evaluation/datasets/` | EV04, EV10 | AC-5, AC-6 | Blocked: EV01 |
| EV12 | Update API contract and spec for the evaluation diagnostic response, if OI-1 option (b) is approved | Specification | `specs/011-evaluation-pipeline/`, API contract docs | EV01 | — | Blocked: OI-1 |
| EV13 | Implement the authorized, non-production diagnostic response with tests (authorization, profile gating, no content logging) | Backend | chat/retrieval code, backend tests | EV12 | FR-7, security | Blocked: OI-1 |
| EV14 | Compute Recall@K/MRR/hit rate on raw retrieved candidates, relabel as retrieval-based, and classify misses (absent / below threshold / below K) | Backend | `evaluation/lib/metrics/retrieval.mjs` | EV13 | FR-7, AC-15, AC-16 | Blocked: OI-1 |
| EV15 | Implement judge adapter interface and a local-provider judge; mark outputs `advisory` | Backend | `evaluation/lib/judges/` | EV09, OI-2 | AC-7 | Blocked: OI-2 |
| EV16 | Add faithfulness, hallucination/extra-content, and relevance metrics using the judge | Backend | `evaluation/lib/metrics/generation.mjs` | EV15, OI-3 | FR-8 | Blocked: OI-3 |
| EV17 | Add judge calibration against human labels and promote to `calibrated` only after recorded agreement | Backend | `evaluation/lib/judges/` | EV16, B06 reviewers | AC-8 | Blocked: B06 |
| EV18 | Document the regression-case procedure for verified failures (`source: production-failure`) | Backend / Specification | `evaluation/README.md`, guide | EV10 | AC-12 | Blocked: OI-4 |
| EV19 | Add OIDC bearer authentication to the runner | Backend | `evaluation/lib/client.mjs` | EV04, B04 | FR-22 | Blocked: B04 |
| EV20 | Add scheduled report-only run on a non-confidential corpus | Backend | CI/scheduler config | EV08, EV10 | FR-23 | Blocked: OI-6 |
| EV21 | Update backend evaluation README: schema v2, metrics, methods, limitations, run steps | Backend | `evaluation/README.md` | EV05–EV11 | — | Blocked: EV05–EV11 |
| EV22 | Run the full unit suite and a v1-compatibility regression run; record actual results | Backend | `evaluation/test/` | EV03–EV08 | AC-1, NFR-2 | Blocked: EV03–EV08 |
| EV23 | Run the representative human-reviewed evaluation and record results in T18/T19 | All | foundation `tasks.md`, `backlog.md` | EV09, EV14, EV16, B06 | AC-13 | Blocked: B06 dataset and reviewers |
| EV24 | Update backlog, plan, and task status to reflect verified work only | Specification | `backlog.md`, `plan.md` | all completed tasks | — | Not started |
| EV25 | Record dataset-level metadata (version, hash, chunking/embedding configuration, reviewer/date) and warn on configuration mismatch; decide stable-label approach (OI-9) | Backend / Specification | `evaluation/lib/dataset.mjs`, `evaluation/README.md` | EV03, OI-9 | AC-18 | Blocked: OI-9 |
| EV26 | Document golden-dataset authoring and results-analysis procedure in the backend evaluation README (aligned with guide §6.2–§6.3) | Backend | `evaluation/README.md` | EV10 | FR-6a | Blocked: EV10 |

## Suggested order
EV01 → EV03 → EV04 → EV05 → EV06 → EV07 → EV08 → EV10 → EV09 → EV11 → EV21 → EV22; in parallel after approval: EV12–EV14 (OI-1), EV15–EV17 (OI-2/OI-3), EV18, EV19, EV20; finish with EV23–EV24.
