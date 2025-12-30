# Prompt - Ops and Debug Parity

## Objective
Close debug parity gaps: REST debug options and gRPC debug correctness.

## Required reading (docs)
- `docs/20251229/multiagent-deep-gap-analysis-v2/agent-ops-admin.md`
- `docs/20251229/multiagent-deep-gap-analysis-v2/implementation-plan/05_ops_debug.md`
- `README.md`
- `CHANGELOG.md`

## Required reading (src/tests)
- `lib/weaviate_ex/debug.ex`
- `lib/weaviate_ex/debug/object_compare.ex`
- `lib/weaviate_ex/grpc/services/search.ex`
- `test/weaviate_ex/debug/*`

## Context
- Debug REST fetch in Python supports node_name and consistency_level parameters; Elixir does not.
- Debug gRPC fetch uses filters that are ignored by gRPC Search, leading to incorrect behavior.

## Implementation instructions (TDD required)
1. Debug REST parameters
   - Add `node_name` and `consistency_level` support to `WeaviateEx.Debug.get_object_rest/4`.
   - Add tests for query param encoding.

2. Debug gRPC correctness
   - Ensure filters are applied in gRPC Search or fall back to GraphQL if filters are used.
   - Add tests verifying correct object retrieval.

## Docs updates
- Update `README.md` and any relevant guides if debug behavior is documented.

## Changelog
- Add entries under `## [0.7.3] - 2025-12-29` in `CHANGELOG.md` describing debug changes.

## Quality gates
- TDD: add/adjust tests first, then implement.
- All tests passing.
- No warnings, credo issues, or dialyzer errors.
