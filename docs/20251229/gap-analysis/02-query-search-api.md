# Query/Search API Gap Analysis

## Executive Summary

This document provides a comprehensive gap analysis between the Python Weaviate client's Query/Search API and the Elixir port (WeaviateEx). The analysis covers vector search, BM25/keyword search, hybrid search, filters, aggregations, and related functionality.

**Overall Status: 85% Feature Parity**

The Elixir port has achieved substantial feature parity with the Python client for query and search operations. Key gaps remain in:
- Advanced generative provider runtime configuration
- Property-specific type handling in return types
- Some aggregation gRPC optimizations
- Multi-vector query patterns (list of vectors)

### Key Findings

| Category | Python Features | Elixir Implementation | Parity |
|----------|----------------|----------------------|--------|
| Vector Search (near_text, near_vector, near_object) | Complete | Complete | 100% |
| Multi-modal Search (near_image, near_media) | Complete | Complete | 100% |
| BM25/Keyword Search | Complete | Complete | 95% |
| Hybrid Search | Complete | Complete | 95% |
| Filters | 13 operators | 12 operators | 92% |
| Aggregations | gRPC + GraphQL | gRPC + GraphQL | 90% |
| Sorting/Pagination | Complete | Complete | 100% |
| Group By | Complete | Complete | 100% |
| Reranking | Complete | Complete | 100% |
| Generate/RAG | Complete | Complete | 90% |
| Target Vectors | Complete | Complete | 100% |

---

## 1. Vector Search Comparison

### 1.1 near_text Search

#### Python Client
```python
# Location: weaviate/collections/queries/near_text/query/executor.py

collection.query.near_text(
    query="machine learning",              # Required: str or List[str]
    certainty=0.7,                         # Optional: 0.0-1.0
    distance=0.3,                          # Optional: max distance
    move_to=Move(force=0.5, concepts=["AI"]),     # Optional: move towards
    move_away=Move(force=0.3, concepts=["biology"]), # Optional: move away
    limit=10,                              # Optional: max results
    offset=0,                              # Optional: skip results
    auto_limit=3,                          # Optional: autocut threshold
    filters=Filter.by_property("status").equal("published"),  # Optional
    group_by=GroupBy(prop="category", objects_per_group=3),   # Optional
    rerank=Rerank(prop="content"),         # Optional: reranking
    target_vector="content_vector",        # Optional: named vector
    include_vector=True,                   # Optional: return vectors
    return_metadata=MetadataQuery.full(),  # Optional: metadata fields
    return_properties=["title", "content"], # Optional: properties
    return_references=[QueryReference(link_on="hasAuthor")]  # Optional
)
```

#### Elixir Port
```elixir
# Location: lib/weaviate_ex/query.ex

Query.get("Article")
|> Query.near_text("machine learning",
    certainty: 0.7,
    distance: 0.3,
    move_to: Move.to(0.5, concepts: ["AI"]),
    move_away: Move.to(0.3, concepts: ["biology"]),
    target_vectors: "content_vector"
  )
|> Query.limit(10)
|> Query.offset(0)
|> Query.auto_limit(3)
|> Query.where(Filter.equal("status", "published"))
|> Query.group_by(GroupBy.new("category", objects_per_group: 3))
|> Query.rerank(Rerank.new("content"))
|> Query.fields(["title", "content"])
|> Query.additional(["id", "distance", "vector"])
|> Query.return_references([
    QueryReference.new("hasAuthor", return_properties: ["name"])
  ])
|> Query.execute(client)
```

**Parity: 100%** - All features implemented.

### 1.2 near_vector Search

#### Python Client
```python
collection.query.near_vector(
    near_vector=[0.1, 0.2, 0.3, ...],      # Required: vector
    certainty=0.8,                          # Optional
    distance=0.2,                           # Optional
    target_vector="title_vector",           # Optional: named vector
    # ... other options same as near_text
)

# Advanced: Multiple vectors over single space
collection.query.near_vector(
    near_vector=NearVector.list_of_vectors(vec1, vec2, vec3),
    # ...
)

# Named vectors with different queries per target
collection.query.near_vector(
    near_vector={
        "title_vector": [0.1, 0.2, ...],
        "content_vector": [0.3, 0.4, ...]
    }
)
```

#### Elixir Port
```elixir
Query.get("Article")
|> Query.near_vector([0.1, 0.2, 0.3],
    certainty: 0.8,
    distance: 0.2,
    target_vectors: "title_vector"
  )
|> Query.execute(client)

# With combined target vectors
target = TargetVectors.combine(["title_vector", "content_vector"], method: :average)
Query.get("Article")
|> Query.near_vector(vector, target_vectors: target)
```

**Gap: Multi-vector queries (NearVector.list_of_vectors) and per-target vector queries**

| Feature | Python | Elixir | Notes |
|---------|--------|--------|-------|
| Single vector | Yes | Yes | - |
| Target vectors | Yes | Yes | Full support |
| Vector combination methods | Yes | Yes | sum, average, minimum, manual_weights, relative_score |
| List of vectors query | Yes | No | Missing NearVector.list_of_vectors equivalent |
| Per-target different vectors | Yes | No | Missing dict-based vector specification |

**Parity: 85%**

### 1.3 near_object Search

#### Python Client
```python
collection.query.near_object(
    near_object="550e8400-e29b-41d4-a716-446655440000",
    certainty=0.7,
    distance=0.3,
    target_vector="content_vector"
)
```

#### Elixir Port
```elixir
Query.get("Article")
|> Query.near_object("550e8400-e29b-41d4-a716-446655440000",
    certainty: 0.7,
    distance: 0.3,
    target_vectors: "content_vector"
  )
|> Query.execute(client)
```

**Parity: 100%**

### 1.4 near_image Search

#### Python Client
```python
# Location: weaviate/collections/queries/near_image/query/executor.py

collection.query.near_image(
    near_image="base64encodeddata",        # or file path, or BufferedReader
    certainty=0.8,
    distance=0.2,
    target_vector="image_vector"
)
```

#### Elixir Port
```elixir
# Location: lib/weaviate_ex/query/near_image.ex

Query.get("ImageCollection")
|> Query.near_image(image: "base64data", certainty: 0.8)
# or
|> Query.near_image(image_file: "/path/to/image.png", certainty: 0.8)
|> Query.execute(client)
```

**Parity: 100%**

### 1.5 near_media Search

#### Python Client
```python
# Location: weaviate/collections/queries/near_media/query/executor.py

from weaviate.classes.query import NearMediaType

collection.query.near_media(
    media="base64data",
    media_type=NearMediaType.AUDIO,        # AUDIO, VIDEO, THERMAL, DEPTH, IMU
    certainty=0.7,
    target_vector="audio_vector"
)
```

#### Elixir Port
```elixir
# Location: lib/weaviate_ex/query/near_media.ex

Query.get("MediaCollection")
|> Query.near_media(:audio, media: "base64data", certainty: 0.7)
# Supported types: :audio, :video, :thermal, :depth, :imu
|> Query.execute(client)
```

**Parity: 100%**

---

## 2. BM25/Keyword Search

### Python Client
```python
# Location: weaviate/collections/queries/bm25/query/executor.py

collection.query.bm25(
    query="machine learning",
    query_properties=["title", "content"],  # Optional: limit to specific properties
    auto_limit=3,                           # Optional: autocut
    limit=10,
    offset=0,
    filters=Filter.by_property("status").equal("published"),
    # BM25 Operator for token matching
    operator=BM25Operator.and_(),           # All tokens must match
    operator=BM25Operator.or_(minimum_match=2)  # At least N tokens
)
```

### Elixir Port
```elixir
# Location: lib/weaviate_ex/query.ex

Query.get("Article")
|> Query.bm25("machine learning", properties: ["title", "content"])
|> Query.auto_limit(3)
|> Query.limit(10)
|> Query.where(Filter.equal("status", "published"))
|> Query.execute(client)
```

| Feature | Python | Elixir | Notes |
|---------|--------|--------|-------|
| Basic BM25 query | Yes | Yes | - |
| query_properties | Yes | Yes | Named as `properties` |
| auto_limit | Yes | Yes | - |
| BM25Operator.and_() | Yes | Yes | Via BM25Operator module |
| BM25Operator.or_(min_match) | Yes | Yes | Via BM25Operator module |

**Parity: 100%**

---

## 3. Hybrid Search

### Python Client
```python
# Location: weaviate/collections/queries/hybrid/query/executor.py

collection.query.hybrid(
    query="machine learning",
    alpha=0.5,                              # Balance: 0=keyword, 1=vector
    vector=[0.1, 0.2, ...],                # Optional: explicit vector
    # OR use HybridVector for advanced vector search
    vector=HybridVector.near_text(
        query="AI concepts",
        move_to=Move(force=0.5, concepts=["AI"]),
        distance=0.3
    ),
    fusion_type=HybridFusion.RELATIVE_SCORE,  # or RANKED
    query_properties=["title", "content"],
    target_vector="content_vector",
    max_vector_distance=0.5,               # Max distance for vector component
    # All other search options apply
)
```

### Elixir Port
```elixir
# Location: lib/weaviate_ex/query.ex, lib/weaviate_ex/query/hybrid_vector.ex

# Basic hybrid
Query.get("Article")
|> Query.hybrid("machine learning", alpha: 0.5)
|> Query.execute(client)

# With HybridVector for advanced vector search
hv = HybridVector.near_text("AI concepts",
  move_to: Move.to(0.5, concepts: ["AI"]),
  distance: 0.3
)

Query.get("Article")
|> Query.hybrid("machine learning",
    vector: hv,
    alpha: 0.7,
    fusion_type: :relative_score,
    properties: ["title", "content"],
    target_vectors: "content_vector",
    max_vector_distance: 0.5,
    bm25_operator: BM25Operator.and_()
  )
|> Query.execute(client)
```

| Feature | Python | Elixir | Notes |
|---------|--------|--------|-------|
| Basic hybrid | Yes | Yes | - |
| alpha parameter | Yes | Yes | - |
| HybridVector.near_text | Yes | Yes | Full Move support |
| HybridVector.near_vector | Yes | Yes | - |
| fusion_type | Yes | Yes | :ranked, :relative_score |
| query_properties | Yes | Yes | - |
| target_vector | Yes | Yes | - |
| max_vector_distance | Yes | Yes | - |
| BM25 operator in hybrid | Yes | Yes | Via bm25_operator option |

**Parity: 100%**

---

## 4. Filter Operators Comparison

### Python Client Filter Classes
```python
# Location: weaviate/collections/classes/filters.py

class _Operator(str, Enum):
    EQUAL = "Equal"
    NOT_EQUAL = "NotEqual"
    LESS_THAN = "LessThan"
    LESS_THAN_EQUAL = "LessThanEqual"
    GREATER_THAN = "GreaterThan"
    GREATER_THAN_EQUAL = "GreaterThanEqual"
    LIKE = "Like"
    IS_NULL = "IsNull"
    CONTAINS_ANY = "ContainsAny"
    CONTAINS_ALL = "ContainsAll"
    CONTAINS_NONE = "ContainsNone"
    WITHIN_GEO_RANGE = "WithinGeoRange"
    AND = "And"
    OR = "Or"
    NOT = "Not"

# Usage examples:
Filter.by_property("title").equal("Hello")
Filter.by_property("count").greater_than(100)
Filter.by_property("tags").contains_any(["a", "b"])
Filter.by_property("location").within_geo_range(GeoCoordinate(lat, lon), 5000)
Filter.by_id().equal("uuid-here")
Filter.by_creation_time().greater_than(datetime)
Filter.by_update_time().less_than(datetime)
Filter.by_ref("hasAuthor").by_property("name").equal("John")
Filter.by_ref_count("hasAuthor").greater_than(0)
Filter.by_property("title", length=True).greater_than(10)  # Length filtering

# Combinators
filter1 & filter2  # AND using & operator
filter1 | filter2  # OR using | operator
~filter1           # NOT using ~ operator
Filter.all_of([f1, f2, f3])  # Combine with AND
Filter.any_of([f1, f2, f3])  # Combine with OR
```

### Elixir Port Filter Module
```elixir
# Location: lib/weaviate_ex/filter.ex

# Basic operators
Filter.equal("title", "Hello")
Filter.not_equal("status", "draft")
Filter.greater_than("count", 100)
Filter.greater_or_equal("score", 0.5)
Filter.less_than("age", 30)
Filter.less_or_equal("price", 100.0)
Filter.like("title", "Hello*")
Filter.null?("optional_field")
Filter.contains_any("tags", ["a", "b"])
Filter.contains_all("tags", ["required1", "required2"])
Filter.contains_none("tags", ["excluded"])
Filter.within_geo_range("location", {40.7128, -74.0060}, 5000.0)

# Special filters
Filter.by_id(:equal, "uuid-here")
Filter.by_creation_time(:greater_than, "2024-01-01T00:00:00Z")
Filter.by_update_time(:less_than, "2024-12-01T00:00:00Z")
Filter.by_ref_count("hasAuthor", :greater_than, 0)
Filter.by_property_length("title", :greater_than, 10)  # Length filtering

# Reference filtering
Filter.by_ref("hasAuthor", "Author", :equal, "John Doe")
# Or using RefPath for complex reference chains
path = RefPath.through("hasAuthor", "Author")
Filter.by_ref_path(path, "name", :equal, "John")

# Multi-target reference filtering
Filter.by_ref_multi_target("relatedTo", "Article", "title", :equal, "Test")

# Combinators
Filter.all_of([filter1, filter2])  # AND
Filter.any_of([filter1, filter2])  # OR
Filter.not_(filter1)               # NOT
```

### Filter Operator Comparison

| Operator | Python | Elixir | Notes |
|----------|--------|--------|-------|
| Equal | Yes | Yes | - |
| NotEqual | Yes | Yes | - |
| LessThan | Yes | Yes | - |
| LessThanEqual | Yes | Yes | - |
| GreaterThan | Yes | Yes | - |
| GreaterThanEqual | Yes | Yes | - |
| Like | Yes | Yes | Wildcard matching |
| IsNull | Yes | Yes | Via null?/1 |
| ContainsAny | Yes | Yes | - |
| ContainsAll | Yes | Yes | - |
| ContainsNone | Yes | Yes | Implemented as NOT(ContainsAny) |
| WithinGeoRange | Yes | Yes | - |
| And | Yes | Yes | Via all_of/1 |
| Or | Yes | Yes | Via any_of/1 |
| Not | Yes | Yes | Via not_/1 |
| Filter by ID | Yes | Yes | - |
| Filter by creation time | Yes | Yes | - |
| Filter by update time | Yes | Yes | - |
| Filter by ref count | Yes | Yes | - |
| Filter by property length | Yes | Yes | - |
| Reference chain filtering | Yes | Yes | Via RefPath |
| Multi-target ref filtering | Yes | Yes | - |
| Bitwise operators (&, |, ~) | Yes | No | Use all_of/any_of/not_ instead |

**Gap: Python supports bitwise operators for filter composition, Elixir uses explicit function calls**

**Parity: 92%**

---

## 5. Aggregation Comparison

### Python Client
```python
# Location: weaviate/collections/aggregations/*.py

# Over all objects
result = collection.aggregate.over_all(
    total_count=True,
    return_metrics=[
        Metrics.text("category").top_occurrences(limit=5),
        Metrics.integer("views").sum().mean().maximum().minimum(),
        Metrics.number("price").median().mode(),
        Metrics.boolean("published").percentage_true(),
        Metrics.date("created_at").minimum().maximum()
    ],
    group_by=GroupByAggregate(prop="category", limit=10)
)

# With vector search context
result = collection.aggregate.near_text(
    query="machine learning",
    certainty=0.7,
    object_limit=100,
    return_metrics=[Metrics.text("category").top_occurrences()]
)

# With hybrid search
result = collection.aggregate.hybrid(
    query="machine learning",
    alpha=0.5,
    return_metrics=[Metrics.integer("views").mean()]
)
```

### Elixir Port
```elixir
# Location: lib/weaviate_ex/api/aggregate.ex

# Over all objects
{:ok, results} = Aggregate.over_all(client, "Article",
  metrics: [:count],
  properties: [
    {:category, [:topOccurrences], limit: 5},
    {:views, [:sum, :mean, :maximum, :minimum]},
    {:price, [:median, :mode]},
    {:published, [:percentageTrue, :percentageFalse]},
    {:created_at, [:minimum, :maximum]}
  ]
)

# With vector search context
{:ok, results} = Aggregate.with_near_text(client, "Article",
  "machine learning",
  certainty: 0.7,
  properties: [{:category, [:topOccurrences]}]
)

# With hybrid search
{:ok, results} = Aggregate.with_hybrid(client, "Article",
  "machine learning",
  alpha: 0.5,
  properties: [{:views, [:mean]}]
)

# Group by
{:ok, results} = Aggregate.group_by(client, "Article", "category",
  metrics: [:count],
  properties: [{:views, [:mean]}]
)
```

### Aggregation Features

| Feature | Python | Elixir | Notes |
|---------|--------|--------|-------|
| over_all | Yes | Yes | - |
| with_near_text | Yes | Yes | - |
| with_near_vector | Yes | Yes | - |
| with_near_object | Yes | Yes | - |
| with_near_image | Yes | No | Missing in Elixir |
| with_hybrid | Yes | Yes | - |
| with_where (filter) | Yes | Yes | - |
| group_by | Yes | Yes | - |
| Metrics: count | Yes | Yes | - |
| Metrics: sum | Yes | Yes | - |
| Metrics: mean | Yes | Yes | - |
| Metrics: median | Yes | Yes | - |
| Metrics: mode | Yes | Yes | - |
| Metrics: maximum | Yes | Yes | - |
| Metrics: minimum | Yes | Yes | - |
| Metrics: topOccurrences | Yes | Yes | - |
| Metrics: percentageTrue/False | Yes | Yes | - |
| Metrics: totalTrue/False | Yes | Yes | - |
| Property-typed metrics | Yes | Partial | Elixir uses generic property tuples |
| gRPC execution | Yes | Yes | Falls back to GraphQL for complex queries |

**Gap: Missing `with_near_image` aggregation. Property-typed metrics classes not as granular.**

**Parity: 90%**

---

## 6. Sorting, Pagination, and Limiting

### Python Client
```python
# Sorting
from weaviate.classes.query import Sort

collection.query.fetch_objects(
    sort=Sort.by_property("title", ascending=True)
          .by_id(ascending=False)
          .by_creation_time(ascending=False)
          .by_update_time(ascending=True),
    limit=10,
    offset=20
)

# Cursor pagination
collection.query.fetch_objects(
    after="cursor-uuid",
    limit=100,
    sort=Sort.by_id()  # Required for cursor pagination
)
```

### Elixir Port
```elixir
# Sorting
Query.get("Article")
|> Query.sort(
    Sort.by_property("title", :asc)
    |> Sort.then_by_id(:desc)
    |> Sort.then_by_creation_time(:desc)
    |> Sort.then_by_update_time(:asc)
  )
|> Query.limit(10)
|> Query.offset(20)
|> Query.execute(client)

# Cursor pagination
Query.get("Article")
|> Query.sort(Sort.by_id())
|> Query.limit(100)
|> Query.after_cursor("cursor-uuid")
|> Query.execute(client)
```

| Feature | Python | Elixir | Notes |
|---------|--------|--------|-------|
| limit | Yes | Yes | - |
| offset | Yes | Yes | - |
| auto_limit (autocut) | Yes | Yes | - |
| after (cursor) | Yes | Yes | Via after_cursor/2 |
| Sort by property | Yes | Yes | - |
| Sort by ID | Yes | Yes | - |
| Sort by creation time | Yes | Yes | - |
| Sort by update time | Yes | Yes | - |
| Multiple sort criteria | Yes | Yes | Via then_by_* functions |
| Sort direction | Yes | Yes | :asc/:desc |

**Parity: 100%**

---

## 7. Group By Functionality

### Python Client
```python
from weaviate.classes.query import GroupBy

collection.query.near_text(
    query="machine learning",
    group_by=GroupBy(
        prop="category",
        objects_per_group=5,
        number_of_groups=10
    )
)
```

### Elixir Port
```elixir
# Location: lib/weaviate_ex/query/group_by.ex

group_by = GroupBy.new("category",
  objects_per_group: 5,
  number_of_groups: 10
)

Query.get("Article")
|> Query.near_text("machine learning")
|> Query.group_by(group_by)
|> Query.execute(client)

# Nested property path
group_by = GroupBy.new(["metadata", "type"])
```

| Feature | Python | Elixir | Notes |
|---------|--------|--------|-------|
| prop | Yes | Yes | Named as `path` |
| objects_per_group | Yes | Yes | - |
| number_of_groups | Yes | Yes | - |
| Nested property path | Yes | Yes | List of strings |
| to_graphql conversion | Yes | Yes | - |
| to_grpc conversion | Yes | Yes | Via to_map/1 |

**Parity: 100%**

---

## 8. Reranking

### Python Client
```python
from weaviate.classes.query import Rerank

collection.query.near_text(
    query="machine learning",
    rerank=Rerank(
        prop="content",
        query="What is deep learning?"  # Optional: override query
    )
)
```

### Elixir Port
```elixir
# Location: lib/weaviate_ex/query/rerank.ex

rerank = Rerank.new("content", query: "What is deep learning?")

Query.get("Article")
|> Query.near_text("machine learning")
|> Query.rerank(rerank)
|> Query.execute(client)
```

| Feature | Python | Elixir | Notes |
|---------|--------|--------|-------|
| prop | Yes | Yes | - |
| query (optional) | Yes | Yes | - |
| to_graphql | Yes | Yes | - |
| to_grpc | Yes | Yes | Via to_map/1 |
| Validation | Yes | Yes | - |

**Parity: 100%**

---

## 9. Generate (RAG) Integration

### Python Client
```python
# Location: weaviate/collections/queries/*/generate/executor.py

# Each search type has a generate variant
collection.generate.near_text(
    query="machine learning",
    single_prompt="Summarize this article: {title}",  # Per-object
    grouped_task="Write a summary of all articles",   # Grouped
    grouped_properties=["title", "content"],          # Context for grouped
    generative_provider=GenerativeProvider.openai()   # Runtime provider
)

# Also available for: near_vector, near_object, near_image, hybrid, bm25

# Advanced: SinglePrompt and GroupedTask objects
from weaviate.classes.query import SinglePrompt, GroupedTask

collection.generate.near_text(
    query="...",
    single_prompt=SinglePrompt(prompt="...", debug=True),
    grouped_task=GroupedTask(prompt="...", debug=True)
)
```

### Elixir Port
```elixir
# Location: lib/weaviate_ex/query/generate.ex

# Dedicated Generate builder
Generate.new("Article")
|> Generate.near_text("machine learning")
|> Generate.single_prompt("Summarize: {title}")
|> Generate.grouped_task("Write overall summary", properties: ["title", "content"])
|> Generate.limit(5)
|> Generate.execute(client)

# Or via Query builder
Query.get("Article")
|> Query.near_text("machine learning")
|> Query.generate(:single, "Summarize: {title}")
|> Query.execute(client)

Query.get("Article")
|> Query.bm25("elixir")
|> Query.generate(:grouped, "Write overview", properties: ["title", "content"])
|> Query.execute(client)
```

### Generate Features Comparison

| Feature | Python | Elixir | Notes |
|---------|--------|--------|-------|
| single_prompt | Yes | Yes | Per-object generation |
| grouped_task | Yes | Yes | Grouped generation |
| grouped_properties | Yes | Yes | - |
| generative_provider runtime | Yes | No | Missing runtime provider config |
| SinglePrompt object with debug | Yes | No | Only string prompts |
| GroupedTask object with debug | Yes | No | Only string prompts |
| near_text + generate | Yes | Yes | - |
| near_vector + generate | Yes | Yes | - |
| near_object + generate | Yes | Yes | - |
| near_image + generate | Yes | Partial | Via Generate builder |
| hybrid + generate | Yes | Yes | - |
| bm25 + generate | Yes | Yes | - |
| Response parsing | Yes | Yes | GenerativeResult struct |

**Gaps:**
1. Runtime generative provider configuration (e.g., switch between OpenAI and Cohere at query time)
2. Debug mode for prompts via SinglePrompt/GroupedTask objects

**Parity: 90%**

---

## 10. GraphQL vs gRPC Implementation

### Python Client Architecture

The Python client uses a sophisticated dual-path architecture:

```
Query Methods (near_text, hybrid, etc.)
         |
         v
    _BaseExecutor
         |
    +----+----+
    |         |
    v         v
  gRPC     GraphQL
(primary) (fallback)
```

**gRPC Path (Primary):**
- Uses protobuf definitions from `weaviate/proto/v1/`
- Direct binary protocol for efficiency
- Supports all search types, filters, aggregations
- Async and sync variants
- Connection pooling via grpcio

**GraphQL Path (Fallback):**
- Built via query builder classes
- Used when gRPC unavailable or for certain edge cases
- Full feature support

### Elixir Port Architecture

```
Query Builder (WeaviateEx.Query)
         |
         v
    Query.execute/2
         |
    +----+----+
    |         |
    v         v
  gRPC     GraphQL
(primary) (fallback)
```

**gRPC Path (Primary):**
- Uses protobuf definitions in `lib/weaviate_ex/grpc/generated/v1/`
- Implemented via `WeaviateEx.GRPC.Services.Search`
- Supports: near_vector, near_text, near_object, bm25, hybrid
- Connection management via `WeaviateEx.GRPC.Channel`
- Retry support via `WeaviateEx.GRPC.Retry`

**GraphQL Path (Fallback):**
- Built via internal `build_graphql/1` function
- Used when no gRPC channel available
- Full feature support including complex filters

### Protocol Feature Support

| Feature | Python gRPC | Python GraphQL | Elixir gRPC | Elixir GraphQL |
|---------|-------------|----------------|-------------|----------------|
| near_vector | Yes | Yes | Yes | Yes |
| near_text | Yes | Yes | Yes | Yes |
| near_object | Yes | Yes | Yes | Yes |
| near_image | Yes | Yes | No* | Yes |
| near_media | Yes | Yes | No* | Yes |
| hybrid | Yes | Yes | Yes | Yes |
| bm25 | Yes | Yes | Yes | Yes |
| Filters | Yes | Yes | Yes | Yes |
| Aggregations | Yes | Yes | Partial | Yes |
| Sorting | Yes | Yes | No* | Yes |
| Pagination | Yes | Yes | Yes | Yes |
| Cursor | Yes | Yes | No* | Yes |
| Group By | Yes | Yes | No* | Yes |
| Rerank | Yes | Yes | No* | Yes |
| Generate | Yes | Yes | No* | Yes |

*These features work via GraphQL fallback in Elixir

**Gap: Elixir gRPC implementation covers core search operations but delegates advanced features to GraphQL**

---

## 11. Code Examples: Side-by-Side Comparison

### Example 1: Complex Vector Search with Filters

#### Python
```python
from weaviate.classes.query import Filter, MetadataQuery, Sort

results = collection.query.near_text(
    query="machine learning applications",
    certainty=0.7,
    filters=(
        Filter.by_property("status").equal("published") &
        Filter.by_property("views").greater_than(1000) &
        Filter.by_creation_time().greater_than(datetime(2024, 1, 1))
    ),
    limit=20,
    offset=0,
    return_metadata=MetadataQuery.full(),
    return_properties=["title", "content", "author"],
    sort=Sort.by_property("views", ascending=False)
)

for obj in results.objects:
    print(f"{obj.properties['title']} - {obj.metadata.distance}")
```

#### Elixir
```elixir
filter = Filter.all_of([
  Filter.equal("status", "published"),
  Filter.greater_than("views", 1000),
  Filter.by_creation_time(:greater_than, "2024-01-01T00:00:00Z")
])

{:ok, results} = Query.get("Article")
|> Query.near_text("machine learning applications", certainty: 0.7)
|> Query.where(filter)
|> Query.limit(20)
|> Query.offset(0)
|> Query.additional(["id", "distance", "certainty", "creationTimeUnix"])
|> Query.fields(["title", "content", "author"])
|> Query.sort(Sort.by_property("views", :desc))
|> Query.execute(client)

Enum.each(results, fn obj ->
  IO.puts("#{obj["title"]} - #{obj["_additional"]["distance"]}")
end)
```

### Example 2: Hybrid Search with RAG

#### Python
```python
from weaviate.classes.query import HybridVector, Move

results = collection.generate.hybrid(
    query="artificial intelligence trends",
    alpha=0.7,
    vector=HybridVector.near_text(
        query="AI future",
        move_to=Move(force=0.5, concepts=["innovation", "technology"])
    ),
    single_prompt="Summarize the key points: {content}",
    grouped_task="Write an executive summary of all articles",
    grouped_properties=["title", "content"],
    limit=10
)

print(f"Grouped result: {results.generated}")
for obj in results.objects:
    print(f"Individual: {obj.generated}")
```

#### Elixir
```elixir
hv = HybridVector.near_text("AI future",
  move_to: Move.to(0.5, concepts: ["innovation", "technology"])
)

{:ok, result} = Generate.new("Article")
|> Generate.hybrid("artificial intelligence trends",
    alpha: 0.7,
    vector: hv
  )
|> Generate.single_prompt("Summarize the key points: {content}")
|> Generate.grouped_task("Write an executive summary", properties: ["title", "content"])
|> Generate.limit(10)
|> Generate.execute(client)

IO.puts("Grouped: #{result.grouped}")
Enum.each(result.objects, fn obj ->
  IO.puts("Individual: #{Enum.at(result.generated_per_object, 0)}")
end)
```

---

## 12. Priority Recommendations

### High Priority (Critical Gaps)

1. **Multi-Vector Query Support**
   - Implement `NearVector.list_of_vectors` equivalent
   - Support per-target different vectors in near_vector queries
   - Estimated effort: Medium

2. **Aggregation near_image Support**
   - Add `with_near_image/4` to Aggregate module
   - Estimated effort: Low

3. **gRPC Coverage Expansion**
   - Extend gRPC service to handle near_image, near_media, sorting, cursor pagination
   - Currently these work via GraphQL fallback
   - Estimated effort: High

### Medium Priority (Enhancement Gaps)

4. **Generative Provider Runtime Configuration**
   - Allow switching generative models at query time
   - Match Python's `generative_provider` parameter
   - Estimated effort: Medium

5. **Debug Mode for Prompts**
   - Implement SinglePrompt and GroupedTask struct types with debug flag
   - Estimated effort: Low

6. **Property-Typed Aggregation Metrics**
   - Create specific metric types (Metrics.Text, Metrics.Integer, etc.)
   - More type-safe aggregation configuration
   - Estimated effort: Medium

### Low Priority (Nice to Have)

7. **Bitwise Filter Operators**
   - Consider supporting `&`, `|`, `~` operators via custom protocols
   - Would improve Python-like ergonomics
   - Estimated effort: Low

8. **Typed Return Properties**
   - Allow specifying return property types like Python's generics
   - Would require macro-based implementation
   - Estimated effort: High

---

## 13. Summary

The Elixir port (WeaviateEx) has achieved **85% feature parity** with the Python client for Query/Search operations. The implementation provides:

**Strengths:**
- Complete vector search support (near_text, near_vector, near_object)
- Full multi-modal support (near_image, near_media)
- Comprehensive filter system with all operators
- Complete hybrid and BM25 search
- Full sorting, pagination, and cursor support
- Group by and reranking functionality
- Generative (RAG) integration
- Target vector support for multi-vector collections
- Both gRPC and GraphQL execution paths

**Key Gaps:**
- Multi-vector query patterns (list of vectors, per-target vectors)
- Near_image aggregations
- Runtime generative provider configuration
- Some gRPC operations fall back to GraphQL
- Prompt debug mode

The architecture follows idiomatic Elixir patterns with a fluent builder API while maintaining functional semantics. The dual gRPC/GraphQL execution path provides robustness similar to the Python client.
