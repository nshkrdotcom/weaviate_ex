# Query/Search Gap Analysis: Python vs Elixir Weaviate Client

**Date**: 2025-12-28
**Analysis Version**: 1.0
**Python Client Version**: Latest (weaviate-python-client)
**Elixir Client Version**: WeaviateEx (current master)

---

## Executive Summary

The Elixir WeaviateEx client has foundational query capabilities but is **significantly behind** the Python client in terms of feature completeness. The Python client offers a mature, production-ready query API with gRPC support, comprehensive filter operations, advanced search configurations, and streaming/iterator patterns. The Elixir client currently relies on GraphQL and lacks many advanced features.

### Critical Gaps (Blocking Production Use)
- **No gRPC support** - All queries go through GraphQL (slower, less efficient)
- **Missing Rerank configuration** - Cannot use reranking modules
- **No Iterator/Cursor support** - Cannot efficiently iterate large result sets
- **Incomplete Filter System** - Missing several operators and filter types
- **No Consistency Level support** in queries
- **No Tenant specification** in queries

### High Priority Gaps
- Incomplete near_text options (move_to, move_away)
- Missing auto_limit (autocut) support
- No target_vector support for named vector configurations
- No BM25 operator options (AND/OR with minimum match)
- Missing hybrid vector sub-search configurations
- No return_references with nested traversal
- Limited metadata selection

---

## Detailed Comparison Table

### Vector Search Operations

| Feature | Python Client | Elixir Client | Gap Status |
|---------|--------------|---------------|------------|
| near_text basic | Yes | Yes | Implemented |
| near_text with certainty/distance | Yes | Yes | Implemented |
| near_text with move_to/move_away | Yes | No | **MISSING** |
| near_vector basic | Yes | Yes | Implemented |
| near_vector with named vectors | Yes | No | **MISSING** |
| near_vector with list of vectors | Yes | No | **MISSING** |
| near_object basic | Yes | Yes | Implemented |
| near_object with target_vector | Yes | No | **MISSING** |
| near_image | Yes | Partial | Fields only |
| near_media (audio/video/depth/thermal/imu) | Yes | Partial | Basic only |
| Auto-limit (autocut) | Yes | No | **MISSING** |

### Hybrid Search

| Feature | Python Client | Elixir Client | Gap Status |
|---------|--------------|---------------|------------|
| Basic hybrid query | Yes | Yes | Implemented |
| Alpha parameter | Yes | Yes | Implemented |
| Fusion type | Yes | Yes | Implemented |
| query_properties | Yes | No | **MISSING** |
| vector sub-search | Yes | No | **MISSING** |
| near_text sub-search | Yes | No | **MISSING** |
| max_vector_distance | Yes | No | **MISSING** |
| BM25 operator (AND/OR) | Yes | No | **MISSING** |

### BM25 Keyword Search

| Feature | Python Client | Elixir Client | Gap Status |
|---------|--------------|---------------|------------|
| Basic BM25 | Yes | Yes | Implemented |
| query_properties | Yes | Partial | Limited |
| Operator (AND/OR) | Yes | No | **MISSING** |
| minimum_should_match | Yes | No | **MISSING** |

### Filter Operations

| Feature | Python Client | Elixir Client | Gap Status |
|---------|--------------|---------------|------------|
| Equal | Yes | Yes | Implemented |
| NotEqual | Yes | Yes | Implemented |
| LessThan | Yes | Yes | Implemented |
| LessThanEqual | Yes | Yes | Implemented |
| GreaterThan | Yes | Yes | Implemented |
| GreaterThanEqual | Yes | Yes | Implemented |
| Like (wildcards) | Yes | Yes | Implemented |
| IsNull | Yes | Yes | Implemented |
| ContainsAny | Yes | Yes | Implemented |
| ContainsAll | Yes | Yes | Implemented |
| **ContainsNone** | Yes | No | **MISSING** |
| WithinGeoRange | Yes | Yes | Implemented |
| Filter by ID | Yes | Yes | Implemented |
| Filter by creation time | Yes | No | **MISSING** |
| Filter by update time | Yes | No | **MISSING** |
| Filter by reference | Yes | Partial | Basic only |
| Filter by reference count | Yes | No | **MISSING** |
| Filter by multi-target reference | Yes | No | **MISSING** |
| Length-based filtering | Yes | No | **MISSING** |
| Nested filters (AND/OR/NOT) | Yes | Yes | Implemented |
| Bitwise operators (&, |, ~) | Yes | No | **MISSING** |

### Query Options

| Feature | Python Client | Elixir Client | Gap Status |
|---------|--------------|---------------|------------|
| limit | Yes | Yes | Implemented |
| offset | Yes | Yes | Implemented |
| after (cursor) | Yes | No | **MISSING** |
| filters | Yes | Yes | Implemented |
| group_by | Yes | Partial | Basic only |
| rerank | Yes | No | **MISSING** |
| target_vector | Yes | No | **MISSING** |
| include_vector | Yes | Partial | Limited |
| return_metadata | Yes | Partial | Limited |
| return_properties | Yes | Yes | Implemented |
| return_references | Yes | No | **MISSING** |
| consistency_level | Yes | No | **MISSING** |
| tenant | Yes | No | **MISSING** |
| sort | Yes | Partial | Basic only |

### Metadata Selection

| Feature | Python Client | Elixir Client | Gap Status |
|---------|--------------|---------------|------------|
| creation_time | Yes | Yes | Via _additional |
| last_update_time | Yes | Yes | Via _additional |
| distance | Yes | Yes | Via _additional |
| certainty | Yes | Yes | Via _additional |
| score | Yes | Yes | Via _additional |
| explain_score | Yes | No | **MISSING** |
| is_consistent | Yes | No | **MISSING** |
| rerank_score | Yes | No | **MISSING** |
| MetadataQuery.full() | Yes | No | **MISSING** |

### GroupBy Operations

| Feature | Python Client | Elixir Client | Gap Status |
|---------|--------------|---------------|------------|
| Basic group_by | Yes | Partial | Basic only |
| objects_per_group | Yes | Partial | Limited |
| number_of_groups | Yes | Partial | Limited |
| GroupBy with all searches | Yes | No | **MISSING** |
| GroupByReturn objects | Yes | No | **MISSING** |

### Aggregation Queries

| Feature | Python Client | Elixir Client | Gap Status |
|---------|--------------|---------------|------------|
| over_all | Yes | Yes | Implemented |
| with_near_text | Yes | Yes | Implemented |
| with_near_vector | Yes | Yes | Implemented |
| with_near_object | Yes | No | **MISSING** |
| with_near_image | Yes | No | **MISSING** |
| with_hybrid | Yes | No | **MISSING** |
| group_by in aggregation | Yes | Yes | Implemented |
| Text metrics (topOccurrences) | Yes | Yes | Implemented |
| Numeric metrics | Yes | Yes | Implemented |
| Boolean metrics | Yes | Yes | Implemented |
| Date metrics | Yes | Partial | Limited |
| Reference metrics | Yes | No | **MISSING** |

### Iterator/Streaming

| Feature | Python Client | Elixir Client | Gap Status |
|---------|--------------|---------------|------------|
| Object iterator | Yes | No | **MISSING** |
| Async iterator | Yes | No | **MISSING** |
| Cursor-based pagination | Yes | No | **MISSING** |
| Configurable cache size | Yes | No | **MISSING** |

---

## Feature Details with Code Examples

### 1. near_text move_to/move_away (CRITICAL)

**Python Implementation:**
```python
from weaviate.classes.query import Move

response = collection.query.near_text(
    query="fashion",
    move_to=Move(force=0.5, concepts=["summer", "beach"]),
    move_away=Move(force=0.25, objects=["uuid-to-avoid"]),
    limit=10
)
```

**Proposed Elixir Implementation:**
```elixir
defmodule WeaviateEx.Query.Move do
  defstruct [:force, :concepts, :objects]

  def to(force, opts) do
    %__MODULE__{
      force: force,
      concepts: Keyword.get(opts, :concepts),
      objects: Keyword.get(opts, :objects)
    }
  end
end

# Usage
query = WeaviateEx.Query.get("Article")
  |> WeaviateEx.Query.near_text("fashion",
    move_to: Move.to(0.5, concepts: ["summer", "beach"]),
    move_away: Move.to(0.25, objects: ["uuid-to-avoid"])
  )
  |> WeaviateEx.Query.limit(10)
```

**Priority**: High - Required for semantic search refinement

---

### 2. Rerank Configuration (CRITICAL)

**Python Implementation:**
```python
from weaviate.classes.query import Rerank

response = collection.query.near_text(
    query="machine learning",
    rerank=Rerank(prop="content", query="deep learning applications"),
    limit=10
)
```

**Proposed Elixir Implementation:**
```elixir
defmodule WeaviateEx.Query.Rerank do
  defstruct [:prop, :query]

  def new(prop, opts \\ []) do
    %__MODULE__{
      prop: prop,
      query: Keyword.get(opts, :query)
    }
  end
end

# Usage
query = WeaviateEx.Query.get("Article")
  |> WeaviateEx.Query.near_text("machine learning")
  |> WeaviateEx.Query.rerank(Rerank.new("content", query: "deep learning"))
  |> WeaviateEx.Query.limit(10)
```

**Priority**: Critical - Required for production search quality

---

### 3. Iterator/Cursor for Large Result Sets (CRITICAL)

**Python Implementation:**
```python
# Iterate over all objects in a collection
for obj in collection.iterator(
    include_vector=True,
    return_properties=["title", "content"]
):
    process(obj)

# With cursor pagination
for obj in collection.iterator(after="last-uuid-seen"):
    process(obj)
```

**Proposed Elixir Implementation:**
```elixir
defmodule WeaviateEx.Iterator do
  defstruct [:collection, :client, :opts, :cursor, :cache]

  def new(client, collection, opts \\ []) do
    %__MODULE__{
      client: client,
      collection: collection,
      opts: opts,
      cursor: Keyword.get(opts, :after),
      cache: []
    }
  end

  def stream(iterator) do
    Stream.resource(
      fn -> iterator end,
      fn iter -> fetch_next_batch(iter) end,
      fn _iter -> :ok end
    )
  end
end

# Usage
WeaviateEx.Iterator.new(client, "Article",
  include_vector: true,
  return_properties: ["title", "content"]
)
|> WeaviateEx.Iterator.stream()
|> Stream.each(&process/1)
|> Stream.run()
```

**Priority**: Critical - Required for data export/migration/batch processing

---

### 4. Target Vector Support (HIGH)

**Python Implementation:**
```python
from weaviate.classes.query import TargetVectors

# Single target vector
response = collection.query.near_text(
    query="machine learning",
    target_vector="content_vector",
    limit=10
)

# Multiple target vectors with combination
response = collection.query.near_text(
    query="machine learning",
    target_vector=TargetVectors.average(["title_vector", "content_vector"]),
    limit=10
)
```

**Proposed Elixir Implementation:**
```elixir
defmodule WeaviateEx.Query.TargetVectors do
  def single(name), do: name

  def sum(vectors), do: {:sum, vectors}
  def average(vectors), do: {:average, vectors}
  def minimum(vectors), do: {:minimum, vectors}
  def manual_weights(weights), do: {:manual_weights, weights}
  def relative_score(weights), do: {:relative_score, weights}
end

# Usage
query = WeaviateEx.Query.get("Article")
  |> WeaviateEx.Query.near_text("machine learning",
    target_vector: TargetVectors.average(["title_vec", "content_vec"])
  )
```

**Priority**: High - Required for named vector collections

---

### 5. BM25 Operator Options (HIGH)

**Python Implementation:**
```python
from weaviate.classes.query import BM25OperatorFactory

# OR with minimum match
response = collection.query.bm25(
    query="machine learning AI",
    operator=BM25OperatorFactory.or_(minimum_match=2),
    limit=10
)

# AND - all tokens must match
response = collection.query.bm25(
    query="machine learning",
    operator=BM25OperatorFactory.and_(),
    limit=10
)
```

**Proposed Elixir Implementation:**
```elixir
defmodule WeaviateEx.Query.BM25Operator do
  def or_(minimum_match) do
    %{type: :or, minimum_should_match: minimum_match}
  end

  def and_() do
    %{type: :and}
  end
end

# Usage
query = WeaviateEx.Query.get("Article")
  |> WeaviateEx.Query.bm25("machine learning AI",
    operator: BM25Operator.or_(2)
  )
```

**Priority**: High - Important for keyword search tuning

---

### 6. Hybrid Vector Sub-search (HIGH)

**Python Implementation:**
```python
from weaviate.classes.query import HybridVector

# Hybrid with near_text sub-search
response = collection.query.hybrid(
    query="coffee",
    vector=HybridVector.near_text(
        query="espresso brewing",
        move_to=Move(force=0.5, concepts=["barista"])
    ),
    alpha=0.75,
    limit=10
)

# Hybrid with explicit vector
response = collection.query.hybrid(
    query="coffee",
    vector=HybridVector.near_vector(
        vector=[0.1, 0.2, ...],
        distance=0.5
    ),
    alpha=0.75
)
```

**Proposed Elixir Implementation:**
```elixir
defmodule WeaviateEx.Query.HybridVector do
  def near_text(query, opts \\ []) do
    %{
      type: :near_text,
      text: query,
      move_to: Keyword.get(opts, :move_to),
      move_away: Keyword.get(opts, :move_away),
      certainty: Keyword.get(opts, :certainty),
      distance: Keyword.get(opts, :distance)
    }
  end

  def near_vector(vector, opts \\ []) do
    %{
      type: :near_vector,
      vector: vector,
      certainty: Keyword.get(opts, :certainty),
      distance: Keyword.get(opts, :distance)
    }
  end
end

# Usage
query = WeaviateEx.Query.get("Article")
  |> WeaviateEx.Query.hybrid("coffee",
    vector: HybridVector.near_text("espresso brewing"),
    alpha: 0.75
  )
```

**Priority**: High - Advanced hybrid search control

---

### 7. ContainsNone Filter Operator (MEDIUM)

**Python Implementation:**
```python
from weaviate.classes.query import Filter

response = collection.query.fetch_objects(
    filters=Filter.by_property("tags").contains_none(["spam", "nsfw"])
)
```

**Proposed Elixir Implementation:**
```elixir
# Add to WeaviateEx.Filter module
def contains_none(property, values) when is_list(values) do
  %{
    path: [property],
    operator: :contains_none,
    value_text_array: values
  }
end
```

**Priority**: Medium - Useful for exclusion filters

---

### 8. Filter by Creation/Update Time (MEDIUM)

**Python Implementation:**
```python
from datetime import datetime
from weaviate.classes.query import Filter

# Filter by creation time
response = collection.query.fetch_objects(
    filters=Filter.by_creation_time().greater_than(datetime(2024, 1, 1))
)

# Filter by update time
response = collection.query.fetch_objects(
    filters=Filter.by_update_time().less_than(datetime.now())
)
```

**Proposed Elixir Implementation:**
```elixir
defmodule WeaviateEx.Filter do
  # Add new functions
  def by_creation_time(operator, datetime) do
    %{
      path: ["_creationTimeUnix"],
      operator: operator,
      value_date: DateTime.to_iso8601(datetime)
    }
  end

  def by_update_time(operator, datetime) do
    %{
      path: ["_lastUpdateTimeUnix"],
      operator: operator,
      value_date: DateTime.to_iso8601(datetime)
    }
  end
end

# Usage
filter = Filter.by_creation_time(:greater_than, ~U[2024-01-01 00:00:00Z])
```

**Priority**: Medium - Time-based filtering

---

### 9. Filter by Reference Count (MEDIUM)

**Python Implementation:**
```python
from weaviate.classes.query import Filter

# Objects with more than 5 references
response = collection.query.fetch_objects(
    filters=Filter.by_ref_count("hasArticles").greater_than(5)
)
```

**Proposed Elixir Implementation:**
```elixir
def by_ref_count(ref_property, operator, count) do
  %{
    path: [ref_property],
    operator: operator,
    value_int: count
    # Note: Special handling needed for count operations
  }
end
```

**Priority**: Medium - Reference cardinality filtering

---

### 10. Consistency Level in Queries (MEDIUM)

**Python Implementation:**
```python
from weaviate.classes.config import ConsistencyLevel

# Collection with consistency level
collection = client.collections.get(
    "Article",
    consistency_level=ConsistencyLevel.QUORUM
)

# Queries automatically use the consistency level
response = collection.query.near_text(...)
```

**Proposed Elixir Implementation:**
```elixir
# Add consistency_level option to query struct
defstruct [
  # ... existing fields
  consistency_level: nil  # :one, :quorum, :all
]

def consistency_level(%__MODULE__{} = query, level)
    when level in [:one, :quorum, :all] do
  %{query | consistency_level: level}
end
```

**Priority**: Medium - Required for distributed deployments

---

### 11. Tenant in Queries (MEDIUM)

**Python Implementation:**
```python
# Collection with tenant
collection = client.collections.get("Article", tenant="tenant_A")

# All queries scoped to tenant
response = collection.query.near_text("search term")
```

**Proposed Elixir Implementation:**
```elixir
# Add tenant option to query struct
defstruct [
  # ... existing fields
  tenant: nil
]

def tenant(%__MODULE__{} = query, tenant_name) do
  %{query | tenant: tenant_name}
end
```

**Priority**: Medium - Required for multi-tenant deployments

---

### 12. Return References with Traversal (MEDIUM)

**Python Implementation:**
```python
from weaviate.classes.query import QueryReference

response = collection.query.fetch_objects(
    return_references=[
        QueryReference(
            link_on="hasAuthor",
            return_properties=["name", "bio"],
            return_references=[
                QueryReference(link_on="hasPublisher")
            ]
        )
    ]
)
```

**Proposed Elixir Implementation:**
```elixir
defmodule WeaviateEx.Query.Reference do
  defstruct [:link_on, :return_properties, :return_references, :include_vector]

  def new(link_on, opts \\ []) do
    %__MODULE__{
      link_on: link_on,
      return_properties: Keyword.get(opts, :return_properties),
      return_references: Keyword.get(opts, :return_references),
      include_vector: Keyword.get(opts, :include_vector, false)
    }
  end
end

# Usage
query = WeaviateEx.Query.get("Article")
  |> WeaviateEx.Query.return_references([
    Reference.new("hasAuthor",
      return_properties: ["name", "bio"],
      return_references: [Reference.new("hasPublisher")]
    )
  ])
```

**Priority**: Medium - Graph traversal in queries

---

### 13. Sorting Operations (MEDIUM)

**Python Implementation:**
```python
from weaviate.classes.query import Sort

response = collection.query.fetch_objects(
    sort=Sort.by_property("title", ascending=True)
        .by_creation_time(ascending=False)
)
```

**Proposed Elixir Implementation:**
```elixir
defmodule WeaviateEx.Query.Sort do
  defstruct [:sorts]

  def by_property(name, ascending \\ true) do
    %__MODULE__{sorts: [%{prop: name, ascending: ascending}]}
  end

  def by_creation_time(sort, ascending \\ true) do
    add_sort(sort, %{prop: "_creationTimeUnix", ascending: ascending})
  end

  def by_update_time(sort, ascending \\ true) do
    add_sort(sort, %{prop: "_lastUpdateTimeUnix", ascending: ascending})
  end

  def by_id(sort, ascending \\ true) do
    add_sort(sort, %{prop: "_id", ascending: ascending})
  end

  defp add_sort(%__MODULE__{sorts: sorts}, new_sort) do
    %__MODULE__{sorts: sorts ++ [new_sort]}
  end
end
```

**Priority**: Medium - Result ordering

---

### 14. MetadataQuery.full() Helper (LOW)

**Python Implementation:**
```python
from weaviate.classes.query import MetadataQuery

response = collection.query.near_text(
    query="search",
    return_metadata=MetadataQuery.full()  # Returns all metadata
)
```

**Proposed Elixir Implementation:**
```elixir
defmodule WeaviateEx.Query.Metadata do
  @all_fields ["id", "creationTimeUnix", "lastUpdateTimeUnix",
               "distance", "certainty", "score", "explainScore",
               "isConsistent"]

  def full, do: @all_fields

  def select(fields) when is_list(fields), do: fields
end
```

**Priority**: Low - Convenience helper

---

### 15. GroupBy with Full Configuration (LOW)

**Python Implementation:**
```python
from weaviate.classes.query import GroupBy

response = collection.query.near_text(
    query="search",
    group_by=GroupBy(
        prop="category",
        objects_per_group=3,
        number_of_groups=5
    )
)
```

**Proposed Elixir Implementation:**
```elixir
defmodule WeaviateEx.Query.GroupBy do
  defstruct [:prop, :objects_per_group, :number_of_groups]

  def new(prop, opts \\ []) do
    %__MODULE__{
      prop: prop,
      objects_per_group: Keyword.get(opts, :objects_per_group, 10),
      number_of_groups: Keyword.get(opts, :number_of_groups, 10)
    }
  end
end
```

**Priority**: Low - Advanced grouping

---

## Priority Recommendations

### Critical (Must Have for Production)
1. **Iterator/Cursor Support** - Cannot process large datasets without this
2. **Rerank Configuration** - Core feature for search quality
3. **Consistency Level** - Required for distributed deployments
4. **Tenant Support in Queries** - Required for multi-tenant applications

### High (Important for Feature Parity)
5. **near_text move_to/move_away** - Semantic search refinement
6. **Target Vector Support** - Named vector collections
7. **BM25 Operator Options** - Keyword search tuning
8. **Hybrid Vector Sub-search** - Advanced hybrid search
9. **Auto-limit (autocut)** - Quality-based result limiting
10. **Return References** - Graph traversal

### Medium (Useful Enhancements)
11. **ContainsNone Filter** - Exclusion filtering
12. **Filter by Time** - Time-based queries
13. **Filter by Reference Count** - Cardinality filtering
14. **Complete Sorting** - Full sort options
15. **Complete Metadata Selection** - All metadata fields

### Low (Nice to Have)
16. **MetadataQuery.full()** - Convenience helper
17. **GroupBy Full Configuration** - Advanced grouping
18. **Bitwise Filter Operators** - Syntactic sugar

---

## Implementation Roadmap

### Phase 1: Critical Features (Week 1-2)
- Iterator/Cursor with Stream support
- Rerank configuration
- Consistency level in queries
- Tenant specification in queries

### Phase 2: High Priority (Week 3-4)
- near_text move_to/move_away
- Target vector support (single and multi)
- BM25 operator options
- Hybrid vector sub-search
- Auto-limit (autocut)

### Phase 3: Medium Priority (Week 5-6)
- ContainsNone filter operator
- Filter by creation/update time
- Filter by reference count
- Return references with traversal
- Complete sorting options

### Phase 4: Low Priority (Week 7+)
- MetadataQuery.full() helper
- GroupBy full configuration
- Filter by property length
- Bitwise filter operators

---

## Architecture Recommendations

### 1. Consider gRPC Migration
The Python client uses gRPC for queries which provides:
- Better performance (binary protocol)
- Streaming support
- Type safety

**Recommendation**: Plan for gRPC support using `grpc` Elixir library.

### 2. Adopt Builder Pattern Consistently
The current Elixir client uses a struct-based builder. Extend this to support:
- All search types with common options
- Composable configurations (Move, Rerank, GroupBy, etc.)
- Easy-to-use helper modules

### 3. Type Specifications
Add comprehensive typespecs for all query functions to enable:
- Dialyzer static analysis
- Better IDE support
- Documentation generation

### 4. Error Handling
Python client has specific exception types. Consider:
```elixir
defmodule WeaviateEx.QueryError do
  defexception [:type, :message, :query]
end
```

---

## Conclusion

The Elixir WeaviateEx client provides a good foundation but requires significant work to achieve feature parity with the Python client. The most critical gaps are:

1. **No iterator/streaming support** - Blocks batch operations
2. **Missing rerank** - Limits search quality optimization
3. **No multi-tenancy support** - Blocks enterprise use cases
4. **Incomplete advanced search options** - Limits fine-tuning capabilities

Following the proposed roadmap will bring the Elixir client to production readiness within 6-7 weeks of focused development.
