# Repository Map and Workspace Instructions

## Project Repositories

This project is maintained across three separate Git repositories.

| Repository    | Relative Path                                | Responsibility                                                                  |
| ------------- | -------------------------------------------- | ------------------------------------------------------------------------------- |
| Specification | `./enterprise-knowledge-assistant-spec/`     | Requirements, architecture, decisions, feature specifications, plans, and tasks |
| Backend       | `./enterprise-knowledge-assistant-backend/`  | Java 21, Spring Boot, Spring AI, REST APIs, RAG pipeline, and persistence       |
| Frontend      | `./enterprise-knowledge-assistant-frontend/` | React, TypeScript, Vite, UI components, and frontend API integration            |

## Instructions for Copilot

1. Treat the specification repository as the canonical source of truth for approved requirements and architecture decisions.
2. When working on backend implementation, inspect the backend repository and the relevant specifications before making changes.
3. When working on frontend implementation, inspect the frontend repository and the relevant specifications before making changes.
4. For changes spanning backend and frontend, review the relevant API contracts and feature specifications first.
5. Do not assume these relative paths exist in the current workspace. Verify repository availability before accessing them.
6. If a required repository is not available, ask the user to open the appropriate repository or workspace. Do not invent file contents or implementation status.
7. Keep changes within the requested repository unless cross-repository changes are explicitly required.
8. Do not modify approved architecture or product decisions without explicit authorization.

## Mandatory Spec-Driven Development Workflow

For every new feature or significant change, follow this workflow:

1. **Understand the request**
   - Read the relevant product requirements, architecture decisions, security decisions, and existing feature specifications.
   - Identify missing information, assumptions, dependencies, and scope.
   - Ask questions when a missing decision could materially affect the implementation.
2. **Create or update the specification**
   - Create `specs/NNN-feature-name/spec.md`.
   - Describe the problem, users, functional requirements, non-functional requirements, acceptance criteria, error scenarios, security requirements, and out-of-scope items.
   - Use measurable, testable acceptance criteria.
   - Do not silently convert proposed decisions into approved decisions.
3. **Create the implementation plan**
   - Create `specs/NNN-feature-name/plan.md`.
   - Describe the architecture, components, API contracts, data model, dependencies, security considerations, and testing strategy.
   - Follow existing approved architecture decisions.
4. **Create implementation tasks**
   - Create `specs/NNN-feature-name/tasks.md`.
   - Break the plan into small, ordered, verifiable tasks.
   - Identify the target repository and relevant files for each task.
   - Include automated tests and documentation updates.
5. **Implement**
   - Implement against the approved specification, plan, and tasks.
   - Do not implement unrelated features or silently expand scope.
   - Do not assume files, APIs, or configuration exist without checking.
   - For cross-repository changes, check the API contracts and coordinate the backend and frontend changes.
6. **Verify**
   - Run the relevant tests, builds, static analysis, and security checks available in the repository.
   - Map acceptance criteria to implementation and test evidence.
   - Report failures, skipped checks, limitations, and unresolved issues honestly.
7. **Update project records**
   - Update task completion status only when supported by actual implementation and verification.
   - Update specifications, plans, architecture decisions, API contracts, and the backlog when they have genuinely changed.

## Required Rules

- The specification is the source of truth for feature behavior.
- Approved architecture and security decisions take precedence over implementation convenience.
- If the specification conflicts with existing approved decisions, stop and explain the conflict.
- Do not invent requirements or claim that tests passed when they were not run.
- For a substantial feature, do not skip specification, planning, or task breakdown unless the user explicitly authorizes a smaller workflow.
- Keep implementation changes in the appropriate backend or frontend repository.
- Treat security, authorization, data isolation, and privacy as mandatory requirements, not optional enhancements.

## Expected Deliverables

For a new substantial feature, produce or update:

1. `spec.md`
2. `plan.md`
3. `tasks.md`
4. Implementation and automated tests, when authorized
5. A verification summary and documentation updates
