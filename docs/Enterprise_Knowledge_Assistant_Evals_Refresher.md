# Evals: 10-minute refresher and interview notes

This generic learning aid summarizes the main concepts and glossary from the [Evaluation Developer Guide](./Enterprise_Knowledge_Assistant_Evaluation_Guide_v1.md) for RAG and agentic applications. It omits detailed examples and project-specific plans; use the guide for depth.

## 1. What is an eval?

- An **evaluation (eval)** is a repeatable way to assess a system: define the target, success criteria, test cases, scoring method and decision. A metric is one measurement within that process.
- An **eval case** is one input with expected evidence or behavior. An **eval suite** groups related cases, methods and criteria for a capability or risk, such as retrieval or safety.
- The objective is an actionable decision: diagnose a failure, compare configurations, detect a regression or assess release readiness.

## 2. Model evals versus application evals

- **Model evals** assess model capabilities. Public benchmark evals use shared tests; custom model evals use task-specific data and criteria.
- **Application evals** assess the complete product or its parts, including prompts, retrieval, model, authorization, citations and user-visible outcomes. A strong benchmark does not guarantee a good application.
- **RAG evals** assess retrieval and evidence-grounded answers; **agentic evals** assess goal completion, tool use, decisions and outcomes across multiple steps.
- Compare benchmarks only when dataset, prompts (zero-shot or few-shot), model settings, attempts, tools, scoring and aggregation are compatible. `pass@1` uses one attempt; `pass@k` assesses success across multiple attempts. Temperature zero can reduce variation but does not guarantee determinism.
- **Public leaderboards** rank models or agents under particular evaluation conditions: [Arena](https://arena.ai/leaderboard) (human preference), [Artificial Analysis](https://huggingface.co/spaces/ArtificialAnalysis/LLM-Performance-Leaderboard) (performance and pricing), [Open LLM Leaderboard](https://huggingface.co/spaces/open-llm-leaderboard/open_llm_leaderboard) (open models), [HELM](https://crfm.stanford.edu/helm/latest/) (holistic evaluation), [SWE-bench](https://www.swebench.com/) and [SWE-bench-Live](https://swe-bench-live.github.io/) (software agents), [LiveCodeBench](https://livecodebench.github.io/leaderboard.html) (coding), and [MTEB](https://huggingface.co/spaces/mteb/leaderboard) (embeddings). Use rankings to shortlist, then test on your own tasks; check verification and possible benchmark contamination.

### Public benchmark examples

- **Knowledge and science:** MMLU and MMLU-Pro (multiple subjects), GPQA (graduate-level science), HellaSwag (commonsense reasoning), and [Humanity's Last Exam (HLE)](https://www.nature.com/articles/s41586-025-09962-4) (expert-level questions across disciplines).
- **Mathematics:** GSM8K (word problems) and MATH (challenging math problems).
- **Coding:** HumanEval, MBPP and LiveCodeBench. SWE-bench evaluates software-repository tasks with an agent and its tools, not just the model in isolation.
- **Factuality and behavior:** [SimpleQA](https://openai.com/index/introducing-simpleqa/) (short, verifiable factual questions and whether the model attempts an answer), TruthfulQA (truthfulness and misconceptions), and IFEval (instruction following).
- **Embeddings:** MTEB evaluates text embeddings across tasks including retrieval. A benchmark is the test; a leaderboard displays comparative results.

### Benchmark execution and capability coverage

- **Run:** load each test case, construct the prompt, call the model under recorded settings, then extract the answer, grade it and aggregate scores. A brittle extractor can misgrade a correct answer.
- **Long context:** test whether relevant information can be found and combined across long inputs; an advertised context-window size does not prove effective use. RULER is an example benchmark.
- **Multimodal:** test reasoning over images, charts or documents as well as text; examples include MMMU, ChartQA and DocVQA.
- **Reliability:** use representative samples, repeated runs where practical, and confidence intervals or uncertainty estimates. Small samples and nondeterminism make small score differences unreliable.

## 3. Evaluation levels

- **Component:** test one part, such as retrieval against labeled evidence. It isolates a cause but cannot prove the whole system works.
- **Workflow/integration:** test connected steps, such as retrieve-then-generate or ingest-then-index. It reveals interaction failures.
- **Whole application:** test the user-facing result and operational behavior, including authorization, correctness, citations and latency.
- Example: the right chunks may be retrieved, yet the generator can ignore them or give an incomplete answer. Test all three levels.

## 4. What to measure

- **Quality:** correctness, completeness, relevance and groundedness. Check citation validity, completeness and **accuracy** (whether the cited source supports the claim); flag unsupported claims and check abstention when evidence is insufficient.
- **Style and usefulness:** clarity, appropriate tone and whether the answer helps the intended user; use a clear rubric rather than treating style as factual correctness.
- **Safety:** prompt injection, jailbreaks, unauthorized access, sensitive-data leakage, toxicity, harmful content, bias/fairness and appropriate refusal. Good quality scores do not prove safety.
- **Operations:** retrieval and end-to-end latency, error and timeout rates, and token usage/cost where available. Report missing measurements as unavailable, not zero.
- **p95 latency** is the 95th percentile: approximately 95% of observed requests finish within that time. Always report the sample size and measurement window.

## 5. RAG triad

- **Context relevance:** are the retrieved passages useful for the question?
- **RAG basics:** a retriever finds document **chunks** (pieces of text); the generator uses that context to answer, ideally with **citations** pointing to supporting sources.
- **Groundedness/faithfulness:** are the answer's claims supported by the retrieved evidence? An answer can be grounded in evidence that is itself incorrect.
- **Answer relevance:** does the response address the user's question?
- The triad is not a complete eval: also check correctness, completeness, citations, authorization, safety and operations.

## 6. Retrieval metrics

- **Recall@K** = relevant items found in the top K / all relevant items for that question; top K means the first K retrieved results. If one of two gold chunks is found in the top five, Recall@5 = **0.5**. Average over answerable questions with labeled relevant items; report the sample size.
- **MRR** averages `1 / rank` of the first relevant item; a miss contributes zero. It indicates how early the first relevant result appears.
- **Hit rate@K** is the fraction of eligible questions with at least one relevant item in the top K. It does not show whether all required evidence was found.
- Recall does not penalize irrelevant results or measure ranking within K; pair it with context relevance or precision and MRR. Unanswerable questions need a separate abstention check.
- Compute retrieval metrics from raw retrieved candidates when available. Metrics derived only from returned citations must be labeled citation-based; they do not isolate retriever performance.

### Diagnosing retrieval misses

- Determine whether gold evidence was **absent** from the index/candidates, **below the similarity threshold**, or **ranked below K**. Verify that gold labels are correct and current.
- Examine per-case results and category slices; distinguish retrieval failures from generation failures when evidence was present but ignored.

## 7. Agentic evaluation

- Evaluate the **final outcome** against the task goal and constraints, including task completion, correctness and any required external state change.
- Evaluate the **trajectory**: whether the agent chose appropriate tools, supplied valid arguments, used tool results and followed required ordering or approval rules. Several different paths may be valid.
- Include cases for failed or misleading tools, unavailable information, ambiguous requests and injected instructions; check recovery, safe stopping and escalation when appropriate.
- Measure safety and operations independently: unauthorized actions, data exposure, harmful side effects, tool-call counts, latency and cost. Use controlled or simulated tools for risky actions.
- Example: for a booking agent, check both that it requests approval before a purchase and that the final booking matches the user's request; a convincing answer alone is not proof of success.

## 8. Golden dataset and evaluation methods

- Build a versioned, reviewed **golden dataset** of realistic questions, expected evidence or answers, including single-source, multi-source, unanswerable and adversarial cases. **Gold evidence** is the labeled evidence expected to support an answer. Protect confidential datasets.
- **Reference-based** checks compare with gold answers or evidence; **reference-free** checks use a rubric or supplied context without a predefined gold answer. Groundedness still needs evidence to compare against.
- **Programmatic checks** are repeatable for rules and formulas; **human review** handles nuance using a rubric; an **LLM judge** can scale subjective scoring but can be biased or inconsistent.
- A **rubric** describes what each score or verdict means. Calibrate an LLM judge against human labels before using it for pass/fail. Check label quality, sample counts and category slices; averages can hide important failures.
- Frameworks such as **DeepEval** and **Ragas** can help implement evaluation metrics and workflows; verify their metric definitions, integration, judge calibration and data handling. They do not replace application-specific tests or human review.

## 9. The evaluation loop

- Define the task and target; define measurable success criteria; build and freeze the dataset; choose scoring methods.
- Run the system as an authorized user; score results; analyze per-case failures and category slices, not just aggregate averages.
- Form a hypothesis, change one setting where practical, rerun on comparable cases and inspect regressions. Confirmed failures can become new versioned regression cases.
- Deploy and monitor only under the applicable approved policy. Online monitoring is different from offline evaluation and requires privacy-safe signals and appropriate approval.

## 10. Offline and online evaluation

- **Offline evals** use a fixed dataset, often with gold labels, to compare versions and catch known regressions before release.
- **Online evals** observe real use after deployment to find unexpected failures and **drift**: changes in user needs, documents or system behavior that make prior tests less representative.
- A **trace** is a structured record of a request or workflow. **Captured signals** include measured latency or user feedback; **computed signals** are evaluator-produced scores, such as a judge's faithfulness rating. Collect only authorized, privacy-safe data.
- **Red teaming** deliberately probes failures and attacks. **A/B testing** compares versions on live traffic; **human-in-the-loop (HITL)** places human review or approval in the live workflow.
- Online feedback and reference-free scores are indirect evidence, not proof of correctness. Review verified failures and add approved cases to the offline dataset.

## 11. Baselines and regression testing

- The first **characterization run** records observed behavior and configuration; it is not automatically optimal or an accepted baseline. An authorized reviewer must accept a comparable run as the reference.
- Compare current component, workflow and whole-application results with the accepted baseline; identify new, fixed and unchanged failures as well as metric changes.
- Preserve compatible historical reports for trends; older reports do not independently fail a run. Mark missing or incomparable evidence explicitly.
- Record dataset/label versions, corpus/index, model, prompt, effective settings and runner versions. Re-chunking or embedding changes require appropriate re-ingestion/re-indexing and label validation; compare only when definitions remain compatible.

## 12. Experiment tracking and deployment

- Record each experiment's run ID, baseline/parent, hypothesis, actual parameters, metrics, sample counts, versions and redacted report. Change one variable at a time where practical.
- A CI system can orchestrate evaluations, while an experiment tracker records runs, metrics and report references; for example, GitHub Actions and MLflow can serve these distinct roles. The evaluation runner computes scores; logs are for diagnosis.
- A possible **live deployment gate** requires approved thresholds and no unacceptable regression against an accepted compatible baseline. Equal results can pass; one improvement need not cancel a required safety or other failure.
- Define how the gate handles missing or incompatible evidence and exceptions. Local development need not be gated; deployment policy and thresholds depend on the organization.

## 13. Security and privacy

- Evaluate through authorized identities; the server must enforce access before retrieval, citations or AI-provider context. Treat uploaded and retrieved text as untrusted.
- Keep secrets, confidential questions, answers and passages out of logs and tracking artifacts. External providers or data movement require explicit authorization.
- For agents, authorize every tool action and test for unsafe side effects; isolate test environments and use synthetic or explicitly authorized data.

## 14. Interview answer: putting it together

- “I start with the user task and define quality, safety and operational criteria. I build a reviewed golden dataset with answerable, unanswerable and adversarial cases.”
- “I evaluate retrieval as a component, RAG as a workflow, and the complete application. For example, Recall@5 measures how much gold evidence was found, while groundedness checks whether the answer is supported by context.”
- “I use deterministic checks, human review and a calibrated judge as appropriate. I inspect individual cases and slices, because one aggregate score can hide safety or multi-hop failures.”
- “For an agent, I check task completion and tool-use trajectories, including failed tools, authorization and side effects. I allow different valid paths instead of requiring a single fixed sequence.”
- “For regression, I compare with an accepted compatible baseline, record configuration and versions, and investigate changes. CI can run the suite, while an experiment tracker keeps results for comparison.”
