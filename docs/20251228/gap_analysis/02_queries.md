# Query & Search Gap Analysis

## Overview

The Elixir client provides core query functionality through `WeaviateEx.Query` but lacks several query types and advanced features available in the Python client.

## Query Types Comparison

| Query Type | Python | Elixir | Notes |
|------------|--------|--------|-------|
| `near_vector` | Yes | Yes | `WeaviateEx.Query.near_vector/3` |
| `near_text` | Yes | Yes | `WeaviateEx.Query.near_text/3` |
| `near_object` | Yes | Yes | `WeaviateEx.Query.near_object/3` |
| `near_image` | Yes | **No** | **GAP**: Image-based search |
| `near_media` | Yes | **No** | **GAP**: Multi-modal media search |
| `hybrid` | Yes | Yes | `WeaviateEx.Query.hybrid/3` |
| `bm25` | Yes | Yes | `WeaviateEx.Query.bm25/3` |
| `fetch_objects` | Yes | Yes | Via Query builder with limit/offset |
| `fetch_objects_by_ids` | Yes | **No** | **GAP**: Fetch multiple by UUIDs |
| `fetch_object_by_id` | Yes | Partial | Via Objects API |

---

## Missing Query Types

### 1. `near_image` (HIGH PRIORITY)

Search for objects similar to an image.

```python
# Python
collection.query.near_image(
    near_image=image_bytes,  # file path, base64, BufferedReader, BytesIO
    certainty=0.7,
    distance=None,
    limit=10,
    filters=...,
    return_metadata=...,
)
```

**Recommendation**: Implement `WeaviateEx.Query.near_image/3`
```elixir
# Proposed Elixir API
WeaviateEx.Query.get("Article")
|> WeaviateEx.Query.near_image(image_data, certainty: 0.7)
|> WeaviateEx.Query.limit(10)
|> WeaviateEx.Query.execute()
```

### 2. `near_media` (MEDIUM PRIORITY)

Multi-modal search supporting various media types.

```python
# Python - NearMediaType enum
AUDIO, DEPTH, IMAGE, IMU, THERMAL, VIDEO

collection.query.near_media(
    media=media_bytes,
    media_type=NearMediaType.VIDEO,
    certainty=0.7,
    ...
)
```

**Recommendation**: Implement `WeaviateEx.Query.near_media/4`

### 3. `fetch_objects_by_ids` (HIGH PRIORITY)

Fetch multiple objects by their UUIDs efficiently.

```python
# Python
collection.query.fetch_objects_by_ids(
    uuids=["uuid1", "uuid2", "uuid3"],
    include_vector=True,
    return_metadata=MetadataQuery.full(),
)
```

**Recommendation**: Implement `WeaviateEx.Objects.get_many/2` or `WeaviateEx.Query.by_ids/2`

---

## Query Parameters Comparison

### Common Parameters

| Parameter | Python | Elixir | Notes |
|-----------|--------|--------|-------|
| `limit` | Yes | Yes | |
| `offset` | Yes | Yes | |
| `certainty` | Yes | Yes | |
| `distance` | Yes | Yes | |
| `filters` | Yes | Yes | Via `where` |
| `after` | Yes | **No** | **GAP**: Cursor pagination |
| `auto_limit` | Yes | **No** | **GAP**: Auto-cut results |

### Return Options

| Option | Python | Elixir | Notes |
|--------|--------|--------|-------|
| `return_properties` | Yes | Yes | Via `fields` |
| `return_metadata` | Yes | Partial | Via `additional` |
| `return_references` | Yes | **No** | **GAP**: Deep reference fetching |
| `include_vector` | Yes | Partial | Via additional |

### Advanced Features

| Feature | Python | Elixir | Notes |
|---------|--------|--------|-------|
| `group_by` | Yes | Partial | Elixir has `WeaviateEx.Query.GroupBy` struct |
| `rerank` | Yes | Yes | Via `WeaviateEx.Query.Rerank` |
| `sort` | Yes | Partial | Elixir has `WeaviateEx.Query.Sort` |
| `target_vector` | Yes | Yes | Named vectors support |

---

## Missing: Cursor Pagination (`after`)

Python supports cursor-based pagination for memory-efficient iteration:

```python
# Python
collection.query.fetch_objects(
    after=last_uuid,
    limit=100,
)
```

**Recommendation**: Add `after` parameter to query builder

---

## Missing: Auto Limit

Python's `auto_limit` auto-cuts results at natural boundaries:

```python
# Python
collection.query.near_text(
    query="AI",
    auto_limit=3,  # Stops after 3 result "groups"
)
```

**Recommendation**: Add `auto_limit` support

---

## Missing: Deep Reference Fetching

Python allows fetching referenced objects with their properties:

```python
# Python
from weaviate.classes.query import QueryReference

collection.query.near_text(
    query="...",
    return_references=[
        QueryReference(
            link_on="hasAuthor",
            return_properties=["name", "email"],
            return_references=[  # Nested references
                QueryReference(link_on="worksFor", ...)
            ]
        )
    ]
)
```

**Recommendation**: Implement `WeaviateEx.Query.QueryReference` for nested reference fetching

---

## near_text Specific Features

| Feature | Python | Elixir | Notes |
|---------|--------|--------|-------|
| Single concept | Yes | Yes | |
| Multiple concepts | Yes | **?** | Verify list support |
| `move_to` | Yes | **?** | Move towards concepts/objects |
| `move_away` | Yes | **?** | Move away from concepts/objects |

### Missing: Move To/Away

```python
# Python
from weaviate.classes.query import Move

collection.query.near_text(
    query="technology",
    move_to=Move(force=0.5, concepts=["innovation"]),
    move_away=Move(force=0.3, objects=["uuid-of-spam"]),
)
```

**Elixir Status**: Has `WeaviateEx.Query.Move` struct - verify full integration

---

## hybrid Specific Features

| Feature | Python | Elixir | Notes |
|---------|--------|--------|-------|
| `query` | Yes | Yes | |
| `alpha` | Yes | Yes | Balance between keyword/vector |
| `vector` | Yes | **?** | Custom vector for hybrid |
| `query_properties` | Yes | **?** | Properties to search |
| `fusion_type` | Yes | Yes | `fusionType` option |
| `max_vector_distance` | Yes | **No** | **GAP** |

### Missing: HybridVector

Python supports specifying custom vectors for hybrid search:

```python
# Python
from weaviate.classes.query import HybridVector

collection.query.hybrid(
    query="technology",
    vector=HybridVector.near_text(
        query="innovation",
        move_to=Move(...)
    ),
)
```

**Elixir Status**: Has `WeaviateEx.Query.HybridVector` - verify usage

---

## bm25 Specific Features

| Feature | Python | Elixir | Notes |
|---------|--------|--------|-------|
| `query` | Yes | Yes | |
| `query_properties` | Yes | Yes | Via `properties` option |
| `operator` | Yes | **No** | **GAP**: BM25 operators |

### Missing: BM25 Operators

```python
# Python
from weaviate.classes.query import BM25Operator

collection.query.bm25(
    query="machine learning AI",
    operator=BM25Operator.and_(),  # All tokens must match
    # OR
    operator=BM25Operator.or_(minimum_match=2),  # At least 2 tokens
)
```

**Recommendation**: Add BM25 operator support

---

## Sorting

| Sort By | Python | Elixir | Notes |
|---------|--------|--------|-------|
| Property | Yes | Yes | `WeaviateEx.Query.Sort` |
| ID | Yes | **?** | |
| Creation time | Yes | **?** | |
| Update time | Yes | **?** | |
| Ascending/Descending | Yes | Yes | |

**Status**: Has basic sorting, verify all sort types

---

## Filter Operators Comparison

### Basic Operators

| Operator | Python | Elixir | Notes |
|----------|--------|--------|-------|
| `Equal` | Yes | Yes | `Filter.equal/2` |
| `NotEqual` | Yes | Yes | `Filter.not_equal/2` |
| `LessThan` | Yes | Yes | `Filter.less_than/2` |
| `LessThanEqual` | Yes | Yes | `Filter.less_or_equal/2` |
| `GreaterThan` | Yes | Yes | `Filter.greater_than/2` |
| `GreaterThanEqual` | Yes | Yes | `Filter.greater_or_equal/2` |
| `Like` | Yes | Yes | `Filter.like/2` |
| `IsNull` | Yes | Yes | `Filter.null?/1` |
| `ContainsAny` | Yes | Yes | `Filter.contains_any/2` |
| `ContainsAll` | Yes | Yes | `Filter.contains_all/2` |
| `ContainsNone` | Yes | Yes | `Filter.contains_none/2` |
| `WithinGeoRange` | Yes | Yes | `Filter.within_geo_range/3` |

### Logical Operators

| Operator | Python | Elixir | Notes |
|----------|--------|--------|-------|
| `And` | Yes | Yes | `Filter.all_of/1` |
| `Or` | Yes | Yes | `Filter.any_of/1` |
| `Not` | Yes | Yes | `Filter.not_/1` |

### Filter Targets

| Target | Python | Elixir | Notes |
|--------|--------|--------|-------|
| By property | Yes | Yes | `Filter.by_property/2` |
| By ID | Yes | Yes | `Filter.by_id/2` |
| By creation time | Yes | Yes | `Filter.by_creation_time/2` |
| By update time | Yes | Yes | `Filter.by_update_time/2` |
| By reference | Yes | Yes | `Filter.by_ref/4` |
| By reference count | Yes | Yes | `Filter.by_ref_count/3` |
| By ref multi-target | Yes | **?** | Verify support |

**Status**: Full filter operator coverage

---

## Metadata Options

| Metadata | Python | Elixir | Notes |
|----------|--------|--------|-------|
| `id` | Yes | Yes | Via `additional` |
| `creation_time` | Yes | Yes | Via `additional` |
| `last_update_time` | Yes | Yes | Via `additional` |
| `distance` | Yes | Yes | Via `additional` |
| `certainty` | Yes | Yes | Via `additional` |
| `score` | Yes | Yes | For BM25/hybrid |
| `explain_score` | Yes | **?** | |
| `is_consistent` | Yes | **?** | |
| `vector` | Yes | Yes | Via `additional` |
| `vectors` (named) | Yes | Yes | Via `additional` |

---

## Group By

| Feature | Python | Elixir | Notes |
|---------|--------|--------|-------|
| Group by property | Yes | Yes | `WeaviateEx.Query.GroupBy` |
| Objects per group | Yes | Yes | |
| Number of groups | Yes | Yes | |

**Status**: Full coverage via `WeaviateEx.Query.GroupBy`

---

## Aggregation Queries

| Query Type | Python | Elixir | Notes |
|------------|--------|--------|-------|
| `over_all` | Yes | Yes | `WeaviateEx.API.Aggregate.over_all/3` |
| `with_near_text` | Yes | Yes | `WeaviateEx.API.Aggregate.with_near_text/4` |
| `with_near_vector` | Yes | Yes | `WeaviateEx.API.Aggregate.with_near_vector/4` |
| `with_near_object` | Yes | **?** | |
| `with_near_image` | Yes | **No** | **GAP** |
| `with_hybrid` | Yes | **?** | |
| `with_where` | Yes | Yes | `WeaviateEx.API.Aggregate.with_where/4` |
| `group_by` | Yes | Yes | `WeaviateEx.API.Aggregate.group_by/4` |

### Metrics

| Metric Type | Python | Elixir | Notes |
|-------------|--------|--------|-------|
| `count` | Yes | Yes | |
| `sum` | Yes | Yes | |
| `mean` | Yes | Yes | |
| `median` | Yes | Yes | |
| `mode` | Yes | Yes | |
| `maximum` | Yes | Yes | |
| `minimum` | Yes | Yes | |
| `topOccurrences` | Yes | Yes | |
| `percentageTrue` | Yes | Yes | |
| `percentageFalse` | Yes | Yes | |
| `totalTrue` | Yes | Yes | |
| `totalFalse` | Yes | Yes | |

**Status**: Full metric coverage

---

## Generative Search (RAG)

| Feature | Python | Elixir | Notes |
|---------|--------|--------|-------|
| Single prompt | Yes | Yes | `WeaviateEx.API.Generative.single_prompt/4` |
| Grouped task | Yes | Yes | `WeaviateEx.API.Generative.grouped_task/4` |
| Property interpolation | Yes | Yes | `{property}` syntax |
| Provider selection | Yes | Yes | 20+ providers |
| Model selection | Yes | Yes | |
| Temperature | Yes | Yes | |
| Max tokens | Yes | Yes | |
| Top P | Yes | Yes | |

**Status**: Full generative search coverage

---

## Summary of Query Gaps

### High Priority
1. **`near_image`** - Image-based semantic search
2. **`fetch_objects_by_ids`** - Batch fetch by UUIDs
3. **`return_references`** - Deep reference fetching
4. **Cursor pagination (`after`)** - Memory-efficient iteration

### Medium Priority
1. **`near_media`** - Multi-modal media search
2. **`auto_limit`** - Auto-cut results
3. **`max_vector_distance`** for hybrid - Distance threshold
4. **BM25 operators** - AND/OR with minimum match

### Low Priority
1. Verify all sort types (by ID, timestamps)
2. Verify move_to/move_away integration
3. `explain_score` and `is_consistent` metadata
