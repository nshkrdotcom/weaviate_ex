# Query and Search Operations Gap Analysis

**Date:** 2025-12-29 (Updated)
**Scope:** Vector search, text search, hybrid search, filters, aggregations, sorting, pagination, grouping, reranking, and generative search

## Executive Summary

The Elixir implementation has **substantial query and search coverage** with most core features implemented. The previous assessment of 70-75% coverage was conservative - the current implementation is closer to **85-90%** complete with key gaps primarily in:

- Hybrid search advanced options (bm25_operator, max_vector_distance)
- Named vector input as dictionary format
- Aggregation metrics typed API
- Runtime generative provider selection

**Key Finding:** Many features previously marked as "missing" (multimodal search, HybridVector, BM25Operator) have since been implemented.

---

## Feature Comparison Matrix

| Category | Python Client | Elixir Port | Gap Level |
|----------|---------------|-------------|-----------|
| Vector Search (Basic) | Full | Full | **None** |
| Vector Search (Named Vectors) | Full | Partial | **Low** |
| Hybrid Search | Full | Substantial | **Low** |
| BM25 Keyword Search | Full | Full | **None** |
| Filters & Operators | Full | Full | **None** |
| Aggregations | Full | Substantial | **Medium** |
| Grouping | Full | Full | **None** |
| Generative Search (RAG) | Full | Substantial | **Low** |
| Reranking | Full | Full | **None** |
| Multimodal Search | Full | Full | **None** |
| Query Builder Pattern | OOP/Fluent | Functional/Fluent | **Different Style** |

---

## 1. Vector Search

### 1.1 near_vector

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Basic vector search | `collection.query.near_vector(vector)` | `Query.near_vector(query, vector)` | Complete |
| Certainty threshold | `certainty=0.8` | `certainty: 0.8` | Complete |
| Distance threshold | `distance=0.3` | `distance: 0.3` | Complete |
| Limit/offset | `limit=10, offset=5` | `Query.limit(10) \|> Query.offset(5)` | Complete |
| Auto-limit (autocut) | `auto_limit=3` | `Query.auto_limit(3)` | Complete |
| Filters | `filters=Filter.by_property(...)` | `Query.where(filter_map)` | Complete |
| Group by | `group_by=GroupBy(...)` | `Query.group_by(GroupBy.new(...))` | Complete |
| Rerank | `rerank=Rerank(...)` | `Query.rerank(Rerank.new(...))` | Complete |
| Target vectors (named vectors) | `target_vector="named_vec"` | `target_vectors: "named_vec"` | Complete |
| Include vector | `include_vector=True` | Via `additional: ["vector"]` | Complete |
| Return metadata | `return_metadata=MetadataQuery.full()` | Via `additional: [...]` | Complete |
| Return properties | `return_properties=["title"]` | `Query.fields(["title"])` | Complete |
| Return references | `return_references=[QueryReference....]` | `Query.return_references([...])` | Complete |
| Named vector input (dict) | `{"vec1": [...], "vec2": [...]}` | Not implemented | **Gap** |

**Python Example:**
```python
from weaviate.classes.query import Filter, MetadataQuery

result = collection.query.near_vector(
    near_vector=[0.1, 0.2, ...],
    certainty=0.8,
    limit=10,
    filters=Filter.by_property("status").equal("published"),
    return_metadata=MetadataQuery.full(),
    return_properties=["title", "content"]
)
```

**Elixir Example:**
```elixir
Query.get("Article")
|> Query.near_vector([0.1, 0.2, ...], certainty: 0.8)
|> Query.where(%{path: ["status"], operator: "Equal", valueText: "published"})
|> Query.fields(["title", "content"])
|> Query.additional(["id", "distance", "certainty"])
|> Query.limit(10)
|> Query.execute(client)
```

### 1.2 near_object

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Basic object similarity | `collection.query.near_object(uuid)` | `Query.near_object(query, uuid)` | Complete |
| Certainty/distance | Supported | Supported | Complete |
| All standard query options | Supported | Supported | Complete |

**Python Example:**
```python
result = collection.query.near_object(
    near_object="550e8400-e29b-41d4-a716-446655440000",
    distance=0.3,
    limit=5
)
```

**Elixir Example:**
```elixir
Query.get("Article")
|> Query.near_object("550e8400-e29b-41d4-a716-446655440000", distance: 0.3)
|> Query.limit(5)
|> Query.execute(client)
```

---

## 2. Text Search (BM25)

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Basic BM25 search | `collection.query.bm25(query)` | `Query.bm25(query, text)` | Complete |
| Query properties | `query_properties=["title"]` | `properties: ["title"]` | Complete |
| BM25 operator (AND/OR) | `BM25OperatorOptions(...)` | `BM25Operator.and_()` / `BM25Operator.or_(n)` | Complete |
| Minimum should match | `BM25OperatorOptions.or_(minimum=2)` | `BM25Operator.or_(2)` | Complete |
| Group by | Supported | Supported | Complete |
| Rerank | Supported | Supported | Complete |

**Python Example:**
```python
from weaviate.classes.query import BM25OperatorOptions

result = collection.query.bm25(
    query="machine learning",
    query_properties=["title", "content"],
    operator=BM25OperatorOptions.or_(minimum_should_match=2),
    limit=10
)
```

**Elixir Example:**
```elixir
alias WeaviateEx.Query.BM25Operator

Query.get("Article")
|> Query.bm25("machine learning",
    properties: ["title", "content"],
    operator: BM25Operator.or_(2))
|> Query.limit(10)
|> Query.execute(client)
```

---

## 3. Hybrid Search

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Basic hybrid | `collection.query.hybrid(query)` | `Query.hybrid(query, text)` | Complete |
| Alpha weighting | `alpha=0.7` | `alpha: 0.7` | Complete |
| Fusion type (ranked/relative) | `fusion_type=HybridFusion.RANKED` | `fusion_type: :ranked` | Complete |
| Query properties | `query_properties=[...]` | `properties: [...]` | Complete |
| Custom vector | `vector=[...]` | `vector: [...]` or `HybridVector.near_vector(...)` | Complete |
| Vector via near_text | `vector=HybridVectorType.near_text(...)` | `HybridVector.near_text(...)` | Complete |
| Move to/away operations | In vector config | `HybridVector` with `Move.to(...)` | Complete |
| Max vector distance | `max_vector_distance=0.5` | Not directly exposed | **Gap** |
| BM25 operator in hybrid | `bm25_operator=...` | Not implemented | **Gap** |
| Target vectors | `target_vector=...` | `target_vectors: ...` | Complete |

**Python Example:**
```python
from weaviate.classes.query import HybridFusion, HybridVector

result = collection.query.hybrid(
    query="machine learning",
    alpha=0.7,
    vector=HybridVector.near_text("AI concepts", move_to=Move(force=0.5, concepts=["neural networks"])),
    fusion_type=HybridFusion.RELATIVE_SCORE,
    limit=10
)
```

**Elixir Example:**
```elixir
alias WeaviateEx.Query.{HybridVector, Move}

hv = HybridVector.near_text("AI concepts",
  move_to: Move.to(0.5, concepts: ["neural networks"])
)

Query.get("Article")
|> Query.hybrid("machine learning", alpha: 0.7, vector: hv, fusion_type: :relative_score)
|> Query.limit(10)
|> Query.execute(client)
```

---

## 4. Filters

### 4.1 Filter Operators

| Operator | Python | Elixir | Status |
|----------|--------|--------|--------|
| Equal | `Filter.by_property("x").equal(val)` | `Filter.equal("x", val)` | Complete |
| Not Equal | `.not_equal(val)` | `Filter.not_equal("x", val)` | Complete |
| Less Than | `.less_than(val)` | `Filter.less_than("x", val)` | Complete |
| Less or Equal | `.less_or_equal(val)` | `Filter.less_or_equal("x", val)` | Complete |
| Greater Than | `.greater_than(val)` | `Filter.greater_than("x", val)` | Complete |
| Greater or Equal | `.greater_or_equal(val)` | `Filter.greater_or_equal("x", val)` | Complete |
| Like (wildcards) | `.like("pat*")` | `Filter.like("x", "pat*")` | Complete |
| Contains Any | `.contains_any([...])` | `Filter.contains_any("x", [...])` | Complete |
| Contains All | `.contains_all([...])` | `Filter.contains_all("x", [...])` | Complete |
| Contains None | `.contains_none([...])` | `Filter.contains_none("x", [...])` | Complete |
| Is Null | `.is_none(True)` | `Filter.null?("x")` | Complete |
| Within Geo Range | `.within_geo_range(coord, dist)` | `Filter.within_geo_range("x", {lat, lon}, dist)` | Complete |

### 4.2 Filter Composition

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| AND combination | `filter1 & filter2` | `Filter.all_of([f1, f2])` | Complete |
| OR combination | `filter1 \| filter2` | `Filter.any_of([f1, f2])` | Complete |
| NOT negation | `~filter` | `Filter.not_(filter)` | Complete |
| Static all_of | `Filter.all_of([...])` | `Filter.all_of([...])` | Complete |
| Static any_of | `Filter.any_of([...])` | `Filter.any_of([...])` | Complete |

### 4.3 Special Filters

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Filter by ID | `Filter.by_id().equal(uuid)` | `Filter.by_id(:equal, uuid)` | Complete |
| Filter by creation time | `Filter.by_creation_time().greater_than(dt)` | `Filter.by_creation_time(:greater_than, dt)` | Complete |
| Filter by update time | `Filter.by_update_time().less_than(dt)` | `Filter.by_update_time(:less_than, dt)` | Complete |
| Filter by ref count | `Filter.by_ref_count("prop").equal(n)` | `Filter.by_ref_count("prop", :equal, n)` | Complete |
| Filter by property length | `Filter.by_property("x", length=True).greater_than(10)` | `Filter.by_property_length("x", :greater_than, 10)` | Complete |
| Filter by ref (single target) | `Filter.by_ref("prop").by_property("x").equal(v)` | `Filter.by_ref_path(path, "x", :equal, v)` | Complete |
| Filter by ref (multi target) | `Filter.by_ref_multi_target("prop", "Target").by_property(...)` | `Filter.by_ref_multi_target("prop", "Target", "x", :equal, v)` | Complete |
| Nested reference filters | Chained `.by_ref()` calls | `RefPath.through().through()` | Complete |

### 4.4 API Style Differences

**Python (Fluent Builder Pattern):**
```python
from weaviate.classes.query import Filter

# Composable, type-safe filter building
filter = (
    Filter.by_property("status").equal("published") &
    Filter.by_property("views").greater_than(100) &
    ~Filter.by_property("archived").equal(True)
)

# Reference traversal
ref_filter = (
    Filter.by_ref("hasAuthor")
    .by_property("name")
    .equal("John")
)
```

**Elixir (Function-based):**
```elixir
alias WeaviateEx.Filter

# Combining filters
filter = Filter.all_of([
  Filter.equal("status", "published"),
  Filter.greater_than("views", 100),
  Filter.not_(Filter.equal("archived", true))
])

# Reference filtering
alias WeaviateEx.Filter.RefPath
path = RefPath.through("hasAuthor", "Author")
ref_filter = RefPath.property(path, "name", :equal, "John")
```

### 4.5 Identified Gaps

| Gap | Description | Priority |
|-----|-------------|----------|
| Operator overloading | Python uses `&`, `\|`, `~` operators | Low (Elixir uses functions idiomatically) |
| Method chaining | Python `Filter.by_property().equal()` | Low (Different paradigm) |
| Type inference | Python auto-detects value types | Low (Elixir is explicit) |

---

## 5. Aggregations

### 5.1 Aggregation Types

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Over all (basic) | `collection.aggregate.over_all()` | `Aggregate.over_all(client, coll, opts)` | Complete |
| With near_text | `collection.aggregate.near_text(query)` | `Aggregate.with_near_text(client, coll, query, opts)` | Complete |
| With near_vector | `collection.aggregate.near_vector(vector)` | `Aggregate.with_near_vector(client, coll, vector, opts)` | Complete |
| With near_object | `collection.aggregate.near_object(uuid)` | `Aggregate.with_near_object(client, coll, uuid, opts)` | Complete |
| With hybrid | `collection.aggregate.hybrid(query)` | `Aggregate.with_hybrid(client, coll, query, opts)` | Complete |
| With filters | `filters=...` | `Aggregate.with_where(client, coll, filter, opts)` | Complete |
| Group by | `group_by=GroupByAggregate(prop)` | `Aggregate.group_by(client, coll, prop, opts)` | Complete |

### 5.2 Metrics

| Metric Type | Python | Elixir | Status |
|-------------|--------|--------|--------|
| Count | `total_count=True` | `metrics: [:count]` | Complete |
| Integer (sum, mean, etc.) | `Metrics("prop").integer()` | `properties: [{:prop, [:sum, :mean, ...]}]` | Complete |
| Number (float) | `Metrics("prop").number()` | `properties: [{:prop, [:sum, :mean, ...]}]` | Complete |
| Text (top occurrences) | `Metrics("prop").text()` | `properties: [{:prop, [:topOccurrences], limit: 5}]` | Complete |
| Boolean | `Metrics("prop").boolean()` | `properties: [{:prop, [:percentageTrue, ...]}]` | Complete |
| Date | `Metrics("prop").date_()` | `properties: [{:prop, [:maximum, :minimum, ...]}]` | Complete |
| Reference | `Metrics("prop").reference()` | Not directly exposed | **Gap** |

### 5.3 API Style Differences

**Python (Typed Metrics Class):**
```python
from weaviate.classes.aggregate import Metrics, GroupByAggregate

result = collection.aggregate.over_all(
    total_count=True,
    return_metrics=[
        Metrics("price").integer(sum_=True, mean=True, maximum=True),
        Metrics("category").text(top_occurrences_count=True, limit=5),
        Metrics("isActive").boolean(percentage_true=True)
    ],
    group_by=GroupByAggregate(prop="category")
)
```

**Elixir (Keyword Options):**
```elixir
Aggregate.group_by(client, "Product", "category",
  metrics: [:count],
  properties: [
    {:price, [:sum, :mean, :maximum]},
    {:category, [:topOccurrences], limit: 5},
    {:isActive, [:percentageTrue]}
  ]
)
```

### 5.4 Identified Gaps

| Gap | Description | Priority |
|-----|-------------|----------|
| Metrics class | Python has typed `Metrics` builder | Medium |
| Reference aggregation | `Metrics.reference()` pointing_to | Low |
| Near_image aggregation | Aggregate with image similarity | Low |
| Typed return objects | Python has `AggregateReturn`, `AggregateGroup` | Low |

---

## 6. Sorting and Pagination

### 6.1 Sorting

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Sort by property | Via GraphQL | `Sort.by_property("title")` | Complete |
| Sort direction | `asc`/`desc` | `:asc` / `:desc` | Complete |
| Multiple sorts | Multiple sort specs | `Sort.then_by_property(...)` | Complete |
| Sort by creation time | `_creationTimeUnix` | `Sort.by_creation_time()` | Complete |
| Sort by update time | `_lastUpdateTimeUnix` | `Sort.by_update_time()` | Complete |
| Sort by ID | `id` | `Sort.by_id()` | Complete |

### 6.2 Pagination

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Limit | `limit=10` | `Query.limit(10)` | Complete |
| Offset | `offset=20` | `Query.offset(20)` | Complete |
| Cursor-based (after) | `after=cursor` | `Query.after_cursor(cursor)` | Complete |
| Autocut (auto_limit) | `auto_limit=3` | `Query.auto_limit(3)` | Complete |

**Elixir Sort Example:**
```elixir
alias WeaviateEx.Query.Sort

Query.get("Article")
|> Query.sort(
  Sort.by_property("category")
  |> Sort.then_by_property("title", :desc)
)
|> Query.limit(100)
|> Query.execute(client)
```

---

## 7. Group By Operations

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Group by property | `group_by=GroupBy(prop="category")` | `Query.group_by(GroupBy.new("category"))` | Complete |
| Number of groups | `number_of_groups=10` | `number_of_groups: 10` | Complete |
| Objects per group | `objects_per_group=5` | `objects_per_group: 5` | Complete |
| Nested property path | `prop=["nested", "path"]` | `GroupBy.new(["nested", "path"])` | Complete |
| Group by return type | `GroupByReturn` object | Via query result parsing | Complete |

**Python Example:**
```python
from weaviate.classes.query import GroupBy

result = collection.query.near_text(
    query="technology",
    group_by=GroupBy(
        prop="category",
        number_of_groups=5,
        objects_per_group=3
    )
)

for group in result.groups:
    print(f"Group: {group.grouped_by.value}")
    for obj in group.objects:
        print(f"  - {obj.properties['title']}")
```

**Elixir Example:**
```elixir
alias WeaviateEx.Query.GroupBy

group_by = GroupBy.new("category",
  number_of_groups: 5,
  objects_per_group: 3
)

Query.get("Article")
|> Query.near_text("technology")
|> Query.group_by(group_by)
|> Query.execute(client)
```

---

## 8. Reranking

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Rerank by property | `rerank=Rerank(prop="content")` | `Query.rerank(Rerank.new("content"))` | Complete |
| Custom rerank query | `query="specific query"` | `query: "specific query"` | Complete |
| Rerank score in metadata | `_additional { rerank { score } }` | Via additional fields | Complete |

**Python Example:**
```python
from weaviate.classes.query import Rerank

result = collection.query.near_text(
    query="AI",
    rerank=Rerank(
        prop="content",
        query="What is machine learning?"
    ),
    limit=10
)
```

**Elixir Example:**
```elixir
alias WeaviateEx.Query.Rerank

rerank = Rerank.new("content", query: "What is machine learning?")

Query.get("Article")
|> Query.near_text("AI")
|> Query.rerank(rerank)
|> Query.limit(10)
|> Query.execute(client)
```

---

## 9. Generative Search / RAG Queries

### 9.1 Basic Features

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Single prompt (per object) | `single_prompt="..."` | `Generate.single_prompt(builder, prompt)` | Complete |
| Grouped task (all results) | `grouped_task="..."` | `Generate.grouped_task(builder, task)` | Complete |
| Property interpolation | `"Summarize: {title}"` | `"Summarize: {title}"` | Complete |
| With near_text | Supported | `Generate.near_text(builder, query)` | Complete |
| With near_vector | Supported | `Generate.near_vector(builder, vec)` | Complete |
| With near_object | Supported | `Generate.near_object(builder, id)` | Complete |
| With BM25 | Supported | `Generate.bm25(builder, query)` | Complete |
| With hybrid | Supported | `Generate.hybrid(builder, query)` | Complete |

### 9.2 Advanced Features

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Grouped properties | `grouped_properties=["title", "content"]` | `properties: ["title", "content"]` | Complete |
| Runtime provider selection | `generative_provider=GenerativeProvider.openai()` | Via collection config only | **Gap** |
| Provider parameters | Temperature, max_tokens, etc. | Limited in generative module | **Gap** |
| Both prompts together | `single_prompt=..., grouped_task=...` | Both can be set | Complete |
| Query integration | Part of query API | `Query.generate(query, type, prompt)` | Complete |

### 9.3 Provider Support (Collection Config)

| Provider | Python | Elixir | Status |
|----------|--------|--------|--------|
| OpenAI | `generative-openai` | `:openai` | Complete |
| Anthropic | `generative-anthropic` | `:anthropic` | Complete |
| Cohere | `generative-cohere` | `:cohere` | Complete |
| Google/PaLM | `generative-palm` | `:palm`, `:google_vertex`, `:google_gemini` | Complete |
| AWS Bedrock | `generative-aws` | `:aws_bedrock` | Complete |
| Azure OpenAI | `generative-azure-openai` | `:azure_openai` | Complete |
| Mistral | `generative-mistral` | `:mistral` | Complete |
| Ollama | `generative-ollama` | `:ollama` | Complete |
| Other providers | Various | 20+ providers | Complete |

### 9.4 API Comparison

**Python (Integrated with Query):**
```python
# Generate is part of the collection's generate namespace
result = collection.generate.near_text(
    query="machine learning",
    single_prompt="Summarize this article about {title}",
    grouped_task="Write an overview of these articles",
    grouped_properties=["title", "content"],
    limit=5
)

print(result.generated)  # Grouped result
for obj in result.objects:
    print(obj.generated)  # Per-object result
```

**Elixir (Separate Builder):**
```elixir
alias WeaviateEx.Query.Generate

# Separate Generate builder
result = Generate.new("Article")
|> Generate.near_text("machine learning")
|> Generate.single_prompt("Summarize this article about {title}")
|> Generate.grouped_task("Write an overview", properties: ["title", "content"])
|> Generate.limit(5)
|> Generate.execute(client)

# Or from existing Query
Query.get("Article")
|> Query.near_text("machine learning")
|> Query.generate(:single, "Summarize: {title}")
|> Query.execute(client)
```

### 9.5 Identified Gaps

| Gap | Description | Priority |
|-----|-------------|----------|
| Runtime provider | Select provider at query time, not just config | Medium |
| GenerativeConfigRuntime | Runtime model/temperature override | Medium |

---

## 10. Media Search (Near Image/Audio/Video)

### 10.1 Near Image

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Base64 image | `near_image=encoded_image` | `Query.near_image(image: base64)` | Complete |
| File path | `near_image=path_to_file` | `Query.near_image(image_file: path)` | Complete |
| Certainty/distance | Supported | Supported | Complete |
| Target vectors | Supported | Supported | Complete |

### 10.2 Near Media (Multi-modal)

| Media Type | Python | Elixir | Status |
|------------|--------|--------|--------|
| Audio | `near_audio=...` | `Query.near_media(:audio, media: ...)` | Complete |
| Video | `near_video=...` | `Query.near_media(:video, media: ...)` | Complete |
| Thermal | `near_thermal=...` | `Query.near_media(:thermal, media: ...)` | Complete |
| Depth | `near_depth=...` | `Query.near_media(:depth, media: ...)` | Complete |
| IMU | `near_imu=...` | `Query.near_media(:imu, media: ...)` | Complete |

---

## 11. Additional Query Features

### 11.1 Fetch Operations

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Fetch by ID | `collection.query.fetch_object_by_id(uuid)` | Via `Data.get_object(client, coll, uuid)` | Complete |
| Fetch by IDs (batch) | `collection.query.fetch_objects(ids=[...])` | Via batch/loop | Partial |
| Fetch all objects | Iterator-based | Via pagination | Complete |

### 11.2 Tenant Support

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Query with tenant | `collection.with_tenant(name)` | `Query.tenant(query, name)` | Complete |

---

## 12. Summary of Gaps

### High Priority Gaps

| Area | Gap | Impact |
|------|-----|--------|
| Hybrid Search | `bm25_operator` in hybrid queries | Limited BM25 control in hybrid mode |
| Hybrid Search | `max_vector_distance` parameter | Cannot limit vector component distance |

### Medium Priority Gaps

| Area | Gap | Impact |
|------|-----|--------|
| Vector Search | Named vector input as dict | Multi-vector queries less flexible |
| Aggregation | Metrics class for typed aggregation | Less ergonomic metrics definition |
| Aggregation | Reference aggregation | Cannot aggregate reference pointers |
| Generative | Runtime provider selection | Must configure at collection level |
| Generative | Runtime model parameters | Cannot override temp/tokens per query |

### Low Priority Gaps (Stylistic/Convenience)

| Area | Gap | Notes |
|------|-----|-------|
| Filters | Operator overloading (`&`, `\|`, `~`) | Elixir uses functions (idiomatic) |
| Filters | Fluent builder pattern | Different but functional paradigm |
| Aggregation | Near_image aggregation | Rare use case |
| All | Async variants | Elixir is inherently concurrent |

---

## 13. Recommendations

### Immediate Fixes (< 1 week)
1. Add `max_vector_distance` parameter to hybrid search
2. Add `bm25_operator` support to hybrid queries

### Short-term Improvements (1-4 weeks)
1. Implement `Metrics` module for typed aggregation building
2. Add runtime generative provider selection
3. Support named vector input as map `%{"vec1" => [...], "vec2" => [...]}`

### Long-term Enhancements
1. Consider macro-based filter DSL for more ergonomic filter building
2. Add typed response structs (GenerativeResult, AggregateResult, etc.)
3. Implement reference aggregation metrics

---

## 14. File References

### Python Files
- `/home/home/p/g/n/weaviate_ex/weaviate-python-client/weaviate/collections/queries/near_vector/query/executor.py`
- `/home/home/p/g/n/weaviate_ex/weaviate-python-client/weaviate/collections/queries/bm25/query/executor.py`
- `/home/home/p/g/n/weaviate_ex/weaviate-python-client/weaviate/collections/queries/hybrid/query/executor.py`
- `/home/home/p/g/n/weaviate_ex/weaviate-python-client/weaviate/collections/queries/near_object/query/executor.py`
- `/home/home/p/g/n/weaviate_ex/weaviate-python-client/weaviate/collections/classes/filters.py`
- `/home/home/p/g/n/weaviate_ex/weaviate-python-client/weaviate/collections/filters.py`
- `/home/home/p/g/n/weaviate_ex/weaviate-python-client/weaviate/collections/classes/aggregate.py`
- `/home/home/p/g/n/weaviate_ex/weaviate-python-client/weaviate/collections/queries/near_vector/generate/executor.py`

### Elixir Files
- `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/query.ex`
- `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/filter.ex`
- `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/api/query_advanced.ex`
- `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/api/aggregate.ex`
- `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/api/generative.ex`
- `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/query/sort.ex`
- `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/query/group_by.ex`
- `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/query/rerank.ex`
- `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/query/bm25_operator.ex`
- `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/query/generate.ex`
- `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/query/hybrid_vector.ex`

---

## Changelog

- **2025-12-29 (Updated):** Comprehensive review showing 85-90% feature coverage. Many previously "missing" features (multimodal search, HybridVector, BM25Operator) have been implemented. Updated gap assessment to reflect current state.
- **2025-12-29 (Original):** Initial gap analysis estimating 70-75% coverage.
