# Query & Search Functionality Gap Analysis

## Executive Summary

This analysis compares the Query/Search functionality between the Python client (`weaviate-python-client/weaviate/collections/queries/`) and the Elixir port (`lib/weaviate_ex/query.ex`, `lib/weaviate_ex/api/`).

**Overall Feature Parity: ~65%**

## Feature Comparison Matrix

| Feature | Python | Elixir | Gap Level |
|---------|--------|--------|-----------|
| near_vector | Complete | Partial | MEDIUM |
| near_text with move | Complete | Missing | HIGH |
| near_image | Complete | Partial (GraphQL only) | HIGH |
| near_media (audio/video) | Complete | Partial (GraphQL only) | HIGH |
| hybrid with vector | Complete | Missing | HIGH |
| BM25 with operators | Complete | Partial | MEDIUM |
| Filter CONTAINS_NONE | Yes | No | LOW |
| Filter geo operations | Complete | Partial | LOW |
| Aggregation | Separate module | Implemented | COMPLETE |
| Generative (RAG) | Query-integrated | Separate API | MEDIUM |
| Reranking | Complete | Complete | COMPLETE |
| Sorting | Complete | Complete | COMPLETE |
| GroupBy | Complete | Complete | COMPLETE |

---

## 1. Vector Search (near_vector, near_object)

### Python
```python
near_vector(
    query=vector_list,
    certainty, distance, limit, offset, auto_limit,
    filters, group_by, rerank, target_vector,
    include_vector, return_metadata, return_properties, return_references
)
```

### Elixir
```elixir
near_vector(vector, certainty, distance)
# Missing: limit, offset, auto_limit, filters, group_by, rerank, target_vector
```

### Gap: MEDIUM
- Basic functionality exists but query options are fragmented
- Must set limit/offset separately

---

## 2. Text Search (near_text)

### Python
```python
near_text(
    query=string_or_list,
    move_to=Move(concepts, force, objects),
    move_away=Move(concepts, force, objects),
    certainty, distance, limit, offset, auto_limit,
    filters, group_by, rerank, target_vector
)
```

### Elixir
```elixir
near_text(concepts, certainty, distance)
# Move module exists but not integrated into near_text query builder
```

### Gap: HIGH
- `Move` module exists separately but not chainable with near_text
- Core search options fragmented

---

## 3. Image & Media Search

### Python
- `near_image()` - Full gRPC + HTTP support
- `near_media()` - Supports audio, video, image, depth, thermal, imu
- Full parameter support for all query options

### Elixir
- `QueryAdvanced.near_image()` - GraphQL only, standalone function
- `QueryAdvanced.near_media()` - Supports all media types
- **No gRPC implementation**
- Not chainable with Query builder

### Gap: HIGH
- Partial GraphQL-only implementation
- No fluent API integration
- No gRPC support for media searches

---

## 4. BM25/Keyword Search

### Python
```python
bm25(
    query=string,
    query_properties=list,
    operator=BM25OperatorOptions,  # and(), or(minimum_match)
    limit, offset, auto_limit, filters, group_by, rerank
)
```

### Elixir
```elixir
bm25(query, properties)
# BM25Operator module exists with basic structure
# Missing: operator options, full query parameters
```

### Gap: MEDIUM
- Basic BM25 works
- Missing AND/OR operator options with minimum_match

---

## 5. Hybrid Search

### Python
```python
hybrid(
    query=string,
    alpha=0.7,  # Vector weight
    vector=optional_vector,  # Custom vector input
    query_properties,
    fusion_type=HybridFusion.RANKED or RELATIVE_SCORE,
    max_vector_distance,
    bm25_operator,
    limit, offset, auto_limit, filters, group_by, rerank, target_vector
)
```

### Elixir
```elixir
hybrid(search_query, alpha, fusion_type)
# Missing: vector parameter, query_properties, max_vector_distance, bm25_operator
```

### Gap: HIGH
- Basic hybrid exists
- Missing vector input for custom embeddings
- Missing advanced operators and query options

---

## 6. Filters & Filter Operators

### Python
```python
# Comparison
EQUAL, NOT_EQUAL, LESS_THAN, LESS_THAN_EQUAL, GREATER_THAN, GREATER_THAN_EQUAL, LIKE, IS_NULL
# Array
CONTAINS_ANY, CONTAINS_ALL, CONTAINS_NONE
# Geo
WITHIN_GEO_RANGE
# Logical with operator overloading
& (AND), | (OR), ~ (NOT)
# Reference filtering
_SingleTargetRef, _MultiTargetRef, _CountRef
```

### Elixir
```elixir
# Comparison
equal, not_equal, less_than, less_or_equal, greater_than, greater_or_equal, like, null?
# Array
contains_any, contains_all  # Missing: contains_none
# Geo
within_range (partial)
# Logical
all_of, any_of, not
# No operator overloading
```

### Gap: PARTIAL
- Core operators present
- Missing: `CONTAINS_NONE`, full geo support
- No operator overloading (by design in Elixir)

---

## 7. Sorting, Grouping, Pagination

### Sorting
| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| by_property | Yes | Yes | COMPLETE |
| by_id | Yes | Yes | COMPLETE |
| by_creation_time | Yes | Yes | COMPLETE |
| by_update_time | Yes | Yes | COMPLETE |

### GroupBy
| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| prop | Yes | Yes | COMPLETE |
| objects_per_group | Yes | Yes | COMPLETE |
| number_of_groups | Yes | Yes | COMPLETE |

### Pagination
- Python: limit, offset, auto_limit on all query types
- Elixir: Works with main query but not integrated into search type builders

---

## 8. Aggregation Queries

### Elixir Implementation (Comprehensive)
```elixir
API.Aggregate module:
- over_all, with_near_text, with_near_vector
- with_near_object, with_hybrid, with_bm25
- Metrics: count, sum, mean, median, mode, maximum, minimum
- topOccurrences, percentageTrue, percentageFalse
```

### Status: IMPLEMENTED

---

## 9. Metadata Retrieval Options

### Python
```python
MetadataQuery:
- creation_time, last_update_time
- distance, certainty, score, explain_score
- is_consistent
include_vector: bool or list of vector names
```

### Elixir
```elixir
Query.additional(["id", "certainty", "distance", "creationTimeUnix", ...])
# Missing: is_consistent, full vector retrieval options
```

### Gap: PARTIAL

---

## 10. Generative Queries (RAG)

### Python
- Generate class integrated with all query types
- single_prompt, grouped_task, grouped_properties
- 20+ provider integrations

### Elixir
- `API.Generative` module as separate API
- generate_single, generate_grouped, generate_per_object
- 21 provider integrations
- **Not integrated into Query builder**

### Gap: MEDIUM (implemented but not query-integrated)

---

## 11. Reranking Capabilities

### Both
- Rerank with property and optional query
- Integrated into query methods

### Status: COMPLETE

---

## Priority Implementation Recommendations

### Priority 1 (Critical)
1. **Integrate Move operations into near_text query builder**
2. **Implement near_image and near_media with gRPC support**
3. **Add vector parameter to hybrid search**
4. **Integrate all query parameters into search type builders**

### Priority 2 (High)
1. Add BM25OperatorOptions (AND/OR) support
2. Implement CONTAINS_NONE filter operator
3. Add full Geo filter operations
4. Integrate Generative (RAG) into Query builder

### Priority 3 (Medium)
1. Add is_consistent metadata option
2. Expand vector retrieval options
3. Implement TargetVectorJoinType for named vectors
4. Add query_properties parameter to hybrid and BM25

---

## Conclusion

The Elixir port has solid foundations for core query functionality with complete support for sorting, grouping, and reranking. The main gaps are in media search (gRPC support), hybrid search (vector input), and the lack of fluent API integration across search types. The separation of concerns (QueryAdvanced, API modules) makes feature discovery harder.
