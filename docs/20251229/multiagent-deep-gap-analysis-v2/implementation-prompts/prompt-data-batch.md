# Prompt - Data and Batch Parity

## Objective
Close data CRUD and batch parity gaps: fetch-by-IDs, payload validation, batch semantics, and streaming backoff handling.

## Required reading (docs)
- `docs/20251229/multiagent-deep-gap-analysis-v2/agent-data-batch.md`
- `docs/20251229/multiagent-deep-gap-analysis-v2/implementation-plan/04_data_batch.md`
- `README.md`
- `guides/crud_operations.md`
- `guides/references.md`
- `CHANGELOG.md`

## Required reading (src/tests)
- `lib/weaviate_ex/api/data.ex`
- `lib/weaviate_ex/objects.ex`
- `lib/weaviate_ex/objects/payload.ex`
- `lib/weaviate_ex/api/references.ex`
- `lib/weaviate_ex/batch.ex`
- `lib/weaviate_ex/batch/stream.ex`
- `test/weaviate_ex/api/*`
- `test/weaviate_ex/batch/*`

## Context
- Python exposes a dedicated fetch_objects_by_ids helper; Elixir does not.
- Payload validation is minimal in Elixir; Python validates inputs and reserved names.
- Batch streaming backoff is parsed but not acted on; all-fail semantics differ.

## Implementation instructions (TDD required)
1. Fetch-by-IDs helper
   - Add a `fetch_objects_by_ids` API (GraphQL and/or gRPC).
   - Add tests for return shape and ordering.

2. Payload validation
   - Implement minimal client-side validation (reserved property names, required keys).
   - Add tests covering invalid inputs.

3. Batch semantics
   - Decide on all-fail behavior (raise vs return), document, and test it.

4. Streaming backoff handling
   - Implement backoff behavior (delay or resize buffer) when server sends backoff messages.
   - Add tests to validate backoff usage.

## Docs updates
- Update `README.md`, `guides/crud_operations.md`, and `guides/references.md` as needed.

## Changelog
- Add entries under `## [0.7.3] - 2025-12-29` in `CHANGELOG.md` describing data/batch changes.

## Quality gates
- TDD: add/adjust tests first, then implement.
- All tests passing.
- No warnings, credo issues, or dialyzer errors.
