# Data Operations Gap Analysis

## Executive Summary

This document provides a comprehensive analysis of data operation features between the Python canonical Weaviate client and the Elixir port (WeaviateEx). Data operations encompass CRUD (Create, Read, Update, Delete) operations on individual objects, references, and iteration/cursor-based fetching.

**Overall Assessment**: The Elixir implementation covers the core data operations but has significant gaps in advanced features like typed return models, comprehensive metadata handling, multi-vector support, and sophisticated iterator patterns.

| Category | Python Features | Elixir Status |
|----------|-----------------|---------------|
| Single Object Insert | Complete | Implemented |
| Single Object Update (Replace) | Complete | Implemented |
| Single Object Patch | Complete | Implemented |
| Object Delete | Complete | Implemented |
| Object Get by ID | Complete | Partial |
| Object Exists Check | Complete | Implemented |
| Reference Add/Update/Delete | Complete | Implemented |
| Multi-target References | Complete | Implemented |
| Iterator/Cursor-based Fetching | Complete | Partial |
| Object Validation | Complete | Implemented |
| Vector Handling | Complete | Partial |
| Cross-reference Management | Complete | Partial |
| Object Metadata | Complete | Partial |

---

## 1. Single Object Insert

### Python Implementation

**File**: `weaviate-python-client/weaviate/collections/data/executor.py`

```python
def insert(
    self,
    properties: Properties,
    references: Optional[ReferenceInputs] = None,
    uuid: Optional[UUID] = None,
    vector: Optional[VECTORS] = None,
) -> executor.Result[uuid_package.UUID]:
    """Insert a single object into the collection."""
```

**Features**:
- Typed properties with generic `Properties` type parameter
- Optional references during insertion
- Optional UUID (auto-generated if not provided)
- Support for multiple vector formats:
  - Single vectors: `list`, `numpy.ndarray`, `torch.Tensor`, `tf.Tensor`, `pd.Series`, `pl.Series`
  - Named vectors: `Dict[str, *vector_type*]`
- Input validation with `_validate_input`
- Automatic property serialization (datetime, GeoCoordinate, PhoneNumber, nested objects)
- Multi-tenancy support via tenant parameter
- Consistency level configuration

### Elixir Implementation

**File**: `lib/weaviate_ex/api/data.ex`

```elixir
@spec insert(Client.t(), collection_name(), object_data(), opts()) ::
        {:ok, map()} | {:error, Error.t()}
def insert(client, collection_name, data, opts \\ []) do
  payload_opts = Keyword.take(opts, [:auto_generate_id])
  body = data |> Payload.prepare_for_insert(collection_name, payload_opts)
  path = "/v1/objects" <> build_query_string(opts, [:tenant, :consistency_level])
  Client.request(client, :post, path, body, opts)
end
```

**Features**:
- Basic property insertion
- Optional ID (auto-generated via `Uniq.UUID`)
- Vector support (single vectors only)
- Multi-tenancy support
- Consistency level configuration

### Gap Analysis

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Properties insertion | Yes | Yes | None |
| Auto-generated UUID | Yes | Yes | None |
| Custom UUID | Yes | Yes | None |
| Single vector | Yes | Yes | None |
| Named vectors | Yes | No | **Missing** |
| Multi-vectors (per named vector) | Yes | No | **Missing** |
| numpy/torch/tf tensor support | Yes | N/A | N/A (language-specific) |
| References during insert | Yes | No | **Missing** |
| Property validation | Yes | No | **Missing** |
| DateTime serialization | Yes | Manual | **Partial** |
| GeoCoordinate support | Yes | No | **Missing** |
| PhoneNumber support | Yes | No | **Missing** |
| Nested object serialization | Yes | Manual | **Partial** |
| Type-safe return (UUID) | Yes | No | **Missing** |

### Code Examples

**Python**:
```python
# Insert with named vectors
uuid = collection.data.insert(
    properties={"title": "Article", "content": "..."},
    references={"hasAuthor": author_uuid},
    vector={"title_vector": [0.1, 0.2], "content_vector": [0.3, 0.4]}
)

# Insert with GeoCoordinate
from weaviate.classes.data import GeoCoordinate
uuid = collection.data.insert(
    properties={"location": GeoCoordinate(latitude=52.5, longitude=13.4)}
)
```

**Elixir**:
```elixir
# Current implementation - single vector only
{:ok, object} = Data.insert(client, "Article", %{
  properties: %{"title" => "Article", "content" => "..."},
  vector: [0.1, 0.2, 0.3]
}, tenant: "TenantA")

# Missing: named vectors, references during insert
```

### Priority: HIGH
Named vectors and references during insert are commonly used features.

---

## 2. Single Object Update (Full Replace)

### Python Implementation

```python
def replace(
    self,
    uuid: UUID,
    properties: Properties,
    references: Optional[ReferenceInputs] = None,
    vector: Optional[VECTORS] = None,
) -> executor.Result[None]:
    """Replace an object in the collection (PUT operation)."""
```

**Features**:
- Full object replacement via PUT
- UUID required
- Properties required
- Optional references
- Named vector support
- All property serialization features

### Elixir Implementation

```elixir
@spec replace(Client.t(), collection_name(), object_id(), object_data(), opts()) ::
        {:ok, map()} | {:error, Error.t()}
def replace(client, collection_name, id, data, opts \\ []) do
  update(client, collection_name, id, data, opts)
end

# update/5 uses PUT
def update(client, collection_name, id, data, opts \\ []) do
  body = Payload.prepare_for_update(data, collection_name, id, payload_opts)
  path = "/v1/objects/#{collection_name}/#{id}" <> build_query_string(opts, [:tenant, :consistency_level])
  Client.request(client, :put, path, body, opts)
end
```

**Features**:
- Full object replacement
- UUID required
- Properties update
- `keep_vector` option
- Multi-tenancy support

### Gap Analysis

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Full replacement (PUT) | Yes | Yes | None |
| Properties update | Yes | Yes | None |
| References update | Yes | No | **Missing** |
| Named vectors | Yes | No | **Missing** |
| Multi-vectors | Yes | No | **Missing** |
| Keep existing vector | Implicit | Yes (`:keep_vector`) | Enhanced |

### Priority: MEDIUM

---

## 3. Single Object Patch (Partial Update)

### Python Implementation

```python
def update(
    self,
    uuid: UUID,
    properties: Optional[Properties] = None,
    references: Optional[ReferenceInputs] = None,
    vector: Optional[VECTORS] = None,
) -> executor.Result[None]:
    """Update an object in the collection (PATCH operation)."""
```

**Features**:
- Partial update via PATCH
- All properties optional
- Optional references
- Named vector support

### Elixir Implementation

```elixir
@spec patch(Client.t(), collection_name(), object_id(), object_data(), opts()) ::
        {:ok, map()} | {:error, Error.t()}
def patch(client, collection_name, id, data, opts \\ []) do
  body = data
    |> Payload.prepare_for_patch()
    |> Map.drop(["vector", :vector])
  # PATCH returns 204, so we GET the updated object
  case Client.request(client, :patch, path, body, opts) do
    {:ok, _} -> get_by_id(client, collection_name, id, opts)
    error -> error
  end
end
```

**Features**:
- Partial update via PATCH
- Automatic retrieval after patch
- Vector explicitly excluded from patch

### Gap Analysis

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Partial update (PATCH) | Yes | Yes | None |
| Optional properties | Yes | Yes | None |
| References update | Yes | No | **Missing** |
| Vector update | Yes | No (explicitly dropped) | **Missing** |
| Named vectors | Yes | No | **Missing** |
| Auto-fetch after patch | No | Yes | Enhanced |

### Code Examples

**Python**:
```python
# Partial update with vector
collection.data.update(
    uuid=object_uuid,
    properties={"title": "Updated Title"},
    vector={"title_vector": [0.5, 0.6, 0.7]}
)
```

**Elixir**:
```elixir
# Current - vector updates not supported in patch
{:ok, patched} = Data.patch(client, "Article", uuid, %{
  properties: %{"title" => "Updated Title"}
})
```

### Priority: MEDIUM
Vector updates in patch operations should be supported.

---

## 4. Object Delete

### Python Implementation

```python
def delete_by_id(self, uuid: UUID) -> executor.Result[bool]:
    """Delete an object from the collection based on its UUID."""

def delete_many(
    self, where: _Filters, *, verbose: bool = False, dry_run: bool = False
) -> executor.Result[DeleteManyReturn]:
    """Delete multiple objects based on a filter."""
```

**Features**:
- Single delete by UUID
- Batch delete with filters
- Verbose mode (return deleted objects)
- Dry run mode
- Returns `bool` for single delete (success/not found)
- Returns `DeleteManyReturn` for batch delete

### Elixir Implementation

```elixir
@spec delete_by_id(Client.t(), collection_name(), object_id(), opts()) ::
        {:ok, map()} | {:error, Error.t()}
def delete_by_id(client, collection_name, id, opts \\ []) do
  path = "/v1/objects/#{collection_name}/#{id}" <> build_query_string(opts, [:tenant, :consistency_level])
  Client.request(client, :delete, path, nil, opts)
end

# Batch delete in WeaviateEx.API.Batch
def delete_objects(client, criteria, opts \\ [])
```

### Gap Analysis

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Delete by UUID | Yes | Yes | None |
| Return boolean | Yes | No (returns map) | Minor |
| Batch delete with filters | Yes | Yes (via Batch API) | None |
| Verbose mode | Yes | Yes | None |
| Dry run mode | Yes | Yes | None |
| gRPC support for batch delete | Yes | Yes | None |

### Priority: LOW

---

## 5. Object Get by ID

### Python Implementation

```python
# In fetch_object_by_id/executor.py
def fetch_object_by_id(
    self,
    uuid: UUID,
    include_vector: INCLUDE_VECTOR = False,
    *,
    return_properties: Optional[ReturnProperties[TProperties]] = None,
    return_references: Optional[ReturnReferences[TReferences]] = None,
) -> executor.Result[QuerySingleReturn]:
    """Retrieve an object from the server by its UUID."""
```

**Features**:
- UUID-based retrieval
- Optional vector inclusion (bool, str, or List[str] for named vectors)
- Typed property return (generic `TProperties`)
- Typed reference return (generic `TReferences`)
- Cross-reference expansion with `return_references`
- Metadata auto-fetched (creation_time, last_update_time, is_consistent)
- Uses gRPC for retrieval

### Elixir Implementation

```elixir
@spec get_by_id(Client.t(), collection_name(), object_id(), opts()) ::
        {:ok, map()} | {:error, Error.t()}
def get_by_id(client, collection_name, id, opts \\ []) do
  path = "/v1/objects/#{collection_name}/#{id}" <>
    build_query_string(opts, [:tenant, :consistency_level, :include])
  Client.request(client, :get, path, nil, opts)
end
```

**Features**:
- UUID-based retrieval
- REST API (not gRPC)
- `include` parameter for vector
- Multi-tenancy support

### Gap Analysis

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Get by UUID | Yes | Yes | None |
| Include vector (bool) | Yes | Yes | None |
| Include named vectors (str/list) | Yes | No | **Missing** |
| Typed properties return | Yes | No | **Missing** |
| Typed references return | Yes | No | **Missing** |
| Cross-reference expansion | Yes | No | **Missing** |
| gRPC support | Yes | No | **Missing** |
| Metadata (creation_time) | Yes (auto) | Manual (`include` param) | **Partial** |
| Metadata (last_update_time) | Yes (auto) | Manual (`include` param) | **Partial** |
| Metadata (is_consistent) | Yes (auto) | No | **Missing** |

### Code Examples

**Python**:
```python
# Get with cross-references expanded
from weaviate.classes.query import QueryReference

obj = collection.query.fetch_object_by_id(
    uuid=object_uuid,
    include_vector=["title_vector"],  # Named vector
    return_references=QueryReference(
        link_on="hasAuthor",
        return_properties=["name"]
    )
)
print(obj.properties["title"])
print(obj.metadata.creation_time)
print(obj.references["hasAuthor"].objects[0].properties["name"])
```

**Elixir**:
```elixir
# Current implementation - basic retrieval
{:ok, object} = Data.get_by_id(client, "Article", uuid,
  include: "vector"
)
# object["properties"]["title"]
# No automatic metadata or reference expansion
```

### Priority: HIGH
Cross-reference expansion and metadata are important for practical use.

---

## 6. Object Exists Check

### Python Implementation

```python
def exists(self, uuid: UUID) -> executor.Result[bool]:
    """Check for existence of a single object in the collection."""
    # Uses HEAD request, returns True for 204, False for 404
```

### Elixir Implementation

```elixir
@spec exists?(Client.t(), collection_name(), object_id(), opts()) ::
        {:ok, boolean()}
def exists?(client, collection_name, id, opts \\ []) do
  path = "/v1/objects/#{collection_name}/#{id}" <>
    build_query_string(opts, [:tenant, :consistency_level])
  case Client.request(client, :head, path, nil, opts) do
    {:ok, _} -> {:ok, true}
    {:error, %Error{type: :not_found}} -> {:ok, false}
    {:error, _} -> {:ok, false}
  end
end
```

### Gap Analysis

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| HEAD request check | Yes | Yes | None |
| Return boolean | Yes | Yes | None |
| Multi-tenancy | Yes | Yes | None |
| Consistency level | Yes | Yes | None |

**Status: COMPLETE** - Feature parity achieved.

### Priority: NONE

---

## 7. Reference Add/Update/Delete

### Python Implementation

```python
def reference_add(
    self,
    from_uuid: UUID,
    from_property: str,
    to: SingleReferenceInput,  # UUID or ReferenceToMulti
) -> executor.Result[None]:
    """Create a reference between objects."""

def reference_add_many(
    self,
    refs: List[DataReferences],
) -> executor.Result[BatchReferenceReturn]:
    """Create multiple references in batch."""

def reference_delete(
    self,
    from_uuid: UUID,
    from_property: str,
    to: SingleReferenceInput,
) -> executor.Result[None]:
    """Delete a reference from an object."""

def reference_replace(
    self,
    from_uuid: UUID,
    from_property: str,
    to: ReferenceInput,  # UUID, List[UUID], or ReferenceToMulti
) -> executor.Result[None]:
    """Replace all references on a property."""
```

### Elixir Implementation

**File**: `lib/weaviate_ex/api/references.ex`

```elixir
@spec add(Client.t(), String.t(), uuid(), String.t(), reference_input(), keyword()) ::
        {:ok, map()} | {:error, Error.t()}
def add(client, collection, from_uuid, from_property, to, opts \\ [])

@spec delete(Client.t(), String.t(), uuid(), String.t(), reference_input(), keyword()) ::
        {:ok, map()} | {:error, Error.t()}
def delete(client, collection, from_uuid, from_property, to, opts \\ [])

@spec replace(Client.t(), String.t(), uuid(), String.t(), [reference_input()], keyword()) ::
        {:ok, map()} | {:error, Error.t()}
def replace(client, collection, from_uuid, from_property, references, opts \\ [])

@spec add_many(Client.t(), String.t(), [data_reference()], keyword()) ::
        {:ok, map()} | {:error, Error.t()}
def add_many(client, collection, references, opts \\ [])
```

### Gap Analysis

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Add single reference | Yes | Yes | None |
| Add multi-target reference | Yes | Yes | None |
| Delete single reference | Yes | Yes | None |
| Delete multi-target reference | Yes | Yes | None |
| Replace references | Yes | Yes | None |
| Batch add references | Yes | Yes | None |
| Async concurrent add | Yes | No | Minor |
| One-to-many validation | Yes | No | **Missing** |
| Typed return (BatchReferenceReturn) | Yes | No | Minor |

### Code Examples

**Python**:
```python
# Add multi-target reference
collection.data.reference_add(
    from_uuid=article_uuid,
    from_property="relatedTo",
    to=ReferenceToMulti(target_collection="Category", uuids=category_uuid)
)

# Replace all references
collection.data.reference_replace(
    from_uuid=article_uuid,
    from_property="hasAuthors",
    to=[author1_uuid, author2_uuid, author3_uuid]
)
```

**Elixir**:
```elixir
# Add multi-target reference
References.add(client, "Article", article_uuid, "relatedTo", %{
  target_collection: "Category",
  uuids: category_uuid
})

# Replace all references
References.replace(client, "Article", article_uuid, "hasAuthors",
  [author1_uuid, author2_uuid, author3_uuid]
)
```

### Priority: LOW
Core functionality is complete.

---

## 8. Multi-target References

### Python Implementation

```python
class ReferenceToMulti(_WeaviateInput):
    """Use this class when you want to insert a multi-target reference property."""
    target_collection: str
    uuids: UUIDS  # Single UUID or List[UUID]

    def _to_beacons(self) -> List[Dict[str, str]]:
        return _to_beacons(self.uuids, self.target_collection)
```

### Elixir Implementation

```elixir
@type reference_to_multi :: %{
        target_collection: String.t(),
        uuids: uuid() | [uuid()]
      }

defp build_beacon(%{target_collection: collection, uuids: uuid}) when is_binary(uuid) do
  %{"beacon" => "weaviate://localhost/#{collection}/#{uuid}"}
end
```

### Gap Analysis

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Multi-target reference type | Yes | Yes (map) | None |
| Single UUID | Yes | Yes | None |
| Multiple UUIDs | Yes | Yes | None |
| Beacon generation | Yes | Yes | None |
| Type validation | Yes | No | Minor |

**Status: COMPLETE** - Feature parity achieved.

### Priority: NONE

---

## 9. Iterator/Cursor-based Fetching

### Python Implementation

**File**: `weaviate-python-client/weaviate/collections/iterator.py`

```python
class _ObjectIterator(
    Generic[TProperties, TReferences],
    Iterable[Object[TProperties, TReferences]],
):
    def __init__(
        self,
        query: _FetchObjectsQuery,
        inputs: _IteratorInputs[TProperties, TReferences],
        cache_size: Optional[int] = None,
    ):
        self.__iter_cache_size = cache_size or ITERATOR_CACHE_SIZE  # 100

    def __next__(self) -> Object[TProperties, TReferences]:
        if len(self.__iter_object_cache) == 0:
            res = self.__query.fetch_objects(
                limit=self.__iter_cache_size,
                after=self.__iter_object_last_uuid,
                include_vector=self.__inputs.include_vector,
                return_metadata=self.__inputs.return_metadata,
                return_properties=self.__inputs.return_properties,
                return_references=self.__inputs.return_references,
            )
            self.__iter_object_cache = res.objects
            if len(self.__iter_object_cache) == 0:
                raise StopIteration
        ret_object = self.__iter_object_cache.pop(0)
        self.__iter_object_last_uuid = ret_object.uuid
        return ret_object

class _ObjectAIterator(AsyncIterable):
    """Async variant of the iterator."""
    async def __anext__(self) -> Object[TProperties, TReferences]:
        # Same logic with async fetch
```

**Features**:
- Implements Python `Iterable` protocol
- Uses cursor-based pagination (`after` parameter)
- Configurable cache/batch size (default 100)
- Typed results with generics
- Supports metadata, properties, references selection
- Vector inclusion option
- Async variant for async clients
- Uses gRPC for fetching

### Elixir Implementation

**File**: `lib/weaviate_ex/iterator.ex`

```elixir
defstruct [
  :client, :collection, :cursor, :filter, :tenant,
  batch_size: 100,
  return_properties: [],
  include_vector: false
]

@spec stream(t()) :: Enumerable.t()
def stream(%__MODULE__{} = iterator) do
  Stream.unfold(iterator, fn
    nil -> nil
    iter ->
      case next_batch(iter) do
        {:ok, {[], _next_iter}} -> nil
        {:ok, {objects, next_iter}} -> {objects, next_iter}
        {:error, _} -> nil
      end
  end)
  |> Stream.flat_map(& &1)
end

def next_batch(%__MODULE__{client: client} = iterator) do
  query = build_query(iterator)  # GraphQL query
  case Client.request(client, :post, "/v1/graphql", %{"query" => query}, []) do
    {:ok, %{"data" => %{"Get" => get_results}}} ->
      # Process and return objects with next cursor
  end
end
```

**Features**:
- Elixir `Stream` integration
- Cursor-based pagination
- Configurable batch size
- Filter support
- Multi-tenancy support
- Uses GraphQL (not gRPC)

### Gap Analysis

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Cursor-based iteration | Yes | Yes | None |
| Batch/cache size config | Yes | Yes | None |
| Stream/Enumerable protocol | Yes | Yes | None |
| Typed results | Yes | No | **Missing** |
| Metadata selection | Yes | No | **Missing** |
| Reference selection | Yes | No | **Missing** |
| Vector inclusion | Yes | Yes | None |
| Filter support | Yes | Yes | None |
| Multi-tenancy | Yes | Yes | None |
| gRPC transport | Yes | No (GraphQL) | **Different** |
| Async iterator | Yes | No (but has Stream) | N/A |
| Resume from UUID | Yes | Yes (`:after` option) | None |

### Code Examples

**Python**:
```python
# Iterate through all objects with specific properties
for obj in collection.iterator(
    include_vector=True,
    return_metadata=MetadataQuery.full(),
    return_properties=["title", "content"]
):
    print(obj.uuid, obj.metadata.creation_time, obj.properties["title"])
```

**Elixir**:
```elixir
# Current implementation
Iterator.new(client, "Article",
  return_properties: ["title", "content"],
  include_vector: true,
  batch_size: 100
)
|> Iterator.stream()
|> Stream.take(1000)
|> Enum.each(fn obj ->
  IO.puts("#{obj["_additional"]["id"]}")
end)
```

### Priority: MEDIUM
Metadata and reference selection in iterator would be useful.

---

## 10. Object Validation

### Python Implementation

In Python, validation happens during insertion via `_validate_input`:

```python
if self._validate_arguments:
    _validate_input(
        [
            _ValidateArgument(expected=[UUID, None], name="uuid", value=uuid),
            _ValidateArgument(expected=[Mapping], name="properties", value=properties),
            _ValidateArgument(expected=[Mapping, None], name="references", value=references),
        ],
    )
```

### Elixir Implementation

```elixir
@spec validate(Client.t(), collection_name(), object_data(), opts()) ::
        {:ok, map()} | {:error, Error.t()}
def validate(client, collection_name, data, opts \\ []) do
  body = data
    |> Payload.normalize_keys()
    |> maybe_put_validation_id()
    |> Payload.ensure_class(collection_name)
  path = "/v1/objects/validate" <> build_query_string(opts, [:consistency_level])
  Client.request(client, :post, path, body, opts)
end
```

### Gap Analysis

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Server-side validation | Yes | Yes | None |
| Client-side type validation | Yes | No | **Missing** |
| UUID format validation | Yes | No | **Missing** |
| Property type validation | Yes | No | **Missing** |
| Reference format validation | Yes | No | **Missing** |

### Priority: LOW
Server-side validation is available; client-side is nice-to-have.

---

## 11. Vector Handling

### Python Types

**File**: `weaviate-python-client/weaviate/types.py`

```python
VECTORS = Union[
    Mapping[str, Union[Sequence[NUMBER], Sequence[Sequence[NUMBER]]]],  # Named vectors
    Sequence[NUMBER]  # Single vector
]
```

### Python Vector Processing

```python
def __parse_vector(self, obj: Dict[str, Any], vector: VECTORS) -> Dict[str, Any]:
    if isinstance(vector, dict):
        obj["vectors"] = {key: _get_vector_v4(val) for key, val in vector.items()}
    else:
        obj["vector"] = _get_vector_v4(vector)
    return obj
```

### Elixir Implementation

Vectors are passed as simple lists in the data map:

```elixir
# In insert
Data.insert(client, "Article", %{
  properties: %{"title" => "Hello"},
  vector: [0.1, 0.2, 0.3]
})
```

### Gap Analysis

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Single vector (list) | Yes | Yes | None |
| Named vectors (dict) | Yes | No | **Missing** |
| Multi-vectors per name | Yes | No | **Missing** |
| numpy array support | Yes | N/A | N/A |
| torch tensor support | Yes | N/A | N/A |
| tensorflow support | Yes | N/A | N/A |
| pandas Series support | Yes | N/A | N/A |
| polars Series support | Yes | N/A | N/A |
| Vector validation | Yes | No | Minor |

### Code Examples

**Python**:
```python
# Named vectors
collection.data.insert(
    properties={"title": "Article"},
    vector={
        "title_vector": [0.1, 0.2, 0.3],
        "content_vector": [0.4, 0.5, 0.6]
    }
)

# Multi-vectors (for ColBERT etc.)
collection.data.insert(
    properties={"title": "Article"},
    vector={
        "colbert": [[0.1, 0.2], [0.3, 0.4], [0.5, 0.6]]  # List of vectors
    }
)
```

**Elixir (current)**:
```elixir
# Only single vectors supported
{:ok, _} = Data.insert(client, "Article", %{
  properties: %{"title" => "Article"},
  vector: [0.1, 0.2, 0.3]
})

# Named vectors not yet supported
```

### Priority: HIGH
Named vectors are essential for modern Weaviate usage.

---

## 12. Cross-reference Management

### Python Implementation

Cross-references are deeply integrated into the type system:

```python
class _CrossReference(Generic[Properties, IReferences]):
    def __init__(self, objects: Optional[List[Object[Properties, IReferences]]]):
        self.__objects = objects

    @property
    def objects(self) -> List[Object[Properties, IReferences]]:
        return self.__objects or []

# Type aliases
CrossReference: TypeAlias = _CrossReference[Properties, IReferences]
CrossReferences = Mapping[str, _CrossReference[WeaviateProperties, "CrossReferences"]]
```

### Elixir Implementation

References are managed via `WeaviateEx.API.References` module with simple maps:

```elixir
# Add reference
References.add(client, "Article", article_uuid, "hasAuthor", author_uuid)

# Multi-target
References.add(client, "Article", article_uuid, "relatedTo", %{
  target_collection: "Category",
  uuids: [cat1, cat2]
})
```

### Gap Analysis

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Add references | Yes | Yes | None |
| Delete references | Yes | Yes | None |
| Replace references | Yes | Yes | None |
| Batch add | Yes | Yes | None |
| Cross-reference objects type | Yes | No | **Missing** |
| Nested reference retrieval | Yes | No | **Missing** |
| Reference annotation | Yes | N/A | N/A |
| Reference property expansion | Yes | No | **Missing** |

### Priority: MEDIUM

---

## 13. Object Metadata

### Python Metadata Classes

```python
@dataclass
class MetadataReturn:
    """Metadata of an object returned by a query."""
    creation_time: Optional[datetime.datetime] = None
    last_update_time: Optional[datetime.datetime] = None
    distance: Optional[float] = None
    certainty: Optional[float] = None
    score: Optional[float] = None
    explain_score: Optional[str] = None
    is_consistent: Optional[bool] = None
    rerank_score: Optional[float] = None

@dataclass
class MetadataSingleObjectReturn:
    """Metadata of an object returned by fetch_object_by_id."""
    creation_time: datetime.datetime
    last_update_time: datetime.datetime
    is_consistent: Optional[bool]
```

### Elixir Implementation

Metadata is returned as part of the raw response map, no structured types:

```elixir
# Returned as raw map from API
%{
  "class" => "Article",
  "id" => "uuid",
  "properties" => %{...},
  "creationTimeUnix" => 1234567890,
  "lastUpdateTimeUnix" => 1234567890
}
```

### Gap Analysis

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| creation_time | Yes | Raw only | **Missing struct** |
| last_update_time | Yes | Raw only | **Missing struct** |
| distance | Yes | Raw only | **Missing struct** |
| certainty | Yes | Raw only | **Missing struct** |
| score | Yes | Raw only | **Missing struct** |
| explain_score | Yes | Raw only | **Missing struct** |
| is_consistent | Yes | No | **Missing** |
| rerank_score | Yes | Raw only | **Missing struct** |
| Typed metadata struct | Yes | No | **Missing** |
| DateTime parsing | Yes | No | **Missing** |

### Priority: MEDIUM
Structured metadata improves developer experience.

---

## Summary of Gaps by Priority

### HIGH Priority (Critical for Feature Parity)

1. **Named Vectors Support**
   - Add `vectors` field support in insert/update operations
   - Support dict/map of vector name to vector values
   - Support multi-vectors per named vector

2. **References During Insert**
   - Add `references` parameter to insert function
   - Serialize references to beacon format

3. **Cross-reference Expansion in Get**
   - Add reference retrieval options to get_by_id
   - Support nested property selection

4. **gRPC for Data Operations**
   - Use gRPC for fetch_object_by_id (faster)
   - Consistent with Python client

### MEDIUM Priority (Important Improvements)

5. **Structured Metadata Types**
   - Create `MetadataReturn` struct
   - Parse Unix timestamps to DateTime
   - Include is_consistent field

6. **Iterator Enhancements**
   - Add metadata selection option
   - Add reference selection option
   - Consider gRPC transport

7. **Vector Update in Patch**
   - Allow vector updates in patch operations
   - Support named vectors in patch

### LOW Priority (Nice to Have)

8. **Client-side Validation**
   - UUID format validation
   - Property type validation

9. **Special Property Types**
   - GeoCoordinate support
   - PhoneNumber support

10. **Typed Returns**
    - Return UUID type from insert
    - Return boolean from delete

---

## Implementation Recommendations

### Phase 1: Named Vectors (Priority: HIGH)

```elixir
# Proposed API
Data.insert(client, "Article", %{
  properties: %{"title" => "Hello"},
  vectors: %{
    "title_vector" => [0.1, 0.2, 0.3],
    "content_vector" => [0.4, 0.5, 0.6]
  }
})

# In Payload module
def prepare_for_insert(data, class_name, opts) do
  data
  |> normalize_keys()
  |> ensure_id(opts)
  |> ensure_class(class_name)
  |> handle_vectors()  # New: process "vectors" key
end

defp handle_vectors(%{"vectors" => vectors} = data) when is_map(vectors) do
  data
  |> Map.delete("vector")  # Remove single vector if present
  |> Map.put("vectors", vectors)
end
```

### Phase 2: Metadata Structs

```elixir
defmodule WeaviateEx.Objects.Metadata do
  defstruct [
    :creation_time,
    :last_update_time,
    :distance,
    :certainty,
    :score,
    :explain_score,
    :is_consistent,
    :rerank_score
  ]

  def from_map(map) do
    %__MODULE__{
      creation_time: parse_unix_time(map["creationTimeUnix"]),
      last_update_time: parse_unix_time(map["lastUpdateTimeUnix"]),
      distance: map["distance"],
      certainty: map["certainty"],
      score: map["score"],
      explain_score: map["explainScore"],
      is_consistent: map["isConsistent"],
      rerank_score: map["rerankScore"]
    }
  end
end
```

### Phase 3: Enhanced Get with References

```elixir
# Proposed API
Data.get_by_id(client, "Article", uuid,
  include_vector: ["title_vector"],
  return_properties: ["title", "content"],
  return_references: [
    %{link_on: "hasAuthor", return_properties: ["name"]}
  ]
)
```

---

## Files Analyzed

### Python Files
- `/home/home/p/g/n/weaviate_ex/weaviate-python-client/weaviate/collections/data/executor.py`
- `/home/home/p/g/n/weaviate_ex/weaviate-python-client/weaviate/collections/data/sync.py`
- `/home/home/p/g/n/weaviate_ex/weaviate-python-client/weaviate/collections/data/async_.py`
- `/home/home/p/g/n/weaviate_ex/weaviate-python-client/weaviate/collections/classes/data.py`
- `/home/home/p/g/n/weaviate_ex/weaviate-python-client/weaviate/collections/classes/internal.py`
- `/home/home/p/g/n/weaviate_ex/weaviate-python-client/weaviate/collections/iterator.py`
- `/home/home/p/g/n/weaviate_ex/weaviate-python-client/weaviate/types.py`
- `/home/home/p/g/n/weaviate_ex/weaviate-python-client/weaviate/collections/queries/fetch_object_by_id/executor.py`
- `/home/home/p/g/n/weaviate_ex/weaviate-python-client/weaviate/collections/queries/fetch_objects/query/executor.py`

### Elixir Files
- `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/api/data.ex`
- `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/objects/payload.ex`
- `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/api/references.ex`
- `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/iterator.ex`
- `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/api/batch.ex`
- `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/batch/background.ex`
