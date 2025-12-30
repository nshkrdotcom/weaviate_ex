# Query and Generative Implementation Plan

## Scope
Fix gRPC query correctness gaps, add missing search helpers, and align generative provider parameters.

## Gap sources
- `docs/20251229/multiagent-deep-gap-analysis-v2/agent-query-generative.md`

## Tasks
1. gRPC search parity
   - Add filters, target vectors, and group_by support to gRPC Search.
   - Implement gRPC near_image and near_media paths.
   - Add reference and vector return support in gRPC Search results.

2. gRPC feature gating
   - In `WeaviateEx.Query.execute/3`, detect unsupported options and fall back to GraphQL when needed.

3. Missing query helpers
   - Add `fetch_objects_by_ids` query helper with GraphQL fallback and gRPC path if possible.

4. Generative provider parameters
   - Expand `WeaviateEx.Generative.Config` to support missing fields (log_probs, top_log_probs, n, frequency_penalty variants).
   - Ensure GraphQL clause builder includes new fields.

5. gRPC generative execution (optional)
   - If feasible, implement gRPC generative path with provider-specific configs.

## Acceptance criteria
- Unit tests for gRPC search with filters/target vectors and fallback behavior.
- Generative config tests for new fields.
- README and guides updated (`queries.md`, `generative_search.md`).
- `CHANGELOG.md` 0.7.3 updated.
- Tests passing with no warnings/credo/dialyzer errors.
