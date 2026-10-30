# 010 Documentation Alignment — Specification

**Status:** Implemented and verified on 2026-10-30
**Scope:** Specification repository only; no product or architecture decision is changed.

## Problem

The original v1 requirements, PRD, architecture, backlog, README, and foundation plan describe the pre-implementation target state. Delivered flows—Keycloak OIDC, document lifecycle APIs, baseline RAG, corrective RAG, optional external search, typed citations, and retrieval diagnostics—are documented only in later feature records. This creates conflicting sources of truth.

## Users

Project contributors, reviewers, operators, and future implementation agents who need an accurate description of the supported flow and its remaining release gaps.

## Requirements

- Align top-level documents to approved DEC-001 through DEC-010 and to the implemented API contract.
- Preserve the distinction between implemented behavior and release readiness: representative quality evaluation and live Keycloak verification remain incomplete.
- Describe external search as a bounded, dual-opt-in exception, not unrestricted public-web crawling.
- Do not mark uncommitted backend prompt changes or unverified live-provider behavior as completed.
- Keep API and security boundaries consistent: authorization precedes retrieval; external citations are typed and do not contain internal document identifiers.

## Acceptance criteria

- No top-level document lists feedback, hybrid retrieval, or reranking as current MVP behavior.
- Requirements, PRD, architecture, README, and backlog refer to the approved provider/authentication baseline and the CRAG exception consistently.
- Historical planning language is labelled as historical where it would otherwise be mistaken for a current implementation claim.
- T18/T19 and live-Keycloak validation remain explicitly open.

## Out of scope

Changing DEC-001 through DEC-010, changing application source code, approving DEC-009, or running live provider/Keycloak tests.
