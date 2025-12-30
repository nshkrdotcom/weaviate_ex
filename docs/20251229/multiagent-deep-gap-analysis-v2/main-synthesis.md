# Main Synthesis - Deep Gap Analysis Summary

## Coverage
This synthesis aggregates the multi-agent reviews:
- Transport/connection: `docs/20251229/multiagent-deep-gap-analysis-v2/agent-transport-connection.md`
- Schema/collections: `docs/20251229/multiagent-deep-gap-analysis-v2/agent-schema-collections.md`
- Query/generative: `docs/20251229/multiagent-deep-gap-analysis-v2/agent-query-generative.md`
- Data/batch: `docs/20251229/multiagent-deep-gap-analysis-v2/agent-data-batch.md`
- Auth/RBAC: `docs/20251229/multiagent-deep-gap-analysis-v2/agent-auth-rbac.md`
- Ops/admin: `docs/20251229/multiagent-deep-gap-analysis-v2/agent-ops-admin.md`

## Executive summary
WeaviateEx achieves strong parity in core CRUD, batch, cluster, backup, and schema flows, but has several high-impact gaps where the Python client either provides additional correctness safeguards or feature-complete gRPC coverage. The most significant risks are silent behavior differences when gRPC is selected by default and advanced query options are dropped.

## Top gaps by impact
1. gRPC search feature gaps cause silent correctness issues.
   - gRPC search omits filters, target vectors, group_by, and media search, yet `WeaviateEx.Query.execute/3` prefers gRPC when available.
   - Users can receive unfiltered or incomplete results without explicit errors.
   - See `agent-query-generative.md` and `lib/weaviate_ex/grpc/services/search.ex`.

2. Connection and auth integration lack production readiness.
   - Proxy, pool, and trust_env configuration exists but is not wired into the client pipeline.
   - OIDC token management is available but not integrated into the client lifecycle or gRPC metadata.
   - See `agent-transport-connection.md` and `agent-auth-rbac.md`.

3. Schema builder parity and validation gaps reduce developer safety.
   - Property builder misses `indexRangeFilters`.
   - Object TTL and auto-tenant configs exist but require manual serialization.
   - No typed collection handle or config validation similar to Python.
   - See `agent-schema-collections.md`.

4. Generative and query helper parity gaps.
   - Missing provider parameters (log_probs, n, top_log_probs) for some generative providers.
   - No gRPC generative execution path.
   - Missing `fetch_objects_by_ids` helper.
   - See `agent-query-generative.md` and `agent-data-batch.md`.

5. Debug/ops parity gaps.
   - Debug REST call lacks node_name/consistency options.
   - Debug gRPC path uses filters that are currently ignored by gRPC search.
   - See `agent-ops-admin.md`.

## Recommended closure plan
Phase 1 - Correctness and gRPC parity (highest risk)
- Add gRPC feature gating: fall back to GraphQL when filters, target_vectors, group_by, near_media, or near_image are present.
- Extend gRPC search to support filters, target vectors, near_image/near_media, and references.
- Fix debug gRPC retrieval by applying filters or using GraphQL for ID fetch.

Phase 2 - Connection and auth integration
- Implement WCS gRPC host derivation to match Python.
- Wire proxy/connection config into Finch pools and gRPC options.
- Integrate OIDC token manager into client, including auto-refresh and gRPC metadata.
- Forward additional headers to gRPC by default.

Phase 3 - Developer experience parity
- Add typed collection handle with default tenant/consistency.
- Wire `ObjectTTL`, `AutoTenant`, and `MultiTenancyConfig` into schema create/update.
- Add `indexRangeFilters` in property builder.
- Implement `fetch_objects_by_ids` and expose missing generative parameters.

## Notes
- Many core operational areas (backup, cluster, aliases) appear at parity; remaining deltas are mostly DX and edge-case support.
- The most urgent gap is the gRPC search behavior because it can silently return incorrect results when advanced options are set.
