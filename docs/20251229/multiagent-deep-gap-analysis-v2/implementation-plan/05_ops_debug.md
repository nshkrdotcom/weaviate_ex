# Ops and Debug Implementation Plan

## Scope
Close debug and ops parity gaps, especially around REST debug options and gRPC debug correctness.

## Gap sources
- `docs/20251229/multiagent-deep-gap-analysis-v2/agent-ops-admin.md`

## Tasks
1. Debug REST options
   - Add `node_name` and `consistency_level` to `WeaviateEx.Debug.get_object_rest/4` and include in query params.

2. Debug gRPC correctness
   - Ensure gRPC search filters are applied or route debug gRPC calls through GraphQL when filters are required.

## Acceptance criteria
- Tests for new debug options.
- README and guide updates (if debug functionality is documented).
- `CHANGELOG.md` 0.7.3 updated.
- Tests passing with no warnings/credo/dialyzer errors.
