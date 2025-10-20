# Pillar Plan: Schema Lifecycle & Data Ingestion

**Date:** 2025‑10‑19  
**Owners:** Core API squad  
**Depends on:** Essential scope approval (`01_essential_scope.md`)  
**Goal:** Deliver reliable schema management + CRUD/batch ingestion by WeaviateEx v2.0.

---

## 1. Functional Requirements

### 1.1 Collections

- Create, update, delete classes (`/v1/schema`).  
- Add properties with minimal config (datatype, description, index toggles).  
- Inspect schema, shards, and tenants.  
- Toggle multi-tenancy (`multiTenancyConfig.enabled`) and vector index basics (`vectorIndexType`, `vectorIndexConfig` limited set).  
- Provide raw pass-through for additional config without exposing builders.  
- Surface consistent errors (validation, conflicts, not found).

### 1.2 Objects (CRUD)

- Insert single object with auto/custom UUID, optional vector, `tenant`, `consistencyLevel`.  
- Update & patch existing objects (with server constraints).  
- Delete & existence check by UUID.  
- Validate payloads via `/v1/objects/validate`.  
- Expose request options for `include` to retrieve `_additional` metadata when fetching.

### 1.3 Lightweight Batch

- `Batch.create_objects/2`: Accept list of maps, send to `/v1/batch/objects`, return success/error list.  
- `Batch.delete_objects/2`: Support `where` filters and `dryRun` flag.  
- Shared batch options: `tenant`, `consistencyLevel`, `waitForCompletion`.  
- Provide summary struct: counts, errors (id, message).  
- Keep concurrency/sequencing simple (single request, optional chunking by size).

---

## 2. Architecture Decisions

1. **Module Boundaries**  
   - `WeaviateEx.Collections` for schema commands.  
   - `WeaviateEx.API.Data` (already present) remains single-object CRUD.  
   - New `WeaviateEx.API.Batch` layer focused on essential batch flows.  
   - Optionally add `WeaviateEx.Raw` helper for pass-through config or future features.

2. **Configuration Handling**  
   - Accept plain maps/keywords; only enforce name capitalization.  
   - Offer `config_overrides` keyword to merge raw JSON maps before send.  
   - Validate required keys locally (e.g., property name & datatype) to fail fast.

3. **Error Handling**  
   - Extend `WeaviateEx.Error` to tag `:validation_error`, `:conflict`, `:tenant_missing`.  
   - Batch responses produce `%Batch.Result{objects: [...], errors: [...]}` struct for pattern matching.

4. **UUID & Vector Utilities**  
   - Centralize UUID generation in helper to ensure consistent format and allow future dependency injection.  
   - Accept vector as `list(float)` without local validation; rely on server error for mismatch.

5. **Tenant & Consistency Defaults**  
   - Accept per-request keywords, no global default.  
   - Document interplay with server configuration (e.g., available tenant names).

---

## 3. Implementation Roadmap

| Sprint | Deliverable | Tasks | Exit Criteria |
| --- | --- | --- | --- |
| **S1** | Collections refinements | Ensure `exists?/2`, `delete_all/1`, raw config passthrough, improved error mapping. | Unit + live tests covering duplicate creation, delete missing, tenant toggles. |
| **S2** | Object CRUD polish | Add `_additional` support, strengthen patch retrieval, expose consistency hints, create helper for vector inclusion. | Integration tests for create/update/delete across tenants, 100% moduledoc coverage. |
| **S3** | Batch MVP | Implement create/delete batches with chunking & summary. Provide synchronous wait by default. | Batch integration tests with partial failures + large payload (10k objects) using local Weaviate. |
| **S4** | Stability hardening | Timeouts/retries, connection health check on startup, soak test harness (insert/update loop). | 24h soak run report, doc updates, error taxonomy published. |

---

## 4. Testing Strategy

- **Unit Tests:** Mox to simulate HTTP responses covering success/error shapes; property validation tests; batch summary builder.  
- **Integration Tests:**  
  - Collections create/update/delete across tenants.  
  - Object lifecycle (create → fetch → patch → delete).  
  - Batch create for 1k objects + error case (invalid datatype).  
  - Batch delete with `where` filter and `dryRun` comparative check.  
- **Performance Sanity:** Benchmark ingestion of 50 objects vs 5k objects to ensure Finch config handles payloads.  
- **Failure Injection:**  
  - Simulate 409 conflict on schema change.  
  - Timeout/resume scenario for batch request (use short receive timeout).  
  - Tenant mismatch error propagation.

---

## 5. Documentation & DX

- Update Quick Start to show: define schema → insert object → run batch → query.  
- Provide cookbook snippets (Elixir IEx) for each essential operation.  
- Add troubleshooting section (common validation errors, tenant issues).  
- Document raw config escape hatch examples.

---

## 6. Open Questions

1. Do we need optimistic concurrency (etag) handling now or postpone?  
2. Should batch summary include per-property validation hints or just raw server message?  
3. How to expose custom headers if partner teams require vendor-specific modules before advanced auth lands?

