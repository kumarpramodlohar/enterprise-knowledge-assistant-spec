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
Application evals (component, workflow, and whole-application) for the EKA chat path and ingestion path. Public model-capability benchmarks remain out of scope. An owner-provided custom workflow proposes comparing candidate models as configured within the EKA application; that comparison scope and its relationship to the existing pipeline require a decision under OI-14. The workflow is documented in the [evaluation guide](../../docs/Enterprise_Knowledge_Assistant_Evaluation_Guide_v1.md#98-custom-candidate-model-evaluation-workflow-owner-provided-proposal) and is not approved implementation scope.

**Provider option proposal (not approved):** If OI-14 approves candidate-model comparison and the required data-egress review authorizes it, evaluate OpenRouter as an optional chat-only route using the Spring AI OpenAI-compatible integration. Keep embeddings on their existing provider/index, run candidates in separately configured backend instances, and record the actual provider, model identifier, and route for each run. This proposal does not add OpenRouter to approved production providers or authorize sending confidential prompts, questions, or retrieved passages to OpenRouter or an upstream model provider. Do not implement the integration or run evaluations with confidential data until both approvals are recorded.

**Evaluation framework direction (owner-selected, implementation pending):** Use DeepEval for future application-evaluation work, subject to the integration pilot and approval of this draft specification. Preserve the existing Node.js CLI and dataset/report contracts unless the pilot justifies a separately scoped runtime change. DeepEval does not replace EKA-specific deterministic, human-reviewed, authorization, safety, and operational checks.

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
- FR-25: The regression suite shall produce distinct result matrices for component, workflow/integration, and whole-application targets. Each matrix shall identify its stable suite/target/case IDs, metric and method, sample size, current result, applicable baseline result and delta, status, and run/configuration references; unavailable or unmeasured cells shall be explicit, never treated as passing.
- FR-26: Each run shall be compared with the last accepted baseline for each comparable suite/target and with every retained prior report. The report shall show historical per-level results and deltas where comparison is valid, and explicitly flag missing history or incomparable runs; it shall not silently discard prior reports.
- FR-27: Comparability shall record dataset schema/version/hash, corpus/index and label configuration, target/case/metric identity, and relevant model, prompt, retrieval, and runner versions. A changed configuration may be an intentional experiment; preserve and display the difference, but do not claim a like-for-like regression result when the dataset, labels, or target definition are incompatible.
- FR-28: Regression status shall distinguish pass, new failure, fixed prior failure, unchanged failure, metric regression, metric improvement, and incomparable/unavailable. Gating may use only approved thresholds and the designated accepted baseline; older historical reports provide trend/context and shall not independently fail a run.
- FR-29: Before tuning or regression gating, the first baseline exercise shall create a report-only characterization run using a fixed, authorized dataset and corpus/index snapshot. It shall record effective runtime configuration and all unavailable/unexposed settings; this observed baseline is descriptive and shall not be represented as optimal, approved, or release-ready. A run becomes the accepted regression baseline only after review against the approved requirements, data labels, and configuration decisions.
- FR-30: Each experiment/trial shall have a stable run ID and record its parent/baseline run, purpose/hypothesis, varied parameter(s), effective full configuration, dataset/corpus/index and code/prompt versions, metric matrices at all configured levels, outcomes, errors, resource/latency measurements, and reviewer/acceptance state. Secret values shall never be stored; record safe identifiers or redacted presence/version metadata instead.
- FR-31: Configuration experiments shall use a controlled comparison plan: hold the dataset, corpus/index, evaluation cases, and non-target settings constant where possible; vary one parameter or an explicitly defined parameter group; record required re-ingestion/re-indexing and provider/data-egress approvals; and report interactions or confounders. Temperature or any other setting not exposed by the application shall be marked unsupported/unavailable until implemented and verified, not silently simulated.
- FR-32: After approval, GitHub Actions shall orchestrate manual, scheduled, and approved change-triggered offline evaluation runs using a fixed authorized dataset/corpus/index and the effective tested configuration. Runs shall begin report-only; the live deployment gate is governed by FR-34–FR-37. The workflow shall publish a concise run summary and preserve a redacted machine-readable report as a run artifact.
- FR-33: After approval, the workflow shall record each run in MLflow with a stable run ID, parent/baseline linkage, source commit, dataset/corpus/index identity, effective configuration parameters, evaluated metrics and their sample counts/statuses, and safe report/artifact references. The evaluation runner/framework computes quality metrics; MLflow records and presents them; Actions logs are diagnostic output, not the canonical experiment record. No secrets or confidential question, answer, passage, or equivalent content may be written to logs, artifacts, or MLflow.

### Live deployment gate (owner-selected direction; implementation pending)
- FR-34: After this specification and the gate policy are approved and the gate is implemented, a live deployment shall proceed only if every required approved threshold is met and no required metric or case exceeds an approved regression limit against the explicitly accepted compatible baseline. Results equal to the baseline may pass; strict improvement is not required. A gain in one required metric shall not compensate for another required metric or case failing its rule. Existing security, release and deployment approvals still apply.
- FR-35: The gate shall use an evaluation of the candidate artifact and its deployment-relevant effective configuration, with an authorized dataset, corpus/index, suite, metric methods and accepted baseline whose compatibility is verified. Record artifact identity, source commit, configuration and dataset/index identities, policy version, baseline/run references, results and decision. The deployment job shall verify the decision matches the exact artifact and configuration being deployed; changes after evaluation require a new applicable evaluation or an approved revalidation procedure.
- FR-36: Once enforced, the live deployment gate shall deny automatic deployment and surface a reason when a required threshold or regression rule fails, the required policy or accepted baseline is missing, evidence is missing, stale, incompatible, incomplete, untrusted or unavailable, an evaluation fails, or the gate or tracking dependency needed to verify evidence cannot be reached. A report-only evaluation is not a gate pass. Judge metrics may gate only after the calibration required by FR-13. No automatic baseline promotion or bypass is permitted; bootstrap, emergency and rollback handling requires a separately approved policy (OI-17).
- FR-37: This gate shall not prevent local development, local application startup or local evaluation runs. CI evaluation may run report-only before the live gate is ready; unapproved thresholds shall never be presented as passed. Selection of required gates, margins, sufficient samples, evidence freshness and variability handling remains subject to OI-7 and OI-17.

### Feedback loop and monitoring
- FR-19: A reviewer-driven procedure shall convert a verified failure into a regression case with `source: production-failure`.
- FR-20: Any automated capture of production failures shall exist only after an approved privacy-safe design (OI-4).
- FR-21: Operational metrics shall use existing health, log, and metric signals; no new telemetry shall include question, answer, or passage text.

### Authentication and automation
- FR-22: The runner shall support the local profile now and OIDC bearer authentication when a Keycloak test realm exists (OI-5); credentials come from the environment only.
- FR-23: The suite shall be runnable on demand and, after approval, on a schedule or in CI with non-confidential data (OI-6). Evaluation runs are report-only until the live deployment gate and its rules are approved and implemented (OI-7, OI-17); enforcement is limited to live deployment under FR-34–FR-37.
- FR-24: Online (production-traffic) evaluation is not part of this feature's first delivery. Any online evaluation shall be added only after OI-12 is decided, and shall keep captured and computed signals free of question, answer, and passage text unless an approved privacy design says otherwise (guide §6.4, §6.5, §9.7).
- Proposed workflow addition (pending OI-14): if candidate-model comparison is approved, each candidate shall be run against the same validated, versioned dataset and EKA flow, with model/configuration versions and per-case results recorded. Changes to prompts, retrieval, embeddings, corpus, or other variables shall be recorded so model effects are not misattributed. OpenRouter is a proposed optional chat-only route for this work, subject to technical verification against the deployed Spring AI version and explicit provider/data-egress approval; it is not an approved production provider.

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
- AC-21: Given a configured suite with component, workflow/integration, and whole-application targets, then one run produces a separate result matrix for each level and marks each expected target/metric as measured, failed, unavailable, or not run.
- AC-22: Given retained reports from prior runs, then the current report lists each historical report and its per-level comparison status; compatible rows show current result, prior result, and delta, while incompatible rows show why no numeric comparison is claimed.
- AC-23: Given a case that failed in an earlier accepted run and passes now, then its stable case ID is reported as fixed; a newly failing case is reported as a new failure, and an unchanged failing case remains visible.
- AC-24: Given an intentionally changed model, prompt, retrieval setting, or runner version with the same compatible dataset and case definitions, then the report records the changed configuration and identifies the run as a version comparison; it does not conceal the delta or mislabel the change itself as an automatic regression.
- AC-25: Given a confidential evaluation dataset, then archived matrices and historical comparisons contain no question, answer, or passage text and preserve only approved identifiers, metrics, and redacted metadata.
- AC-26: Given the first evaluation run, then it is identified as a report-only characterization run and records the effective settings, dataset/corpus/index identity, software versions, and missing/unexposed settings; it does not automatically establish an accepted or optimal baseline.
- AC-27: Given a parameter-tuning trial, then its run ID links to the baseline/parent run and records the hypothesis, changed parameters, unchanged controls, required re-indexing/re-ingestion, all three level matrices, and results; secret values are absent.
- AC-28: Given a setting not currently exposed by EKA (including chat temperature unless later verified), then the experiment record marks it unsupported/unavailable and does not claim that EKA evaluated it.
- AC-29: Given an approved Actions evaluation run, then the job starts EKA with the intended configuration, records effective settings and run identity, invokes the evaluation runner on the fixed authorized inputs, and publishes a redacted report and summary; unapproved thresholds do not fail the job.
- AC-30: Given a completed evaluation run, then its MLflow record includes the run lineage, safe parameters, computed metric values/sample counts/statuses, and report reference, while logs, artifacts, and tracking metadata contain no credentials or confidential evaluation text.
- AC-31: Given an enforced live gate and compatible candidate evidence meeting every approved threshold and regression limit, including results equal to the baseline, then the gate permits the deployment job to proceed subject to other release controls.
- AC-32: Given a live candidate with any required threshold failure, unacceptable metric or case regression, or uncalibrated required judge, then the gate denies deployment even when another metric improves and records the reason.
- AC-33: Given an enforced live gate and a missing, stale, failed, incomplete, untrusted or incompatible report, policy or accepted baseline, an unavailable required verification dependency, or a candidate artifact/configuration mismatch, then deployment is denied with an explicit reason; report-only or unapproved thresholds do not constitute a pass.
- AC-34: Given local application startup or a local evaluation run without a baseline, tracker or live gate, then it remains usable without the live deployment gate. Passing a live gate alone does not promote the baseline.

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
- **OI-11: DeepEval integration runtime and scope.** DeepEval is the owner-selected framework direction (DEC-014); the current runner is Node.js (ES modules). Pilot its documented TypeScript/JavaScript integration against the required EKA metrics and existing CLI before choosing the integration shape. Preserve the Node.js entry point and versioned, language-neutral JSON dataset/report contracts. If needed coverage cannot be delivered cleanly there, consider a separately bounded Python component that reads/writes those same contracts rather than rewriting the runner. Do not duplicate metrics, call the public API as a real authorized user, and do not send confidential content to external judges or services without explicit authorization (guide §10). The selected runtime and metric coverage remain to be verified by EV29.
- **OI-12: Online evaluation scope and privacy.** Online evals need per-turn logs and user signals; the common logging design stores raw messages, retrieved context, responses, and feedback, which DEC-008 and specs 005/009 currently prohibit. Options: (a) none for the MVP — offline evals plus scheduled report-only runs and text-free operational metrics only; (b) captured, text-free signals only (latency, errors, evidence-classification counts) on a dashboard with threshold alerts; (c) full tracing with sampled evaluators, requiring an approved privacy design (what is stored, PII scrubbing, retention, access control, external-provider authorization) and a reversal or amendment of DEC-008; (d) opt-in user feedback capture (also needs a DEC-008 amendment). Related: OI-4, OI-6, OI-7. *Recommendation: (a), then (b) using existing health/log/metric signals; revisit (c)/(d) only after the owner approves a privacy design. Tool selection (for example LangSmith or a self-hosted store) is deferred.*
- **OI-13: Golden-dataset interchange format.** The owner-provided custom workflow requests CSV, while the existing runner and this specification use JSONL. Decide whether CSV is the canonical dataset, an import/export format converted to JSONL, or deferred. Any selected format must preserve schema validation, safe quoting/escaping, dataset version/hash, and external access-controlled storage for confidential content.
- **OI-14: Candidate-model comparison scope and provider eligibility.** Decide whether comparing model candidates within the EKA application is part of this pipeline or remains a separate future activity. If included, define comparable-run controls (fixed dataset, corpus/index, prompt and retrieval configuration except for the intentionally varied candidate), eligible providers/data egress, evaluator methods, reporting, and decision criteria. The proposal is to assess OpenRouter for chat only through Spring AI's OpenAI-compatible integration, without changing embeddings or authorizing production use. Before integration or any confidential-data run, verify compatibility with the deployed Spring AI version and explicitly approve the data categories that may be sent to OpenRouter and its selected upstream provider(s). Public model-capability benchmarks remain out of scope.
- **OI-15: Regression-history retention and baseline acceptance.** Decide who may accept/promote a run as the next baseline, how long historical reports and matrices are retained, where they are stored, and who may access or purge them. Until decided, no run automatically replaces the accepted baseline; reports must be access-controlled, omit confidential text, and identify any unavailable or purged historical report rather than silently treating it as comparable.
- **OI-16: Actions/MLflow deployment and data controls.** DEC-015 selects GitHub Actions for evaluation orchestration and MLflow for experiment tracking. Before implementation, decide the runner trust boundary (GitHub-hosted vs controlled/self-hosted), dataset/provider egress eligibility, MLflow hosting/network placement, artifact backend, access control, retention, safe corpus/dataset references, and baseline-promotion permissions. No confidential dataset/provider egress or hosted tracking of confidential content is authorized by DEC-015.
- **OI-17: Live gate policy and enforcement.** Decide which live deployments and configuration changes require evaluation; required suites, metrics and cases across levels; directional thresholds and tolerances (OI-7), sample size, repeatability/variance and evidence freshness; candidate artifact/configuration binding, trusted report verification and protected deployment enforcement; and authority and audit controls for baseline acceptance. Define bootstrap, rollback and emergency handling, including whether any narrowly controlled exception is allowed and who can approve it. Until approved, no exception or automatic bypass is authorized and no numeric rule is implied. Local development remains outside this gate.
