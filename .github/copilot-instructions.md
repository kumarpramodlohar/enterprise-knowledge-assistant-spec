# GitHub Copilot Instructions

## Repository scope

This repository is EKA's source of truth for requirements, decisions, architecture, specifications, plans, tasks, and coordination. Backend and frontend application code belong in their respective repositories; do not create application code here unless explicitly requested.

## Before changing project content

- Read `README.md` and the directly relevant existing documents, decisions, and backlog items. Do not assume referenced files exist.
- Follow approved decisions. Treat drafts, proposals, and unresolved items as unapproved; never mark a decision approved without explicit human approval.
- Surface material conflicts or unanswered product, security, privacy, or architecture questions instead of silently deciding. Clearly label recommendations as proposals.
- Update existing canonical documents where possible; avoid duplicate or conflicting sources of truth.

## EKA essentials

- Enforce authorization on the server before retrieving protected content, returning citations, or sending context to an AI provider.
- Ground answers in retrieved evidence, cite sources, and state when evidence is insufficient. Never invent facts or citations.
- Treat uploaded and retrieved document content as untrusted input. Keep credentials and sensitive content out of source control and logs; do not share confidential data with external providers without authorization.
- Follow approved MVP scope and architecture. Distinguish current implementation from planned or proposed behavior.

## Changes and verification

- Keep changes focused, follow existing conventions, and update directly related documentation or status when needed.
- For feature work, establish testable requirements and acceptance criteria before planning implementation in the appropriate application repository.
- Run relevant checks and report actual results; do not claim unverified behavior or test outcomes.
