# Prompt: Query & Aggregation Expansion

## Context
Phase 2 requires a cohesive GraphQL builder and aggregation toolkit aligned with the essential pillars. `03_query_aggregation_plan.md` outlines functional requirements including `_additional` metadata, aggregation DSL, and result normalization. Current implementations in `lib/weaviate_ex/query.ex`, `lib/weaviate_ex/api/query_advanced.ex`, and associated tests provide partial functionality without the structured DSL, fetch helpers, or aggregation abstractions. This prompt directs the creation of the new query/aggregate stack while maintaining compatibility with existing clients.

## Required Reading
- `docs/20251019/01_essential_scope.md`
- `docs/20251019/03_query_aggregation_plan.md`
- `docs/20251019/10_actionable_implementation_plan.md`
- `lib/weaviate_ex/query.ex`, `lib/weaviate_ex/api/query_advanced.ex`
- `lib/weaviate_ex/filter.ex`, `test/weaviate_ex/filter_test.exs`
- `lib/weaviate_ex/api/aggregate.ex`, `test/weaviate_ex/api/aggregate_test.exs`
- `test/weaviate_ex/query_test.exs`

## Implementation Objectives
1. **Query Builder Struct Upgrade**
   - Extend `%WeaviateEx.Query{}` to include fields for `:sort`, `:autocut`, `:after`, `_additional` configuration, and support for FETCH-by-id helpers per plan.
   - Implement `with_additional/2`, `fetch_object_by_id/4`, and `fetch_objects_by_ids/4`, ensuring raw GraphQL fragments can be appended via `execute_raw/2`.
   - Add safeguard to maintain Blue environment: existing builder functions remain backwards compatible; new features default to current behaviours until flagged on review.
2. **Aggregation DSL**
   - Introduce `%WeaviateEx.Aggregate.Request{}` and `%WeaviateEx.Aggregate.Result{}` plus helper module (e.g., `WeaviateEx.Aggregate`) to build property metrics lists as described.
   - Normalize responses to a predictable struct, mapping topOccurrences and numeric metrics consistently.
3. **Result Normalization & Error Handling**
   - Create `%WeaviateEx.Query.Result{}` encapsulating objects + metadata; update execute functions to emit typed `WeaviateEx.Error` on GraphQL errors.
   - Integrate `WeaviateEx.Filter` so that both map and struct inputs are accepted by `Query.where/1`.
4. **Instrumentation Hooks**
   - Add `Query.to_graphql/1` for debugging; ensure logged output respects safe defaults (no secrets).

## TDD & Quality Gates
- Begin by extending `test/weaviate_ex/query_test.exs` and `test/weaviate_ex/api/aggregate_test.exs` with failing cases covering new DSL usage, `_additional` toggles, and error propagation.
- Leverage blue/green mindset: keep legacy GraphQL builder tests green while new cases describe future behaviour; only switch defaults once both sets pass.
- Enforce `mix test --color` and `mix format` before review; ensure no compiler warnings (pay attention to unused struct fields or pattern matches).
- Document review checklist: GraphQL string generation, error shapes, aggregation metrics parity, backward compatibility.

## Deliverables
- Updated query and aggregate modules with moduledocs describing new DSL entrypoints, plus inline examples for hybrid search, rollups, and fetch helpers.
- Comprehensive tests demonstrating TDD progression and covering success + failure paths (including negative GraphQL response cases).
- Release notes draft snippet for Phase 2 summarizing new query/aggregation capabilities, ready for inclusion in README/changelog.
- Confirmation that green deployment still serves legacy behaviour; review sign-off to plan cutover to blue after integration testing.
