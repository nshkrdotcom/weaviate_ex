# Prompt - Query and Generative Parity

## Objective
Close query/generative gaps: gRPC search parity, gRPC fallback rules, missing query helpers, and missing generative provider parameters.

## Required reading (docs)
- `docs/20251229/multiagent-deep-gap-analysis-v2/agent-query-generative.md`
- `docs/20251229/multiagent-deep-gap-analysis-v2/implementation-plan/03_query_generative.md`
- `README.md`
- `guides/queries.md`
- `guides/generative_search.md`
- `CHANGELOG.md`

## Required reading (src/tests)
- `lib/weaviate_ex/query.ex`
- `lib/weaviate_ex/grpc/services/search.ex`
- `lib/weaviate_ex/query/near_image.ex`
- `lib/weaviate_ex/query/near_media.ex`
- `lib/weaviate_ex/query/group_by.ex`
- `lib/weaviate_ex/query/target_vectors.ex`
- `lib/weaviate_ex/api/generative.ex`
- `lib/weaviate_ex/generative/config.ex`
- `lib/weaviate_ex/generative/parameters.ex`
- `test/weaviate_ex/query/*`
- `test/weaviate_ex/api/generative_test.exs`

## Context
- gRPC Search currently ignores filters, target_vectors, and group_by, and does not support near_image/near_media.
- `WeaviateEx.Query.execute/3` defaults to gRPC if available, which can silently drop advanced options.
- Generative configs miss fields (log_probs, top_log_probs, n, etc.) present in Python.
- No fetch_objects_by_ids helper exists.

## Implementation instructions (TDD required)
1. gRPC search feature parity
   - Add filters, target_vectors, group_by, near_image, and near_media to gRPC Search requests.
   - Add reference and vector return support where applicable.
   - Extend tests to cover these behaviors.

2. gRPC fallback rules
   - In `WeaviateEx.Query.execute/3`, detect unsupported gRPC options and fall back to GraphQL.
   - Add tests verifying fallback when advanced options are set.

3. Fetch by IDs helper
   - Add a `fetch_objects_by_ids` helper (GraphQL + optional gRPC path).
   - Add tests for correctness and ordering guarantees if applicable.

4. Generative provider params
   - Expand `WeaviateEx.Generative.Config` with missing provider fields and ensure GraphQL clauses include them.
   - Add tests for config serialization.

5. gRPC generative execution (optional)
   - If feasible, implement gRPC generative path and tests; otherwise document GraphQL-only behavior.

## Docs updates
- Update `README.md`, `guides/queries.md`, and `guides/generative_search.md` with new behaviors and fallbacks.

## Changelog
- Add entries under `## [0.7.3] - 2025-12-29` in `CHANGELOG.md` describing query/generative changes.

## Quality gates
- TDD: add/adjust tests first, then implement.
- All tests passing.
- No warnings, credo issues, or dialyzer errors.
