# Gaps and Differences

This document lists the major capability gaps between the Elixir `weaviate_ex` client and the reference Python client. Each item cites the Python implementation for comparison and, where helpful, a note on the Elixir side.

## Client Surfaces & Namespaces

- **Alias / Backup / Cluster / Debug / Groups / Roles / Users**: Provided by Python as first-class namespaces (`weaviate-python-client/weaviate/client.py:77`, `weaviate-python-client/weaviate/client.py:149`). No equivalents exist in Elixir beyond low-level REST access.
- **Connection helpers**: Python wraps WCS, local, embedded, and custom connections with validated parameters (`weaviate-python-client/weaviate/connect/helpers.py:61`, `weaviate-python-client/weaviate/connect/helpers.py:200`, `weaviate-python-client/weaviate/connect/helpers.py:282`). Elixir lacks specialized entry points—users must hand-build configs.
- **Async context support**: Python supplies sync/async clients and context manager semantics (`weaviate-python-client/weaviate/client.py:32`, `weaviate-python-client/weaviate/client.py:86`). Elixir exposes synchronous functions only.

## Transport & Configuration

- **gRPC execution paths**: Python implements full gRPC stacks for queries, aggregates, tenants, and batches (`weaviate-python-client/weaviate/collections/grpc/query.py:1`). Elixir currently has only HTTP (`lib/weaviate_ex/protocol/http/client.ex:1`), making high-throughput workloads slower.
- **Retry, pooling, proxy, and TLS configuration**: Python offers `AdditionalConfig` knobs (`weaviate-python-client/weaviate/config.py`) plus environment detection, whereas Elixir’s config struct handles base URL, API key, and timeout only (`lib/weaviate_ex/client/config.ex:1`).
- **Custom headers & auth per request**: Python permits additional headers and credential refresh mechanisms via `Auth` class (`weaviate-python-client/weaviate/auth.py:11`). Elixir supports just a static API key (`lib/weaviate_ex/client/config.ex:14`).

## Authentication

- **OAuth2 / OIDC flows**: Python covers API key, bearer token, client credentials, and password grants (`weaviate-python-client/weaviate/auth.py:85`). Elixir lacks any token exchange or refresh handling.
- **Token lifecycle management**: Python can nudge for upgrades and manage expiry (`weaviate-python-client/weaviate/util.py:606`); Elixir has no equivalent facilities.

## Schema & Vector Configuration

- **Reference property helpers**: Python’s schema executor manages cross-collection references (`weaviate-python-client/weaviate/collections/config/executor.py:452`). Elixir has no `Collections.add_reference/3` or related APIs.
- **Named/multi-vector management**: Python supports adding named vectors post-creation (`weaviate-python-client/weaviate/collections/config/executor.py:493`). Elixir’s vector config builders note “future” support but lack execution paths (`lib/weaviate_ex/api/data.ex:10`).
- **Module configuration breadth**: Python exposes reranker, generative, and vectorizer module configs via class builders (`weaviate-python-client/weaviate/collections/config/__init__.py`). Elixir’s builder covers common vectorizers but not the auxiliary modules.

## Data & References

- **Reference CRUD**: Python implements single and multi-target reference add/update/delete through REST and gRPC (`weaviate-python-client/weaviate/collections/data/executor.py`). Elixir lacks `Data.add_reference/5`, `Data.update_references/5`, etc., blocking link management.
- **Tenant-aware options across every call**: Python threads tenant consistently and validates the input; Elixir supports the REST tenant parameter but lacks higher-level orchestration or validation (e.g., no `Tenant` structs).

## Batch Workflows

- **Dynamic/fixed/rate-limited batching**: Python provides context managers with auto-flush, concurrency control, and vectorizer-aware batching (`weaviate-python-client/weaviate/collections/batch/client.py:28`). Elixir only exposes direct REST calls and a summary struct (`lib/weaviate_ex/api/batch.ex:35`).
- **Detailed per-item error typing**: Python maps errors to concrete exception classes; Elixir surfaces generic maps inside `%Result{errors: []}`.
- **gRPC batch ingestion**: Python can send batches over gRPC for performance; Elixir is limited to REST.

## Query & Search

- **Cursor-based pagination (`after`) on GraphQL**: Python’s query builders expose `after` (`weaviate-python-client/weaviate/collections/query.py`). Elixir’s builder offers offset/limit but not cursors (`lib/weaviate_ex/query.ex:126`).
- **Hybrid/BM25 extras**: Python supports AND/OR operators, fusion mode selection, and rerankers (`weaviate-python-client/weaviate/collections/grpc/query.py:149`). Elixir handles alpha and fusion type but omits BM25 operator selection and reranking.
- **GroupBy metadata parity**: Python returns nested group structures with counts; Elixir supports basic `groupedBy` but lacks full metadata shaping (`lib/weaviate_ex/api/aggregate.ex:237`).
- **gRPC-native streaming**: Absent in Elixir; Python can stream via gRPC for low-latency use cases.

## Generative & Hybrid AI

- **Reranker modules and tool configs**: Python exposes `weaviate.collections.config.configure_reranker` etc., enabling advanced retrieval augmentation. Elixir currently sets generative providers but has no reranker integration or toolchain support.
- **Named vector targeting in generative queries**: Python allows picking specific named vectors in hybrid/generative flows (`weaviate-python-client/weaviate/collections/grpc/query.py:226`). Elixir does not yet support named vectors, so these options are unavailable.

## RBAC & Admin

- **Users, groups, roles management**: Python includes `_Users`, `_Groups`, `_Roles` namespaces (`weaviate-python-client/weaviate/client.py:80`). Elixir has no admin APIs for RBAC, so managing permissions requires direct REST calls outside the client.

## Tooling & Developer Experience

- **Validation and exception typing**: Python uses dedicated validators (`weaviate-python-client/weaviate/validator.py`) and raises typed exceptions. Elixir returns `%WeaviateEx.Error{}` with coarse `type` classifications and limited recovery hints (`lib/weaviate_ex/error.ex`).
- **Upgrade nudges & warnings**: Python warns about deprecated APIs and version skew (`weaviate-python-client/weaviate/warnings.py`). Elixir lacks user-facing warnings or telemetry.

These gaps represent the primary work required to reach functional parity with the Python client. The accompanying roadmap suggests an order of operations for addressing them.
