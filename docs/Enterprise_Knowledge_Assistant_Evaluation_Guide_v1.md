# Enterprise Knowledge Assistant — Evaluation (Evals) Developer Guide

| | |
|---|---|
| **Document ID** | EKA-EVAL-GUIDE-001 |
| **Status** | Draft for review — explanatory guide, not an approved requirement |
| **Audience** | Developers, QA, product owners, reviewers |
| **Source** | Training notes supplied by the owner (9 images and two text passages), analyzed against the current EKA code and specifications |
| **Related** | [Feature specification 011](../specs/011-evaluation-pipeline/spec.md), [plan](../specs/011-evaluation-pipeline/plan.md), [tasks](../specs/011-evaluation-pipeline/tasks.md), [backend evaluation README](../../enterprise-knowledge-assistant-backend/evaluation/README.md), [foundation spec](../specs/001-project-foundation/spec.md) (AC-13), [DEC-007 / DEC-010](./implementation/product-decisions.md) |

> **How to read this page.** Sections 1–6 explain evals in general (what, why, types, risks, the 8-step process). Sections 7–10 map those ideas to EKA: what already exists, what is missing, and what is proposed. Anything labelled **Proposal** is not approved. Numeric targets quoted here are *proposals from the source documents*, not release gates.

## Contents

1. [What is an eval?](#1-what-is-an-eval)
2. [Types of evals: Model evals vs Application evals](#2-types-of-evals)
3. [What an application eval can target](#3-what-an-application-eval-can-target)
4. [Risk categories](#4-risk-categories)
5. [Why component evals are not enough (RAG failure points)](#5-why-component-evals-are-not-enough)
6. [The 8-step eval pipeline](#6-the-8-step-eval-pipeline) — includes eval methods (§6.1), building a golden dataset (§6.2), and analyzing results (§6.3)
7. [Where EKA is today](#7-where-eka-is-today)
8. [Mapping EKA to the eval taxonomy](#8-mapping-eka-to-the-eval-taxonomy)
9. [Proposed EKA eval pipeline](#9-proposed-eka-eval-pipeline)
10. [Guardrails specific to EKA](#10-guardrails-specific-to-eka)
11. [Glossary and FAQ](#11-glossary-and-faq)

---

## 1. What is an eval?

An **eval is not just a metric. An eval is the complete testing setup** for an LLM-powered system. It answers six questions:

| # | Question | EKA example |
|---|---|---|
| 1 | **What are we evaluating?** | The `/api/v1/chat/query` answer path (retrieve → evidence check → generate → cite). |
| 2 | **What does "good" mean?** | Grounded in retrieved evidence, valid citations, honest "insufficient evidence", acceptable latency. |
| 3 | **What test cases are we using?** | A versioned, access-controlled set of questions with expected evidence. |
| 4 | **How are we judging the output?** | Code checks, human review, and (proposal) a calibrated LLM judge. |
| 5 | **When are we running it?** | Before a release, after changing prompt/model/threshold, and on a schedule. |
| 6 | **Which tool are we using?** | The versioned runner in the backend repository (`evaluation/evaluate.mjs`). |

**The goal is not just a score.** The goal is to answer practical decisions:

- Can this model be used for this particular task or application?
- Is the system good enough to ship?
- Did prompt v2 improve over prompt v1?
- Is the RAG answer grounded in the retrieved context?
- Is the agent completing the task correctly? *(EKA has no agent workflow in the MVP.)*
- Is the chatbot safe for real users?
- Is the latency under control?

> **Rule of thumb:** if an eval run cannot change a decision (ship / don't ship / keep prompt v1 / switch model), it is a report, not an eval.

---

## 2. Types of evals

The source notes distinguish two types. Both are LLM evals, but they answer different questions and are owned by different people.

### 2.1 Model evals

**Evaluate the model itself — its general capabilities.** Capabilities in the notes:

| Capability | Question |
|---|---|
| Reasoning | Can it reason? |
| Knowledge | Can it answer knowledge-based questions? |
| Maths | Can it solve maths problems? |
| Coding | Can it write code? |
| Instruction following | Can it follow instructions? |
| Long context | Can it follow long documents? |
| Multimodal understanding | Can it understand images? |
| Tool use | Can it use tools? |

Model capabilities are generally measured with **public benchmarks**. (The attached image is cut off before it lists them; well-known examples such as MMLU, GSM8K, and HumanEval are general industry knowledge, not part of the attachment.)

**Who owns it:** frontier model labs. An application engineer **consumes** these results when choosing a model; they do not re-run or build them.

### 2.2 Application evals (the focus for EKA)

**Evaluate the behaviour and performance of an LLM-powered application — at the level of the entire system or of one component inside it.**

In an application eval we do **not** ask "Can the model do this?" We ask **"Does the product work?"**

The notes use a "CampusX course assistant" as the example. The same questions translated to EKA:

| Course-assistant question (source) | EKA equivalent | Eval dimension |
|---|---|---|
| Did it answer the student's question correctly? | Did it answer the user's question correctly from the uploaded documents? | Answer correctness |
| Did it use the course material properly? | Did it use the retrieved passages and cite them? | Retrieval use, citations |
| Was the answer faithful to the retrieved context? | Does every claim trace back to cited evidence? | Faithfulness / groundedness |
| Was it clear for a beginner? | Is the answer clear and useful (human usefulness rating)? | Usefulness |
| Did it avoid hallucinating policies? | Did it avoid inventing facts when evidence is missing? | Hallucination / abstention |
| Did it respond quickly enough? | Is retrieval and end-to-end latency within budget? | Latency |
| Did it stay safe? | No leaks across collections, no prompt-injection compliance, no sensitive-data exposure. | Safety |

### 2.3 Application's building blocks

The notes show an LLM application as a hub with these parts (circled = emphasized in the notes): **User Interface**, Input Handler, **Prompt Layer**, **LLM / Model**, Context / Memory, **Tools / APIs**, **Orchestrator / Workflow**, **Retrieval System**, **Embedding Model**, **Vector Database**, **Guardrails / Safety**, **Output Parser**, **Monitoring / Logging**, **Feedback Loop**.

Each of these can fail independently, and each can be an eval target (Section 3).

---

## 3. What an application eval can target

The "Failure Points / Target" diagram splits targets into three levels:

```mermaid
flowchart TD
    T[Failure points / eval targets]
    T --> C[Component]
    T --> W[Workflow]
    T --> A[Entire application]
    C --> C1[Prompt · Retriever · Reranker · Query rewriter · Embedding model]
    C --> C2[Vector database · Output parser · Tool selector · Memory · Guardrails]
    W --> W1[RAG workflow · Agent workflow · Multi-turn conversation workflow]
    W --> W2[Structured output workflow · Document extraction workflow]
    A --> A1[End-to-end behaviour, latency, cost, safety]
```

| Level | What you test | Pro | Con |
|---|---|---|---|
| **Component** | One part in isolation (e.g., the retriever against labelled chunks). | Fast, cheap, pinpoints the cause. | Passing parts can still make a failing system. |
| **Workflow** | A multi-step path (e.g., the full RAG path or document ingestion). | Catches hand-off bugs between steps. | Harder to attribute a failure to one step. |
| **Entire application** | The product as a user sees it, including latency and safety. | The only level that answers "does it work?" | Slowest, needs the richest dataset. |

**Recommended practice:** evaluate all three levels; use component evals to *diagnose* and application evals to *decide*.

---

## 4. Risk categories

The notes group LLM application risk into three categories. Keep them separate when designing metrics — a high quality score says nothing about safety.

| Category | The question | Concerns | Is about… |
|---|---|---|---|
| **Application quality** | "Is the answer any good?" | Correct, relevant, complete answers that do the job asked. | The **content** of the answer. |
| **Safety** | "Could the answer cause harm?" | No toxic/dangerous content, no bias, no leaking private data, no being tricked into breaking its rules. | The **harm** the answer could do. |
| **Operational** | "Is it fast, cheap, and reliable enough to run?" | Responds quickly, costs acceptable money per answer, does not crash or fail under real traffic. | The **system producing** the answer. |

```mermaid
flowchart LR
    R[LLM application eval risks] --> Q[Quality: content]
    R --> S[Safety: harm]
    R --> O[Operational: speed, cost, reliability]
```

### 4.1 Detailed criteria

The criteria below come from the attached tables. The last column maps each to EKA and is our analysis, not part of the source.

#### 1. Application quality

**1a. Core generation quality**

| Criterion | Description | EKA relevance |
|---|---|---|
| Correctness / accuracy | Whether the factual claims in the answer are actually true. | Applies. Needs a reference answer or gold evidence (spec 011 FR-9). |
| Relevance | Whether the answer addresses what the user actually asked. | Applies (FR-8). |
| Completeness | Whether the answer covers all parts of a multi-part question. | Applies; add multi-part questions to the dataset. |
| Instruction following | Whether the output obeys explicit constraints (format, length, etc.). | Limited: the chat API has no user-set format or length constraints; relevant to prompt-v2 comparisons. |

**1b. RAG-specific quality** — the primary focus for EKA.

| Criterion | Description | EKA relevance |
|---|---|---|
| Context relevance | Whether the retrieved chunks are actually relevant to the query. | Applies (component: retriever). |
| Retrieval recall | Whether all chunks needed to answer were retrieved. | Applies; the current runner measures it from citations only (gap G1). |
| Groundedness / faithfulness | Whether every claim is supported by the retrieved context. | Applies; not yet automated (gap G2). |
| Citation accuracy | Whether cited sources genuinely support the claims made. | Applies. Today only citation field completeness is checked, not whether the source supports the claim. |

**1c. Agent / tool-use quality**

| Criterion | Description | EKA relevance |
|---|---|---|
| Tool selection | Whether the agent chose the right tool for the task. | Not applicable in the MVP (no agent or tools). |
| Parameter correctness | Whether the tool was called with valid, correctly-typed arguments. | Not applicable. |
| Task completion | Whether the agent actually accomplished the user's goal. | Not applicable. |
| Error recovery | Whether it handled tool failures gracefully and retried sensibly. | Not applicable for agents. The optional web-search fallback (DEC-010 P4) should abstain safely on failure, which falls under operational and safety checks. |

**1d. Multi-turn conversation quality**

| Criterion | Description | EKA relevance |
|---|---|---|
| Context retention / memory | Whether it remembers relevant facts given earlier in the conversation. | Not applicable: no conversation history in the MVP (DEC-008). |
| Clarification behavior | Whether it asks for clarification when the request is ambiguous. | Not applicable today; EKA answers or states insufficient evidence. |

#### 2. Safety

| Criterion | Description | EKA relevance |
|---|---|---|
| Toxicity | Whether the output contains offensive, abusive, or hateful language. | Applies; include in the safety suite. |
| Harmful content | Whether it provides dangerous instructions (self-harm, weapons, illegal acts). | Applies; include refusal cases. |
| Bias / fairness | Whether outputs are free of unfair treatment or stereotyping across groups. | Applies; lower priority for a document Q&A assistant. |
| PII leakage | Whether it exposes personal/private data. | Applies; also covers cross-collection and unauthorized-source leakage (spec 011 FR-11). |
| Prompt injection / jailbreak resistance | Whether it resists attempts to override its rules or bypass guardrails. | Applies; includes instructions embedded in uploaded documents (AC-11). |

#### 3. Operational

| Criterion | Description | EKA relevance |
|---|---|---|
| End-to-end latency | Total time from user request to final response. | Applies; report p50/p95/p99, not only the mean (gap G4). |
| Cost per request | Total token/compute spend to produce one response. | Applies; unavailable through the MVP API (gap G5). |
| Token efficiency | Whether it achieves its result without wasteful token usage. | Applies; depends on usage data. Context budget is configured (4,000 tokens, DEC-007). |
| Error / failure rate | Fraction of requests that fail, time out, or return malformed output. | Applies (spec 011 FR-10, NFR-3). |
| Latency under load | Whether latency stays acceptable at production concurrency. | Applies, but needs a load test; the current runner sends sequential requests. |

#### 4.2 Applicability summary for EKA

| Group | Applies now | Deferred / not in MVP |
|---|---|---|
| 1a Core generation | Correctness, relevance, completeness | Instruction following (limited) |
| 1b RAG-specific | All four criteria | — |
| 1c Agent / tool use | — | All four (no agent in the MVP) |
| 1d Multi-turn | — | Both (DEC-008) |
| 2 Safety | All five | — |
| 3 Operational | All five (cost and load need new measurement) | — |

---

## 5. Why component evals are not enough

A RAG chatbot has two primary failure points.

### 5.1 Retrieval-time failure

> Did the system retrieve the relevant documents or not?

Typical measures: Recall@K, MRR, hit rate, context relevance.

### 5.2 Generation-time failure

> Is the generated answer…
> a) **faithful** to the retrieved context?
> b) **grounded** (supported by evidence, not training memory)?
> c) free of **hallucination** and of **extra content** the question did not ask for?

Typical measures: faithfulness / groundedness, answer relevance, hallucination rate, citation validity.

### 5.3 Both can pass while the system fails

The source gives this scenario (restated):

1. Retrieval fetches **K = 5** documents. The document that really contains the answer is **#5 (last)**. Retrieval is "working" — the right document is in the set.
2. The generator answers from document **#1** or **#2**, faithfully to *those* documents. Generation is "working" — it is grounded in what it was given.
3. The final answer is **wrong**. Each part passed; the **system** failed.

```mermaid
flowchart LR
    Q[Question] --> R[Retriever K=5]
    R --> D1[Doc 1]
    R --> D2[Doc 2]
    R --> D3[Doc 3]
    R --> D4[Doc 4]
    R --> D5["Doc 5 ✔ has the answer"]
    D1 --> G[Generator]
    D2 --> G
    G --> A["Answer from Doc 1/2: grounded but wrong"]
    D5 -. not used .-> G
```

**Conclusion:** you need an eval on the **combination (Retrieval + Generator)** — an end-to-end *answer-correctness* eval with a reference answer or gold evidence, not just component scores.

### 5.4 There is still one more eval: operations

Even if retrieval, generation, and the combination all pass, the system can **miss its latency threshold**. So a whole-application **latency** eval is also required (and by extension cost and error rate — the operational category).

### 5.5 Summary of the eval set this implies

| Eval | Level | Catches |
|---|---|---|
| Retrieval relevance | Component | Wrong or missing documents |
| Generation faithfulness / groundedness | Component | Unsupported claims, hallucination, extra content |
| **Retrieval + generation correctness** | **Workflow / application** | Right docs retrieved but wrong answer used |
| **Latency / cost / reliability** | **Application (operational)** | Correct but too slow or too costly |
| Safety | Application | Leaks, injection, harmful output |

### 5.6 How do I know the retriever is working? (Recall@K)

The retriever is working when it **puts the evidence needed to answer the question into the top K results**. The standard measure is **Recall@K**:

$$
\text{Recall@K} = \frac{\text{number of relevant items retrieved in the top } K}{\text{total number of relevant items}}
$$

(Formula from the notes.) Here an "item" is a **chunk** and "relevant" means a human has confirmed that chunk contains evidence for the question (the *gold evidence*, stored in `relevantChunkIds`).

**Worked example (K = 5).** A question has 2 relevant chunks, A and B. The retriever returns `[X, A, Y, Z, W]`.

- Relevant items in the top 5: 1 (A). Total relevant: 2.
- Recall@5 = 1 / 2 = **0.5**. Chunk B was missed, so an answer needing both is likely incomplete.

If the retriever had returned both A and B in the top 5, Recall@5 would be 1.0. Average the per-question values over the dataset to get the reported Recall@5.

**How to read the number**

| Result | What it suggests | What to check next |
|---|---|---|
| Recall@5 high | The needed evidence usually reaches the generator. | Then look at generation faithfulness and answer correctness (§5.3): a high recall does not guarantee a correct answer. |
| Recall@5 low | The generator never sees the evidence, so it cannot answer correctly. | Chunking, embedding model, similarity threshold, metadata filters, or missing/failed ingestion. |
| Recall@5 low but Recall@10 high | The evidence is retrieved but ranked too low. | Ranking quality, K, a reranker (not in the MVP). |
| Recall high but MRR low | The evidence is present but not near the top; the generator may favour earlier, less relevant chunks (the §5.3 scenario). | Ranking and context ordering. |

**What Recall@K does not tell you**

- It ignores **noise**: returning 4 irrelevant chunks next to the relevant one still scores 1.0. Pair it with context relevance (are the returned chunks useful?) or precision.
- It ignores **order** within the top K. Use MRR for rank.
- It is only defined for questions that **have relevant items**. Unanswerable questions (empty `relevantChunkIds`) are excluded from Recall and checked through the answer-versus-abstain accuracy instead.
- It is only as good as the **labels**. If the gold chunks are wrong or incomplete, the score is misleading.

**Practical checklist for deciding the retriever is healthy**

1. Use a labelled dataset where each answerable question lists its gold chunk IDs.
2. Compute Recall@K and MRR on the **raw retrieved candidates**, not on the final citations.
3. Report the number of questions used, and slice by category (factual, multi-hop, etc.) so one easy category does not hide a failing one.
4. Compare against a baseline when you change the embedding model, chunk size, K, or threshold; change one thing at a time.
5. Inspect the misses individually: was the gold chunk absent, below the threshold, or ranked below K?
6. Treat any target as **proposed** until the product owner approves it; this guide does not set a Recall@K threshold.

**EKA specifics**

- **Current runner:** it computes `recallAt5` and MRR from the chunk IDs in the **returned citations** (gap G1), so it measures what the answer cited, not what the retriever fetched. A low value can come from the retriever, the similarity threshold (default 0.70, DEC-007), or the generator not citing a retrieved chunk. Until raw candidates are available (spec 011 OI-1), read it as *citation-based recall*.
- **Threshold effect:** chunks below the similarity threshold are dropped before generation, so a threshold set too high lowers recall and produces insufficient-evidence answers. The existing 30-case reports show zero Recall@5 at 0.70 and are not human reviewed, so they are not evidence of retriever quality (DEC-010).
- **Existing diagnostics:** spec 009 logs ranked candidates with scores and whether they met the threshold (no text). These help investigate individual misses today, but they are logs, not an aggregate metric.

---

## 6. The 8-step eval pipeline

This is the automation flow from the notes (the flow diagram spans three images: steps 1–5, the evaluate/improve loop, and the analyze step).

```mermaid
flowchart TD
    S1[1. Define task and target] --> S2[2. Define success criteria]
    S2 --> S3[3. Build a dataset]
    S3 --> S4[4. Define an eval method]
    S4 --> S5[5. Run the model / system]
    S5 --> S6{6. Evaluate the results}
    S6 -- needs improvement --> IMP[Improve the model or the system\ne.g. change to a bigger model, prompt, retrieval]
    IMP --> S5
    S6 -- acceptable --> S7[7. Analyze the results]
    S7 --> S8[8. Deploy and monitor]
    S8 -- production failures --> NEW[Add failures to the dataset]
    NEW --> S3
```

| Step | What you do | Key outputs | Common mistakes |
|---|---|---|---|
| **1. Define task & target** | State what the app must do and which level you are testing (component / workflow / application). | One-paragraph task statement; target list. | Evaluating "the chatbot" without naming the failure point. |
| **2. Define success criteria** | Turn "good" into measurable pass conditions per risk category. | Metric list with thresholds (marked *proposed* until approved). | Inventing thresholds with no baseline. |
| **3. Build a dataset** | Collect representative questions, expected evidence/answers, and unanswerable and adversarial cases. | Versioned dataset with provenance. | Using only easy, synthetic, or leaked questions. |
| **4. Define an eval method** | Choose how each metric is judged: code, human, LLM judge. | Method per metric, with calibration plan for any LLM judge. | Trusting an uncalibrated LLM judge. |
| **5. Run the model** | Execute the system over the dataset with pinned versions. | Raw per-case results. | Not recording model/config/dataset versions. |
| **6. Evaluate the results** | Score against criteria. If not good enough, **improve the model or the system**, then re-run from step 5 (the notes say this may include changing to a bigger model). | Pass/fail per metric. | Changing several things at once, so you cannot attribute the change. |
| **7. Analyze the results** | Slice by category, find failure clusters, inspect worst cases. | Failure analysis and next actions. | Reading only the average. |
| **8. Deploy & monitor** | Release, watch production signals. **If production failures occur, add them to the dataset and restart from step 3.** | Monitoring signals; new dataset cases. | Never feeding production failures back. |

**Two loops to remember**

- **Inner loop (steps 5 → 6 → improve → 5):** fast iteration on prompt/model/system until criteria pass.
- **Outer loop (step 8 → 3):** production failures become permanent regression cases.

### 6.1 Eval methods (detail for step 4)

An **eval method** is the mechanism that decides whether an output is good or not — the actual procedure that takes an output and produces a judgment about it. In the eval pipeline, step 4 chooses the method for each metric (the notes' margin comment: *eval pipeline → method works*).

| # | Method | Who/what produces the verdict | Typical checks | Strengths | Limits |
|---|---|---|---|---|---|
| 1 | **Programmatic / deterministic** | Code | Exact match, regex, JSON schema validation, running the output (e.g., execute code or SQL) and comparing results against a rule or known correct answer | Fast, cheap, reproducible | Works only where correctness is mechanically checkable |
| 2 | **Human** | A person | Rate, rank, or compare outputs directly | Gold standard for nuanced, subjective, or high-stakes judgments | Most expensive and slowest |
| 3 | **Model-graded (LLM-as-judge)** | A strong LLM | Scores or ranks the output against a rubric; used where there is no single right answer but "good" can be described — helpfulness, tone, groundedness | Scales subjective checks | Needs a clear rubric and validation against human judgments |

**Choosing a method.** Prefer the cheapest method that is trustworthy for the property being measured, and combine them:

```mermaid
flowchart TD
    Q{Can correctness be checked mechanically?}
    Q -- Yes --> P[Programmatic check]
    Q -- No --> R{Can you describe what good looks like as a rubric?}
    R -- Yes --> J[LLM judge, validated against human labels]
    R -- No or high stakes --> H[Human review]
```

**Applied to EKA metrics** (proposal; see [spec 011 FR-12–FR-14](../specs/011-evaluation-pipeline/spec.md)):

| Metric | Method |
|---|---|
| Recall@K, MRR, hit rate | Programmatic (compare retrieved IDs to gold IDs) |
| Citation field completeness; citation resolves to an authorized source | Programmatic |
| Answer-versus-abstain classification | Programmatic |
| Latency percentiles, error rate, token counts | Programmatic |
| Prompt-injection and cross-collection leakage checks | Programmatic where a known marker or unauthorized ID can be detected; human review otherwise |
| Groundedness / faithfulness, hallucination, relevance | LLM judge (after calibration) with human sampling |
| Answer correctness against a reference answer | Programmatic for exact facts; human or judge for free text |
| Usefulness, clarity | Human review |
| Citation accuracy (does the source really support the claim?) | LLM judge or human review |

An LLM judge is a model too, so its verdict must be validated before it influences a decision (§9.5).

### 6.2 Building a golden dataset (detail for step 3)

A **golden dataset** (gold set) is a curated set of questions where a human has recorded the **correct evidence** (and, optionally, the correct answer) in advance. Every automated retrieval metric is computed by comparing what the system returned against this ground truth, so the dataset's quality caps the quality of every score.

**Example from the notes** (a course-assistant corpus; IDs are the labels used in the example):

| Query ID | Question | Gold doc IDs |
|---|---|---|
| q1 | How long is the ML course? | 101 |
| q2 | What are the prerequisites for the ML course and how long is it? | 101, 103 |
| q3 | What is the fee for the Deep Learning course? | 202 |
| q4 | Does the ML course cover neural networks? | 101, 104 |
| q5 | How do I get a refund if I drop out? | 301 |
| q6 | Is there any EMI or installment option for fees? | 205, 207 |

Observations worth copying:

- **Single-source and multi-source questions are mixed.** q1 and q3 need one source; q2, q4, and q6 need two. Multi-part or multi-hop questions are what make Recall interesting (partial credit is possible).
- **Questions are written in the user's own words.** q5 says "drop out" while the gold document likely says something else (e.g., "withdrawal"); this tests vocabulary mismatch, not keyword matching.
- **Each question lists every relevant source,** not just one. A missing gold ID makes a correct retrieval look like a miss.

**How to build one for EKA**

| Step | Action |
|---|---|
| 1. Choose the corpus | Use an authorized, representative document set; keep confidential content out of the repository (§10). |
| 2. Collect questions | Real or realistic user questions from subject-matter experts, support/FAQ material, and known past failures. Avoid writing questions by copying a sentence from the document, which makes retrieval unrealistically easy. |
| 3. Label the evidence | For each question a reviewer lists **all** chunk IDs that support the answer (`relevantChunkIds`). EKA labels at **chunk** level, not document level (see below). |
| 4. Add reference answers | Short expected answer (`referenceAnswer`) so answer correctness can be scored later. |
| 5. Cover the categories | Single-source, multi-source/multi-part, paraphrased/vocabulary-mismatch, **unanswerable** (empty `relevantChunkIds`), adversarial, and cases where the gold chunk is likely to rank low. |
| 6. Review the labels | A second reviewer checks a sample; resolve disagreements; record who reviewed and when. |
| 7. Version and freeze | Give the dataset a version and hash; change it only by adding a new version, so scores stay comparable. |
| 8. Grow it | Add verified production failures as regression cases (pipeline step 8 → 3). |

**Size and balance.** The foundation spec proposes a curated 50-question set as a starting evaluation target (not an approved requirement). Keep enough cases per category that a category score is not decided by one question.

**Document-level vs chunk-level gold.** The example labels whole documents (101, 103…). EKA's runner and schema use **chunk IDs** produced at ingestion. Chunk IDs change when a document is re-chunked, re-embedded, or re-uploaded, so labels can go stale. Mitigation options (open decision, not decided here): store a stable document reference plus a text anchor with each label and re-resolve it to chunk IDs before a run, or re-label after any ingestion change. Until decided, record the chunking and embedding configuration in the dataset version.

**Existing EKA tooling.** The backend already has a dataset builder (`build-dataset.mjs`), a 30-case seed question file, and an optional review-sheet export. These are not a representative, human-reviewed golden set (DEC-010).

### 6.3 Analyzing the evaluation results (detail for step 7)

#### Worked example: Recall@5 per query

Using the six questions above and K = 5:

| Query | Gold IDs | Retrieved top-5 | Found | Recall@5 |
|---|---|---|---|---|
| q1 | 101 | 101, 202, 108, 305, 410 | 101 | 1/1 = **1.0** |
| q2 | 101, 103 | 101, 202, 108, 305, 410 | 101 | 1/2 = **0.5** |
| q3 | 202 | 202, 205, 101, 309, 118 | 202 | 1/1 = **1.0** |
| q4 | 101, 104 | 104, 101, 210, 305, 401 | 101, 104 | 2/2 = **1.0** |
| q5 | 301 | 118, 209, 405, 210, 150 | (none) | 0/1 = **0.0** |
| q6 | 205, 207 | 205, 101, 308, 209, 410 | 205 | 1/2 = **0.5** |

**Mean Recall@5 = (1.0 + 0.5 + 1.0 + 1.0 + 0.0 + 0.5) ÷ 6 = 4.0 ÷ 6 ≈ 0.67.**

Other metrics computed from the same table (our calculation, using the retrieved order shown):

| Metric | Calculation | Result |
|---|---|---|
| Hit rate@5 (at least one gold item found) | 5 of 6 queries (all but q5) | ≈ 0.83 |
| MRR (first gold item's rank) | q1 = 1, q2 = 1, q3 = 1, q4 = 1 (104 is rank 1), q5 = 0, q6 = 1 → 5 ÷ 6 | ≈ 0.83 |

#### Reading the table: look past the average

The average of 0.67 hides three different situations. Triage each query:

| Query | Pattern | Likely cause to investigate |
|---|---|---|
| q1, q3, q4 | Full recall | Healthy. Check generation next. |
| q2, q6 | **Partial recall** — one of two needed sources found | Multi-part questions: the retriever fetched one half. Check chunk size, whether the question needs query decomposition/rewriting, and whether the missing source ranked just below K (try Recall@10). The answer is likely incomplete. |
| q5 | **Total miss** — nothing relevant retrieved | Vocabulary mismatch ("drop out" vs the document's wording), the gold chunk missing from the index, a failed ingestion, a metadata filter, or the similarity threshold. Often the highest-value case to fix. |

Note that **retrieved IDs that are not gold are not automatically wrong** (e.g., 202 in q1). Recall does not penalize them; judge their usefulness with context relevance or precision.

#### Analysis procedure

1. **Per-query table first.** Never report only the mean. Keep the table of gold IDs, retrieved IDs, found, and score.
2. **Classify every miss** into one cause:
   - *Absent:* the gold chunk is not in the candidates at all (indexing, embedding, wording, chunking, label error).
   - *Below threshold:* it was a candidate but filtered out by the similarity threshold (EKA default 0.70, DEC-007).
   - *Ranked below K:* it was found but too low (ranking, K).
   - *Label error:* the gold label is wrong or stale — fix the dataset, not the system.
3. **Slice by category** (single-source, multi-source, paraphrased, unanswerable, adversarial) so a strong easy category does not hide a weak one.
4. **Combine retrieval and generation** for each query to separate the failure points from §5:

   | Retrieval | Answer | Interpretation |
   |---|---|---|
   | Full recall | Correct | Working end to end. |
   | Full recall | Wrong or unfaithful | Generation problem (prompt, model, context ordering — the §5.3 scenario). |
   | Partial/zero recall | Wrong or incomplete | Retrieval problem; fix retrieval first. |
   | Zero recall | Correct anyway | Suspicious: possible model memory instead of evidence (groundedness failure) or a label error. |
   | No relevant items (unanswerable) | Abstains | Correct behaviour. |
   | No relevant items (unanswerable) | Answers confidently | Hallucination/abstention failure. |

5. **Form one hypothesis, change one thing,** re-run on the same dataset version, and compare to the previous run (the §6 inner loop). Changing chunk size, embedding model, K, and threshold together makes the result unattributable.
6. **Check for regressions,** not only improvements: a change that fixes q5 may lower q1.
7. **Record the decision and limits:** dataset version/hash, configuration and model versions, number of questions per category, what was changed, and known weaknesses of the dataset. With only six questions, one query moves the mean by about 0.17 — treat small-sample differences as signals to inspect, not proof.
8. **Feed failures back:** add each confirmed production failure to the dataset (§6, step 8 → 3).

#### What EKA's report gives you today

The current runner prints aggregate metrics and per-case rows without question or answer text, but they are **citation-based** (§5.6, gap G1). It does not yet list the retrieved IDs, classify misses, or slice by category. Spec 011 adds those (AC-3, AC-14–AC-17). Until then, investigate individual misses with the retrieval diagnostics logs from spec 009 (rank, score, threshold outcome, no text).

---

## 7. Where EKA is today

Verified against the backend repository (`evaluation/evaluate.mjs`, `evaluation/README.md`) and the specification repository.

### 7.1 What exists

| Capability | Status |
|---|---|
| Versioned runner (`node evaluation/evaluate.mjs`) that calls `POST /api/v1/chat/query` | Implemented |
| Dataset JSONL schema: `id`, `question`, `answerable`, `relevantChunkIds`, optional `humanReview` | Implemented |
| Dataset SHA-256, model version, and config version recorded in every report | Implemented |
| Metrics: Recall@5, MRR, citation-field completeness, evidence-classification accuracy, mean end-to-end and retrieval latency, mean human scores | Implemented |
| Optional baseline-vs-CRAG paired comparison with deltas | Implemented |
| Optional human review sheet export (non-confidential corpora only) | Implemented |
| Safe retrieval diagnostics (ranks, scores, threshold outcome) in logs only | Implemented (spec 009) |
| Dataset builder and 30-case seed for the EKA documentation corpus | Implemented (not human reviewed) |

### 7.2 Known gaps and limitations (observed in the code)

| # | Gap | Why it matters |
|---|---|---|
| G1 | **"Recall@5" is computed from returned citations, not from the raw retrieved top-K.** | It measures cited evidence, not retriever recall, so it cannot isolate a retriever failure (§5.1). |
| G2 | **No automated faithfulness / groundedness / hallucination score.** Only optional manual 1–5 ratings, null until reviewed. | Generation-time failure (§5.2) is unmeasured at scale. |
| G3 | **No answer-correctness metric** (no reference answer in the schema). | The "right doc retrieved, wrong doc used" failure (§5.3) is invisible. |
| G4 | **Latency is reported as a mean only** — no p50/p95/p99, no retrieval-vs-generation breakdown beyond `retrievalMs`. | Operational thresholds are normally percentile-based. |
| G5 | **No cost or token usage** (reported as unavailable). | Operational risk is incomplete. |
| G6 | **No safety eval suite** (prompt injection, cross-collection leakage, sensitive data) beyond backend integration tests. | Safety is a separate risk category (§4). |
| G7 | **No production-failure feedback loop.** | Step 8 → 3 of the pipeline is manual. |
| G8 | **Runner authenticates with local Basic auth only.** | Cannot yet evaluate OIDC-secured deployments. |
| G9 | **No automated runs, no threshold gating, no report history/trend.** | Evals run only when someone remembers. |
| G10 | **No representative, access-authorized, human-reviewed dataset.** | Blocks T18/T19 (backlog B06). The existing 30-case reports are explicitly *not* representative quality evidence. |

---

## 8. Mapping EKA to the eval taxonomy

### 8.1 Components

| Component (from the diagram) | In EKA today | Eval relevance |
|---|---|---|
| Prompt | Evidence/safety chat prompt in the backend | **High** — prompt versions must be compared (v1 vs v2). |
| Retriever | pgvector top-K with similarity threshold (default K=5, 0.70, DEC-007) | **High** — Recall@K, MRR on true candidates. |
| Reranker | None in the MVP | Not applicable now. |
| Query rewriter | CRAG P3, disabled by default (DEC-010) | Evaluate only when CRAG is enabled. |
| Embedding model | Ollama / OpenAI, independently selectable (DEC-002) | High — changing it requires re-indexing and re-evaluation. |
| Vector database | PostgreSQL + pgvector | Covered through retriever evals and latency. |
| Output parser | Citation validation against authorized indexed sources | High — citation validity. |
| Tool selector | None | Not applicable. |
| Memory | None (no conversation history, DEC-008) | Not applicable. |
| Guardrails | Evidence threshold, injection handling, server-side authorization | **High** — safety eval. |

### 8.2 Workflows

| Workflow | In EKA | Eval relevance |
|---|---|---|
| RAG workflow | Core chat path | **Primary target.** |
| Document extraction workflow | PDF/DOCX/TXT/MD extraction → chunking → embedding | Medium — extraction fidelity and chunk quality affect retrieval. |
| CRAG workflow | Optional, disabled by default | Compare against baseline when enabled. |
| Agent / multi-turn / structured-output | Not in the MVP | Out of scope. |

### 8.3 Entire application

End-to-end answer correctness, latency, error rate, cost, and safety through the public API (and, later, the UI).

### 8.4 Risk-category map

| Risk | EKA metrics (existing → gap) |
|---|---|
| **Quality** | Recall@K, MRR, citation completeness, evidence-classification accuracy → **add** faithfulness, hallucination, answer correctness, answer relevance, usefulness |
| **Safety** | Backend integration tests → **add** injection, cross-collection leakage, sensitive-data and refusal checks as an eval suite |
| **Operational** | Mean latency, mean retrieval latency → **add** p50/p95/p99, error/timeout rate, tokens and cost |

---

## 9. Proposed EKA eval pipeline

> **Proposal.** Subject to the open decisions in [spec 011](../specs/011-evaluation-pipeline/spec.md#open-items).

### 9.1 Placement

Keep evals **separate from runtime services** but do not build a separate deployed service yet. The runner stays in the backend repository's `evaluation/` area (outside Spring startup and request handling) and exercises the application over its API. Requirements and decisions stay in this specification repository.

```text
backend/evaluation/
  evaluate.mjs            # stable CLI entry point (kept backward compatible)
  lib/
    dataset.mjs           # load + validate + version dataset
    client.mjs            # API client (local auth now, OIDC later)
    metrics/
      retrieval.mjs       # Recall@K, MRR, hit rate
      generation.mjs      # faithfulness, hallucination, relevance
      end-to-end.mjs      # answer correctness
      operational.mjs     # latency percentiles, errors, cost
      safety.mjs          # injection, leakage, abstention
    judges/               # LLM-judge adapters + calibration helpers
    report.mjs            # JSON + Markdown report, comparison
  datasets/               # schema + non-sensitive samples only
  reports/                # generated; git-ignored
  test/                   # unit tests for metrics and loaders
```

### 9.2 Flow mapped to the 8 steps

| Step | EKA artifact |
|---|---|
| 1. Task & target | Eval charter in spec 011 (targets: retriever, generator, RAG workflow, whole app). |
| 2. Success criteria | Metric catalogue with **proposed** targets; approval required before any release gate. |
| 3. Dataset | Versioned JSONL (schema v2, backward compatible with v1) with `category` and `source` provenance. |
| 4. Method | Per-metric method: code / human / calibrated LLM judge. |
| 5. Run | `node evaluation/evaluate.mjs` with pinned model/config/dataset versions. |
| 6. Evaluate | Score + comparison against a stored baseline; improve prompt/model/system and re-run. |
| 7. Analyze | Per-category slices, worst-case list, failure-cluster notes in the report. |
| 8. Deploy & monitor | Operational metrics from existing logs/metrics; production failures enter the dataset through an approved path (see §10). |

### 9.3 Metric catalogue (proposed)

| Group | Metric | Method | Level |
|---|---|---|---|
| Retrieval | Recall@K, MRR, hit rate on **raw retrieved candidates** | Code | Component |
| Retrieval | Context relevance | Human / LLM judge | Component |
| Generation | Faithfulness / groundedness | LLM judge calibrated to human | Component |
| Generation | Hallucination, extra-content rate | LLM judge + human sample | Component |
| Generation | Citation validity and completeness | Code | Component |
| Combined | Answer correctness vs reference answer / gold evidence | Human + judge | Workflow |
| Combined | Evidence-classification (answer vs abstain) accuracy | Code | Workflow |
| Operational | Latency p50/p95/p99 (retrieval, generation, end-to-end), timeout/error rate, tokens/cost | Code | Application |
| Safety | Prompt-injection resistance, cross-collection leakage, sensitive-data exposure | Code + human | Application |

Targets already proposed in the source documents (**not approved**): ≥ 80% supported and relevant answers on a curated 50-question set; ≥ 95% valid citations on factual answers; retrieval p95 ≤ 1.5 s for up to 10,000 chunks on documented local hardware.

### 9.4 Dataset design (proposed schema v2)

Existing v1 fields remain valid. Added optional fields:

| Field | Purpose |
|---|---|
| `referenceAnswer` | Short expected answer for correctness scoring. |
| `category` | e.g., `factual`, `multi-hop`, `unanswerable`, `adversarial`, `latency-probe`. |
| `source` | `curated`, `synthetic`, `adversarial`, `production-failure`. |
| `expectedBehavior` | `answer` or `abstain`. |
| `tags`, `difficulty` | Slicing for analysis. |

Include deliberately: *gold evidence ranked low in the top-K* (the §5.3 scenario), unanswerable questions, injection attempts embedded in documents, and questions that must not cross collection boundaries. The dataset stays outside source control when it contains confidential content.

### 9.5 Eval methods and trust

See §6.1 for the definition of each method and how to choose one.

| Method | Use for | Caveat |
|---|---|---|
| Code checks | Recall, MRR, citation validity, latency, format | Only objective properties. |
| Human review | Groundedness, usefulness, correctness ground truth | Slow; needs a rubric and reviewer availability. |
| LLM judge | Scaling groundedness/hallucination checks | Must be **calibrated against human labels** (agreement measured on a sample) before it influences decisions. Content sent to an external judge needs explicit authorization (§10). |

### 9.6 Reporting

Each run writes a machine-readable report and a short Markdown summary containing: dataset hash and version, model and configuration versions, per-metric results with sample sizes, per-category slices, latency percentiles, failures to inspect, comparison against the stored baseline, and known limitations. Reports never contain question or answer text unless the dataset is explicitly non-confidential.

---

## 10. Guardrails specific to EKA

These come from approved project rules and apply to any eval work:

1. **Authorization first.** Evals must run as a real, appropriately scoped user; they must not bypass server-side authorization or read other collections.
2. **Confidential data stays out of the repository and logs.** Datasets with production questions or confidential text live in an access-controlled location (backend evaluation README).
3. **No external sharing without authorization.** Sending document passages or answers to an external judge model needs explicit approval; default to a local provider for confidential data.
4. **Untrusted content.** Treat retrieved and uploaded text as untrusted; adversarial cases test that instructions inside documents are not followed.
5. **No invented results.** Never record scores that were not produced by a run. Synthetic or fixture data is not "representative evaluation".
6. **Production feedback vs privacy.** DEC-008 defers conversation history and feedback, and spec 009 forbids logging questions. The step 8 → 3 loop therefore needs an explicitly approved, privacy-safe mechanism (open decision) — until then, failures are added manually by a reviewer.
7. **Thresholds are proposals** until the product owner approves them; evals report-only until then.

---

## 11. Glossary and FAQ

| Term | Meaning |
|---|---|
| **Eval** | The full test setup: target, criteria, dataset, method, schedule, tool. |
| **Benchmark** | A public test set used for model evals. |
| **Recall@K** | Number of relevant items retrieved in the top K ÷ total number of relevant items (see §5.6). |
| **MRR** | Mean reciprocal rank of the first relevant item. |
| **Faithfulness / groundedness** | Every claim in the answer is supported by the provided evidence. |
| **Hallucination** | A claim that the evidence does not support. |
| **LLM judge** | A model that scores another model's output against a rubric. |
| **Gold evidence** | The chunk(s) a human confirms answer the question. |
| **Golden dataset** | A curated, versioned set of questions with human-labelled correct evidence (and optionally reference answers); see §6.2. |
| **Regression case** | A past failure kept in the dataset to prevent recurrence. |

**Why not just use model benchmarks?** They tell you what a model *can* do in general, not whether *your* product, corpus, prompt, retrieval, and latency budget work together.

**Is an average score enough?** No. Slice by category and read the worst cases; an average hides a failing safety or unanswerable category.

**Can we improve and re-run immediately?** Yes (inner loop), but change one variable at a time and re-run on the same versioned dataset.

**What blocks real results today?** An authorized, representative, human-reviewed dataset (backlog B06). Building the pipeline does not remove that dependency.
