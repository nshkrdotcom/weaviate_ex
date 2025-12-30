# Schema and Collections Implementation Plan

## Scope
Close schema builder and collection configuration gaps, including TTL, auto-tenant, property options, and collection handle parity.

## Gap sources
- `docs/20251229/multiagent-deep-gap-analysis-v2/agent-schema-collections.md`

## Tasks
1. Property `indexRangeFilters`
   - Add `:index_range_filters` option to `WeaviateEx.Property.new/3` and map to `indexRangeFilters`.

2. Object TTL integration
   - Update `WeaviateEx.Collections.create/3` and `update/3` to recognize `%WeaviateEx.Config.ObjectTTL{}` and serialize via `ObjectTTL.to_map/1`.

3. Auto-tenant and multi-tenancy wiring
   - Support `%WeaviateEx.Config.AutoTenant{}` and `%WeaviateEx.Schema.MultiTenancyConfig{}` in collection config serialization.

4. Optional collection handle
   - Introduce a `WeaviateEx.Collection` handle with tenant/consistency defaults (if aligned with project direction).
   - Ensure existing module-level functions remain supported.

## Acceptance criteria
- New unit tests for schema payload serialization and property builder options.
- README and guides updated (`collections.md`, `multi_tenancy.md`, `getting_started.md`).
- `CHANGELOG.md` 0.7.3 updated.
- Tests passing with no warnings/credo/dialyzer errors.
