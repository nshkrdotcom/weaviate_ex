# Data and Batch Implementation Plan

## Scope
Close data CRUD helper gaps, improve payload validation, and align batch semantics.

## Gap sources
- `docs/20251229/multiagent-deep-gap-analysis-v2/agent-data-batch.md`

## Tasks
1. Add fetch_objects_by_ids in data API
   - Implement `WeaviateEx.API.Data.fetch_objects_by_ids/3` (and/or `WeaviateEx.Objects.fetch_many/2`).

2. Payload validation improvements
   - Add basic validations for reserved property names and required keys before insert/update.

3. Batch semantics
   - Decide and document behavior when all batch inserts fail (raise vs return).
   - Align behavior with Python for all-fail scenarios.

4. Streaming batch backoff
   - Respect server backoff signals in `WeaviateEx.Batch.Stream` by delaying or adjusting batch size.

## Acceptance criteria
- New tests for data helpers and validation.
- Batch streaming tests for backoff handling.
- README and guides updated (`crud_operations.md`, `references.md`).
- `CHANGELOG.md` 0.7.3 updated.
- Tests passing with no warnings/credo/dialyzer errors.
