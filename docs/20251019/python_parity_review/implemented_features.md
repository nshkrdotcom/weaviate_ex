# Implemented Features

This document captures the Weaviate functionality that already exists in the Elixir client and ties each item back to the Python reference surface. References use 1-based line numbers.

## Client & Core Utilities

- Basic client struct with protocol abstraction and Finch-backed HTTP transport (`lib/weaviate_ex/client.ex:1`, `lib/weaviate_ex/protocol/http/client.ex:1`).
- Application-wide helper for health, ready, and live checks plus embedded server lifecycle (`lib/weaviate_ex.ex:55`, `lib/weaviate_ex/health.ex:1`, `lib/weaviate_ex/embedded.ex:1`).
- Config struct supports base URL, optional API key, timeout selection, and future protocol hooks (`lib/weaviate_ex/client/config.ex:1`).

## Collections (Schema) Management

- Schema list/get/create/update/delete coverage (`lib/weaviate_ex/collections.ex:61`, `lib/weaviate_ex/collections.ex:79`, `lib/weaviate_ex/collections.ex:115`, `lib/weaviate_ex/collections.ex:140`, `lib/weaviate_ex/collections.ex:163`).
- Property addition with normalization and overrides helpers (`lib/weaviate_ex/collections.ex:196`, `lib/weaviate_ex/collections.ex:210`).
- Shard status controls and multi-tenancy lifecycle, mirroring Python’s collection configuration endpoints (`lib/weaviate_ex/collections.ex:205`, `lib/weaviate_ex/collections.ex:226`, `lib/weaviate_ex/collections.ex:250`, `lib/weaviate_ex/collections.ex:275`).
- Vector configuration builders spanning vectorizers, index types, and quantization (`lib/weaviate_ex/api/vector_config.ex:1`).

## Tenants

- REST coverage for tenant CRUD, status transitions, activation helpers, and filtering (`lib/weaviate_ex/api/tenants.ex:31`, `lib/weaviate_ex/api/tenants.ex:68`, `lib/weaviate_ex/api/tenants.ex:102`, `lib/weaviate_ex/api/tenants.ex:129`, `lib/weaviate_ex/api/tenants.ex:167`, `lib/weaviate_ex/api/tenants.ex:190`).

## Data (Objects) Operations

- Object create/update/patch/delete/exists/validate with tenant and consistency-level support (`lib/weaviate_ex/api/data.ex:91`, `lib/weaviate_ex/api/data.ex:126`, `lib/weaviate_ex/api/data.ex:158`, `lib/weaviate_ex/api/data.ex:194`, `lib/weaviate_ex/api/data.ex:232`, `lib/weaviate_ex/api/data.ex:262`, `lib/weaviate_ex/api/data.ex:297`).
- Vector and UUID handling through payload normalizers (`lib/weaviate_ex/objects/payload.ex:1`).
- Public convenience layer mirroring the API module (`lib/weaviate_ex/objects.ex:1`).

## Batch Workflows

- Batch create/delete/reference operations plus summary struct for per-object success tracking (`lib/weaviate_ex/batch.ex:83`, `lib/weaviate_ex/batch.ex:130`, `lib/weaviate_ex/batch.ex:162`, `lib/weaviate_ex/api/batch.ex:35`, `lib/weaviate_ex/api/batch.ex:122`).

## Query & Search

- GraphQL “Get” builder with fluent chaining for fields, where filters, near-text/vector/object, BM25, hybrid, pagination, and additional metadata (`lib/weaviate_ex/query.ex:59`, `lib/weaviate_ex/query.ex:121`, `lib/weaviate_ex/query.ex:137`, `lib/weaviate_ex/query.ex:163`, `lib/weaviate_ex/query.ex:185`, `lib/weaviate_ex/query.ex:200`, `lib/weaviate_ex/query.ex:221`).
- Filter DSL for composing GraphQL `where` clauses (`lib/weaviate_ex/filter.ex:53`, `lib/weaviate_ex/filter.ex:108`, `lib/weaviate_ex/filter.ex:173`).
- Advanced query helpers for near-image/media, sorting, grouping, and autocut controls (`lib/weaviate_ex/api/query_advanced.ex:43`, `lib/weaviate_ex/api/query_advanced.ex:125`, `lib/weaviate_ex/api/query_advanced.ex:214`, `lib/weaviate_ex/api/query_advanced.ex:249`, `lib/weaviate_ex/api/query_advanced.ex:289`).
- Aggregation API with metrics, property-specific stats, filters, near search support, and group-by (`lib/weaviate_ex/api/aggregate.ex:64`, `lib/weaviate_ex/api/aggregate.ex:92`, `lib/weaviate_ex/api/aggregate.ex:121`, `lib/weaviate_ex/api/aggregate.ex:149`, `lib/weaviate_ex/api/aggregate.ex:204`).

## Generative AI Integration

- Single and grouped generative prompts with provider validation, prompt interpolation, and GraphQL clause builder supporting thirteen providers (`lib/weaviate_ex/api/generative.ex:60`, `lib/weaviate_ex/api/generative.ex:108`, `lib/weaviate_ex/api/generative.ex:155`, `lib/weaviate_ex/api/generative.ex:216`, `lib/weaviate_ex/api/generative.ex:313`).

## Embedded Runtime & Monitoring

- Embedded binary management (download/cache/spawn/stop) emulating Python’s `connect_to_embedded` flow (`lib/weaviate_ex/embedded.ex:1`).
- Retryable connection validation, wait-until-ready loop, and logging similar to Python client startup checks (`lib/weaviate_ex/health.ex:31`, `lib/weaviate_ex/health.ex:88`, `lib/weaviate_ex/health.ex:107`).

These features provide a solid baseline for application developers and align with a significant subset of the Python client’s synchronous REST capabilities.
