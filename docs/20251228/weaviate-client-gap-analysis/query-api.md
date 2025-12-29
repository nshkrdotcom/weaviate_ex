# Query API Gap Analysis

## Overview
Comprehensive comparison of Weaviate Python vs Elixir client Query API coverage.

**Analysis Date:** 2025-12-28
**Python Files Analyzed:** `weaviate/collections/queries/*/executor.py`, `weaviate/collections/aggregations/`
**Elixir Files Analyzed:** `lib/weaviate_ex/query.ex`, `lib/weaviate_ex/api/query_advanced.ex`, `lib/weaviate_ex/api/aggregate.ex`

---

## Query Type Coverage

| Query Type | Python | Elixir | Coverage | Critical Gaps |
|------------|--------|--------|----------|---------------|
| `fetch_objects` | Complete | Partial | 65% | fetch_by_ids, metadata options |
| `near_vector` | Complete | Partial | 60% | rerank, group_by, target_vector |
| `near_text` | Complete | Partial | 70% | rerank, group_by |
| `near_image/media` | Complete | Partial | 80% | Full media type support |
| `near_object` | Complete | Partial | 60% | rerank, group_by |
| `bm25` | Complete | Partial | 50% | operator, rerank, group_by |
| `hybrid` | Complete | Partial | 50% | vector param, bm25_operator, rerank |
| `aggregate` | Complete | Complete | 95% | with_near_image variant |

---

## Detailed Query Analysis

### near_vector Queries

**Python Parameters** (`queries/near_vector/query/executor.py`):
```python
near_vector(
    near_vector: NearVectorInputType,
    certainty: Optional[NUMBER],
    distance: Optional[NUMBER],
    limit: Optional[int],
    offset: Optional[int],
    auto_limit: Optional[int],
    filters: Optional[_Filters],
    group_by: Literal[None],
    rerank: Optional[Rerank],
    target_vector: Optional[TargetVectorJoinType],
    include_vector: INCLUDE_VECTOR,
    return_metadata: Optional[METADATA],
    return_properties: Union[PROPERTIES, bool, None],
    return_references: REFERENCES
)
```

**Elixir Implementation** (`query.ex`):
- ✅ `near_vector(query, vector, opts)` - Basic implementation
- ✅ `certainty`, `distance` options
- ❌ Missing: `rerank`, `group_by`, `auto_limit`, `target_vector`
- ❌ Missing: `return_metadata`, `return_properties`, `return_references`, `include_vector`

### BM25 (Keyword) Search

**Python Parameters** (`queries/bm25/query/executor.py`):
```python
bm25(
    query: Optional[str],
    query_properties: Optional[List[str]],
    limit: Optional[int],
    offset: Optional[int],
    operator: Optional[BM25OperatorOptions],  # AND/OR operators
    auto_limit: Optional[int],
    filters: Optional[_Filters],
    group_by: Literal[None],
    rerank: Optional[Rerank],
    ...
)
```

**Elixir Implementation**:
- ✅ `bm25(query, search_query, opts)` - Basic query
- ✅ `properties` option
- ❌ Missing: `operator` (AND/OR/NOT)
- ❌ Missing: `auto_limit`, `rerank`, `group_by`

### Hybrid Search

**Python Parameters** (`queries/hybrid/query/executor.py`):
```python
hybrid(
    query: Optional[str],
    alpha: NUMBER = 0.7,
    vector: Optional[HybridVectorType],
    query_properties: Optional[List[str]],
    fusion_type: Optional[HybridFusion],
    max_vector_distance: Optional[NUMBER],
    bm25_operator: Optional[BM25OperatorOptions],
    ...
)
```

**Elixir Implementation**:
- ✅ `hybrid(query, search_query, opts)` - Basic query
- ✅ `alpha`, `fusion_type` options
- ❌ Missing: `vector` (custom vector for hybrid)
- ❌ Missing: `query_properties`, `max_vector_distance`
- ❌ Missing: `bm25_operator`, `rerank`, `group_by`, `target_vector`

---

## Critical Missing Features

### 1. Reranking Integration (CRITICAL)

**Python Implementation**: Integrated into all query types
```python
rerank: Optional[Rerank]  # property, query (optional)
```

**Elixir Status**:
- Module exists: `lib/weaviate_ex/query/rerank.ex`
- ❌ **NOT integrated** into main Query module
- GraphQL conversion implemented but unused in queries

**Required Action**: Add `rerank()` function to Query module for all search types.

### 2. Group By Integration (HIGH)

**Python Implementation**: Integrated into all query types
```python
group_by: Literal[None]  # GroupBy object with path, objectsPerGroup, number_of_groups
```

**Elixir Status**:
- Module exists: `lib/weaviate_ex/query/group_by.ex`
- Module exists: `lib/weaviate_ex/api/query_advanced.ex`
- ❌ **NOT integrated** into main Query module

**Required Action**: Integrate group_by support into all Query search methods.

### 3. Advanced Query Options (HIGH)

Missing parameters across all query types:
- `auto_limit` - Automatic result cutoff
- `target_vector` - Multi-vector search targeting
- `return_references` - Cross-reference fetching
- `return_metadata` - Structured metadata selection
- `include_vector` - Vector embedding inclusion

---

## Aggregate Queries

### Python Aggregate Types

| Type | Python | Elixir | Status |
|------|--------|--------|--------|
| `over_all()` | ✅ | ✅ | Full |
| `with_near_text()` | ✅ | ✅ | Full |
| `with_near_vector()` | ✅ | ✅ | Full |
| `with_near_object()` | ✅ | ✅ | Full |
| `with_near_image()` | ✅ | ❌ | Missing |
| `with_hybrid()` | ✅ | ✅ | Full |
| `with_where()` | ✅ | ✅ | Full |
| `group_by()` | ✅ | ✅ | Full |

### Aggregate Metrics
Both clients support: count, sum, mean, median, mode, maximum, minimum, topOccurrences, percentageTrue, percentageFalse, totalTrue, totalFalse

---

## Generative (RAG) Queries

### Python Generative Support
- Location: `weaviate/collections/queries/*/generate/executor.py`
- Full integration with all query types
- Parameters: `single_prompt`, `grouped_task`, `generative_provider`, `grouped_properties`

### Elixir Generative Support
- Location: `lib/weaviate_ex/api/generative.ex`
- ✅ `single_prompt()` - Single result generation
- ✅ `grouped_task()` - Grouped result generation
- ✅ 21 provider support

**Status**: Core generative features implemented

---

## Supporting Features

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Cursor pagination | Complete | Complete | ✅ 100% |
| Filters | Complete | Complete | ✅ 100% |
| Sorting | Complete | Complete | ✅ 100% |
| Pagination (limit/offset) | Complete | Complete | ✅ 100% |
| Additional metadata | Full options | Basic support | ⚠️ Partial |

---

## Recommendations

### Critical Priority
1. **Reranking Integration** - Add `rerank()` to Query module, support all search types
2. **Group By Integration** - Integrate existing GroupBy module into main Query

### High Priority
3. Add `auto_limit`, `target_vector`, `return_references` to all queries
4. Implement `BM25Operator` (AND/OR/NOT) for keyword search
5. Add `vector` parameter to hybrid search

### Medium Priority
6. Implement `with_near_image()` aggregate variant
7. Complete media type support in main Query module
8. Add structured `return_metadata` options
