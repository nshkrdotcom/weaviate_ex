# Data Operations (CRUD) Gap Analysis

## Overview

This document compares data operations between the Weaviate Python client (canonical reference) and the WeaviateEx Elixir port, focusing on CRUD operations, references, iteration, validation, and UUID handling.

## Summary Table

| Feature | Python | Elixir | Gap Status |
|---------|--------|--------|------------|
| **Object Insertion** | | | |
| Single insert | `collection.data.insert()` | `Data.insert/4` | Partial |
| Insert with references | Inline references | Inline references | Complete |
| Insert with vector | Named + single vectors | Named + single vectors | Complete |
| Insert many (batch) | `collection.data.insert_many()` | `Batch.create_objects/2` | Complete |
| **Object Retrieval** | | | |
| Get by ID | `query.fetch_object_by_id()` | `Data.get_by_id/4` | Partial |
| Get by multiple IDs | `query.fetch_objects_by_ids()` | Not available | Missing |
| Rich return types | TypedDict models | Plain maps | Gap |
| **Object Updates** | | | |
| Full replace (PUT) | `collection.data.replace()` | `Data.replace/5`, `Data.update/5` | Complete |
| Partial update (PATCH) | `collection.data.update()` | `Data.patch/5` | Complete |
| Update with references | Inline | Not in patch | Partial |
| **Object Deletion** | | | |
| Delete by ID | `collection.data.delete_by_id()` | `Data.delete_by_id/4` | Complete |
| Delete many (filter) | `collection.data.delete_many()` | `Batch.delete_objects/2` | Complete |
| Verbose/dry run mode | Yes | Yes (via gRPC) | Complete |
| **Reference Management** | | | |
| Add reference | `collection.data.reference_add()` | `References.add/6` | Complete |
| Delete reference | `collection.data.reference_delete()` | `References.delete/6` | Complete |
| Replace references | `collection.data.reference_replace()` | `References.replace/6` | Complete |
| Add many references | `collection.data.reference_add_many()` | `References.add_many/4` | Complete |
| Multi-target refs | `ReferenceToMulti` | `ReferenceToMulti` struct | Complete |
| **Iterator/Cursor** | | | |
| Collection iterator | `collection.iterator()` | `Iterator.stream/1` | Partial |
| Async iterator | `collection.iterator()` async | N/A (Elixir is concurrent) | N/A |
| Return properties | Filter-able | Filter-able | Complete |
| Return references | Configurable | Not configurable | Gap |
| **Object Validation** | | | |
| Pre-insert validation | `_validate_input()` | `Data.validate/4` | Partial |
| Type checking | Runtime type validation | Limited (maps) | Gap |
| **UUID Generation** | | | |
| Random UUID v4 | `uuid.uuid4()` | `Uniq.UUID.uuid4()` / `Types.UUID.generate()` | Complete |
| Deterministic UUID v5 | N/A in data module | `Types.UUID.from_string/2` | Extra |

---

## 1. Object Insertion (Single)

### Python Implementation

```python
# weaviate/collections/data/executor.py

def insert(
    self,
    properties: Properties,
    references: Optional[ReferenceInputs] = None,
    uuid: Optional[UUID] = None,
    vector: Optional[VECTORS] = None,
) -> executor.Result[uuid_package.UUID]:
    """Insert a single object into the collection."""
    # Validates input arguments
    if self._validate_arguments:
        _validate_input([
            _ValidateArgument(expected=[UUID, None], name="uuid", value=uuid),
            _ValidateArgument(expected=[Mapping], name="properties", value=properties),
            _ValidateArgument(expected=[Mapping, None], name="references", value=references),
        ])

    # Serializes props and refs
    props = self.__serialize_props(properties)
    refs = self.__serialize_refs(references)

    weaviate_obj = {
        "class": self.name,
        "properties": {**props, **refs},
        "id": str(uuid if uuid is not None else uuid_package.uuid4()),
    }

    # Handle named vectors or single vector
    if vector is not None:
        weaviate_obj = self.__parse_vector(weaviate_obj, vector)
```

**Key Features:**
- Automatic UUID generation if not provided
- Runtime input validation with detailed error messages
- Inline reference support merged into properties
- Named vector support (`vectors` dict) and single vector support
- Type serialization (datetime, GeoCoordinate, PhoneNumber)
- Returns the UUID of the inserted object

### Elixir Implementation

```elixir
# lib/weaviate_ex/api/data.ex

def insert(client, collection_name, data, opts \\ []) do
  payload_opts = Keyword.take(opts, [:auto_generate_id])

  body =
    data
    |> Payload.prepare_for_insert(collection_name, payload_opts)

  path = "/v1/objects" <> build_query_string(opts, [:tenant, :consistency_level])
  Client.request(client, :post, path, body, opts)
end
```

**Key Features:**
- UUID auto-generation via `Uniq.UUID.uuid4()`
- Named and single vector support
- Inline reference support (converted to beacons)
- Property serialization (DateTime, GeoCoordinate, PhoneNumber)
- Returns full object response (not just UUID)

### Gaps and Differences

| Aspect | Python | Elixir | Gap |
|--------|--------|--------|-----|
| Return value | UUID only | Full object map | Different (Elixir returns more) |
| Input validation | Rich type checking | No type checking | Gap |
| Vector type support | numpy, torch, tf, pd, pl | Lists only | Gap (Elixir uses plain lists) |
| Reference serialization | `_Reference._to_beacons()` | `Payload.build_beacons/1` | Complete |

### Recommendations

1. **Add input validation**: Create a validation module similar to Python's `_validate_input()`
2. **Consider returning just UUID**: For API parity, optionally return only UUID

---

## 2. Object Retrieval

### By ID

#### Python Implementation

```python
# weaviate/collections/queries/fetch_object_by_id/executor.py

def fetch_object_by_id(
    self,
    uuid: UUID,
    include_vector: INCLUDE_VECTOR = False,
    *,
    return_properties: Optional[ReturnProperties[TProperties]] = None,
    return_references: Optional[ReturnReferences[TReferences]] = None,
) -> executor.Result[ObjectSingleReturn[Properties, References]]:
    """Retrieve an object from the server by its UUID."""
    # Uses gRPC with Filter.by_id().equal(uuid)
    # Returns rich ObjectSingleReturn with typed properties
```

**Features:**
- Uses gRPC for retrieval
- Rich return type with metadata (creation_time, last_update_time, is_consistent)
- Configurable return_properties and return_references
- Typed generic response

#### Elixir Implementation

```elixir
# lib/weaviate_ex/api/data.ex

def get_by_id(client, collection_name, id, opts \\ []) do
  path =
    "/v1/objects/#{collection_name}/#{id}" <>
      build_query_string(opts, [:tenant, :consistency_level, :include])

  Client.request(client, :get, path, nil, opts)
end
```

**Features:**
- Uses REST API
- Returns raw map from Weaviate
- Optional `include` parameter for vectors

### Gaps

| Aspect | Python | Elixir | Status |
|--------|--------|--------|--------|
| Protocol | gRPC | REST | Gap (REST is slower) |
| Return typing | `ObjectSingleReturn[P, R]` | Plain map | Gap |
| Return references | Configurable | Not configurable | Gap |
| Return properties | Configurable | All or nothing | Gap |

### By Multiple IDs

#### Python Implementation

```python
def fetch_objects_by_ids(
    self,
    ids: Iterable[UUID],
    *,
    limit: Optional[int] = None,
    offset: Optional[int] = None,
    after: Optional[UUID] = None,
    sort: Optional[Sorting] = None,
    include_vector: INCLUDE_VECTOR = False,
    return_metadata: Optional[METADATA] = None,
    return_properties: Optional[ReturnProperties[TProperties]] = None,
    return_references: Optional[ReturnReferences[TReferences]] = None,
) -> executor.Result[QueryReturnType[...]]:
    """Fetch multiple objects by their IDs using Filter.any_of()"""
```

#### Elixir Implementation

**Not implemented** - No equivalent method exists.

### Recommendations

1. **Add gRPC retrieval option**: For performance-critical operations
2. **Add `fetch_objects_by_ids/3`**: Implement batch ID fetching
3. **Add return property/reference configuration**: Filter what's returned

---

## 3. Object Updates

### Full Replace (PUT)

#### Python Implementation

```python
def replace(
    self,
    uuid: UUID,
    properties: Properties,
    references: Optional[ReferenceInputs] = None,
    vector: Optional[VECTORS] = None,
) -> executor.Result[None]:
    """Replace an object (PUT operation)."""
    # Full replacement - all properties must be provided
```

#### Elixir Implementation

```elixir
def replace(client, collection_name, id, data, opts \\ []) do
  update(client, collection_name, id, data, opts)
end

def update(client, collection_name, id, data, opts \\ []) do
  payload_opts = Keyword.take(opts, [:keep_vector])
  body = Payload.prepare_for_update(data, collection_name, id, payload_opts)
  path = "/v1/objects/#{collection_name}/#{id}" <> build_query_string(opts, [:tenant, :consistency_level])
  Client.request(client, :put, path, body, opts)
end
```

**Status: Complete** - Both implementations support full replacement with vectors.

### Partial Update (PATCH)

#### Python Implementation

```python
def update(
    self,
    uuid: UUID,
    properties: Optional[Properties] = None,
    references: Optional[ReferenceInputs] = None,
    vector: Optional[VECTORS] = None,
) -> executor.Result[None]:
    """Update an object (PATCH operation)."""
    # Merges with existing data
```

#### Elixir Implementation

```elixir
def patch(client, collection_name, id, data, opts \\ []) do
  body =
    data
    |> Payload.prepare_for_patch()
    |> Map.drop(["vector", :vector])

  # PATCH returns 204 No Content, so we need to GET the updated object
  case Client.request(client, :patch, path, body, opts) do
    {:ok, _} -> get_by_id(client, collection_name, id, opts)
    error -> error
  end
end
```

### Gaps

| Aspect | Python | Elixir | Status |
|--------|--------|--------|--------|
| Update properties | Yes | Yes | Complete |
| Update references | Inline in update | Not supported in patch | Gap |
| Update vector | Yes | Explicitly dropped | Gap |
| Return value | None | Full updated object | Different |

### Recommendations

1. **Support vector updates in patch**: Allow vector modification
2. **Support inline references in patch**: Match Python behavior

---

## 4. Object Deletion

### Delete by ID

Both implementations are equivalent:

```python
# Python
def delete_by_id(self, uuid: UUID) -> executor.Result[bool]:
    """Delete an object by UUID. Returns True if deleted, False if not found."""
```

```elixir
# Elixir
def delete_by_id(client, collection_name, id, opts \\ []) do
  path = "/v1/objects/#{collection_name}/#{id}" <> build_query_string(opts, [:tenant, :consistency_level])
  Client.request(client, :delete, path, nil, opts)
end
```

**Status: Complete**

### Delete Many (Filter-based)

#### Python Implementation

```python
def delete_many(
    self,
    where: _Filters,
    *,
    verbose: bool = False,
    dry_run: bool = False
) -> executor.Result[DeleteManyReturn[...]]:
    """Delete multiple objects based on a filter."""
```

#### Elixir Implementation

```elixir
# Via Batch API with gRPC support
def delete_objects(client, criteria, opts \\ []) when is_map(criteria) do
  if grpc_available?(client) do
    delete_objects_grpc(client, criteria, opts)  # Uses gRPC batch delete
  else
    delete_objects_http(client, criteria, opts)  # Falls back to REST
  end
end
```

**Status: Complete** - Both support verbose and dry_run options.

---

## 5. Reference Management

### Python Implementation

```python
def reference_add(
    self,
    from_uuid: UUID,
    from_property: str,
    to: SingleReferenceInput,  # UUID | ReferenceToMulti
) -> executor.Result[None]:
    """Create a reference between objects."""

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
    to: ReferenceInput,  # UUID | Sequence[UUID] | ReferenceToMulti
) -> executor.Result[None]:
    """Replace all references on a property."""

def reference_add_many(
    self,
    refs: List[DataReferences],
) -> executor.Result[BatchReferenceReturn]:
    """Create multiple references in batch."""
```

### Elixir Implementation

```elixir
# lib/weaviate_ex/api/references.ex

def add(client, collection, from_uuid, from_property, to, opts \\ [])
def delete(client, collection, from_uuid, from_property, to, opts \\ [])
def replace(client, collection, from_uuid, from_property, references, opts \\ [])
def add_many(client, collection, references, opts \\ [])
```

### Multi-Target Reference Support

```python
# Python
class ReferenceToMulti(_WeaviateInput):
    target_collection: str
    uuids: UUIDS
```

```elixir
# Elixir
defmodule WeaviateEx.Data.ReferenceToMulti do
  defstruct [:target_collection, :uuids]

  def new(target_collection, uuids)
  def to_beacons(ref)
  def to_map(ref)
end
```

**Status: Complete** - Full parity for reference operations.

---

## 6. Iterator/Cursor-Based Retrieval

### Python Implementation

```python
# weaviate/collections/iterator.py

class _ObjectIterator(Iterable[Object[TProperties, TReferences]]):
    """Cursor-based iteration through collection objects."""

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
```

**Key Features:**
- Uses gRPC `fetch_objects` with cursor pagination
- Configurable return_properties and return_references
- Configurable return_metadata
- Cache size of 100 objects by default
- Supports both sync and async iterators

### Elixir Implementation

```elixir
# lib/weaviate_ex/iterator.ex

defmodule WeaviateEx.Iterator do
  defstruct [
    :client, :collection, :cursor, :filter, :tenant,
    batch_size: 100,
    return_properties: [],
    include_vector: false
  ]

  def stream(%__MODULE__{} = iterator) do
    Stream.unfold(iterator, fn
      nil -> nil
      iter ->
        case next_batch(iter) do
          {:ok, {[], _}} -> nil
          {:ok, {objects, next_iter}} -> {objects, next_iter}
          {:error, _} -> nil
        end
    end)
    |> Stream.flat_map(& &1)
  end

  def next_batch(%__MODULE__{} = iterator) do
    query = build_query(iterator)  # Uses GraphQL
    # ...
  end
end
```

### Gaps

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Protocol | gRPC | GraphQL | Different |
| Return metadata | Configurable | Not configurable | Gap |
| Return references | Configurable | Not supported | Gap |
| Typed objects | Generic type support | Plain maps | Gap |
| Filter support | Via query | Via filter param | Complete |

### Recommendations

1. **Add return_metadata option**: Allow configuring which metadata to return
2. **Add return_references option**: Support reference resolution in iteration
3. **Consider gRPC protocol**: For better performance

---

## 7. Object Validation

### Python Implementation

```python
# weaviate/validator.py

@dataclass
class _ValidateArgument:
    expected: List[Any]
    name: str
    value: Any

def _validate_input(inputs: Union[List[_ValidateArgument], _ValidateArgument]) -> None:
    """Validate input arguments against expected types."""
    for validate in inputs:
        if not any(_is_valid(exp, validate.value) for exp in validate.expected):
            raise WeaviateInvalidInputError(
                f"Argument '{validate.name}' must be one of: {validate.expected}, "
                f"but got {type(validate.value)}"
            )
```

**Used in data operations:**
```python
if self._validate_arguments:
    _validate_input([
        _ValidateArgument(expected=[UUID, None], name="uuid", value=uuid),
        _ValidateArgument(expected=[Mapping], name="properties", value=properties),
    ])
```

### Elixir Implementation

```elixir
# lib/weaviate_ex/api/data.ex

def validate(client, collection_name, data, opts \\ []) do
  body =
    data
    |> Payload.normalize_keys()
    |> maybe_put_validation_id()
    |> Payload.ensure_class(collection_name)

  path = "/v1/objects/validate" <> build_query_string(opts, [:consistency_level])
  Client.request(client, :post, path, body, opts)
end
```

### Gaps

| Aspect | Python | Elixir | Status |
|--------|--------|--------|--------|
| Pre-call type validation | Rich type checking | None | Gap |
| Server-side validation | Via validate endpoint | Via validate endpoint | Complete |
| Error messages | Detailed type info | Server-side only | Gap |

### Recommendations

1. **Add client-side validation module**: Create guards/validators for common types
2. **Consider using specs**: Leverage dialyzer for static analysis

---

## 8. UUID Generation

### Python Implementation

```python
# In data operations
uuid_package.uuid4()  # Standard library UUID
```

### Elixir Implementation

```elixir
# lib/weaviate_ex/objects/payload.ex
Uniq.UUID.uuid4()  # Via Uniq library

# lib/weaviate_ex/types/uuid.ex
defmodule WeaviateEx.Types.UUID do
  def generate() do
    # Custom crypto-based UUID v4
    bytes = :crypto.strong_rand_bytes(16)
    # Set version to 4 and variant to RFC 4122
  end

  def validate(uuid)  # Validates UUID format
  def valid?(uuid)    # Boolean check
  def from_string(namespace, name)  # Deterministic UUID v5
  def extract_from_beacon(beacon)   # Extract UUID from beacon URL
end
```

### Comparison

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Random UUID v4 | `uuid.uuid4()` | `Uniq.UUID.uuid4()` | Complete |
| Deterministic UUID | Not in data module | `UUID.from_string/2` | Extra |
| UUID validation | Not explicit | `UUID.validate/1` | Extra |
| Beacon extraction | Implicit | `UUID.extract_from_beacon/1` | Extra |

**Status: Complete** - Elixir has additional UUID utilities.

---

## API Ergonomics Comparison

### Python - Collection-Centric API

```python
# Python uses collection-bound API
collection = client.collections.get("Article")

# Data operations
uuid = collection.data.insert(properties={"title": "Hello"})
collection.data.replace(uuid, properties={"title": "Updated"})
collection.data.delete_by_id(uuid)

# Reference operations
collection.data.reference_add(uuid, "hasAuthor", author_uuid)

# Iteration
for obj in collection.iterator():
    print(obj.properties)
```

### Elixir - Module-Based API

```elixir
# Elixir uses module-based API with explicit client
{:ok, object} = Data.insert(client, "Article", %{properties: %{"title" => "Hello"}})
{:ok, updated} = Data.replace(client, "Article", uuid, %{properties: %{"title" => "Updated"}})
{:ok, _} = Data.delete_by_id(client, "Article", uuid)

# Reference operations
References.add(client, "Article", uuid, "hasAuthor", author_uuid)

# Iteration
Iterator.new(client, "Article")
|> Iterator.stream()
|> Enum.each(&IO.inspect/1)
```

### Key Ergonomic Differences

| Aspect | Python | Elixir |
|--------|--------|--------|
| Collection binding | Objects bound to collection | Pass collection each call |
| Client passing | Implicit (via collection) | Explicit in each call |
| Return types | Typed dataclasses | Plain maps |
| Error handling | Exceptions | Tagged tuples `{:ok, _}` / `{:error, _}` |
| Type hints | Full generics support | Typespecs (less rich) |
| Validation | Optional runtime checking | Relies on typespecs |
| Async support | Separate async classes | Native (BEAM concurrency) |

---

## Summary of Gaps to Address

### High Priority

1. **Add `fetch_objects_by_ids/3`**: Batch retrieval by multiple UUIDs
2. **Add return_references to iterator**: Match Python's reference configuration
3. **Add client-side validation**: Type checking before API calls
4. **Support vector updates in patch**: Allow modifying vectors

### Medium Priority

5. **Add return_metadata to iterator**: Configurable metadata return
6. **Consider gRPC for retrieval**: Better performance for get_by_id
7. **Add inline references in patch**: Match Python's update behavior

### Low Priority (Different by Design)

8. **Collection-bound API**: Elixir uses explicit module calls (idiomatic)
9. **Typed return objects**: Plain maps are idiomatic Elixir
10. **Vector type support**: Python supports numpy/torch/etc., Elixir uses lists

---

## Files Referenced

### Python
- `weaviate-python-client/weaviate/collections/data/executor.py` - Main data operations
- `weaviate-python-client/weaviate/collections/classes/data.py` - Data types
- `weaviate-python-client/weaviate/collections/iterator.py` - Iterator implementation
- `weaviate-python-client/weaviate/validator.py` - Input validation
- `weaviate-python-client/weaviate/types.py` - Type definitions
- `weaviate-python-client/weaviate/collections/classes/internal.py` - Reference types

### Elixir
- `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/api/data.ex` - Data operations
- `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/api/references.ex` - Reference operations
- `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/iterator.ex` - Iterator implementation
- `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/objects/payload.ex` - Payload utilities
- `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/api/batch.ex` - Batch operations
- `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/types/uuid.ex` - UUID utilities
- `/home/home/p/g/n/weaviate_ex/lib/weaviate_ex/data/reference_to_multi.ex` - Multi-target refs
