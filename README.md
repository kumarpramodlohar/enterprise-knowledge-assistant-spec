# Enterprise Knowledge Assistant — Specification & Agentic Development

**A single source of truth for product requirements, architecture decisions, feature specifications, and AI-assisted software development.**

## 1. Overview

The Enterprise Knowledge Assistant (EKA) is an AI-powered knowledge retrieval application that enables users to upload technical documents and ask natural-language questions. The system uses Retrieval-Augmented Generation (RAG) to produce evidence-grounded answers with source citations and explicitly identifies when the available evidence is insufficient.

This repository is the **central specification and development coordination repository** for EKA.

It defines what we build, why we build it, how the system should behave, and how AI coding assistants should approach implementation.

Application source code lives in separate backend and frontend repositories.

## 2. Project Repositories

| Repository                                | Responsibility                                                                                                            |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `enterprise-knowledge-assistant-spec`     | Requirements, product decisions, architecture, feature specifications, plans, tasks, and agent instructions               |
| `enterprise-knowledge-assistant-backend`  | REST APIs, authentication, document ingestion, embeddings, retrieval, RAG orchestration, persistence, and backend testing |
| `enterprise-knowledge-assistant-frontend` | React UI, document management, chat interface, citations, and frontend testing                                            |

Repository URLs will be added after the repositories are created.

## 3. Product Vision

Build a secure and reliable enterprise knowledge assistant that allows authorized users to find answers from technical documents without manually searching through large collections of files.

### Core capabilities

- Secure local authentication and Keycloak OIDC, with server-side role-based authorization.
- Collection-level access control.
- Document upload and lifecycle management.
- PDF, DOCX, TXT, and Markdown text extraction.
- Document chunking and embedding generation.
- Vector similarity search using PostgreSQL and pgvector.
- Metadata filtering and retrieval optimization.
- Evidence-grounded answers using an LLM.
- Typed internal/external citations linking answers to supporting evidence.
- Explicit insufficient-evidence responses.
- Retrieval-quality evaluation and safe retrieval diagnostics.
- Optional disabled-by-default corrective RAG, including the approved dual-opt-in external-search fallback.
- Logging, monitoring, error handling, and operational controls.

## 4. Technology Stack

### Backend

- Java 21
- Spring Boot 4.1.1
- Spring AI
- Spring Security
- PostgreSQL
- pgvector
- Gradle
- Docker and Docker Compose

### Frontend

- React
- TypeScript
- Vite
- Tailwind CSS

### AI providers

- Ollama for local development.
- OpenAI for configured hosted environments.
- Provider configuration externalized to support future alternatives.

### Engineering practices

- Spec-Driven Development (SDD).
- GitHub Copilot-assisted implementation.
- Automated unit and integration testing.
- CI/CD.
- Retrieval and answer-quality evaluation.
- Security-first design.

The technology choices above represent the intended architecture. Approved decisions and feature specifications take precedence when a choice is still under review.

## 5. Repository Structure

```text
enterprise-knowledge-assistant-spec/
├── README.md
├── AGENTS.md
├── backlog.md
│
├── .github/
│   ├── copilot-instructions.md
│   ├── instructions/
│   └── prompts/
│       ├── clarify-requirements.prompt.md
│       ├── create-spec.prompt.md
│       ├── create-plan.prompt.md
│       ├── create-tasks.prompt.md
│       └── review-implementation.prompt.md
│
├── docs/
│   ├── product/
│   ├── decisions/
│   ├── architecture/
│   ├── engineering/
│   └── operations/
│
├── specs/
│   ├── 001-project-foundation/
│   ├── 002-authentication-authorization/
│   ├── 003-document-ingestion/
│   ├── 004-rag-retrieval/
│   ├── 005-chat-and-citations/
│   └── 006-evaluation-and-observability/
│
├── agents/
│   ├── product-owner.md
│   ├── solution-architect.md
│   ├── backend-engineer.md
│   ├── frontend-engineer.md
│   ├── qa-engineer.md
│   └── security-reviewer.md
│
└── templates/
    ├── feature-spec-template.md
    ├── architecture-decision-template.md
    ├── implementation-plan-template.md
    └── task-template.md
```

This was the original target structure. The current repository uses `docs/` for top-level product/architecture records and numbered `specs/` directories for feature specifications, plans, and tasks. See `rg --files` or the repository root for the current layout.

## 6. Purpose of Key Directories

| Path                    | Purpose                                                                             |
| ----------------------- | ----------------------------------------------------------------------------------- |
| `docs/product/`         | Product vision, requirements, personas, and acceptance criteria                     |
| `docs/decisions/`       | Approved product, architecture, and security decisions                              |
| `docs/architecture/`    | System architecture, component boundaries, API contracts, data models, and diagrams |
| `docs/engineering/`     | Coding standards, testing, security, and evaluation practices                       |
| `docs/operations/`      | Local development and deployment guidance                                           |
| `specs/`                | Feature-level specifications, implementation plans, and task breakdowns             |
| `agents/`               | Role-specific guidance for AI-assisted workflows                                    |
| `.github/prompts/`      | Reusable GitHub Copilot prompts                                                     |
| `.github/instructions/` | Path-specific Copilot instructions                                                  |
| `templates/`            | Standardized document templates                                                     |
| `backlog.md`            | Unresolved questions, planned work, and implementation progress                     |

## 7. Spec-Driven Development Workflow

Each feature should follow a consistent workflow before application code is implemented.

### Step 1: Clarify requirements

Identify the business problem, user needs, constraints, assumptions, dependencies, and acceptance criteria.

Unresolved questions must be surfaced rather than silently answered by the AI assistant.

### Step 2: Record decisions

Document approved product and architecture decisions, including their rationale and relevant acceptance criteria.

Use explicit decision statuses:

- `Proposed` — recommended but not approved.
- `Approved` — reviewed and accepted.
- `Needs clarification` — more information is required.
- `Superseded` — replaced by a later decision.

### Step 3: Create the feature specification

Create a numbered feature directory under `specs/`.

Each feature should define expected behavior, user scenarios, functional requirements, edge cases, security considerations, and acceptance criteria.

### Step 4: Create the implementation plan

Document the proposed design, components affected, APIs, data changes, dependencies, security implications, and testing strategy.

### Step 5: Generate implementation tasks

Break the plan into small, testable tasks with explicit dependencies and completion criteria.

Identify which tasks belong to the backend and which belong to the frontend.

### Step 6: Implement in application repositories

Use GitHub Copilot to implement approved tasks in the appropriate application repository.

Follow the approved specification and architecture decisions. Avoid unrelated refactoring and scope expansion.

### Step 7: Verify and review

Run automated tests and review the implementation against acceptance criteria, security requirements, and architecture decisions.

### Step 8: Update project status

Update task status, record important implementation deviations, and document newly approved decisions.

A feature is complete only when its agreed acceptance criteria are satisfied.

## 8. AI Agent Responsibilities

AI-assisted workflows may use the following roles:

| Role               | Responsibility                                                           |
| ------------------ | ------------------------------------------------------------------------ |
| Product Owner      | Clarify business needs and approve product behavior                      |
| Solution Architect | Define system boundaries, interfaces, and architecture decisions         |
| Backend Engineer   | Implement APIs, persistence, ingestion, retrieval, and RAG logic         |
| Frontend Engineer  | Implement UI, API integration, and user interactions                     |
| QA Engineer        | Design tests and verify acceptance criteria                              |
| Security Reviewer  | Review authentication, authorization, data isolation, and security risks |

These are logical responsibilities, not necessarily six independently running agents. They may be handled by GitHub Copilot through prompts, instructions, or supported agent workflows.

**Human approval is required** for important product decisions, security-sensitive design choices, external data-sharing decisions, and material changes to the approved architecture.

## 9. Architecture Principles

The project follows these principles:

1. **Specification before implementation:** Resolve material requirements and design questions before coding.
2. **Single source of truth:** Maintain canonical requirements and decisions in this repository.
3. **Provider independence:** Isolate LLM and embedding provider configuration from business logic where practical.
4. **Security by design:** Enforce authorization on the server before retrieving protected content or sending context to an LLM.
5. **Evidence-grounded answers:** Responses must be supported by retrieved evidence, with citations where applicable.
6. **Honest uncertainty:** Do not fabricate evidence when retrieval is insufficient.
7. **Measurable quality:** Evaluate retrieval, answer relevance, citation correctness, latency, and cost.
8. **Incremental delivery:** Deliver a working vertical slice before adding advanced capabilities.
9. **Testable changes:** Every feature must have verifiable acceptance criteria.
10. **Controlled scope:** New requirements and architecture changes must be reviewed and documented.

## 10. Initial Quality Goals

The MVP will establish repeatable evaluation and testing before being considered ready for broader use.

Initial goals include:

- Evaluate retrieval using a human-labelled question-and-relevant-chunk dataset.
- Measure Recall@5 and Mean Reciprocal Rank (MRR).
- Evaluate answer relevance and factual support.
- Validate source citations against the retrieved evidence.
- Test insufficient-evidence behavior.
- Verify that unauthorized users cannot access protected documents or chunks.
- Measure retrieval latency separately from end-to-end LLM response latency.
- Track token usage and AI provider costs.

Initial proposed evaluation targets include at least 80% supported and relevant answers on a curated 50-question evaluation set, and valid citations for at least 95% of factual answers. These targets must be validated against the evaluation methodology and treated as acceptance criteria only after formal approval.

## 11. GitHub Copilot Instructions

Before generating specifications, plans, tasks, or application code, GitHub Copilot should:

1. Read the applicable requirements and approved decisions.
2. Check the current backlog and existing feature specifications.
3. Identify missing information and conflicts.
4. Recommend practical defaults when decisions are missing.
5. Clearly distinguish proposed decisions from approved decisions.
6. Ask for human input on material unresolved questions.
7. Preserve existing conventions and avoid unrelated changes.
8. Generate testable acceptance criteria and implementation tasks.
9. Verify that implementation matches the relevant specification.
10. Update documentation and task status when changes are approved and completed.

Do not treat a generated recommendation as an approved product decision without human review.

## 12. Definition of Done

A feature is considered complete when:

- [ ] Its requirements and acceptance criteria are documented.
- [ ] Required product and architecture decisions are approved.
- [ ] Implementation matches the approved specification.
- [ ] Unit and integration tests pass.
- [ ] Authorization and relevant security tests pass.
- [ ] Error handling and important edge cases are covered.
- [ ] Relevant documentation is updated.
- [ ] No unresolved critical defects remain.
- [ ] Evaluation results are recorded where applicable.
- [ ] Backlog and implementation task statuses are accurate.

Not every item applies to every task; applicable criteria must be identified during planning.

## 13. Getting Started

To begin contributing to EKA:

1. Review this README and `AGENTS.md`.
2. Read the product requirements and approved decisions in `docs/`.
3. Review `backlog.md` for unresolved questions and pending work.
4. Confirm that the intended feature scope and acceptance criteria are clear.
5. Create or update the relevant feature specification under `specs/`.
6. Generate an implementation plan and task breakdown.
7. Implement tasks in the backend or frontend repository.
8. Run the required tests and review the changes.
9. Update the documentation and backlog.

## 14. Current Project Status

This repository is the starting point for specification-driven development.

Update this section as the project progresses:

- [ ] Repository structure established.
- [ ] Requirements reviewed and approved.
- [ ] Initial product and architecture decisions recorded.
- [ ]
