# Query and Search Capabilities: Gap Analysis

## Python Weaviate Client vs Elixir WeaviateEx

**Date:** December 28, 2024
**Analysis Scope:** Query and Search capabilities
**Reference:** weaviate-python-client
**Target:** WeaviateEx (Elixir port)

---

## Executive Summary

The Elixir WeaviateEx library has **good coverage** of core query and search functionality but has several gaps compared to the Python reference client. The most critical gaps are in:

1. **Multi-vector queries** (list of vectors for single-vector spaces)
2. **Query-time named vector support** (multi-target vector joins in queries)
3. **Generative/RAG integration** with search queries (single API call)
4. **Advanced filter operators** (property length filter, multi-target reference filters)

---

## 1. Vector Search

### near_vector

| Feature | Python | Elixir | Gap | Criticality |
|---------|--------|--------|-----|-------------|
| Basic vector search | Yes | Yes | - | - |
| certainty threshold | Yes | Yes | - | - |
| distance threshold | Yes | Yes | - | - |
| Named target vector (single) | Yes | Yes | - | - |
| Multi-target vector join (sum/avg/min) | Yes | No | **GAP** | Medium |
| Manual weights for multi-target | Yes | No | **GAP** | Medium |
| Relative score fusion for multi-target | Yes | No | **GAP** | Medium |
| List of vectors (multi-query) | Yes | No | **GAP** | High |
| 2D vector support (multi-vector spaces) | Yes | No | **GAP** | Medium |

**Python Implementation:**
```python
# Multi-target vector join
from weaviate.classes.query import TargetVectors
collection.query.near_vector(
    near_vector=vector,
    target_vector=TargetVectors.sum(["title_vector", "content_vector"])
)

# List of vectors query
from weaviate.classes.query import NearVector
collection.query.near_vector(
    near_vector=NearVector.list_of_vectors(vec1, vec2, vec3)
)
```

**Elixir Implementation:**
```elixir
# Basic support exists
Query.get("Article")
|> Query.near_vector([0.1, 0.2, 0.3], certainty: 0.7)

# TargetVectors module exists but not integrated in query execution
# lib/weaviate_ex/query/target_vectors.ex
```

**Gap Details:**
- Elixir has `TargetVectors` module but it's not fully integrated into query execution
- No support for `NearVector.list_of_vectors()` equivalent
- No 2D vector support for multi-vector embedding models

### near_text

| Feature | Python | Elixir | Gap | Criticality |
|---------|--------|--------|-----|-------------|
| Basic text search | Yes | Yes | - | - |
| certainty/distance | Yes | Yes | - | - |
| move_to (concepts) | Yes | Yes | - | - |
| move_to (objects) | Yes | Yes | - | - |
| move_away (concepts) | Yes | Yes | - | - |
| move_away (objects) | Yes | Yes | - | - |
| Multi-target vector | Yes | No | **GAP** | Medium |
| List of text queries | Yes | Partial | **GAP** | Low |

**Elixir Implementation:**
```elixir
# Move support is complete
alias WeaviateEx.Query.Move
move_to = Move.to(0.5, concepts: ["summer", "beach"])
Query.get("Article")
|> Query.near_text("vacation", move_to: move_to)
```

### near_object

| Feature | Python | Elixir | Gap | Criticality |
|---------|--------|--------|-----|-------------|
| Basic object similarity | Yes | Yes | - | - |
| certainty/distance | Yes | Yes | - | - |
| Multi-target vector | Yes | No | **GAP** | Low |

### near_image

| Feature | Python | Elixir | Gap | Criticality |
|---------|--------|--------|-----|-------------|
| Base64 image search | Yes | Yes | - | - |
| certainty/distance | Yes | Yes | - | - |
| File path support | Yes | No | **GAP** | Low |

**Elixir Implementation:**
```elixir
# In lib/weaviate_ex/api/query_advanced.ex
QueryAdvanced.near_image(client, "Article", base64_image,
  limit: 10,
  certainty: 0.7
)
```

### near_audio, near_video, near_imu, near_thermal, near_depth

| Feature | Python | Elixir | Gap | Criticality |
|---------|--------|--------|-----|-------------|
| near_audio | Yes | Yes | - | - |
| near_video | Yes | Yes | - | - |
| near_imu | Yes | Yes | - | - |
| near_thermal | Yes | Yes | - | - |
| near_depth | Yes | Yes | - | - |
| File path support | Yes | No | **GAP** | Low |

**Elixir Implementation:**
```elixir
# Generic near_media function supports all types
QueryAdvanced.near_media(client, "Podcast", :audio, audio_data,
  limit: 5,
  certainty: 0.75
)
```

---

## 2. Keyword Search (BM25)

| Feature | Python | Elixir | Gap | Criticality |
|---------|--------|--------|-----|-------------|
| Basic BM25 search | Yes | Yes | - | - |
| Query properties filter | Yes | Yes | - | - |
| BM25Operator.or_(minimum_match) | Yes | Yes | - | - |
| BM25Operator.and_() | Yes | Yes | - | - |
| Auto-limit (autocut) | Yes | Yes | - | - |

**Python Implementation:**
```python
from weaviate.classes.query import BM25Operator
collection.query.bm25(
    query="machine learning",
    operator=BM25Operator.or_(minimum_match=2)
)
```

**Elixir Implementation:**
```elixir
# Full BM25 operator support
alias WeaviateEx.Query.BM25Operator
operator = BM25Operator.or_(2)
Query.get("Article")
|> Query.bm25("machine learning", operator: operator)
```

**Status: COMPLETE**

---

## 3. Hybrid Search

| Feature | Python | Elixir | Gap | Criticality |
|---------|--------|--------|-----|-------------|
| Basic hybrid search | Yes | Yes | - | - |
| Alpha parameter | Yes | Yes | - | - |
| Ranked fusion | Yes | Yes | - | - |
| Relative score fusion | Yes | Yes | - | - |
| Query properties | Yes | Partial | **GAP** | Low |
| Vector parameter (raw) | Yes | Yes | - | - |
| HybridVector.near_text() | Yes | Yes | - | - |
| HybridVector.near_vector() | Yes | Yes | - | - |
| move_to/move_away in hybrid | Yes | Yes | - | - |
| Multi-target vector | Yes | No | **GAP** | Medium |

**Python Implementation:**
```python
from weaviate.classes.query import HybridFusion, HybridVector

collection.query.hybrid(
    query="coffee",
    alpha=0.75,
    fusion_type=HybridFusion.RELATIVE_SCORE,
    vector=HybridVector.near_text("espresso brewing")
)
```

**Elixir Implementation:**
```elixir
alias WeaviateEx.Query.HybridVector
Query.get("Article")
|> Query.hybrid("coffee",
  alpha: 0.75,
  fusion_type: "relativeScoreFusion",
  vector: HybridVector.near_text("espresso brewing")
)
```

---

## 4. Filters

### Basic Operators

| Operator | Python | Elixir | Gap | Criticality |
|----------|--------|--------|-----|-------------|
| Equal | Yes | Yes | - | - |
| NotEqual | Yes | Yes | - | - |
| LessThan | Yes | Yes | - | - |
| LessThanEqual | Yes | Yes | - | - |
| GreaterThan | Yes | Yes | - | - |
| GreaterThanEqual | Yes | Yes | - | - |
| Like (wildcards) | Yes | Yes | - | - |
| IsNull | Yes | Yes | - | - |
| ContainsAny | Yes | Yes | - | - |
| ContainsAll | Yes | Yes | - | - |
| ContainsNone | Yes | Yes | - | - |
| WithinGeoRange | Yes | Yes | - | - |

### Combinators

| Feature | Python | Elixir | Gap | Criticality |
|---------|--------|--------|-----|-------------|
| AND (&) | Yes | Yes | - | - |
| OR (\|) | Yes | Yes | - | - |
| NOT (~) | Yes | Yes | - | - |
| all_of() | Yes | Yes | - | - |
| any_of() | Yes | Yes | - | - |
| not_() | Yes | Yes | - | - |

### Special Filters

| Feature | Python | Elixir | Gap | Criticality |
|---------|--------|--------|-----|-------------|
| by_property | Yes | Yes | - | - |
| by_id | Yes | Yes | - | - |
| by_creation_time | Yes | Yes | - | - |
| by_update_time | Yes | Yes | - | - |
| by_ref (single target) | Yes | Partial | **GAP** | Medium |
| by_ref_multi_target | Yes | No | **GAP** | Medium |
| by_ref_count | Yes | Yes | - | - |
| Property length filter (len()) | Yes | No | **GAP** | Low |

**Python Implementation:**
```python
from weaviate.classes.query import Filter

# Property length filter
Filter.by_property("content", length=True).greater_than(100)

# Multi-target reference filter
Filter.by_ref_multi_target("hasAuthor", "Author").by_property("name").equal("John")
```

**Elixir Implementation:**
```elixir
# Basic filter support
Filter.equal("status", "published")
Filter.by_creation_time(:greater_than, "2024-01-01T00:00:00Z")
Filter.by_ref("hasAuthor", "Author", :equal, "John Doe")

# Missing: length filter, multi-target reference
```

---

## 5. Aggregations

| Feature | Python | Elixir | Gap | Criticality |
|---------|--------|--------|-----|-------------|
| count (meta) | Yes | Yes | - | - |
| sum | Yes | Yes | - | - |
| mean | Yes | Yes | - | - |
| median | Yes | Yes | - | - |
| mode | Yes | Yes | - | - |
| maximum | Yes | Yes | - | - |
| minimum | Yes | Yes | - | - |
| topOccurrences | Yes | Yes | - | - |
| percentageTrue | Yes | Yes | - | - |
| percentageFalse | Yes | Yes | - | - |
| totalTrue | Yes | Yes | - | - |
| totalFalse | Yes | Yes | - | - |
| with_near_text | Yes | Yes | - | - |
| with_near_vector | Yes | Yes | - | - |
| with_where | Yes | Yes | - | - |
| group_by | Yes | Yes | - | - |
| gRPC support | Yes | Partial | **GAP** | Low |

**Elixir Implementation:**
```elixir
# Full aggregation support
Aggregate.over_all(client, "Article", metrics: [:count])

Aggregate.over_all(client, "Product",
  properties: [
    {:price, [:sum, :mean, :maximum, :minimum]},
    {:category, [:topOccurrences], limit: 5}
  ]
)

Aggregate.with_near_text(client, "Article", "AI", metrics: [:count])
Aggregate.group_by(client, "Article", "category", metrics: [:count])
```

**Status: COMPLETE**

---

## 6. Group By

| Feature | Python | Elixir | Gap | Criticality |
|---------|--------|--------|-----|-------------|
| Group by property | Yes | Yes | - | - |
| objects_per_group | Yes | Yes | - | - |
| number_of_groups | Yes | Yes | - | - |
| Nested property path | Yes | Yes | - | - |

**Elixir Implementation:**
```elixir
alias WeaviateEx.Query.GroupBy

group_by = GroupBy.new("category", objects_per_group: 5, number_of_groups: 20)
Query.get("Article")
|> Query.group_by(group_by)
```

**Status: COMPLETE**

---

## 7. Sorting

| Feature | Python | Elixir | Gap | Criticality |
|---------|--------|--------|-----|-------------|
| Sort by property | Yes | Yes | - | - |
| Sort by ID | Yes | Yes | - | - |
| Sort by creation time | Yes | Yes | - | - |
| Sort by update time | Yes | Yes | - | - |
| Multiple sort criteria | Yes | Yes | - | - |
| Ascending/Descending | Yes | Yes | - | - |

**Elixir Implementation:**
```elixir
alias WeaviateEx.Query.Sort

Sort.by_property("title", :desc)
|> Sort.then_by_property("createdAt", :asc)
```

**Status: COMPLETE**

---

## 8. Metadata Returns

| Feature | Python | Elixir | Gap | Criticality |
|---------|--------|--------|-----|-------------|
| id/uuid | Yes | Yes | - | - |
| distance | Yes | Yes | - | - |
| certainty | Yes | Yes | - | - |
| score | Yes | Yes | - | - |
| explainScore | Yes | Yes | - | - |
| creationTimeUnix | Yes | Yes | - | - |
| lastUpdateTimeUnix | Yes | Yes | - | - |
| isConsistent | Yes | Yes | - | - |
| vector | Yes | Yes | - | - |
| vectors (named) | Yes | No | **GAP** | Low |
| MetadataQuery.full() | Yes | Yes | - | - |

**Elixir Implementation:**
```elixir
alias WeaviateEx.Query.Metadata

# Full metadata
Query.get("Article")
|> Query.return_metadata(Metadata.full())

# Common metadata
Query.get("Article")
|> Query.return_metadata(Metadata.common())
```

---

## 9. Generative/RAG

| Feature | Python | Elixir | Gap | Criticality |
|---------|--------|--------|-----|-------------|
| Single prompt generation | Yes | Yes | - | - |
| Grouped task generation | Yes | Yes | - | - |
| Grouped properties | Yes | Partial | **GAP** | Low |
| Generative in search query | Yes | No | **GAP** | High |
| Provider runtime config | Yes | Yes | - | - |
| 20+ AI providers | Yes | Yes | - | - |

**Python Implementation (Integrated):**
```python
# Generation integrated with search
response = collection.generate.near_text(
    query="artificial intelligence",
    single_prompt="Summarize this: {content}",
    grouped_task="What are the main themes?",
    grouped_properties=["title", "content"],
    limit=5
)
```

**Elixir Implementation (Separate):**
```elixir
# Separate API module
Generative.single_prompt(client, "Article",
  "Summarize: {title}",
  provider: :openai,
  near_text: "artificial intelligence"
)

# Not integrated into query builder like Python
```

**Gap Details:**
The Python client has `collection.generate.near_text()`, `collection.generate.hybrid()`, etc. that combine search + generation in a single call. The Elixir implementation requires separate calls to search and then generate.

---

## 10. Reranking

| Feature | Python | Elixir | Gap | Criticality |
|---------|--------|--------|-----|-------------|
| Basic rerank | Yes | Yes | - | - |
| Rerank with custom query | Yes | Yes | - | - |
| Rerank property selection | Yes | Yes | - | - |
| Rerank score in metadata | Yes | Yes | - | - |

**Elixir Implementation:**
```elixir
alias WeaviateEx.Query.Rerank

rerank = Rerank.new("content", query: "What is machine learning?")
Query.get("Article")
|> Query.near_text("AI")
|> Query.rerank(rerank)
```

**Status: COMPLETE**

---

## 11. Cursor/Pagination

| Feature | Python | Elixir | Gap | Criticality |
|---------|--------|--------|-----|-------------|
| limit | Yes | Yes | - | - |
| offset | Yes | Yes | - | - |
| after (cursor) | Yes | Yes | - | - |
| Iterator class | Yes | Yes | - | - |
| Async iterator | Yes | No | **GAP** | Low |
| Iterator with filter | Yes | Yes | - | - |
| Iterator with include_vector | Yes | Yes | - | - |
| Iterator cache size | Yes | Yes | - | - |
| Stream support | No (Python iter) | Yes | +Elixir | - |

**Python Implementation:**
```python
# Iterator pattern
for obj in collection.iterator(include_vector=True):
    process(obj)

# Async iterator
async for obj in collection.iterator():
    await process(obj)
```

**Elixir Implementation:**
```elixir
# Iterator with stream support (Elixir advantage)
Iterator.new(client, "Article", batch_size: 100)
|> Iterator.stream()
|> Stream.take(500)
|> Enum.to_list()

# Manual iteration
{:ok, {objects, next_iterator}} = Iterator.next_batch(iterator)
```

**Note:** Elixir's Stream integration is actually more idiomatic and powerful than Python's iterator pattern for functional programming use cases.

---

## Summary: Critical Gaps

### Critical Priority

| Gap | Description | Impact |
|-----|-------------|--------|
| Generative in search | Generate API not integrated with search queries | Users must make two API calls |
| Multi-vector queries | No NearVector.list_of_vectors() support | Cannot do multi-query vector search |

### High Priority

| Gap | Description | Impact |
|-----|-------------|--------|
| Multi-target vector joins | TargetVectors not fully integrated | Named vector collections limited |
| 2D vector support | No multi-vector embedding model support | Cannot use colBERT-style models |

### Medium Priority

| Gap | Description | Impact |
|-----|-------------|--------|
| Multi-target reference filters | Cannot filter through multi-target refs | Complex reference queries limited |
| Property length filter | Cannot filter by text length | Some text filtering use cases affected |

### Low Priority

| Gap | Description | Impact |
|-----|-------------|--------|
| File path support for media | Must pass base64, not file path | Minor convenience |
| Async iterator | Elixir has streams instead | Different paradigm, not truly missing |
| Named vectors in metadata | Cannot return specific named vectors | Rarely needed |

---

## Recommendations

### Phase 1: Critical (Next Release)

1. **Integrate Generative with Query Builder**
   - Add `Query.generate/3` function
   - Support `single_prompt` and `grouped_task` in query struct
   - Execute combined search+generate via gRPC

2. **Multi-vector Query Support**
   - Add `NearVector.list_of_vectors/1` function
   - Update gRPC serialization for vector lists

### Phase 2: High Priority

3. **Complete TargetVectors Integration**
   - Wire `TargetVectors` into query execution
   - Add to all near_* functions

4. **2D Vector Support**
   - Extend vector types for nested vector arrays
   - Update gRPC serialization

### Phase 3: Medium Priority

5. **Advanced Filter Operators**
   - Add `by_property(name, length: true)` support
   - Add `by_ref_multi_target/3` filter

---

## Appendix: File Locations

### Python Reference Files

- `/weaviate-python-client/weaviate/collections/queries/near_vector/query/executor.py`
- `/weaviate-python-client/weaviate/collections/queries/near_text/query/executor.py`
- `/weaviate-python-client/weaviate/collections/queries/hybrid/query/executor.py`
- `/weaviate-python-client/weaviate/collections/queries/bm25/query/executor.py`
- `/weaviate-python-client/weaviate/collections/classes/filters.py`
- `/weaviate-python-client/weaviate/collections/classes/grpc.py`
- `/weaviate-python-client/weaviate/collections/generate.py`
- `/weaviate-python-client/weaviate/collections/iterator.py`

### Elixir Implementation Files

- `/lib/weaviate_ex/query.ex` - Main query builder
- `/lib/weaviate_ex/api/query_advanced.ex` - Media search
- `/lib/weaviate_ex/filter.ex` - Filter system
- `/lib/weaviate_ex/api/aggregate.ex` - Aggregations
- `/lib/weaviate_ex/api/generative.ex` - RAG/Generation
- `/lib/weaviate_ex/iterator.ex` - Cursor pagination
- `/lib/weaviate_ex/query/rerank.ex` - Reranking
- `/lib/weaviate_ex/query/group_by.ex` - GroupBy
- `/lib/weaviate_ex/query/sort.ex` - Sorting
- `/lib/weaviate_ex/query/metadata.ex` - Metadata selection
- `/lib/weaviate_ex/query/bm25_operator.ex` - BM25 operators
- `/lib/weaviate_ex/query/target_vectors.ex` - Target vectors
- `/lib/weaviate_ex/query/hybrid_vector.ex` - Hybrid sub-search
- `/lib/weaviate_ex/query/move.ex` - Move operations
