# Prompt: Schema Lifecycle & Data Ingestion Foundation

## Context
We are executing Phase 1 of the essential program to harden schema collections, object CRUD, and lightweight batch flows. The scope must align with the essential blueprint (`01_essential_scope.md`) and detailed responsibilities in `02_schema_data_plan.md`. Existing modules (`lib/weaviate_ex/collections.ex`, `lib/weaviate_ex/api/collections.ex`, `lib/weaviate_ex/objects.ex`, `lib/weaviate_ex/api/data.ex`, `lib/weaviate_ex/batch.ex`) provide partial coverage but lack tenant toggles, raw config passthrough, consistent error mapping, and batch summaries. The implementation must be backwards compatible while enabling the roadmap for Sprints S1–S3 in the schema & ingestion pillar.

## Required Reading
- `docs/20251019/01_essential_scope.md`
- `docs/20251019/02_schema_data_plan.md`
- `docs/20251019/10_actionable_implementation_plan.md`
- `lib/weaviate_ex/collections.ex`, `lib/weaviate_ex/api/collections.ex`
- `lib/weaviate_ex/objects.ex`, `lib/weaviate_ex/api/data.ex`
- `lib/weaviate_ex/batch.ex`, `test/weaviate_ex/batch_test.exs`
- `test/weaviate_ex/collections_test.exs`, `test/weaviate_ex/api/data_test.exs`

## Implementation Objectives
1. **Collections Reliability**
   - Introduce helper(s) on `WeaviateEx.Collections` to check existence, toggle multi-tenancy, and merge raw config overrides as described in `02_schema_data_plan.md`.
   - Ensure `WeaviateEx.API.Collections` exposes equivalent functions with structured `%WeaviateEx.Error{}` typing for validation/conflict scenarios.
   - Add tenant-aware shard inspection helpers and verify consistent option handling across requests.
2. **Object Lifecycle Polish**
   - Extend `WeaviateEx.Objects` and `WeaviateEx.API.Data` to expose `_additional` fields and consistency/tenant options for all read/write operations.
   - Centralize UUID/vector utilities, ensuring existing callers remain green (feature flag any new defaults).
3. **Batch MVP Preparation**
   - Scaffold `WeaviateEx.API.Batch` (module + struct) responsible for create/delete flows, including summary struct for success/error separation.
   - Update `WeaviateEx.Batch` public module to delegate to the API implementation, preserving current behaviour until new module passes tests (blue/green).
4. **Documentation Hooks**
   - Add moduledocs and inline examples that mirror the quick start narrative; no TODOs left behind.

## TDD & Quality Gates
- Write failing unit tests before implementation: update `test/weaviate_ex/api/collections_test.exs`, `test/weaviate_ex/api/data_test.exs`, and add new tests for batch summary semantics.
- Maintain Blue/Green behaviour by keeping existing public APIs stable; gate new functionality behind explicit options until documentation and tests confirm readiness.
- Require `mix format` + `mix test --color` to pass with zero warnings. Ensure Credo/Dialyzer (if enabled) remain silent.
- Capture review notes inline (docstrings or comments) rather than TODOs; code review checklist must include schema CRUD edge cases and tenant handling.

## Deliverables
- Updated modules (`lib/weaviate_ex/collections.ex`, `lib/weaviate_ex/objects.ex`, `lib/weaviate_ex/batch.ex`, new `lib/weaviate_ex/api/batch.ex`) with comprehensive moduledocs and examples.
- Expanded tests proving success/error paths, tenant toggles, and batch summaries with all tests passing.
- Documentation cross-reference mention in quick start doc PR description (prepared as part of review).
- Status update entry for Program Ops (Phase 1) indicating Blue environment remains untouched until review sign-off.
