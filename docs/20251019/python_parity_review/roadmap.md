# Roadmap Toward Python Parity

The following phased plan bridges the documented gaps. Each phase is scoped to deliver coherent user-facing value while minimizing churn.

## Phase 1 — Transport & Configuration Foundations

**Goals**

- Introduce retryable HTTP configuration (timeouts, retries, custom headers, proxies, TLS options).
- Add connection helper functions mirroring Python’s `connect_to_local/embedded/custom`, reusing existing `WeaviateEx.Embedded`.
- Expand auth support to bearer tokens and OAuth2 Client Credentials.

**Key Tasks**

1. Extend `WeaviateEx.Client.Config` to capture retry/pool/proxy/TLS options and expose them through `WeaviateEx.Client.new/1`.
2. Wrap Finch with middleware for retry/backoff and header injection.
3. Implement helper modules (`WeaviateEx.Connect.Local`, `WeaviateEx.Connect.Custom`) that build configs and call `Client.new/1`.
4. Introduce an auth behaviour for token providers; implement API key and OAuth2 client credentials providers initially.

**Risks & Mitigations**

- *OAuth2 complexity*: use an external dependency (e.g., `oauth2`) with refresh token handling; cache tokens in ETS keyed by audience.
- *Breaking config API*: keep existing `base_url`/`api_key` defaults and make new options optional.

## Phase 2 — gRPC & High-Performance Operations

**Goals**

- Add gRPC protocol implementation for query, aggregate, and batch workloads.
- Support named vectors and reference property helpers aligned with Python’s schema executor.
- Provide tenant structs and validation similar to Python’s `_Filters` and `_Tenant`.

**Key Tasks**

1. Generate gRPC stubs using Weaviate protobuf definitions (`weaviate-python-client/weaviate/proto` as reference).
2. Implement `WeaviateEx.Protocol.GRPC.Client` and protocol switching (`:protocol => :grpc | :auto`).
3. Extend collection APIs with `add_reference/3`, named vector builders, and validation.
4. Update batch module to offer gRPC ingestion and expand `%Result{}` to include typed errors.

**Risks & Mitigations**

- *Binary compatibility*: add integration tests against dockerized Weaviate versions for REST vs gRPC parity.
- *Stub drift*: automate proto sync via CI script to track upstream changes.

## Phase 3 — Namespace Parity & RBAC

**Goals**

- Implement backup, cluster, debug, alias, users, groups, and roles namespaces.
- Introduce dynamic/fixed/rate-limited batching contexts for ergonomic ingestion control.
- Provide richer query modifiers (cursor pagination, BM25 operators, rerankers).

**Key Tasks**

1. Map REST endpoints for each namespace into `WeaviateEx.API.*` modules and expose through top-level facets.
2. Build a batching context abstraction (using `GenServer` or processes) that mirrors Python’s `_BatchClientWrapper`.
3. Enhance `WeaviateEx.Query` to accept `after` cursors, BM25 operator options, and reranker specs, sharing logic with the gRPC layer.

**Risks & Mitigations**

- *Surface area sprawl*: ship namespaces incrementally (e.g., backup/cluster first) and document stability expectations.
- *Concurrency costs*: reuse async Tasks and telemetry to monitor batch flush performance.

## Phase 4 — Developer Experience & Polishing

**Goals**

- Provide typed error modules, validation helpers, and deprecation warnings.
- Add upgrade nudges & compatibility checks akin to Python warnings.
- Document parity status and publish migration guides.

**Key Tasks**

1. Expand `WeaviateEx.Error` with distinct structs (`:validation_error`, `:auth_error`, `:grpc_error`) and helper constructors.
2. Implement a lightweight warning system triggered on deprecated options or version mismatches.
3. Refresh documentation and examples, including parity matrices and guides for new auth/transport features.

**Risks & Mitigations**

- *Warning noise*: allow configuration to suppress non-critical warnings.
- *Maintenance burden*: align release checklist with parity docs to keep status accurate.
