# AI Provider Selection

## Status

Proposed for implementation under the owner's explicit request (2026-10-22). This specification narrows DEC-002's provider selection behavior; it does not change the RAG API contract.

## Problem

The backend currently couples AI provider choice to the `local` and `deployed` Spring profiles. That makes it inconvenient to use OpenAI in local development, choose different providers for chat and embeddings, or switch one capability without changing the other. Both Spring AI provider starters are already dependencies, but the runtime configuration exposes Ollama in `local` and OpenAI in `deployed` only.

## Users

- Developers running the backend locally who need to select providers without changing source code.
- Operators who need explicit, logged provider/model selection.

## Functional requirements

- FR-1: Ollama and OpenAI are both supported as chat providers and as embedding providers in local/development environments.
- FR-2: Chat and embedding provider selections are independent. Supported configurations include Ollama/Ollama, OpenAI/OpenAI, Ollama/OpenAI, and OpenAI/Ollama (chat/embedding order).
- FR-3: Provider selection is supplied through backend configuration/environment variables. Changing it requires a backend restart; no provider switch API or UI is introduced.
- FR-4: If provider variables are omitted in the `local` profile, both default to Ollama, preserving existing local behavior.
- FR-5: OpenAI use requires `OPENAI_API_KEY`. A selected OpenAI provider with a missing/blank key must fail startup with a clear configuration error; the key must never be logged or exposed by an API.
- FR-6: Provider-specific model IDs, Ollama base URL, embedding dimensions, and vector-table selection must match the selected provider configuration and be validated at startup.
- FR-7: The active chat and embedding providers and model IDs are logged at startup without secrets.
- FR-8: An embedding provider/model/dimension change selects an isolated compatible vector index/table. Existing Ollama vectors must never be searched using OpenAI query vectors, or vice versa.
- FR-9: Changing the chat provider alone does not require re-indexing. Changing embedding provider/model requires re-indexing all desired documents into the selected embedding index before those documents can be retrieved in that configuration.
- FR-10: Local HTTP Basic and OIDC authentication remain independent of provider selection. Adding `oidc` to a local run must not force a particular AI provider.
- FR-11: Deployed defaults remain OpenAI for chat and embeddings, with OIDC authentication.
- FR-12: The service uses one selected provider per capability for each backend process. Automatic failover, per-request routing, and sending the same request to both vendors are out of scope.

## Non-functional requirements

- NFR-1: Provider configuration is externalized; credentials are not committed to source control or returned in responses.
- NFR-2: Provider startup failures and request failures retain the existing safe error handling and correlation behavior.
- NFR-3: Existing Ollama local behavior, deployed OpenAI behavior, authorization-scoped retrieval, and the public API schema remain compatible.

## Acceptance criteria

- AC-1: With no provider overrides under `local`, startup logs Ollama for chat and embeddings with configured model IDs and the Ollama vector table.
- AC-2: Configuration tests cover all four chat/embedding provider combinations and verify the selected Spring AI model adapters and dimensions/table.
- AC-3: A local OpenAI configuration starts only when a nonblank `OPENAI_API_KEY` is supplied; secrets do not appear in logs.
- AC-4: `local,oidc` accepts provider configuration independently of authentication, while the existing authentication behavior remains enforced.
- AC-5: An embedding configuration selects only its matching vector table; mismatched dimensions fail clearly before indexing/search can persist incompatible vectors.
- AC-6: Existing Ollama vectors are not returned under an OpenAI embedding configuration; re-indexing creates compatible searchable vectors in the OpenAI table.
- AC-7: Chat-provider selection changes do not alter embedding configuration or vector-table choice.
- AC-8: Deployed defaults remain OpenAI for both capabilities and require OIDC settings as currently specified.

## Error scenarios

- OpenAI selected without an API key: fail startup with a safe, actionable message.
- Unknown provider identifier, missing model, invalid dimensions, or incompatible table: fail startup with the offending configuration key identified, but no secret value.
- Selected provider unavailable: preserve the current safe `CHAT_PROVIDER_FAILED` or `EMBEDDING_PROVIDER_FAILED` behavior.
- Provider switched for embeddings without re-indexing: documents present only in the old index do not appear in retrieval; operators must re-index them.

## Security requirements

- Keep `OPENAI_API_KEY` server-side and redact it from logs and exception messages.
- Preserve authentication and collection authorization independently from provider selection.
- Do not add client-controlled provider selection to chat, upload, or retrieval endpoints.

## Out of scope

- Runtime hot switching without restart.
- Automatic provider fallback, load balancing, or concurrent fan-out.
- Per-user, per-request, or per-collection provider selection.
- Migration or automatic dual-writing of all existing vectors when embedding configuration changes.
- Changes to retrieval, prompt, citation, or answer API behavior.

## Implementation notes / assumptions

- Keep the two existing Spring AI starters. Use explicit Spring AI model selection and provider-specific configuration rather than creating custom provider SDK clients.
- Keep existing provider-specific vector tables and bind the active table and dimensions to the embedding selection.
- Update the approved DEC-002 wording and affected local/deployed setup docs in the implementation repository as part of delivery.
