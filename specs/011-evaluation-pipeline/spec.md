# 011 Evaluation Pipeline — Specification

**Status:** Draft for review — not approved for implementation. Thresholds and open items below are proposals until the product owner approves them.
**Related:** [001-project-foundation](../001-project-foundation/spec.md) (AC-10, AC-11, AC-13; T18/T19), [005-corrective-rag](../005-corrective-rag/spec.md), [009-retrieval-diagnostics](../009-retrieval-diagnostics/spec.md), DEC-007, DEC-008, DEC-010
**Concept guide:** [Evaluation Developer Guide](../../docs/Enterprise_Knowledge_Assistant_Evaluation_Guide_v1.md)
**Application repository:** Backend (`evaluation/`); this repository holds requirements only.

## Problem
EKA has a working evaluation runner, but it only reports retrieval-citation metrics, citation field completeness, evidence classification, and mean latency. It cannot show where a RAG failure occurs (retriever, generator, or their combination), has no automated generation-quality, safety, or operational percentile metrics, and has no repeatable loop that turns failures into regression cases. As a result, the project cannot make an evidence-based ship / no-ship or prompt/model-change decision, and T18/T19 remain blocked.

## Users
- AI/backend engineers who change prompts, models, thresholds, embeddings, or CRAG.
- QA and product reviewers who label data and review results.
- The product owner making release decisions.

## Scope
Application evals (component, workflow, and whole-application) for the EKA chat path and ingestion path. Model evals (public capability benchmarks) are out of scope: EKA consumes those results when choosing a model.

## Functional requirements

### Pipeline and structure
- FR-1: The pipeline shall implement the 8-step flow: define task/target, define success criteria, build dataset, define eval method, run, evaluate (with an improve-and-rerun loop), analyze, deploy and monitor (with production failures returning to dataset building).
- FR-2: The runner shall remain outside Spring application startup and user request handling, and shall evaluate the application through its public API unless an approved diagnostic interface exists (see OI-1).
- FR-3: The existing CLI (`node evaluation/evaluate.mjs`), environment variables, dataset v1 schema, and report fields shall continue to work.

### Dataset
- FR-4: The dataset format shall extend v1 with optional `referenceAnswer`, `category`, `source`, `expectedBehavior`, `tags`, and `difficulty`; the loader shall validate rows and report the dataset hash and version.
- FR-5: The dataset shall support case categories for factual, multi-hop, unanswerable, adversarial, and latency-probe cases, and cases where gold evidence is ranked low in the retrieved set.
- FR-6: Confidential datasets shall be read from an external access-controlled path; only non-sensitive samples and the schema may be committed.
- FR-6a: Golden dataset authoring guidance (evidence labelled for every relevant source, mixed single-source and multi-source questions, paraphrased and unanswerable cases, second-reviewer sampling, versioning and freezing) shall be documented in the evaluation guide (§6.2) and the backend evaluation README.
- FR-6b: Each dataset version shall record the chunking and embedding configuration its chunk-ID labels were created under, and the runner shall warn when the current configuration differs (see OI-9).

### Metrics (each reported with sample size)
- FR-7: **Retrieval:** Recall@K, MRR, and hit rate computed on the raw retrieved candidates (subject to OI-1); until available, the existing citation-based metrics shall be labelled as citation-based. Recall@K is defined as the number of relevant chunks in the top K divided by the total number of relevant chunks for that question, averaged over answerable questions only; questions with no relevant chunks are excluded and the number of questions used is reported.
- FR-8: **Generation:** faithfulness/groundedness, hallucination/extra-content rate, answer relevance, citation validity and completeness.
- FR-9: **Combined:** answer correctness against `referenceAnswer` or gold evidence, and answer-versus-abstain classification accuracy.
- FR-10: **Operational:** p50/p95/p99 for retrieval and end-to-end latency, timeout/error rate, and token usage/cost when the API or logs expose it; otherwise reported as unavailable.
- FR-11: **Safety:** prompt-injection resistance, cross-collection and unauthorized-source leakage, sensitive-data exposure, and correct refusal/abstention.

### Methods
- FR-12: Each metric shall declare its method: programmatic/deterministic (code), human review, or model-graded (LLM judge). Methods and selection guidance are described in the evaluation guide (§6.1).
- FR-13: An LLM judge shall not affect any pass/fail result until its agreement with human labels on a sample has been measured and recorded (calibration).
- FR-14: Human review shall use a documented rubric and 1–5 scales for groundedness and usefulness (helpfulness); the helpfulness rubric anchors are 5 = fully answers the question, accurate and complete, appropriate tone; 3 = partially helpful, missing something or slightly off; 1 = unhelpful, wrong, or irrelevant (guide §6.1.1). Reports shall show the score distribution and number of rated answers; review data shall be importable into the report. Treatment of correct abstentions on unanswerable questions is an open item (OI-10).

### Runs, reports, and comparison
- FR-15: Every run shall record dataset hash/version, model and configuration versions, embedding configuration, prompt version, runner version, and timestamps.
- FR-16: Reports shall be machine-readable and include a human-readable summary with per-category slices, a worst-case list, failure clusters, known limitations, and a comparison to a stored baseline. Reports shall include a per-case retrieval table (gold IDs, retrieved IDs, found IDs, per-case Recall@K) without question or answer text, and each miss shall carry a cause classification (OI-1 dependent).
- FR-17: Reports shall not contain question or answer text unless the dataset is explicitly marked non-confidential.
- FR-18: Metric targets shall be configurable, labelled `proposed` until approved, and shall not fail a run until approved (report-only mode by default).

### Feedback loop and monitoring
- FR-19: A reviewer-driven procedure shall convert a verified failure into a regression case with `source: production-failure`.
- FR-20: Any automated capture of production failures shall exist only after an approved privacy-safe design (OI-4).
- FR-21: Operational metrics shall use existing health, log, and metric signals; no new telemetry shall include question, answer, or passage text.

### Authentication and automation
- FR-22: The runner shall support the local profile now and OIDC bearer authentication when a Keycloak test realm exists (OI-5); credentials come from the environment only.
- FR-23: The suite shall be runnable on demand and, after approval, on a schedule or in CI with non-confidential data (OI-6). In CI, a build shall fail when a metric is below an approved threshold (OI-7); until thresholds are approved the run is report-only.
- FR-24: Online (production-traffic) evaluation is not part of this feature's first delivery. Any online evaluation shall be added only after OI-12 is decided, and shall keep captured and computed signals free of question, answer, and passage text unless an approved privacy design says otherwise (guide §6.4, §6.5, §9.7).

## Non-functional requirements
- NFR-1: Runs are reproducible: same dataset, versions, and settings produce comparable results; nondeterminism is documented and sample counts recorded.
- NFR-2: Unit tests cover dataset validation and metric computation without calling a model.
- NFR-3: A failed API call aborts or is counted explicitly; it is never silently scored as success.
- NFR-4: Runtime cost of a run is bounded and configurable (case limit, concurrency, timeouts).

## Acceptance criteria
- AC-1: Given a v1 dataset, when the runner executes, then it produces the same fields as today and does not fail.
- AC-2: Given a v2 dataset with an invalid row, then the loader rejects it with the row number and no question text.
- AC-3: Given a case whose gold chunk is ranked 5th and the generator cites chunk 1, then the report shows retrieval success, generation faithfulness, and answer-correctness failure separately.
- AC-4: Given a run, then the report includes p50/p95/p99 latency with sample size, and error/timeout counts.
- AC-5: Given an adversarial case with an injection instruction inside a document, then the safety result records whether the instruction was followed.
- AC-6: Given a case requesting content from an unauthorized collection, then the safety result records any leakage as a failure.
- AC-7: Given an uncalibrated LLM judge, then its scores are labelled `advisory` and excluded from pass/fail.
- AC-8: Given a calibration sample, then the report records agreement with human labels before the judge is marked `calibrated`.
- AC-9: Given two runs, then the comparison shows metric deltas against the stored baseline and flags differing dataset hashes.
- AC-10: Given a confidential dataset, then no question, answer, or passage text appears in the report, logs, or repository.
- AC-11: Given an unapproved target, then the run does not fail on it and marks the target `proposed`.
- AC-12: Given the documented procedure, then a reviewer can add a verified failure as a regression case and see it in the next run.
- AC-13: Given T18/T19 criteria, then the report maps results to AC-10, AC-11, and AC-13 of the foundation specification.
- AC-14: Given a question with 2 relevant chunks of which 1 appears in the top 5 retrieved candidates, then Recall@5 for that question is 0.5; a question with no relevant chunks is excluded from Recall and the report states how many questions were used.
- AC-15: Given a run before raw retrieved candidates are available, then Recall@K and MRR are labelled citation-based in the report; after OI-1 is implemented, they are labelled retrieval-based and computed from raw candidates.
- AC-16: Given a miss, then the report distinguishes whether the gold chunk was absent, below the similarity threshold, or ranked below K (requires raw candidates and scores).
- AC-17: Given six answerable questions with per-question Recall@5 of 1.0, 0.5, 1.0, 1.0, 0.0, and 0.5, then the report shows each per-question value and a mean of approximately 0.67 with the sample size.
- AC-18: Given a dataset version created under a different chunking or embedding configuration than the running system, then the report warns that chunk-ID labels may be stale.
- AC-19: Given a run, then the report lets a reviewer combine retrieval and answer outcomes per case (full recall/wrong answer, zero recall/correct answer, unanswerable/answered) to separate retrieval, generation, and abstention failures.
- AC-20: Given human helpfulness ratings, then the report shows the distribution of scores 1–5 and the number of rated answers, not only the mean, and reports groundedness and helpfulness separately.

## Error scenarios
- Dataset missing, unreadable, empty, or invalid: fail fast with a safe message.
- API 4xx/5xx or timeout: record per case and fail the run when the configured failure budget is exceeded.
- Judge provider unavailable: mark affected metrics unavailable; do not substitute zeros.
- Human review missing: leave human metrics null and report coverage.

## Security and privacy requirements
- Use a real authorized user; never bypass server-side authorization.
- Credentials and confidential datasets stay out of source control and logs.
- Do not send passages or answers to an external judge without explicit authorization; default to a local provider for confidential data.
- Treat retrieved and uploaded text as untrusted input, including in judge prompts.
- A diagnostic/evaluation interface, if approved, must be unavailable or disabled in deployed profiles by default and must enforce authorization before returning content.

## Proposed targets (not approved)
Carried from the foundation specification as evaluation targets only: ≥ 80% supported and relevant answers on a curated 50-question set; ≥ 95% valid citations on factual answers; retrieval p95 ≤ 1.5 s for up to 10,000 chunks on documented local hardware. No new numeric targets are proposed here.

## Out of scope
- Model capability benchmarks and building or fine-tuning models.
- Agent, multi-turn, and tool-selection evals (not in the MVP).
- A separately deployed evaluation service, UI dashboard, or hosted eval platform (revisit only after the first approved baseline).
- Storing conversation history or user feedback in the application (DEC-008).
- Changing retrieval defaults, thresholds, or prompts as part of building the pipeline.
- Online human evaluation: A/B testing on production traffic and human-in-the-loop review of live answers (guide §6.1.2). Red-team findings are handled manually and added to the dataset as adversarial regression cases (FR-5, FR-11).
- Online evaluators, tracing or observability tooling, live dashboards, and alerting on production traffic (guide §6.4, §6.5), pending OI-12.

## Open items
- **OI-1: Raw retrieval visibility.** Current Recall@5 uses returned citations. Options: (a) keep citation-based metrics and label them; (b) add an authorized, non-production evaluation/diagnostic response carrying retrieved chunk IDs, ranks, and scores; (c) run an in-process Java evaluation harness. *Recommendation: (b), disabled by default in deployed profiles.*
- **OI-2: Generation-judge model.** Options: local Ollama judge only; hosted judge for non-confidential data only; hosted judge after explicit data authorization. *Recommendation: local by default.*
- **OI-3: Answer-context visibility for faithfulness.** Citations expose snippets, not the full prompt context. Options: judge against cited snippets only; expose full context through the OI-1 diagnostic interface. *Recommendation: start with cited snippets and record the limitation.*
- **OI-4: Production-failure capture.** DEC-008 and spec 009 forbid storing/logging questions. Options: reviewer-submitted failures only; opt-in user feedback with an approved retention policy; none. *Recommendation: reviewer-submitted only until a privacy design is approved.*
- **OI-5: OIDC runner authentication** depends on the Keycloak test realm (backlog B04).
- **OI-6: Automation.** Options: manual runs; scheduled run on a non-confidential corpus; CI gate after thresholds are approved. *Recommendation: manual, then scheduled report-only.*
- **OI-7: Approval of thresholds** and which metrics become release gates.
- **OI-8: Dataset and reviewers.** An authorized representative corpus and reviewer availability are required (backlog B06); this specification does not remove that dependency.
- **OI-9: Stable gold labels.** Chunk IDs change when documents are re-chunked, re-embedded, or re-uploaded. Options: (a) label chunk IDs and record the ingestion configuration, re-labelling after changes; (b) label a stable document reference plus a text anchor and resolve to chunk IDs before each run; (c) label documents only and score at document level. *Recommendation: (a) first, evaluate (b) if re-labelling cost becomes high.*
- **OI-10: Helpfulness scoring of unanswerable questions and naming.** The source rubric defines only scores 5, 3 and 1 for answerable questions. Options: (a) a correct abstention scores 5 and an invented answer scores 1; (b) score helpfulness only on answerable cases and track abstention separately; (c) keep the rubric as-is. Also confirm that "helpfulness" equals the existing `humanReview.usefulness` key. *Recommendation: (a), with the key unchanged.*
- **OI-11: Evaluation runner language.** The current runner (`evaluation/evaluate.mjs`) and the planned modules are Node.js (ES modules). Python has the richest eval ecosystem (e.g., RAGAS, DeepEval, statistics and notebook tooling), which may matter for LLM-judge calibration and metric breadth. Options: (a) Node.js only for the MVP; (b) Node.js runner plus an optional, separate Python component (for example judge calibration or analysis) that reads and writes the same versioned dataset and JSON report files, so neither runtime depends on the other's internals; (c) rewrite the runner in Python; (d) in-process Java harness (see OI-1 option c). Constraints for any option: call the public API as a real authorized user; keep the dataset and report formats language-neutral (JSON, schema-versioned); do not send confidential content to an external judge or library without authorization (guide §10); and avoid maintaining two parallel implementations of the same metric. *Recommendation: (a) for the MVP, designing the dataset/report schemas to be language-neutral so (b) can be added later without rework; decide (b) or (c) when a specific library need is established.*
- **OI-12: Online evaluation scope and privacy.** Online evals need per-turn logs and user signals; the notes' design stores raw messages, retrieved context, responses, and feedback, which DEC-008 and specs 005/009 currently prohibit. Options: (a) none for the MVP — offline evals plus scheduled report-only runs and text-free operational metrics only; (b) captured, text-free signals only (latency, errors, evidence-classification counts) on a dashboard with threshold alerts; (c) full tracing with sampled evaluators, requiring an approved privacy design (what is stored, PII scrubbing, retention, access control, external-provider authorization) and a reversal or amendment of DEC-008; (d) opt-in user feedback capture (also needs a DEC-008 amendment). Related: OI-4, OI-6, OI-7. *Recommendation: (a), then (b) using existing health/log/metric signals; revisit (c)/(d) only after the owner approves a privacy design. Tool selection (for example LangSmith or a self-hosted store) is deferred.*
