# Pillar Plan: Query & Aggregation Experience

**Date:** 2025‑10‑19  
**Owners:** Search squad  
**Scope:** Deliver fluent GraphQL Get + Aggregation APIs covering essential search scenarios (keyword, vector, hybrid) for v2.0.

---

## 1. Functional Requirements

### 1.1 Query Builder

- Support `Get` queries for a single collection with:  
  - Field selection (properties + `_additional`).  
  - `where` filters built from `WeaviateEx.Filter`.  
  - `near_text`, `near_vector`, `near_object`.  
  - `bm25` keyword search.  
  - `hybrid` with `alpha` and `fusionType`.  
  - `limit`, `offset`, optional `autocut`.  
  - `with_additional` for id, distance, certainty, timestamps, vector (default false).  
- Provide specialized helpers: `Query.fetch_object_by_id/4` (GraphQL path) and `Query.fetch_objects_by_ids/4`.

### 1.2 Aggregations

- Rollups for `over_all`, `with_where`, `with_near_text`, `with_near_vector`, `group_by`.  
- Metrics: count, sum, mean, median, mode, min, max, topOccurrences, percentageTrue/False.  
- Accept property definitions with optional per-property options (limit, topOccurrences count).  
- Align response parsing to return normalized list/struct.

### 1.3 Additional Metadata

- `_additional` builder should expose: `id`, `vector` (optional), `distance`, `certainty`, `score`, `explainScore`, `creationTimeUnix`, `lastUpdateTimeUnix`.  
- Provide simple term to opt-in to raw `_additional` map for forward compatibility.

---

## 2. Architecture & API Shape

1. **Builder Pattern**  
   - Maintain immutable `%WeaviateEx.Query{}` struct.  
   - Extend struct fields for `sort`, `autocut`, `_additional`, `after` (even if stored but not processed until implemented to avoid breaking future extension).  
   - Provide `Query.execute/2` and `Query.to_graphql/1` for debugging.

2. **Filter Integration**  
   - `Filter` module should output GraphQL-ready map; builder just embeds output.  
   - Add `Query.where(Filter.t())` overload to reduce manual map passing.

3. **Result Normalization**  
   - Wrap output in `%Query.Result{collection: "Article", objects: [...], meta: %{took: ...}}`.  
   - On GraphQL errors, return `{:error, %WeaviateEx.Error{type: :graphql_error, details: errors}}`.

4. **Aggregations**  
   - Introduce `%Aggregate.Request{}` + `%Aggregate.Result{}` to enforce consistent shape.  
   - Provide DSL-style helpers for properties: `Aggregate.property("views", [:mean, :sum], limit: 3)`.

5. **Raw Escape Hatch**  
   - `Query.execute_raw/2` returns raw GraphQL JSON for advanced users.  
   - Document how to attach custom GraphQL fragments via raw path.

---

## 3. Implementation Timeline

| Sprint | Deliverable | Key Tasks | Acceptance |
| --- | --- | --- | --- |
| **S1** | Query builder consolidation | Implement builder struct upgrades, execution pipeline, `_additional` options, fetch-by-id helpers. | Unit + integration tests for each query type; GraphQL errors surfaced cleanly. |
| **S2** | Aggregation high-level API | Replace current imperative functions with DSL struct + supportive helpers; ensure metrics map. | Integration tests comparing outputs with Python client for sample dataset. |
| **S3** | Metadata & ergonomics | Expand `_additional`, add `Query.to_graphql/1`, raw escape hatch, doc updates. | Developer feedback session + doc review complete. |
| **S4** | Performance & stability | Add pagination limit guardrails, ensure builder handles large filter trees, soak test queries with 100k objects dataset. | Soak test report, profiling shows acceptable latency, no JSON encoding blowups. |

---

## 4. Testing Strategy

- **Unit Tests:**  
  - Ensure GraphQL strings match expectations for each builder combination.  
  - Validate `_additional` expansion toggles.  
  - Aggregation property DSL -> JSON conversion.
- **Integration Tests:**  
  - near_text / near_vector / hybrid with real embeddings and baseline dataset.  
  - Filters combining AND/OR/NOT to confirm translation.  
  - Aggregations verifying metrics and group_by behavior.  
  - `_additional` retrieval for vectors, distance, timestamps.  
  - Negative cases: invalid operator, unknown property -> server error propagation.
- **Load Tests:**  
  - Use example dataset to run 1k queries sequentially ensuring no memory leaks.  
  - Evaluate aggregator with large property set to ensure JSON encoding within limits.

---

## 5. Documentation Deliverables

- Query cookbook (semantic search, hybrid, filter combos, pagination).  
- Aggregation cookbook (totals, numeric stats, text topOccurrences).  
- Troubleshooting page (GraphQL error hints, vector length mismatch).  
- Comparison table vs Python client highlighting intentionally omitted features.

---

## 6. Outstanding Questions

1. Do we expose `autocut` in initial release or hide behind raw options?  
2. Should `_additional.vector` be enabled by default or require explicit opt-in due to payload size?  
3. Is there demand for cross-collection `MultiGet` queries now, or defer entirely?  
4. How do we expose server-driven defaults like `limit=20` to developer (doc vs warning)?

