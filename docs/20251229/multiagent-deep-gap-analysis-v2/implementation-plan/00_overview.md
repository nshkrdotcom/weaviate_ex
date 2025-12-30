# Implementation Plan Overview

## Purpose
Translate the deep gap analysis into executable workstreams that close parity gaps between `weaviate-python-client` and `weaviate_ex`.

## Source references
- Synthesis: `docs/20251229/multiagent-deep-gap-analysis-v2/main-synthesis.md`
- Transport: `docs/20251229/multiagent-deep-gap-analysis-v2/agent-transport-connection.md`
- Schema: `docs/20251229/multiagent-deep-gap-analysis-v2/agent-schema-collections.md`
- Query: `docs/20251229/multiagent-deep-gap-analysis-v2/agent-query-generative.md`
- Data: `docs/20251229/multiagent-deep-gap-analysis-v2/agent-data-batch.md`
- Ops: `docs/20251229/multiagent-deep-gap-analysis-v2/agent-ops-admin.md`

## Workstreams and sequencing
1. Query/gRPC correctness (blocking)
   - Ensure gRPC search uses filters, target vectors, near_image/near_media, and references.
   - Add gRPC feature gating so advanced options fall back to GraphQL when needed.
   - This unblocks Debug fixes and reduces silent correctness risks.

2. Transport/auth integration
   - Wire proxy/connection configs into Finch and gRPC channel options.
   - Implement WCS gRPC host derivation parity.
   - Integrate OIDC token management into client request path and gRPC metadata.

3. Schema/collections parity
   - Add missing property options (indexRangeFilters).
   - Wire Object TTL and auto-tenant configs into create/update payloads.
   - Consider a collection handle for default tenant/consistency.

4. Data/batch parity
   - Add fetch_objects_by_ids helper for data retrieval.
   - Introduce minimal payload validation before inserts/updates.
   - Apply server backoff in streaming batch mode.

5. Ops/debug parity
   - Add node_name and consistency_level to debug REST fetch.
   - Fix debug gRPC fetch to use real filters or GraphQL fallback.

## Deliverables
- Implementation prompts per workstream in `docs/20251229/multiagent-deep-gap-analysis-v2/implementation-prompts/`.
- Code changes with TDD, updated README and guides, and `CHANGELOG.md` entry for 0.7.3.

## Global acceptance criteria (all workstreams)
- Tests added/updated with TDD and all tests passing.
- No warnings, credo issues, or dialyzer errors.
- README and relevant guides updated for new behavior.
- `CHANGELOG.md` 0.7.3 updated with changes.
