# Prompt - Schema and Collections Parity

## Objective
Implement schema/collections parity gaps: property indexRangeFilters, TTL/auto-tenant serialization, and optional collection handle defaults.

## Required reading (docs)
- `docs/20251229/multiagent-deep-gap-analysis-v2/agent-schema-collections.md`
- `docs/20251229/multiagent-deep-gap-analysis-v2/implementation-plan/02_schema_collections.md`
- `README.md`
- `guides/collections.md`
- `guides/multi_tenancy.md`
- `guides/vectorizers.md`
- `CHANGELOG.md`

## Required reading (src/tests)
- `lib/weaviate_ex/collections.ex`
- `lib/weaviate_ex/property.ex`
- `lib/weaviate_ex/config/object_ttl.ex`
- `lib/weaviate_ex/config/auto_tenant.ex`
- `lib/weaviate_ex/schema/multi_tenancy_config.ex`
- `lib/weaviate_ex/api/vector_config.ex`
- `lib/weaviate_ex/api/named_vectors.ex`
- `test/weaviate_ex/collections/*`
- `test/weaviate_ex/property/*`

## Context
- Python `Property` supports `indexRangeFilters`; Elixir builder omits it.
- TTL and auto-tenant configs exist as structs but are not serialized automatically into collection create/update payloads.
- Elixir lacks a collection handle with default tenant/consistency (Python provides this via collection objects).

## Implementation instructions (TDD required)
1. Property `index_range_filters`
   - Add option to `WeaviateEx.Property.new/3` and convenience builders.
   - Serialize to `indexRangeFilters` in property map.
   - Add unit tests for new option.

2. TTL integration
   - Detect `%WeaviateEx.Config.ObjectTTL{}` in collection config and serialize with `ObjectTTL.to_map/1`.
   - Add tests for create/update payloads.

3. Auto-tenant + multi-tenancy wiring
   - Detect `%WeaviateEx.Config.AutoTenant{}` and `%WeaviateEx.Schema.MultiTenancyConfig{}` in collection config and serialize accordingly.
   - Add tests for create/update payloads.

4. Optional collection handle
   - If aligned with repo direction, introduce `WeaviateEx.Collection` with tenant/consistency defaults and backward compatibility.
   - Add tests and docs for new API.

## Docs updates
- Update `README.md` and relevant guides to document new schema options and usage patterns.

## Changelog
- Add entries under `## [0.7.3] - 2025-12-29` in `CHANGELOG.md` describing schema/collections enhancements.

## Quality gates
- TDD: add/adjust tests first, then implement.
- All tests passing.
- No warnings, credo issues, or dialyzer errors.
