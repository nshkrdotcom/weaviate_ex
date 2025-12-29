# Query and Search API Gap Analysis

## Executive Summary

This document provides a comprehensive gap analysis between the Weaviate Python client's query implementation and the WeaviateEx Elixir port. The analysis examines vector search, hybrid search, BM25 keyword search, filters, aggregations, grouping, generative search (RAG), reranking, and query builder patterns.

**Overall Assessment**: The Elixir port implements approximately **70-75%** of the Python client's query functionality. Core search operations (near_text, near_vector, near_object, hybrid, bm25) are well-implemented. However, there are significant gaps in multimodal search, advanced filter features, and some aggregation capabilities.

### Key Findings

| Category | Python Client | Elixir Port | Gap Level |
|----------|---------------|-------------|-----------|
| Vector Search (Basic) | Full | Full | **None** |
| Vector Search (Advanced) | Full | Partial | **Medium** |
| Hybrid Search | Full | Full | **None** |
| BM25 Keyword Search | Full | Partial | **Low** |
| Filters & Operators | Full | Partial | **Medium** |
| Aggregations | Full | Partial | **High** |
| Grouping | Full | Full | **None** |
| Generative Search (RAG) | Full | Full | **None** |
| Reranking | Full | Full | **None** |
| Multimodal Search | Full | **Missing** | **Critical** |
| Query Builder Pattern | OOP/Fluent | Functional/Fluent | **Different Style** |

---

## Feature-by-Feature Comparison

### 1. Vector Search

#### 1.1 near_vector

| Feature | Python Client | Elixir Port | Status |
|---------|---------------|-------------|--------|
| Basic vector search | Yes | Yes | Implemented |
| Certainty threshold | Yes | Yes | Implemented |
| Distance threshold | Yes | Yes | Implemented |
| Target vectors (named vectors) | Yes | Partial | **Gap** - `TargetVectors` module exists but not integrated into query execution |
| Multi-vector queries | Yes (`NearVector.list_of_vectors`) | No | **Missing** |
| 2D vector support | Yes | No | **Missing** |

**Python Implementation** (`weaviate/collections/queries/near_vector/query/executor.py`):
```python
def near_vector(
    self,
    near_vector: NearVectorInputType,  # Supports 1D, 2D, or dict of named vectors
    certainty: Optional[float] = None,
    distance: Optional[float] = None,
    target_vector: Optional[TargetVectorJoinType] = None,
    ...
)
```

**Elixir Implementation** (`lib/weaviate_ex/query.ex`):
```elixir
def near_vector(%__MODULE__{} = query, vector, opts \\ []) when is_list(vector) do
  params = %{vector: vector}
  params = if opts[:certainty], do: Map.put(params, :certainty, opts[:certainty]), else: params
  params = if opts[:distance], do: Map.put(params, :distance, opts[:distance]), else: params
  %{query | near_vector: params}
end
```

**Gap**: Elixir lacks:
- Named vector targeting in query execution
- Multi-vector list queries
- 2D vector support for multi-vector spaces

#### 1.2 near_text

| Feature | Python Client | Elixir Port | Status |
|---------|---------------|-------------|--------|
| Basic text search | Yes | Yes | Implemented |
| Certainty/Distance | Yes | Yes | Implemented |
| moveTo concepts | Yes | Yes | Implemented |
| moveAwayFrom concepts | Yes | Yes | Implemented |
| moveTo/moveAwayFrom objects | Yes | Yes | Implemented |
| Target vectors | Yes | No | **Missing** |

**Both implementations support Move operations:**

Python:
```python
Move(force=0.5, concepts=["summer"], objects=["uuid"])
```

Elixir:
```elixir
Move.to(0.5, concepts: ["summer"], objects: ["uuid"])
```

#### 1.3 near_object

| Feature | Python Client | Elixir Port | Status |
|---------|---------------|-------------|--------|
| Basic object similarity | Yes | Yes | Implemented |
| Certainty/Distance | Yes | Yes | Implemented |
| Target vectors | Yes | No | **Missing** |

### 2. Hybrid Search

| Feature | Python Client | Elixir Port | Status |
|---------|---------------|-------------|--------|
| Basic hybrid query | Yes | Yes | Implemented |
| Alpha weighting | Yes | Yes | Implemented |
| Fusion type (ranked) | Yes | Yes | Implemented |
| Fusion type (relative score) | Yes | Yes | Implemented |
| Vector sub-search | Yes (`HybridVector.near_vector`) | No | **Missing** |
| Text sub-search | Yes (`HybridVector.near_text`) | No | **Missing** |
| Properties filter for BM25 | Yes | No | **Missing** |
| Target vectors | Yes | No | **Missing** |

**Python Advanced Hybrid Features**:
```python
# Python supports explicit vector/text sub-searches in hybrid
collection.query.hybrid(
    query="text",
    vector=HybridVector.near_text("concepts", move_to=Move(...)),
    alpha=0.5,
    fusion_type=HybridFusion.RELATIVE_SCORE
)
```

**Gap**: Elixir hybrid only supports basic query string, not advanced sub-search configuration.

### 3. BM25 Keyword Search

| Feature | Python Client | Elixir Port | Status |
|---------|---------------|-------------|--------|
| Basic keyword search | Yes | Yes | Implemented |
| Properties filter | Yes | Yes | Implemented |
| BM25 Operator (And) | Yes (`BM25OperatorFactory.and_()`) | No | **Missing** |
| BM25 Operator (Or with min match) | Yes (`BM25OperatorFactory.or_(min)`) | No | **Missing** |

**Python BM25 Operator Support**:
```python
@dataclass
class BM25OperatorOr(BM25OperatorOptions):
    operator = base_search_pb2.SearchOperatorOptions.OPERATOR_OR
    minimum_should_match: int

@dataclass
class BM25OperatorAnd(BM25OperatorOptions):
    operator = base_search_pb2.SearchOperatorOptions.OPERATOR_AND
```

### 4. Multimodal Search (Critical Gap)

| Feature | Python Client | Elixir Port | Status |
|---------|---------------|-------------|--------|
| near_image | Yes (full implementation) | **No** | **Missing** |
| near_media (audio/video/thermal/depth/IMU) | Yes | **No** | **Missing** |

**Python Multimodal Types** (`weaviate/collections/classes/grpc.py`):
```python
class NearMediaType(str, Enum):
    AUDIO = "audio"
    DEPTH = "depth"
    IMAGE = "image"
    IMU = "imu"
    THERMAL = "thermal"
    VIDEO = "video"
```

**Recommendation**: Implement `near_image` and `near_media` modules for multimodal search support.

### 5. Filters and Operators

#### 5.1 Operators Comparison

| Operator | Python Client | Elixir Port | Status |
|----------|---------------|-------------|--------|
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
| ContainsNone | Yes (native operator) | Yes (via NOT ContainsAny) | Implemented differently |
| WithinGeoRange | Yes | Yes | Implemented |
| And/Or/Not combinators | Yes | Yes | Implemented |

#### 5.2 Filter Target Types

| Target Type | Python Client | Elixir Port | Status |
|-------------|---------------|-------------|--------|
| By property | Yes | Yes | Implemented |
| By ID | Yes | Yes | Implemented |
| By creation time | Yes | Yes | Implemented |
| By update time | Yes | Yes | Implemented |
| By reference | Yes | Partial | **Partial** |
| By reference count | Yes | Yes | Implemented |
| By multi-target reference | Yes | No | **Missing** |
| By property length | Yes (`length=True`) | No | **Missing** |

#### 5.3 Filter API Patterns

**Python (OOP with operator overloading)**:
```python
# Operator overloading for filter composition
filter1 & filter2  # AND
filter1 | filter2  # OR
~filter1           # NOT

# Fluent chaining through references
Filter.by_ref("author").by_property("name").equal("John")
```

**Elixir (Functional composition)**:
```elixir
# Explicit combinator functions
Filter.all_of([filter1, filter2])  # AND
Filter.any_of([filter1, filter2])  # OR
Filter.not_(filter1)               # NOT

# Simple function-based API
Filter.equal("name", "John")
Filter.by_ref("author", "Author", :equal, "John")
```

**Gap**: Python's filter chaining through references is more sophisticated. The Elixir version doesn't support deep reference path traversal.

### 6. Aggregations

#### 6.1 Aggregation Types

| Aggregation Type | Python Client | Elixir Port | Status |
|------------------|---------------|-------------|--------|
| over_all (basic) | Yes | Yes | Implemented |
| near_text | Yes | Yes | Implemented |
| near_vector | Yes | Yes | Implemented |
| near_object | Yes | No | **Missing** |
| near_image | Yes | No | **Missing** |
| hybrid | Yes | No | **Missing** |

#### 6.2 Aggregation Metrics

| Metric | Python Client | Elixir Port | Status |
|--------|---------------|-------------|--------|
| count | Yes | Yes | Implemented |
| sum | Yes | Yes | Implemented |
| mean | Yes | Yes | Implemented |
| median | Yes | Yes | Implemented |
| mode | Yes | Yes | Implemented |
| maximum | Yes | Yes | Implemented |
| minimum | Yes | Yes | Implemented |
| topOccurrences | Yes | Yes | Implemented |
| percentageTrue/False | Yes | Yes | Implemented |
| totalTrue/False | Yes | Yes | Implemented |
| reference.pointingTo | Yes | No | **Missing** |

#### 6.3 Metrics Builder Pattern

**Python (Type-safe metrics builder)**:
```python
Metrics("price").integer(count=True, mean=True, sum_=True)
Metrics("category").text(top_occurrences_count=True, limit=5)
Metrics("isActive").boolean(percentage_true=True)
Metrics("createdAt").date_(minimum=True, maximum=True)
```

**Elixir (Tuple-based)**:
```elixir
properties: [
  {:price, [:sum, :mean, :maximum, :minimum]},
  {:category, [:topOccurrences], limit: 5}
]
```

**Gap**: Python's `Metrics` class provides type-safe, per-data-type metric specifications. Elixir uses a simpler but less type-safe approach.

### 7. Grouping

| Feature | Python Client | Elixir Port | Status |
|---------|---------------|-------------|--------|
| GroupBy property | Yes | Yes | Implemented |
| Objects per group | Yes | Yes | Implemented |
| Number of groups | Yes | Yes | Implemented |
| Nested property path | Yes | Yes | Implemented |

**Python**:
```python
GroupBy(prop="category", objects_per_group=5, number_of_groups=10)
```

**Elixir**:
```elixir
GroupBy.new("category", objects_per_group: 5, number_of_groups: 10)
```

### 8. Generative Search (RAG)

| Feature | Python Client | Elixir Port | Status |
|---------|---------------|-------------|--------|
| Single prompt (per-object) | Yes | Yes | Implemented |
| Grouped task (all results) | Yes | Yes | Implemented |
| Grouped properties | Yes | Yes | Implemented |
| All search types supported | Yes | Yes | Implemented |
| Error handling in response | Yes | Yes | Implemented |

**Both implementations well-aligned**:

Python:
```python
collection.generate.near_text(
    query="AI",
    single_prompt="Summarize {title}",
    grouped_task="Write overview",
    grouped_properties=["title", "content"]
)
```

Elixir:
```elixir
Generate.new("Article")
|> Generate.near_text("AI")
|> Generate.single_prompt("Summarize {title}")
|> Generate.grouped_task("Write overview", properties: ["title", "content"])
```

### 9. Reranking

| Feature | Python Client | Elixir Port | Status |
|---------|---------------|-------------|--------|
| Rerank by property | Yes | Yes | Implemented |
| Custom rerank query | Yes | Yes | Implemented |
| Score in response | Yes | Yes | Implemented |

**Python**:
```python
Rerank(prop="content", query="machine learning")
```

**Elixir**:
```elixir
Rerank.new("content", query: "machine learning")
```

### 10. Return Properties and Metadata

#### 10.1 Metadata Options

| Metadata Field | Python Client | Elixir Port | Status |
|----------------|---------------|-------------|--------|
| id/uuid | Yes | Yes | Implemented |
| creation_time | Yes | Yes | Implemented |
| last_update_time | Yes | Yes | Implemented |
| distance | Yes | Yes | Implemented |
| certainty | Yes | Yes | Implemented |
| score | Yes | Yes | Implemented |
| explain_score | Yes | Yes | Implemented |
| is_consistent | Yes | Yes | Implemented |
| vector | Yes | Yes | Implemented |
| named vectors | Yes | No | **Missing** |

**Python MetadataQuery**:
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

**Elixir Metadata**:
```elixir
Metadata.full()      # All fields
Metadata.common()    # id, distance, certainty, score
Metadata.timestamps() # creation/update times
```

#### 10.2 Query References (Cross-references)

| Feature | Python Client | Elixir Port | Status |
|---------|---------------|-------------|--------|
| Single-target reference | Yes | Yes | Implemented |
| Multi-target reference | Yes | No | **Missing** |
| Nested references | Yes | Yes | Implemented |
| Include vector in ref | Yes | Yes | Implemented |
| Return metadata in ref | Yes | No | **Missing** |

**Python QueryReference**:
```python
QueryReference(
    link_on="hasAuthor",
    include_vector=True,
    return_metadata=MetadataQuery.full(),
    return_properties=["name"],
    return_references=[nested_ref]
)
QueryReference.MultiTarget(link_on="hasCategory", target_collection="Category")
```

**Elixir QueryReference**:
```elixir
QueryReference.new("hasAuthor",
  return_properties: ["name"],
  return_references: [nested_ref],
  include_vector: true
)
```

**Gap**: Elixir lacks multi-target reference support and return_metadata for references.

### 11. Sorting

| Feature | Python Client | Elixir Port | Status |
|---------|---------------|-------------|--------|
| By property | Yes | Yes | Implemented |
| By ID | Yes | Yes | Implemented |
| By creation time | Yes | Yes | Implemented |
| By update time | Yes | Yes | Implemented |
| Ascending/Descending | Yes | Yes | Implemented |
| Multiple sort criteria | Yes | Yes | Implemented |

Both implementations are feature-complete for sorting.

### 12. Pagination

| Feature | Python Client | Elixir Port | Status |
|---------|---------------|-------------|--------|
| Limit | Yes | Yes | Implemented |
| Offset | Yes | Yes | Implemented |
| Cursor-based (after) | Yes | Yes | Implemented |
| Auto-limit (autocut) | Yes | Yes | Implemented |

### 13. Multi-tenancy

| Feature | Python Client | Elixir Port | Status |
|---------|---------------|-------------|--------|
| Tenant parameter | Yes | Yes | Implemented |

---

## Missing Features in Elixir Port

### Critical Priority (P0)

1. **Multimodal Search**
   - `near_image` - Image-based vector search
   - `near_media` - Audio, video, thermal, depth, IMU search
   - Required for multi2vec-clip, multi2vec-bind modules

### High Priority (P1)

2. **Advanced Hybrid Search**
   - `HybridVector.near_text()` - Text sub-search with Move support
   - `HybridVector.near_vector()` - Vector sub-search in hybrid
   - Properties filter for BM25 component

3. **BM25 Operators**
   - `BM25OperatorFactory.and_()` - All tokens must match
   - `BM25OperatorFactory.or_(min)` - Minimum token match

4. **Named Vector Support**
   - Target vector in near_vector, near_text, near_object
   - Multi-target vector joins (sum, average, minimum, manual weights)
   - Multi-vector list queries

5. **Aggregation Enhancements**
   - `near_object` aggregation
   - `near_image` aggregation
   - `hybrid` aggregation
   - Reference pointing_to metric

### Medium Priority (P2)

6. **Filter Enhancements**
   - Multi-target reference filters
   - Property length filtering (`len(property)`)
   - Deep reference path traversal (fluent API)

7. **Query Reference Enhancements**
   - Multi-target reference support
   - Return metadata option for references

8. **Type-safe Metrics Builder**
   - Per-data-type metric specifications
   - Integer, Number, Text, Boolean, Date metric classes

### Low Priority (P3)

9. **2D Vector Support**
   - Two-dimensional vector inputs
   - Multi-vector space queries

---

## Implementation Differences

### 1. API Pattern

| Aspect | Python Client | Elixir Port |
|--------|---------------|-------------|
| Style | Object-Oriented | Functional |
| Builder Pattern | Method chaining on objects | Pipe operator with structs |
| Filter Composition | Operator overloading (&, |, ~) | Explicit combinator functions |
| Type Safety | Pydantic models, dataclasses | Structs with @spec |
| Async Support | Separate async classes | Inherent in Elixir/OTP |

### 2. Execution Model

**Python**:
- Synchronous by default with async variants
- Connection pooling via `weaviate.connect_to_*`
- gRPC/REST selection based on Weaviate version

**Elixir**:
- Async-first with GenServer-based client
- gRPC channel management via Client struct
- Automatic fallback from gRPC to HTTP/GraphQL

### 3. Response Parsing

**Python**: Returns typed dataclasses (`QueryReturn`, `AggregateReturn`, etc.)

**Elixir**: Returns maps with string keys, following GraphQL response structure

---

## Recommendations for Closing Gaps

### Phase 1: Critical Features (Estimated: 2-3 weeks)

1. **Implement near_image module**
   ```elixir
   defmodule WeaviateEx.Query.NearImage do
     # Support base64, file path, URL inputs
     # Image encoding utilities
   end
   ```

2. **Implement near_media module**
   ```elixir
   defmodule WeaviateEx.Query.NearMedia do
     @media_types [:audio, :video, :thermal, :depth, :imu]
   end
   ```

### Phase 2: Advanced Search (Estimated: 2 weeks)

3. **Enhance HybridVector support**
   - Add `HybridVector` module with `near_text/near_vector` functions
   - Integrate Move operations into hybrid text sub-search

4. **Add BM25 operators**
   ```elixir
   defmodule WeaviateEx.Query.BM25Operator do
     def and_(), do: %{operator: :and}
     def or_(min_match), do: %{operator: :or, minimum_should_match: min_match}
   end
   ```

### Phase 3: Named Vectors (Estimated: 1-2 weeks)

5. **Integrate TargetVectors into query execution**
   - Add `target_vector` option to near_vector, near_text, near_object
   - Implement multi-target vector joins in gRPC layer

### Phase 4: Filter and Aggregation Enhancements (Estimated: 2 weeks)

6. **Enhance Filter module**
   - Add multi-target reference support
   - Add property length filtering
   - Consider fluent reference traversal API

7. **Complete Aggregation module**
   - Add near_object, near_image, hybrid aggregations
   - Add reference.pointingTo metric
   - Consider type-safe Metrics builder

### Phase 5: Polish (Estimated: 1 week)

8. **QueryReference enhancements**
   - Multi-target reference
   - Return metadata option

9. **Documentation and examples**
   - Update all module docs with new features
   - Add integration tests for new functionality

---

## Conclusion

The WeaviateEx Elixir port provides a solid foundation with good coverage of core search functionality. The main gaps are:

1. **Multimodal search** (critical for AI/ML applications)
2. **Advanced hybrid search** (HybridVector sub-searches)
3. **Named vector support** (multi-vector spaces)
4. **BM25 operators** (advanced keyword matching)

The functional/pipe-based API is idiomatic for Elixir and works well. The existing architecture should accommodate these additions without major refactoring.

**Estimated total effort to reach feature parity: 6-8 weeks**
