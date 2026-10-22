# 009 Retrieval Diagnostics — Specification

**Status:** Approved for implementation by the user's request
**Related:** [001-project-foundation](../001-project-foundation/spec.md) (FR-06–FR-08, DEC-007), [003-ask-page](../003-ask-page/spec.md)

## Problem
The chat API returns insufficient evidence without exposing which authorized vector candidates were retrieved or their similarity scores. Operators cannot distinguish poor ranking from candidates excluded by the configured evidence threshold.

## Users
Backend developers and operators diagnosing retrieval quality in local and development environments.

## Functional requirements
- FR-1: For each chat retrieval, the backend shall log up to a configurable number of nearest eligible candidates before the similarity threshold is applied.
- FR-2: Each diagnostic entry shall include correlation ID, rank, document ID, chunk ID, page number when available, similarity score, and whether it meets the configured threshold.
- FR-3: Diagnostics shall not log the question, extracted text, credentials, or unauthorized candidates.
- FR-4: Diagnostic logging shall not change the existing top-K, threshold, evidence, citation, authorization, or response behavior.
- FR-5: Diagnostic candidate count shall be configurable and validated as positive.

## Acceptance criteria
- AC-1: A query with candidates below threshold logs their scores and `meetsThreshold=false`, then preserves the existing insufficient-evidence response if no eligible top-K candidate passes.
- AC-2: A query with a candidate above threshold logs it as passing and preserves normal answer/citation behavior.
- AC-3: Logs contain no question or passage content and include no candidates outside the caller's authorized collections or requested filters.
- AC-4: Setting the diagnostic candidate count to 10 logs at most 10 ranked candidates while the answer context remains governed by the existing top-K and threshold.

## Out of scope
Changing default retrieval threshold/top-K, query rewriting, reranking, CRAG, public API changes, and logging passage contents.
