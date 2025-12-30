# Agent Ops - Backup, Cluster, Debug, Aliases Gap Analysis

## Scope and sources
- Python: `weaviate-python-client/weaviate/debug/executor.py`, `weaviate-python-client/weaviate/backup/backup.py`, `weaviate-python-client/weaviate/cluster/*`, `weaviate-python-client/weaviate/aliases/*`
- Elixir: `lib/weaviate_ex/debug.ex`, `lib/weaviate_ex/debug/object_compare.ex`, `lib/weaviate_ex/api/backup.ex`, `lib/weaviate_ex/api/cluster.ex`, `lib/weaviate_ex/api/aliases.ex`

## Parity highlights
- Backup create/restore/list/cancel with compression options is implemented (`lib/weaviate_ex/api/backup.ex`, `lib/weaviate_ex/backup/compression.ex`).
- Cluster nodes, shards, and replication operations exist (`lib/weaviate_ex/api/cluster.ex`).
- Aliases API is present (`lib/weaviate_ex/api/aliases.ex`).

## Gap findings
1. Debug REST retrieval lacks node and consistency controls.
   - Impact: cannot target a specific node or control consistency on REST debug calls; limits parity for investigating replication issues.
   - Evidence (Python): `weaviate-python-client/weaviate/debug/executor.py` supports `node_name` and `consistency_level` parameters.
   - Evidence (Elixir): `lib/weaviate_ex/debug.ex` `get_object_rest/4` only supports `tenant` and `include` options.

2. Debug gRPC retrieval relies on filters that are not actually sent.
   - Impact: `Debug.get_object_grpc/4` builds a filter query but the gRPC Search service ignores filters, so results may be incorrect or empty.
   - Evidence (Elixir): `lib/weaviate_ex/debug.ex` builds `filters` and calls `GRPCSearch.search/4`; `lib/weaviate_ex/grpc/services/search.ex` does not apply filters when building `SearchRequest`.

## Suggested closure
- Extend `Debug.get_object_rest/4` to accept `node_name` and `consistency_level` and include them in query params to match Python capabilities.
- Implement filter support in `WeaviateEx.GRPC.Services.Search` or change debug gRPC retrieval to a GraphQL path when filters are needed.
