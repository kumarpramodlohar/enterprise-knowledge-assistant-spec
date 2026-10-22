# AI Provider Selection Tasks

| ID | Task | Repository | Target areas | Verification | Status |
|---|---|---|---|---|---|
| P01 | Inspect Spring AI 2.0.1 auto-configuration and determine a safe independent chat/embedding selection mechanism | Backend | Spring AI auto-configuration and `spring.ai.model.chat` / `spring.ai.model.embedding` selectors | Confirmed selector conditions in Spring AI 2.0.1 source/docs | Done |
| P02 | Add externalized chat-provider and embedding-provider configuration, local/deployed defaults, model/key settings, and startup validation | Backend | `application.properties`, `application-deployed.properties`, `AiProviderConfigurationValidator` | Unit tests cover accepted providers, key requirement, invalid values | Done |
| P03 | Select chat and embedding adapters independently without ambiguous beans | Backend | Spring AI selector properties, starters already in `build.gradle` | Context test verifies intended chat and embedding adapter for all four combinations | Done |
| P04 | Bind embedding dimensions and vector table to the selected embedding config; reject incompatible configuration before data writes | Backend | application configuration, validator, existing vector tables | Tests reject mismatched configured dimensions/table | Done |
| P05 | Preserve local Basic, `local,oidc`, and deployed OIDC behavior with provider selection independent | Backend | auth profiles and security tests | Focused local/deployed profile tests pass | Done |
| P06 | Keep model/provider startup logs accurate and secret-free | Backend | `AiModelStartupLogger` | Existing logger reports selected providers/models and no credentials | Done |
| P07 | Update backend `.env.example`, README, and startup scripts for local OpenAI and mixed provider configurations | Backend | `.env.example`, `README.md`, `scripts/start-local.sh` | Bash syntax and diff checks pass | Done |
| P08 | Run backend unit/integration tests and Gradle build; update completion records from evidence | Backend + Specification | test suite and this task table | Focused tests pass; full suite has one unrelated upload-limit failure (see verification note) | Partial |

## Verification note

`./gradlew test --tests '*AiProviderConfigurationValidatorTest' --tests '*AiProviderSelectionAutoConfigurationTest' --tests '*DeployedProfileTest' --tests '*LocalOidcProfileTest'` passed. The isolated Spring AI context test verified each of the four provider combinations. `bash -n scripts/start-local.sh` and `git diff --check` passed. The full `./gradlew test` run compiled the backend and executed 101 tests, but one existing dirty-worktree test failed: `DocumentUploadIntegrationTest.distinguishesPdfPageAndExtractedContentLimitsFromFileByteLimit` at line 166. That upload-limit path is outside this provider change and was not modified here. No live Ollama/OpenAI requests were made.
