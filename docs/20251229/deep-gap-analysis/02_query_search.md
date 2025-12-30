# Deep Gap Analysis: Query and Search Features

**Date:** 2025-12-29
**Scope:** Comparison of Python canonical Weaviate client vs Elixir WeaviateEx implementation
**Focus Areas:** Vector search, semantic search, hybrid search, BM25, filters, aggregations, group by, sorting, pagination, reranking, metadata, references

---

## Executive Summary

The Elixir WeaviateEx library has achieved substantial feature parity with the Python canonical client for query and search operations. Core functionality including vector search, semantic search, hybrid search, BM25, filtering, and pagination are well-implemented. However, there are notable gaps in advanced features and API ergonomics that should be addressed for production readiness.

### Overall Status by Category

| Category | Status | Coverage |
|----------|--------|----------|
| Vector Search (near_vector, near_object) | Implemented | ~90% |
| Semantic Search (near_text) | Implemented | ~85% |
| Multimodal Search (near_image, near_media) | Implemented | ~90% |
| Hybrid Search | Implemented | ~80% |
| BM25 Keyword Search | Partial | ~70% |
| Filter Operations | Implemented | ~85% |
| Aggregations | Partial | ~60% |
| Group By | Implemented | ~80% |
| Sorting | Implemented | ~95% |
| Pagination | Implemented | ~90% |
| Reranking | Implemented | ~85% |
| Metadata Return | Implemented | ~90% |
| Query References | Implemented | ~85% |

---

## 1. Vector Search (near_vector, near_object)

### Python Features

```python
# near_vector with all options
collection.query.near_vector(
    near_vector=[0.1, 0.2, 0.3, ...],  # or named vectors dict
    certainty=0.7,
    distance=0.3,
    limit=10,
    offset=0,
    auto_limit=5,
    filters=Filter.by_property("status").equal("published"),
    group_by=GroupBy(prop="category", objects_per_group=3, number_of_groups=5),
    rerank=Rerank(prop="content", query="specific query"),
    target_vector="content_vector",  # or TargetVectors.sum/average/minimum/manual_weights
    include_vector=True,  # or ["vec1", "vec2"]
    return_metadata=MetadataQuery.full(),
    return_properties=["title", "content"],
    return_references=[QueryReference(link_on="hasAuthor")]
)

# near_object with all options
collection.query.near_object(
    near_object="uuid-here",
    certainty=0.7,
    distance=0.3,
    # ... same options as near_vector
)
```

### Elixir Implementation

```elixir
# near_vector
Query.get("Article")
|> Query.near_vector([0.1, 0.2, 0.3],
    certainty: 0.7,
    distance: 0.3,
    target_vectors: "content_vector"  # or TargetVectors config
)
|> Query.fields(["title", "content"])
|> Query.limit(10)
|> Query.execute(client)

# near_object
Query.get("Article")
|> Query.near_object("uuid-here", certainty: 0.7)
|> Query.execute(client)
```

### Gap Analysis

| Feature | Python | Elixir | Status | Priority |
|---------|--------|--------|--------|----------|
| Basic near_vector | Yes | Yes | Implemented | - |
| Basic near_object | Yes | Yes | Implemented | - |
| Certainty threshold | Yes | Yes | Implemented | - |
| Distance threshold | Yes | Yes | Implemented | - |
| Target vectors (single) | Yes | Yes | Implemented | - |
| Target vectors (multi - sum) | Yes | Yes | Implemented | - |
| Target vectors (multi - average) | Yes | Yes | Implemented | - |
| Target vectors (multi - minimum) | Yes | Yes | Implemented | - |
| Target vectors (manual_weights) | Yes | Yes | Implemented | - |
| Target vectors (relative_score) | Yes | Yes | Implemented | - |
| Named vectors dict input | Yes | Partial | Partial | Medium |
| 2D vectors (multi-vectors) | Yes | No | Missing | Low |
| ListOfVectorsQuery | Yes | No | Missing | Low |
| include_vector: list of names | Yes | No | Missing | Medium |

### Missing Features

1. **Named vectors dictionary input**: Python supports `{name: vector}` dict, Elixir requires explicit target_vectors parameter
2. **Multi-dimensional vectors (2D)**: Python supports `ListOfVectorsQuery` for advanced vector types
3. **include_vector with specific vector names**: Python allows returning specific named vectors

---

## 2. Semantic Search (near_text)

### Python Features

```python
collection.query.near_text(
    query="machine learning",  # or list of concepts
    certainty=0.7,
    distance=0.3,
    move_to=Move(force=0.5, concepts=["AI"], objects=["uuid1"]),
    move_away=Move(force=0.3, concepts=["biology"]),
    limit=10,
    offset=0,
    auto_limit=5,
    filters=...,
    group_by=...,
    rerank=...,
    target_vector=...,
    include_vector=True,
    return_metadata=...,
    return_properties=...,
    return_references=...
)
```

### Elixir Implementation

```elixir
Query.get("Article")
|> Query.near_text("machine learning",
    certainty: 0.7,
    move_to: Move.to(0.5, concepts: ["AI"]),
    move_away: Move.to(0.3, concepts: ["biology"]),
    target_vectors: "content_vector"
)
|> Query.limit(10)
|> Query.execute(client)
```

### Gap Analysis

| Feature | Python | Elixir | Status | Priority |
|---------|--------|--------|--------|----------|
| Single concept query | Yes | Yes | Implemented | - |
| Multiple concepts (list) | Yes | Partial | Partial | Low |
| Certainty threshold | Yes | Yes | Implemented | - |
| Distance threshold | Yes | Yes | Implemented | - |
| Move to concepts | Yes | Yes | Implemented | - |
| Move to objects | Yes | Yes | Implemented | - |
| Move away from concepts | Yes | Yes | Implemented | - |
| Move away from objects | Yes | Yes | Implemented | - |
| Target vectors | Yes | Yes | Implemented | - |

### Missing Features

1. **Multiple concepts as list**: Python allows `["concept1", "concept2"]`, Elixir takes single string

---

## 3. Multimodal Search (near_image, near_audio, near_video)

### Python Features

```python
# near_image
collection.query.near_image(
    near_image=base64_string,  # or file path, or file object
    certainty=0.8,
    distance=0.2,
    target_vector="image_vector",
    # ... all standard options
)

# near_media (audio, video, thermal, depth, imu)
collection.query.near_media(
    media=base64_string,
    media_type=NearMediaType.AUDIO,
    certainty=0.8,
    # ... all standard options
)
```

### Elixir Implementation

```elixir
# near_image
Query.get("ImageCollection")
|> Query.near_image(image: base64_data, certainty: 0.8)
|> Query.execute(client)

# near_image from file
Query.get("ImageCollection")
|> Query.near_image(image_file: "/path/to/image.png")
|> Query.execute(client)

# near_media
Query.get("MediaCollection")
|> Query.near_media(:audio, media: base64_audio, certainty: 0.7)
|> Query.execute(client)
```

### Gap Analysis

| Feature | Python | Elixir | Status | Priority |
|---------|--------|--------|--------|----------|
| near_image base64 | Yes | Yes | Implemented | - |
| near_image file path | Yes | Yes | Implemented | - |
| near_image file object | Yes | No | Missing | Low |
| near_audio | Yes | Yes | Implemented | - |
| near_video | Yes | Yes | Implemented | - |
| near_thermal | Yes | Yes | Implemented | - |
| near_depth | Yes | Yes | Implemented | - |
| near_imu | Yes | Yes | Implemented | - |
| Target vectors | Yes | Yes | Implemented | - |

---

## 4. Hybrid Search

### Python Features

```python
collection.query.hybrid(
    query="machine learning",
    alpha=0.7,  # 0 = pure BM25, 1 = pure vector
    vector=HybridVector.near_text("concepts",
        move_to=Move(...),
        move_away=Move(...)
    ),  # or HybridVector.near_vector(vec)
    query_properties=["title", "content"],
    fusion_type=HybridFusion.RELATIVE_SCORE,  # or RANKED
    max_vector_distance=0.5,
    bm25_operator=BM25Operator.or_(minimum_match=2),
    limit=10,
    offset=0,
    auto_limit=5,
    filters=...,
    group_by=...,
    rerank=...,
    target_vector=...,
    include_vector=True,
    return_metadata=...,
    return_properties=...,
    return_references=...
)
```

### Elixir Implementation

```elixir
# Basic hybrid
Query.get("Article")
|> Query.hybrid("machine learning", alpha: 0.7)
|> Query.execute(client)

# With HybridVector subsearch
hv = HybridVector.near_text("concepts",
  move_to: Move.to(0.5, concepts: ["AI"]),
  move_away_from: Move.to(0.3, concepts: ["biology"])
)

Query.get("Article")
|> Query.hybrid("search term",
    vector: hv,
    alpha: 0.7,
    fusion_type: :relative_score,
    properties: ["title", "content"]
)
|> Query.execute(client)
```

### Gap Analysis

| Feature | Python | Elixir | Status | Priority |
|---------|--------|--------|--------|----------|
| Basic hybrid search | Yes | Yes | Implemented | - |
| Alpha parameter | Yes | Yes | Implemented | - |
| Query properties | Yes | Yes | Implemented | - |
| Fusion type RANKED | Yes | Yes | Implemented | - |
| Fusion type RELATIVE_SCORE | Yes | Yes | Implemented | - |
| HybridVector.near_text | Yes | Yes | Implemented | - |
| HybridVector.near_vector | Yes | Yes | Implemented | - |
| Move to/away in hybrid | Yes | Yes | Implemented | - |
| Target vectors in hybrid | Yes | Yes | Implemented | - |
| max_vector_distance | Yes | No | Missing | Medium |
| bm25_operator | Yes | No | Missing | Medium |
| BM25Operator.or_(min) | Yes | Partial | Partial | Medium |
| BM25Operator.and_() | Yes | Partial | Partial | Medium |

### Missing Features

1. **max_vector_distance**: Python supports limiting vector search results in hybrid by distance
2. **bm25_operator in hybrid**: Python supports combining with BM25 operators in hybrid queries
3. **BM25Operator integration**: Elixir has the types but limited integration in hybrid

---

## 5. BM25 Keyword Search

### Python Features

```python
collection.query.bm25(
    query="machine learning",
    query_properties=["title", "content"],
    operator=BM25Operator.or_(minimum_match=2),  # or BM25Operator.and_()
    limit=10,
    offset=0,
    auto_limit=5,
    filters=...,
    group_by=...,
    rerank=...,
    include_vector=True,
    return_metadata=...,
    return_properties=...,
    return_references=...
)
```

### Elixir Implementation

```elixir
Query.get("Article")
|> Query.bm25("machine learning", properties: ["title", "content"])
|> Query.limit(10)
|> Query.execute(client)
```

### Gap Analysis

| Feature | Python | Elixir | Status | Priority |
|---------|--------|--------|--------|----------|
| Basic BM25 query | Yes | Yes | Implemented | - |
| Query properties | Yes | Yes | Implemented | - |
| BM25Operator.or_(min) | Yes | Partial | Partial | High |
| BM25Operator.and_() | Yes | Partial | Partial | High |
| Filters | Yes | Yes | Implemented | - |
| Group by | Yes | Yes | Implemented | - |
| Rerank | Yes | Yes | Implemented | - |

### Missing Features

1. **BM25Operator in query**: Elixir has `BM25Operator` module but limited query integration
2. **operator parameter**: Not passed through to GraphQL/gRPC in BM25 queries

---

## 6. Filter Operations

### Python Features

```python
from weaviate.classes.query import Filter

# Property filters
Filter.by_property("status").equal("published")
Filter.by_property("views").greater_than(100)
Filter.by_property("title").like("*machine*")
Filter.by_property("tags").contains_any(["AI", "ML"])
Filter.by_property("tags").contains_all(["AI", "ML"])
Filter.by_property("tags").contains_none(["spam"])
Filter.by_property("field").is_none(True)

# Length filters
Filter.by_property("title", length=True).greater_than(10)

# ID filters
Filter.by_id().equal("uuid")
Filter.by_id().contains_any(["uuid1", "uuid2"])

# Time filters
Filter.by_creation_time().greater_than(datetime)
Filter.by_update_time().less_than(datetime)

# Reference filters
Filter.by_ref("hasAuthor").by_property("name").equal("John")
Filter.by_ref_count("hasAuthors").greater_than(2)
Filter.by_ref_multi_target("relatedTo", "Article").by_property("title").equal("Test")

# Geo filters
Filter.by_property("location").within_geo_range(
    GeoCoordinate(latitude=40.7, longitude=-74.0),
    distance=5000.0
)

# Combinators
Filter.all_of([filter1, filter2])  # AND
Filter.any_of([filter1, filter2])  # OR
filter1 & filter2  # AND operator
filter1 | filter2  # OR operator
~filter1  # NOT operator
```

### Elixir Implementation

```elixir
alias WeaviateEx.Filter

# Property filters
Filter.equal("status", "published")
Filter.not_equal("status", "draft")
Filter.greater_than("views", 100)
Filter.greater_or_equal("views", 100)
Filter.less_than("views", 1000)
Filter.less_or_equal("views", 1000)
Filter.like("title", "*machine*")
Filter.contains_any("tags", ["AI", "ML"])
Filter.contains_all("tags", ["AI", "ML"])
Filter.contains_none("tags", ["spam"])
Filter.null?("field")

# Length filters
Filter.by_property_length("title", :greater_or_equal, 10)

# ID filters
Filter.by_id(:equal, "uuid")

# Time filters
Filter.by_creation_time(:greater_than, "2024-01-01T00:00:00Z")
Filter.by_update_time(:less_than, "2024-12-31T00:00:00Z")

# Reference filters
Filter.by_ref("hasAuthor", "Author", :equal, "John")
Filter.by_ref_count("hasAuthors", :greater_than, 2)
Filter.by_ref_multi_target("relatedTo", "Article", "title", :equal, "Test")

# Geo filters
Filter.within_geo_range("location", {40.7, -74.0}, 5000.0)

# Combinators
Filter.all_of([filter1, filter2])  # AND
Filter.any_of([filter1, filter2])  # OR
Filter.not_(filter1)  # NOT
```

### Gap Analysis

| Feature | Python | Elixir | Status | Priority |
|---------|--------|--------|--------|----------|
| equal | Yes | Yes | Implemented | - |
| not_equal | Yes | Yes | Implemented | - |
| greater_than | Yes | Yes | Implemented | - |
| greater_or_equal | Yes | Yes | Implemented | - |
| less_than | Yes | Yes | Implemented | - |
| less_or_equal | Yes | Yes | Implemented | - |
| like (wildcards) | Yes | Yes | Implemented | - |
| contains_any | Yes | Yes | Implemented | - |
| contains_all | Yes | Yes | Implemented | - |
| contains_none | Yes | Yes | Implemented | - |
| is_none/null? | Yes | Yes | Implemented | - |
| by_property length | Yes | Yes | Implemented | - |
| by_id | Yes | Yes | Implemented | - |
| by_creation_time | Yes | Yes | Implemented | - |
| by_update_time | Yes | Yes | Implemented | - |
| by_ref (simple) | Yes | Yes | Implemented | - |
| by_ref (chained) | Yes | Partial | Partial | Medium |
| by_ref_count | Yes | Yes | Implemented | - |
| by_ref_multi_target | Yes | Yes | Implemented | - |
| within_geo_range | Yes | Yes | Implemented | - |
| all_of (AND) | Yes | Yes | Implemented | - |
| any_of (OR) | Yes | Yes | Implemented | - |
| not_ (NOT) | Yes | Yes | Implemented | - |
| Operator overloading (&, |, ~) | Yes | No | Missing | Low |
| Chained reference traversal | Yes | Partial | Partial | Medium |
| contains_any on IDs | Yes | No | Missing | Low |
| contains_none on IDs | Yes | No | Missing | Low |
| contains_any on dates | Yes | No | Missing | Low |
| contains_none on dates | Yes | No | Missing | Low |

### Missing Features

1. **Operator overloading**: Python uses `&`, `|`, `~` for filter combination
2. **Chained reference traversal**: Python allows `.by_ref().by_ref().by_property()`
3. **ID contains_any/none**: Filter by multiple UUIDs
4. **Date contains_any/none**: Filter by multiple dates

---

## 7. Aggregations

### Python Features

```python
# over_all aggregation
collection.aggregate.over_all(
    total_count=True,
    filters=...,
    return_metrics=[
        Metrics("price").number(sum_=True, mean=True, maximum=True, minimum=True),
        Metrics("category").text(top_occurrences_count=True, top_occurrences_value=True),
        Metrics("is_available").boolean(percentage_true=True, total_true=True)
    ]
)

# near_text aggregation
collection.aggregate.near_text(
    query="machine learning",
    certainty=0.7,
    object_limit=100,
    total_count=True,
    return_metrics=...
)

# near_vector aggregation
collection.aggregate.near_vector(
    near_vector=[0.1, 0.2, ...],
    certainty=0.7,
    object_limit=100,
    total_count=True,
    return_metrics=...
)

# near_object aggregation
collection.aggregate.near_object(
    near_object="uuid",
    certainty=0.7,
    object_limit=100,
    return_metrics=...
)

# hybrid aggregation
collection.aggregate.hybrid(
    query="text",
    alpha=0.7,
    object_limit=100,
    return_metrics=...
)

# group_by aggregation
collection.aggregate.over_all(
    group_by="category",
    total_count=True,
    return_metrics=...
)
```

### Elixir Implementation

```elixir
# over_all
Aggregate.over_all(client, "Article",
  metrics: [:count],
  properties: [
    {:price, [:sum, :mean, :maximum, :minimum]},
    {:category, [:topOccurrences], limit: 5}
  ]
)

# with near_text
Aggregate.with_near_text(client, "Article", "machine learning",
  certainty: 0.7,
  metrics: [:count]
)

# with near_vector
Aggregate.with_near_vector(client, "Article", vector,
  certainty: 0.7,
  metrics: [:count]
)

# with filter (where)
Aggregate.with_where(client, "Article", filter,
  metrics: [:count]
)

# group by
Aggregate.group_by(client, "Article", "category",
  metrics: [:count],
  properties: [{:price, [:mean]}]
)
```

### Gap Analysis

| Feature | Python | Elixir | Status | Priority |
|---------|--------|--------|--------|----------|
| over_all aggregation | Yes | Yes | Implemented | - |
| total_count | Yes | Yes | Implemented | - |
| Numeric metrics (sum, mean, max, min) | Yes | Yes | Implemented | - |
| Text metrics (topOccurrences) | Yes | Yes | Implemented | - |
| Boolean metrics (percentageTrue/False) | Yes | Yes | Implemented | - |
| Median | Yes | Yes | Implemented | - |
| Mode | Yes | Yes | Implemented | - |
| near_text aggregation | Yes | Yes | Implemented | - |
| near_vector aggregation | Yes | Yes | Implemented | - |
| near_object aggregation | Yes | No | Missing | Medium |
| hybrid aggregation | Yes | No | Missing | High |
| Filters in aggregation | Yes | Yes | Implemented | - |
| Group by | Yes | Yes | Implemented | - |
| object_limit | Yes | No | Missing | Medium |
| Metrics class structure | Yes | Partial | Partial | Low |

### Missing Features

1. **near_object aggregation**: Not implemented in Elixir
2. **hybrid aggregation**: Not implemented in Elixir
3. **object_limit**: Limit objects considered in aggregation
4. **Metrics class**: Python has typed Metrics builder

---

## 8. Group By Operations

### Python Features

```python
GroupBy(
    prop="category",
    objects_per_group=5,
    number_of_groups=10
)
```

### Elixir Implementation

```elixir
GroupBy.new("category",
  objects_per_group: 5,
  number_of_groups: 10
)

# Nested path
GroupBy.new(["metadata", "type"])
```

### Gap Analysis

| Feature | Python | Elixir | Status | Priority |
|---------|--------|--------|--------|----------|
| Basic group by | Yes | Yes | Implemented | - |
| objects_per_group | Yes | Yes | Implemented | - |
| number_of_groups | Yes | Yes | Implemented | - |
| Nested property path | Yes | Yes | Implemented | - |
| Group by in all search types | Yes | Yes | Implemented | - |

---

## 9. Sorting Capabilities

### Python Features

```python
Sort.by_property(name="title", ascending=True)
Sort.by_id(ascending=False)
Sort.by_creation_time(ascending=False)
Sort.by_update_time(ascending=True)

# Chaining
Sort.by_property("category").by_property("title", ascending=False)
```

### Elixir Implementation

```elixir
Sort.by_property("title")
Sort.by_property("title", :desc)
Sort.by_id()
Sort.by_creation_time(:desc)
Sort.by_update_time()

# Chaining
Sort.by_property("category")
|> Sort.then_by_property("title", :desc)
|> Sort.then_by_creation_time(:desc)
```

### Gap Analysis

| Feature | Python | Elixir | Status | Priority |
|---------|--------|--------|--------|----------|
| by_property | Yes | Yes | Implemented | - |
| by_id | Yes | Yes | Implemented | - |
| by_creation_time | Yes | Yes | Implemented | - |
| by_update_time | Yes | Yes | Implemented | - |
| Ascending/descending | Yes | Yes | Implemented | - |
| Multiple sort criteria | Yes | Yes | Implemented | - |
| Chained sorting | Yes | Yes | Implemented | - |

---

## 10. Pagination (limit, offset, cursor)

### Python Features

```python
# Offset pagination
collection.query.fetch_objects(
    limit=100,
    offset=200
)

# Cursor pagination
collection.query.fetch_objects(
    limit=100,
    after=last_uuid  # cursor
)

# Auto-cut (natural score boundaries)
collection.query.near_text(
    query="...",
    auto_limit=3
)
```

### Elixir Implementation

```elixir
# Offset pagination
Query.get("Article")
|> Query.limit(100)
|> Query.offset(200)
|> Query.execute(client)

# Cursor pagination
Query.get("Article")
|> Query.limit(100)
|> Query.sort(Sort.by_id())
|> Query.after_cursor("last-uuid")
|> Query.execute(client)

# Auto-limit
Query.get("Article")
|> Query.near_text("query")
|> Query.auto_limit(3)
|> Query.execute(client)
```

### Gap Analysis

| Feature | Python | Elixir | Status | Priority |
|---------|--------|--------|--------|----------|
| limit | Yes | Yes | Implemented | - |
| offset | Yes | Yes | Implemented | - |
| Cursor (after) | Yes | Yes | Implemented | - |
| auto_limit/autocut | Yes | Yes | Implemented | - |
| fetch_objects | Yes | Partial | Partial | Medium |
| fetch_object_by_id | Yes | Partial | Partial | Medium |
| fetch_objects_by_ids | Yes | No | Missing | Medium |

### Missing Features

1. **fetch_objects_by_ids**: Batch fetch by multiple UUIDs

---

## 11. Reranking

### Python Features

```python
Rerank(
    prop="content",
    query="specific rerank query"  # optional
)
```

### Elixir Implementation

```elixir
Rerank.new("content")
Rerank.new("content", query: "specific rerank query")
```

### Gap Analysis

| Feature | Python | Elixir | Status | Priority |
|---------|--------|--------|--------|----------|
| Basic rerank | Yes | Yes | Implemented | - |
| Property selection | Yes | Yes | Implemented | - |
| Custom query | Yes | Yes | Implemented | - |
| Rerank in all search types | Yes | Yes | Implemented | - |

---

## 12. Return Metadata Options

### Python Features

```python
MetadataQuery(
    creation_time=True,
    last_update_time=True,
    distance=True,
    certainty=True,
    score=True,
    explain_score=True,
    is_consistent=True
)

MetadataQuery.full()  # all fields
```

### Elixir Implementation

```elixir
Metadata.full()
Metadata.common()  # id, distance, certainty, score
Metadata.timestamps()  # creation/update time
Metadata.select(["id", "distance", "certainty"])
```

### Gap Analysis

| Feature | Python | Elixir | Status | Priority |
|---------|--------|--------|--------|----------|
| id/uuid | Yes | Yes | Implemented | - |
| distance | Yes | Yes | Implemented | - |
| certainty | Yes | Yes | Implemented | - |
| score | Yes | Yes | Implemented | - |
| explain_score | Yes | Yes | Implemented | - |
| creation_time | Yes | Yes | Implemented | - |
| last_update_time | Yes | Yes | Implemented | - |
| is_consistent | Yes | Yes | Implemented | - |
| Full metadata helper | Yes | Yes | Implemented | - |
| Selective metadata | Yes | Yes | Implemented | - |
| vector inclusion | Yes | Partial | Partial | Low |
| Named vector inclusion | Yes | No | Missing | Medium |

### Missing Features

1. **Named vector inclusion**: Python allows `include_vector=["vec1", "vec2"]`

---

## 13. Query with References

### Python Features

```python
QueryReference(
    link_on="hasAuthor",
    return_properties=["name", "bio"],
    return_metadata=MetadataQuery.full(),
    include_vector=True,
    return_references=[  # nested
        QueryReference(link_on="hasPublisher", return_properties=["name"])
    ]
)

# Multi-target reference
QueryReference.MultiTarget(
    link_on="relatedTo",
    target_collection="Article",
    return_properties=["title"]
)
```

### Elixir Implementation

```elixir
QueryReference.new("hasAuthor",
  return_properties: ["name", "bio"],
  return_metadata: :full,
  include_vector: true,
  return_references: [
    QueryReference.new("hasPublisher", return_properties: ["name"])
  ]
)

# Multi-target
QueryReference.multi_target("relatedTo", "Article",
  return_properties: ["title"]
)
```

### Gap Analysis

| Feature | Python | Elixir | Status | Priority |
|---------|--------|--------|--------|----------|
| Basic reference | Yes | Yes | Implemented | - |
| return_properties | Yes | Yes | Implemented | - |
| return_metadata | Yes | Yes | Implemented | - |
| include_vector | Yes | Yes | Implemented | - |
| Nested references | Yes | Yes | Implemented | - |
| Multi-target references | Yes | Yes | Implemented | - |

---

## Priority Recommendations

### High Priority (Critical for Production)

1. **BM25Operator integration** - Full support for `operator` parameter in BM25 and hybrid queries
2. **Hybrid aggregation** - Complete aggregation API parity
3. **fetch_objects_by_ids** - Batch fetch capability

### Medium Priority (Feature Completeness)

1. **max_vector_distance in hybrid** - Vector distance limiting
2. **near_object aggregation** - Complete aggregation methods
3. **object_limit in aggregations** - Limit objects considered
4. **Named vector inclusion** - `include_vector=["vec1", "vec2"]`
5. **Chained reference filters** - Deep reference traversal

### Low Priority (Nice to Have)

1. **Operator overloading for filters** - `&`, `|`, `~` operators
2. **2D vectors / ListOfVectorsQuery** - Advanced vector types
3. **Multiple concepts in near_text** - List input support
4. **File object input for images** - In addition to paths and base64

---

## API Ergonomics Comparison

### Python API Style (Collection-Centric)

```python
client = weaviate.connect_to_local()
collection = client.collections.get("Article")

results = collection.query.near_text(
    query="machine learning",
    certainty=0.7,
    limit=10,
    return_properties=["title", "content"],
    return_metadata=MetadataQuery.full()
)

for obj in results.objects:
    print(obj.properties["title"])
    print(obj.metadata.distance)
```

### Elixir API Style (Query Builder)

```elixir
{:ok, client} = WeaviateEx.Client.connect(base_url: "http://localhost:8080")

{:ok, results} = Query.get("Article")
|> Query.near_text("machine learning", certainty: 0.7)
|> Query.fields(["title", "content"])
|> Query.additional(["id", "distance"])
|> Query.limit(10)
|> Query.execute(client)

for obj <- results do
  IO.puts(obj["title"])
  IO.puts(obj["_additional"]["distance"])
end
```

### Design Differences

| Aspect | Python | Elixir |
|--------|--------|--------|
| Query construction | Method call with all options | Pipeline builder pattern |
| Collection binding | Collection-centric (`collection.query`) | Query specifies collection |
| Return type | Typed `QueryReturn` objects | Plain maps |
| Property access | `obj.properties["title"]` | `obj["title"]` |
| Metadata access | `obj.metadata.distance` | `obj["_additional"]["distance"]` |
| Type safety | Strong typing with generics | Runtime typing with specs |
| Async support | Built-in async methods | Task-based (external) |

---

## Conclusion

WeaviateEx has achieved strong feature coverage for query and search operations, with most core functionality implemented. The main gaps are in:

1. Advanced BM25 operator support
2. Hybrid/near_object aggregations
3. Batch fetch operations
4. Some edge cases in vector handling

The Elixir implementation provides an idiomatic API using the pipeline pattern while maintaining functional parity with the Python client for typical use cases.
