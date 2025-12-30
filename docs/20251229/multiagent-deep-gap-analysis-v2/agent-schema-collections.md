# Agent Schema - Collections and Configuration Gap Analysis

## Scope and sources
- Python: `weaviate-python-client/weaviate/collections/collection/base.py`, `weaviate-python-client/weaviate/collections/classes/config.py`, `weaviate-python-client/weaviate/collections/classes/config_object_ttl.py`, `weaviate-python-client/weaviate/collections/classes/config_vectorizers.py`
- Elixir: `lib/weaviate_ex/collections.ex`, `lib/weaviate_ex/property.ex`, `lib/weaviate_ex/schema/multi_tenancy_config.ex`, `lib/weaviate_ex/config/auto_tenant.ex`, `lib/weaviate_ex/config/object_ttl.ex`, `lib/weaviate_ex/api/vector_config.ex`, `lib/weaviate_ex/api/named_vectors.ex`

## Parity highlights
- Broad vectorizer coverage is implemented (Elixir `lib/weaviate_ex/api/vector_config.ex` mirrors Python vectorizer list in `weaviate-python-client/weaviate/collections/classes/config_vectorizers.py`).
- Named vectors and vector index settings exist in Elixir (`lib/weaviate_ex/api/named_vectors.ex`).
- Multi-tenancy CRUD APIs exist in Elixir (`lib/weaviate_ex/api/tenants.ex`) with gRPC support.

## Gap findings
1. Property-level `indexRangeFilters` is missing in the Elixir builder.
   - Impact: collection property configs cannot express range filter indexing via the fluent builder, forcing raw map usage.
   - Evidence (Python): `weaviate-python-client/weaviate/collections/classes/config.py` `Property` includes `indexRangeFilters`.
   - Evidence (Elixir): `lib/weaviate_ex/property.ex` does not expose an `index_range_filters` option.

2. Object TTL config exists but is not integrated into collection create/update flows.
   - Impact: `WeaviateEx.Config.ObjectTTL` must be manually converted to API maps, increasing error risk and reducing parity with Python typed builders.
   - Evidence (Python): `weaviate-python-client/weaviate/collections/classes/config_object_ttl.py` is part of collection config.
   - Evidence (Elixir): `lib/weaviate_ex/config/object_ttl.ex` exists, but `lib/weaviate_ex/collections.ex` only deep-merges maps and does not call `ObjectTTL.to_map/1`.

3. Auto-tenant and multi-tenancy config builders are not wired to collection config.
   - Impact: auto-tenant creation/activation settings require manual mapping; config structs are not automatically serialized into the schema payload.
   - Evidence (Python): collection config includes `autoTenantCreation` and `autoTenantActivation` options.
   - Evidence (Elixir): `lib/weaviate_ex/schema/multi_tenancy_config.ex` and `lib/weaviate_ex/config/auto_tenant.ex` exist but are not handled by `lib/weaviate_ex/collections.ex`.

4. No collection handle pattern or typed config objects in the public API.
   - Impact: users cannot create a scoped collection object with defaults (tenant, consistency, vector index settings) or use typed Pydantic-style configs; higher DX burden and more room for invalid config.
   - Evidence (Python): `weaviate-python-client/weaviate/collections/collection/base.py` defines collection objects with tenant/consistency context; config classes in `weaviate-python-client/weaviate/collections/classes/config.py` enforce validation.
   - Evidence (Elixir): `lib/weaviate_ex/collections.ex` is a set of module-level functions that accept raw maps, with minimal validation.

## Suggested closure
- Extend `WeaviateEx.Property` to accept `index_range_filters` and map it to `indexRangeFilters`.
- Add collection config serialization helpers that recognize `ObjectTTL`, `AutoTenant`, and `MultiTenancyConfig` structs inside `WeaviateEx.Collections.create/3` and `update/3`.
- Consider introducing a `WeaviateEx.Collection` handle with defaults (tenant, consistency) similar to Python, and typed config structs with validation to reduce invalid schema payloads.
