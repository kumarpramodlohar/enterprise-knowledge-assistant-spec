# AI Provider Selection Plan

## Scope

Implement FR-1 through FR-12 from [spec.md](./spec.md) in the backend, with DEC-002 and setup documentation aligned in the spec and backend repositories. No frontend or public API changes.

## Design

- Separate authentication profiles (`local`, `oidc`) from AI provider/model configuration. Keep the existing `deployed` entry point compatible by defaulting its AI settings to OpenAI and retaining OIDC.
- Expose one provider setting for chat and one for embeddings, each accepting `ollama` or `openai`. Defaults: local Ollama/Ollama; deployed OpenAI/OpenAI.
- Configure provider-specific model names, OpenAI secret, Ollama base URL, and embedding dimension through externalized configuration. Keep profile-specific defaults for model IDs and dimensions.
- Ensure Spring AI creates the adapter selected for each capability. Do not create an ambiguous unqualified `ChatModel` or `EmbeddingModel` injection when both provider implementations are on the classpath. If Spring AI auto-configuration cannot support independent selectors in this version, add narrowly scoped conditional configuration keyed by the provider properties and inject the selected interface explicitly.
- Derive the active embedding index/table from the embedding provider/model-dimension configuration and validate supported dimensions against the migrated table before persistence. Preserve table isolation and current model metadata checks.
- Retain one selected adapter per capability per process. No per-request routing/failover.
- Keep startup logs provider/model/table/dimension-aware and secret-free.

## Data and re-indexing

No schema migration is expected because the existing provider-specific tables exist. Switching embedding provider/model changes the active index. Previously indexed data stays isolated in its old table and must be re-indexed into the target table using stored extracted text/chunks. Confirm existing re-index operations work for this path; do not silently expose mixed dimensions.

## Security

- Do not put OpenAI credentials in frontend configuration.
- Validate OpenAI key presence when an OpenAI adapter is selected, without logging its value.
- Provider settings do not alter local Basic/OIDC auth selection or authorization-scoped retrieval.

## Verification strategy

- Configuration binding/validation tests for provider identifiers, defaults, key requirement, model IDs, dimensions, and table selection.
- Spring context tests for all four provider combinations; ensure each injected Spring AI interface is the requested provider.
- Regression tests for local Basic, `local,oidc`, deployed OIDC, selected model startup logging, and vector-table isolation.
- Existing backend unit/integration suite and Gradle build.
- Manual provider smoke test is optional and requires an available Ollama service and/or OpenAI key; do not claim remote-provider connectivity from context tests.

## Risks

- Spring AI 2.0.1 provider autoconfiguration may constrain multiple model implementations or expect the selector property to enable a particular bean. Inspect actual resolved dependency behavior before implementation; prefer framework-native selection.
- Embedding model dimension can be configured on OpenAI models. Unsupported combinations must fail early rather than write incompatible vectors.
- Existing indexed documents may need explicit re-index actions after changing embeddings; no automatic destructive migration is allowed.
