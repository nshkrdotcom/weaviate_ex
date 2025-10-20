# Prompt: Operational Reliability & DX Polish

## Context
Phase 3 focuses on elevating reliability, telemetry, and developer experience per `04_operations_dx_plan.md` while supporting the overarching implementation program. Existing protocol and error modules (`lib/weaviate_ex/protocol/**/*`, `lib/weaviate_ex/error.ex`, `lib/weaviate_ex/health.ex`, `lib/weaviate_ex/client.ex`) require enhancements for retries, typed errors, telemetry, and raw request escape hatches. We must introduce changes without destabilising current integrations; observe blue/green deployment principles and ensure the experience remains warning-free.

## Required Reading
- `docs/20251019/01_essential_scope.md`
- `docs/20251019/04_operations_dx_plan.md`
- `docs/20251019/10_actionable_implementation_plan.md`
- `lib/weaviate_ex/client.ex`, `lib/weaviate_ex/client/config.ex`
- `lib/weaviate_ex/protocol.ex`, `lib/weaviate_ex/protocol/http/client.ex`
- `lib/weaviate_ex/error.ex`, `lib/weaviate_ex/health.ex`, `lib/weaviate_ex/raw.ex` (create if missing)
- `test/weaviate_ex/protocol/*`, `test/weaviate_ex/error_test.exs`, `test/weaviate_ex/health_test.exs`
- `test/support/finch_mock.ex` (if present) and any integration harness in `test/weaviate_ex/protocol/`

## Implementation Objectives
1. **Client Configuration & Protocol Enhancements**
   - Expand `WeaviateEx.Client.Config` to validate base URL, timeouts, pool size, retry policy, telemetry prefix, default headers, and per-request overrides. Provide descriptive errors for invalid inputs.
   - Introduce `WeaviateEx.Protocol.HTTP.Request` struct capturing method/path/body/options. Apply retry/backoff middleware (idempotent operations default; opt-in per request for others) using exponential backoff with jitter.
   - Emit telemetry events (`[:weaviate_ex, :request, stage]`) wrapping Finch requests with metadata for attempts, durations, status.
2. **Error Taxonomy & Health Checks**
   - Extend `WeaviateEx.Error` to include typed reasons (`:connection_error`, `:timeout`, `:validation_error`, `:conflict`, `:graphql_error`, etc.) and ensure all API modules emit these types.
   - Implement `WeaviateEx.Health.ready?/1` and `live?/1` wrappers that respect timeouts and fallback endpoints as defined in the operations plan.
3. **Raw Request Escape Hatch & Diagnostics**
   - Add `WeaviateEx.Raw.request/5` delegating to the protocol while honoring config validation, telemetry, and error taxonomy.
   - Provide optional `mix weaviate_ex.doctor` task (or documented mix task) to run readiness checks, version fetch, and print summary diagnostics.
4. **Observability & Logging**
   - Create `WeaviateEx.Logger` helper (or documented integration) to route telemetry events into standard Logger; ensure instrumentation examples are ready for docs.

## TDD & Quality Gates
- Start by authoring failing tests: extend `test/weaviate_ex/error_test.exs`, `test/weaviate_ex/health_test.exs`, `test/weaviate_ex/protocol/http/client_test.exs` (or create) covering retry logic, telemetry emission, and new error tagging.
- Practice blue/green: keep existing protocol behaviour as default; wrap new retry/backoff behind explicitly enabled config until soak tests prove stability.
- Run `mix format`, `mix test --color`, and any available integration smoke (docker-compose) with zero warnings/errors. Capture telemetry assertions using `:telemetry_test.attach_many`.
- Review checklist must confirm: retry idempotency rules, error struct completeness, telemetry metadata, raw escape hatch documentation, and backwards compatibility.

## Deliverables
- Updated protocol, client config, error, health, and raw modules with moduledocs describing new capabilities and usage.
- New or expanded tests demonstrating retries, telemetry, typed errors, health fallbacks, and raw request behaviour—all green.
- Draft updates for `QUICK_START_GUIDE.md` and telemetry/troubleshooting docs prepared for review.
- Confirmation from soak/blue environment that the new instrumentation introduces no warnings and all tests pass before green deployment.
