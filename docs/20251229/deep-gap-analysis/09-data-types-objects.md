# Deep Gap Analysis: Data Types and Object Handling

## Reference: weaviate-python-client (canonical Python client)
## Port: lib/weaviate_ex/ (Elixir implementation)

---

## Executive Summary

This analysis compares data type handling and object CRUD operations between the canonical Python client and the Elixir implementation. The Elixir client has solid foundational coverage for basic data types and CRUD operations but reveals significant gaps in advanced features like typed property validation, multi-dimensional vectors, sophisticated reference handling, and streaming batch operations.

### Overall Coverage Assessment

| Category | Python Features | Elixir Implemented | Coverage |
|----------|-----------------|-------------------|----------|
| Basic Data Types | 18 types | 17 types | 94% |
| Object CRUD | 10 operations | 8 operations | 80% |
| Cross-References | 8 features | 5 features | 63% |
| UUID Handling | 6 features | 4 features | 67% |
| Vector Handling | 7 features | 4 features | 57% |
| Nested Objects | 5 features | 4 features | 80% |
| Validation | 8 features | 3 features | 38% |
| Serialization | 12 features | 8 features | 67% |

**Overall Weighted Score: ~65%**

---

## 1. Supported Property Data Types

### Python Client Data Types

**Source:** `/weaviate-python-client/weaviate/types.py` (lines 20-35)

```python
DATATYPE_TO_PYTHON_TYPE = {
    "text": str,
    "int": int,
    "text[]": List[str],
    "int[]": List[int],
    "boolean": bool,
    "boolean[]": List[bool],
    "number": float,
    "number[]": List[float],
    "date": datetime.datetime,
    "date[]": List[datetime.datetime],
    "geoCoordinates": GEO_COORDINATES,
    "object": Dict[str, PRIMITIVE],
    "object[]": List[Dict[str, PRIMITIVE]],
}
```

**Source:** `/weaviate-python-client/weaviate/collections/classes/types.py` (lines 59-79)

```python
WeaviateField: TypeAlias = Union[
    None,  # null
    str,  # text
    bool,  # boolean
    int,  # int
    float,  # number
    datetime.datetime,  # date
    uuid_package.UUID,  # uuid
    GeoCoordinate,  # geoCoordinates
    Union[PhoneNumber, PhoneNumberType],  # phoneNumber
    Mapping[str, "WeaviateField"],  # object
    Sequence[str],  # text[]
    Sequence[bool],  # boolean[]
    Sequence[int],  # int[]
    Sequence[float],  # number[]
    Sequence[datetime.datetime],  # date[]
    Sequence[uuid_package.UUID],  # uuid[]
    Sequence[Mapping[str, "WeaviateField"]],  # object[]
]
```

### Elixir Implementation Data Types

**Source:** `/lib/weaviate_ex/types/data_type.ex` (lines 51-69)

```elixir
@data_types %{
  text: "text",
  text_array: "text[]",
  int: "int",
  int_array: "int[]",
  boolean: "boolean",
  boolean_array: "boolean[]",
  number: "number",
  number_array: "number[]",
  date: "date",
  date_array: "date[]",
  uuid: "uuid",
  uuid_array: "uuid[]",
  geo_coordinates: "geoCoordinates",
  blob: "blob",
  phone_number: "phoneNumber",
  object: "object",
  object_array: "object[]"
}
```

### Data Type Comparison Table

| Data Type | Weaviate API | Python Client | Elixir Implementation | Gap |
|-----------|--------------|---------------|----------------------|-----|
| text | `text` | `str` | `:text` | None |
| text[] | `text[]` | `List[str]` | `:text_array` | None |
| int | `int` | `int` | `:int` | None |
| int[] | `int[]` | `List[int]` | `:int_array` | None |
| boolean | `boolean` | `bool` | `:boolean` | None |
| boolean[] | `boolean[]` | `List[bool]` | `:boolean_array` | None |
| number | `number` | `float` | `:number` | None |
| number[] | `number[]` | `List[float]` | `:number_array` | None |
| date | `date` | `datetime.datetime` | `:date` | None |
| date[] | `date[]` | `List[datetime.datetime]` | `:date_array` | None |
| uuid | `uuid` | `uuid.UUID` | `:uuid` | None |
| uuid[]| `uuid[]` | `List[uuid.UUID]` | `:uuid_array` | None |
| geoCoordinates | `geoCoordinates` | `GeoCoordinate` | `:geo_coordinates` | None |
| phoneNumber | `phoneNumber` | `PhoneNumber` | `:phone_number` | None |
| blob | `blob` | BLOB_INPUT | `:blob` | None |
| object | `object` | `Dict[str, PRIMITIVE]` | `:object` | None |
| object[] | `object[]` | `List[Dict[...]]` | `:object_array` | None |
| cross-reference | `cref` | ReferenceProperty | Not in DataType | **GAP**: Missing dedicated type |

### Detailed Type Handler Comparison

#### GeoCoordinate

**Python:** `/weaviate-python-client/weaviate/collections/classes/types.py` (lines 15-22)
```python
class GeoCoordinate(_WeaviateInput):
    latitude: float = Field(default=..., le=90, ge=-90)
    longitude: float = Field(default=..., le=180, ge=-180)

    def _to_dict(self) -> Dict[str, float]:
        return self.model_dump(exclude_none=True)
```

**Elixir:** `/lib/weaviate_ex/types/geo_coordinate.ex` (lines 42-58)
```elixir
def new(latitude, longitude)
    when is_number(latitude) and is_number(longitude) and
         latitude >= -90 and latitude <= 90 and
         longitude >= -180 and longitude <= 180 do
  {:ok, %__MODULE__{latitude: latitude, longitude: longitude}}
end
```

**Gap Analysis:** Both implementations have validation, but Python uses Pydantic with built-in field constraints while Elixir uses guard clauses. The Elixir version matches the functionality.

#### PhoneNumber

**Python:** `/weaviate-python-client/weaviate/collections/classes/types.py` (lines 25-56)
```python
class PhoneNumber(_PhoneNumberBase):
    default_country: Optional[str] = Field(default=None)

    def _to_dict(self) -> Mapping[str, str]:
        out: Dict[str, str] = {"input": self.number}
        if self.default_country is not None:
            out["defaultCountry"] = self.default_country
        return out

class _PhoneNumber(_PhoneNumberBase):  # Output type
    country_code: int
    default_country: str
    international_formatted: str
    national: int
    national_formatted: str
    valid: bool
```

**Elixir:** `/lib/weaviate_ex/types/phone_number.ex` (lines 73-122)
```elixir
def new(number, opts \\ []) when is_binary(number) do
  %__MODULE__{
    number: number,
    default_country: Keyword.get(opts, :default_country)
  }
end

defmodule Output do
  defstruct [:input, :country_code, :default_country,
             :international_formatted, :national,
             :national_formatted, :valid]
end
```

**Gap Analysis:** Full parity. Both have separate input/output types with all fields.

#### Blob

**Python:** `/weaviate-python-client/weaviate/util.py` (lines 63-137)
```python
def file_encoder_b64(file_or_file_path: Union[str, Path, io.BufferedReader]) -> str:
    # Chunked reading for large files
    # Supports str path, Path object, BufferedReader

def parse_blob(media: BLOB_INPUT) -> str:
    if isinstance(media, str):
        if os.path.isfile(media):
            return file_encoder_b64(media)
        else:
            return media  # Already encoded
    elif isinstance(media, Path) or isinstance(media, io.BufferedReader):
        return file_encoder_b64(media)
```

**Elixir:** `/lib/weaviate_ex/types/blob.ex` (lines 31-107)
```elixir
def encode(data) when is_binary(data), do: Base.encode64(data)

def encode_file(path) do
  case File.read(path) do
    {:ok, data} -> {:ok, encode(data)}
    {:error, reason} -> {:error, reason}
  end
end

def decode_to_file(encoded, path) do
  case decode(encoded) do
    {:ok, data} -> File.write(path, data)
    :error -> {:error, :invalid_base64}
  end
end
```

**Gap Analysis:**
- Missing: Chunked reading for large files (Python's BYTES_PER_CHUNK = 65535)
- Missing: BufferedReader equivalent support
- Missing: Auto-detection of already-encoded strings

---

## 2. Object CRUD Operations

### Python Client CRUD Operations

**Source:** `/weaviate-python-client/weaviate/collections/data/executor.py`

| Operation | Method | Lines | Description |
|-----------|--------|-------|-------------|
| Insert | `insert()` | 86-144 | Single object insert with properties, references, uuid, vector |
| Insert Many | `insert_many()` | 146-206 | Batch insert via gRPC |
| Exists | `exists()` | 208-234 | Check if object exists by UUID |
| Replace | `replace()` | 236-296 | PUT - full replacement |
| Update | `update()` | 298-353 | PATCH - partial update |
| Reference Add | `reference_add()` | 355-425 | Add single reference |
| Reference Add Many | `reference_add_many()` | 427-455 | Batch add references |
| Reference Delete | `reference_delete()` | 457-524 | Delete reference |
| Reference Replace | `reference_replace()` | 526-576 | Replace all references |
| Delete By ID | `delete_by_id()` | 578-596 | Delete single object |
| Delete Many | `delete_many()` | 598-639 | Batch delete with filters |

### Elixir Implementation CRUD Operations

**Source:** `/lib/weaviate_ex/api/data.ex`

| Operation | Method | Lines | Description |
|-----------|--------|-------|-------------|
| Insert | `insert/4` | 91-102 | Single object insert |
| Get By ID | `get_by_id/4` | 126-134 | Retrieve object |
| Update | `update/5` | 158-170 | Full replacement (PUT) |
| Replace | `replace/5` | 203-207 | Alias for update |
| Patch | `patch/5` | 231-248 | Partial update (PATCH) |
| Delete By ID | `delete_by_id/4` | 269-277 | Delete single object |
| Exists? | `exists?/4` | 299-311 | Check existence |
| Validate | `validate/4` | 334-345 | Validate without insert |

### CRUD Operation Gaps

| Operation | Python | Elixir | Gap |
|-----------|--------|--------|-----|
| insert | Yes | Yes | None |
| insert_many | Yes (gRPC) | Via Batch API | Different module |
| get_by_id | Yes (via query) | Yes | None |
| exists | Yes | Yes | None |
| replace (PUT) | Yes | Yes | None |
| update (PATCH) | Yes | Yes | None |
| delete_by_id | Yes | Yes | None |
| delete_many | Yes (gRPC) | Via Batch API | Different module |
| reference_add | Yes | Yes (References API) | Different module |
| reference_add_many | Yes | Yes (References API) | Different module |
| reference_delete | Yes | Yes (References API) | Different module |
| reference_replace | Yes | Yes (References API) | Different module |
| **fetch_object_by_id** | Yes (dedicated) | No | **GAP** |
| **with_data_model** | Yes (typed) | No | **GAP** |

### Critical Gap: Typed Data Models

**Python:** Supports generic typed properties and references:
```python
# Type-safe data model
class MyProperties(TypedDict):
    title: str
    content: str

collection.data.insert(properties=MyProperties(title="Hello", content="World"))
# Properties are validated against the TypedDict
```

**Elixir:** No equivalent type-safe data model:
```elixir
# Properties are plain maps without compile-time validation
Data.insert(client, "Article", %{properties: %{"title" => "Hello"}})
```

---

## 3. Object Validation

### Python Validation Features

**Source:** `/weaviate-python-client/weaviate/validator.py` (lines 22-62)

```python
@dataclass
class _ValidateArgument:
    expected: List[Any]
    name: str
    value: Any

def _validate_input(inputs: Union[List[_ValidateArgument], _ValidateArgument]) -> None:
    if isinstance(inputs, _ValidateArgument):
        inputs = [inputs]
    for validate in inputs:
        if not any(_is_valid(exp, validate.value) for exp in validate.expected):
            raise WeaviateInvalidInputError(
                f"Argument '{validate.name}' must be one of: {validate.expected}"
            )
```

**Source:** `/weaviate-python-client/weaviate/collections/data/executor.py` (lines 111-120)
```python
if self._validate_arguments:
    _validate_input([
        _ValidateArgument(expected=[UUID, None], name="uuid", value=uuid),
        _ValidateArgument(expected=[Mapping], name="properties", value=properties),
        _ValidateArgument(expected=[Mapping, None], name="references", value=references),
    ])
```

### Elixir Validation Features

**Source:** `/lib/weaviate_ex/api/data.ex` - No explicit validation beyond type specs

**Source:** `/lib/weaviate_ex/objects/payload.ex` (lines 152-165)
```elixir
defp validate_vectors!(data) do
  has_vector = Map.has_key?(data, "vector") and data["vector"] != nil
  has_vectors = Map.has_key?(data, "vectors") and data["vectors"] != nil and data["vectors"] != %{}

  if has_vector and has_vectors do
    raise ArgumentError,
          "cannot specify both 'vector' and 'vectors'"
  end
  data
end
```

### Validation Gaps

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Argument type validation | Yes | Partial | **GAP**: No runtime type validation |
| UUID format validation | Yes | Yes | None |
| Property key validation | Yes (`id`, `vector` reserved) | No | **GAP** |
| Reference type validation | Yes | No | **GAP** |
| Vector/Vectors mutual exclusion | Yes | Yes | None |
| Property value serialization check | Yes | No | **GAP** |
| GeoCoordinate bounds | Yes | Yes | None |
| Phone number format | Via Weaviate | Via Weaviate | None |

---

## 4. Cross-Reference Handling

### Python Cross-Reference Classes

**Source:** `/weaviate-python-client/weaviate/collections/classes/internal.py` (lines 454-536)

```python
class _Reference:
    def __init__(self, target_collection: Optional[str], uuids: UUIDS):
        self.__target_collection = target_collection if target_collection else ""
        self.__uuids = uuids

    def _to_beacons(self) -> List[Dict[str, str]]:
        return _to_beacons(self.__uuids, self.__target_collection)

    @property
    def is_one_to_many(self) -> bool:
        return self.__uuids is not None and isinstance(self.__uuids, list) and len(self.__uuids) > 1

class ReferenceToMulti(_WeaviateInput):
    target_collection: str
    uuids: UUIDS

    def _to_beacons(self) -> List[Dict[str, str]]:
        return _to_beacons(self.uuids, self.target_collection)

class _CrossReference(Generic[Properties, IReferences]):
    def __init__(self, objects: Optional[List[Object[Properties, IReferences]]]):
        self.__objects = objects

    @property
    def objects(self) -> List[Object[Properties, IReferences]]:
        return self.__objects or []
```

### Elixir Cross-Reference Implementation

**Source:** `/lib/weaviate_ex/api/references.ex` (lines 70-196)

```elixir
def add(client, collection, from_uuid, from_property, to, opts \\ []) do
  path = "/v1/objects/#{collection}/#{from_uuid}/references/#{from_property}"
  beacon = build_beacon(to)
  Client.request(client, :post, path, beacon, opts)
end

defp build_beacon(uuid) when is_binary(uuid) do
  %{"beacon" => "weaviate://localhost/#{uuid}"}
end

defp build_beacon(%{target_collection: collection, uuids: uuid}) when is_binary(uuid) do
  %{"beacon" => "weaviate://localhost/#{collection}/#{uuid}"}
end
```

**Source:** `/lib/weaviate_ex/data/reference_to_multi.ex` (lines 41-84)

```elixir
def new(target_collection, uuids) when is_binary(target_collection) do
  %__MODULE__{target_collection: target_collection, uuids: uuids}
end

def to_beacons(%__MODULE__{target_collection: col, uuids: uuids}) do
  uuids
  |> List.wrap()
  |> Enum.map(fn uuid ->
    %{"beacon" => "weaviate://localhost/#{col}/#{uuid}"}
  end)
end
```

### Cross-Reference Gaps

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Single-target reference | Yes | Yes | None |
| Multi-target reference | Yes | Yes | None |
| Beacon generation | Yes | Yes | None |
| Reference add | Yes | Yes | None |
| Reference delete | Yes | Yes | None |
| Reference replace | Yes | Yes | None |
| Batch reference add | Yes | Yes | None |
| **CrossReference type (nested objects in refs)** | Yes | No | **GAP** |
| **Reference with metadata** | Yes | No | **GAP** |
| **is_one_to_many property** | Yes | No | **GAP** |
| **CrossReferenceAnnotation** | Yes | No | **GAP** |

---

## 5. UUID Generation and Validation

### Python UUID Handling

**Source:** `/weaviate-python-client/weaviate/util.py` (lines 228-261, 389-399)

```python
def get_valid_uuid(uuid: Union[str, uuid_lib.UUID]) -> str:
    if isinstance(uuid, uuid_lib.UUID):
        return str(uuid)
    if not isinstance(uuid, str):
        raise TypeError("'uuid' must be of type str or uuid.UUID")

    # Handle Weaviate beacon URLs
    _is_weaviate_url = is_weaviate_object_url(uuid)
    _is_object_url = is_object_url(uuid)
    if _is_weaviate_url or _is_object_url:
        _uuid = uuid.split("/")[-1]
    try:
        _uuid = str(uuid_lib.UUID(_uuid))
    except ValueError:
        raise ValueError("Not valid 'uuid' or 'uuid' can not be extracted")
    return _uuid

def generate_uuid5(identifier: Any, namespace: Any = "") -> str:
    return str(uuid_lib.uuid5(uuid_lib.NAMESPACE_DNS, str(namespace) + str(identifier)))
```

### Elixir UUID Handling

**Source:** `/lib/weaviate_ex/types/uuid.ex` (lines 30-121)

```elixir
@uuid_regex ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

def generate do
  bytes = :crypto.strong_rand_bytes(16)
  <<a::48, _version::4, b::12, _variant::2, c::62>> = bytes
  uuid_bytes = <<a::48, 4::4, b::12, 2::2, c::62>>
  format_uuid(uuid_bytes)
end

def validate(uuid) when is_binary(uuid) do
  if Regex.match?(@uuid_regex, uuid) do
    {:ok, String.downcase(uuid)}
  else
    {:error, "Invalid UUID format: #{uuid}"}
  end
end

def from_string(namespace, name) when is_binary(namespace) and is_binary(name) do
  hash = :crypto.hash(:sha, namespace <> name)
  # ... UUID v5 generation
end
```

### UUID Gaps

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| UUID v4 generation | Yes (`uuid.uuid4()`) | Yes (`:crypto.strong_rand_bytes`) | None |
| UUID v5 generation | Yes (`uuid.uuid5()`) | Yes (`from_string/2`) | None |
| UUID validation | Yes | Yes | None |
| UUID normalization | Yes (lowercase) | Yes (lowercase) | None |
| **Extract UUID from beacon URL** | Yes | No | **GAP** |
| **Extract UUID from object URL** | Yes | No | **GAP** |
| **Accept uuid.UUID objects** | Yes | No (strings only) | **Minor GAP** |

---

## 6. Vector Handling

### Python Vector Handling

**Source:** `/weaviate-python-client/weaviate/types.py` (lines 12-13)
```python
VECTORS = Union[Mapping[str, Union[Sequence[NUMBER], Sequence[Sequence[NUMBER]]]], Sequence[NUMBER]]
```

**Source:** `/weaviate-python-client/weaviate/util.py` (lines 264-298)
```python
def get_vector(vector: Sequence) -> Sequence[float]:
    if isinstance(vector, list):
        return vector
    try:
        # numpy.ndarray or torch.Tensor
        return vector.squeeze().tolist()
    except AttributeError:
        pass
    try:
        # tf.Tensor or torch.Tensor
        return vector.numpy().squeeze().tolist()
    except AttributeError:
        pass
    try:
        # pd.Series or pl.Series
        return vector.to_list()
    except AttributeError:
        pass
    raise TypeError("Unsupported vector type")
```

**Source:** `/weaviate-python-client/weaviate/collections/batch/grpc_batch.py` (lines 50-64)
```python
def __single_vec(self, vectors: Optional[VECTORS]) -> Optional[bytes]:
    if not _is_1d_vector(vectors):
        return None
    return _Pack.single(vectors)

def __multi_vec(self, vectors: Optional[VECTORS]) -> Optional[List[base_pb2.Vectors]]:
    if vectors is None or _is_1d_vector(vectors):
        return None
    vectors = cast(Mapping[str, Union[Sequence[float], Sequence[Sequence[float]]]], vectors)
    return [
        base_pb2.Vectors(name=name, vector_bytes=packing.bytes_, type=packing.type_)
        for name, vec_or_vecs in vectors.items()
        if (packing := _Pack.parse_single_or_multi_vec(vec_or_vecs))
    ]
```

### Elixir Vector Handling

**Source:** `/lib/weaviate_ex/objects/payload.ex` (lines 167-195)
```elixir
defp handle_vectors(data) do
  cond do
    has_non_empty_vectors?(data) ->
      data |> Map.delete("vector")
    Map.has_key?(data, "vector") ->
      data |> Map.delete("vectors")
    true ->
      data |> Map.delete("vector") |> Map.delete("vectors")
  end
end

defp has_non_empty_vectors?(data) do
  case Map.get(data, "vectors") do
    nil -> false
    %{} = m when map_size(m) == 0 -> false
    %{} -> true
    _ -> false
  end
end
```

### Vector Handling Gaps

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Single vector (list) | Yes | Yes | None |
| Named vectors (map) | Yes | Yes | None |
| vector/vectors mutual exclusion | Yes | Yes | None |
| **NumPy array support** | Yes | N/A | Not applicable |
| **PyTorch Tensor support** | Yes | N/A | Not applicable |
| **TensorFlow Tensor support** | Yes | N/A | Not applicable |
| **Pandas Series support** | Yes | N/A | Not applicable |
| **Polars Series support** | Yes | N/A | Not applicable |
| **Multi-dimensional vectors (Sequence[Sequence[float]])** | Yes | No | **GAP** |
| **Vector packing to bytes** | Yes (gRPC) | No | **GAP** |
| **Vector type detection (1D vs multi)** | Yes | No | **GAP** |

---

## 7. Nested Object Support

### Python Nested Object Handling

**Source:** `/weaviate-python-client/weaviate/collections/classes/internal.py` (lines 428-451)
```python
Nested = Annotated[P, "NESTED"]

def __is_nested(value: Any) -> bool:
    return (
        get_origin(value) is Annotated
        and len(get_args(value)) == 2
        and cast(str, get_args(value)[1]) == "NESTED"
    )

def __create_nested_property_from_nested(name: str, value: Any) -> QueryNested:
    inner_type = get_args(value)[0]
    if get_origin(inner_type) is list:
        inner_type = get_args(inner_type)[0]

    return QueryNested(
        name=name,
        properties=[
            __create_nested_property_from_nested(key, val) if __is_nested(val) else key
            for key, val in get_type_hints(inner_type, include_extras=True).items()
        ],
    )
```

**Source:** `/weaviate-python-client/weaviate/collections/batch/grpc_batch.py` (lines 253-293)
```python
elif isinstance(entry, dict):
    parsed = self.__translate_properties_from_python_to_grpc(entry, {})
    object_properties.append(
        base_pb2.ObjectProperties(
            prop_name=key,
            value=base_pb2.ObjectPropertiesValue(
                non_ref_properties=parsed.non_ref_properties,
                # ... all nested property types
            ),
        )
    )
elif isinstance(entry, list) and len(entry) > 0 and isinstance(entry[0], dict):
    # Handle object arrays
    object_array_properties.append(...)
```

### Elixir Nested Object Handling

**Source:** `/lib/weaviate_ex/property/nested.ex` (lines 80-114)
```elixir
def new(opts) do
  %__MODULE__{
    name: Keyword.fetch!(opts, :name),
    data_type: Keyword.fetch!(opts, :data_type),
    nested_properties: Keyword.get(opts, :nested_properties),
    description: Keyword.get(opts, :description),
    indexable: Keyword.get(opts, :indexable),
    tokenization: Keyword.get(opts, :tokenization)
  }
end

def to_api(%__MODULE__{} = nested) do
  %{
    "name" => nested.name,
    "dataType" => [DataType.to_string(nested.data_type)]
  }
  |> maybe_put("description", nested.description)
  |> maybe_add_indexable(nested.indexable)
  |> maybe_put("tokenization", normalize_tokenization(nested.tokenization))
  |> maybe_add_nested_properties(nested.nested_properties)
end
```

### Nested Object Gaps

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Define nested property | Yes | Yes | None |
| Recursive nesting | Yes | Yes | None |
| Nested property indexability | Yes | Yes | None |
| Nested property tokenization | Yes | Yes | None |
| **Type-annotated nested (Annotated[P, "NESTED"])** | Yes | No | **GAP** |
| **Automatic property extraction from TypedDict** | Yes | No | **GAP** |
| **gRPC nested property serialization** | Yes | Partial | **GAP** |

---

## 8. Payload Serialization/Deserialization

### Python Serialization

**Source:** `/weaviate-python-client/weaviate/collections/data/executor.py` (lines 657-700)
```python
def __serialize_props(self, props: Properties) -> Dict[str, Any]:
    return {key: self.__serialize_primitive(val) for key, val in props.items()}

def __serialize_primitive(self, value: WeaviateField) -> Any:
    if isinstance(value, str) or isinstance(value, int) or isinstance(value, float):
        return value
    if isinstance(value, uuid_package.UUID):
        return str(value)
    if isinstance(value, datetime.datetime):
        return _datetime_to_string(value)
    if isinstance(value, GeoCoordinate):
        return value._to_dict()
    if isinstance(value, PhoneNumber):
        return value._to_dict()
    if isinstance(value, _PhoneNumber):
        raise WeaviateInvalidInputError(
            "Cannot use _PhoneNumber when inserting. Use PhoneNumber instead."
        )
    if isinstance(value, Mapping):
        return {key: self.__serialize_primitive(val) for key, val in value.items()}
    if isinstance(value, Sequence):
        return [self.__serialize_primitive(val) for val in value]
    if value is None:
        return value
    raise WeaviateInvalidInputError(f"Cannot serialize value of type {type(value)}")
```

**Source:** `/weaviate-python-client/weaviate/util.py` (lines 714-718)
```python
def _datetime_to_string(value: TIME) -> str:
    if value.tzinfo is None:
        _Warnings.datetime_insertion_with_no_specified_timezone(value)
        value = value.replace(tzinfo=datetime.timezone.utc)
    return value.isoformat(sep="T", timespec="microseconds")
```

### Elixir Serialization

**Source:** `/lib/weaviate_ex/objects/payload.ex` (lines 18-43)
```elixir
def normalize_keys(data) when is_map(data) do
  Map.new(data, fn
    {key, value} when is_map(value) ->
      {normalize_key(key), normalize_keys(value)}
    {key, value} when is_list(value) ->
      {normalize_key(key), Enum.map(value, &normalize_nested/1)}
    {key, value} ->
      {normalize_key(key), value}
  end)
end

defp normalize_key(key) when is_atom(key), do: Atom.to_string(key)
defp normalize_key(key), do: key
```

### Serialization Gaps

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| String passthrough | Yes | Yes | None |
| Int/Float passthrough | Yes | Yes | None |
| UUID to string | Yes | No | **GAP** (passed as-is) |
| DateTime to RFC3339 | Yes | No | **GAP** (passed as-is) |
| GeoCoordinate to dict | Yes | No | **GAP** |
| PhoneNumber to dict | Yes | No | **GAP** |
| Nested map recursion | Yes | Yes | None |
| Nested list recursion | Yes | Yes | None |
| **Output type validation (_PhoneNumber check)** | Yes | No | **GAP** |
| **Timezone warning for naive datetime** | Yes | No | **GAP** |
| **Microsecond precision** | Yes | Unknown | **Verify** |

---

## Summary of Critical Gaps

### High Priority (Core Functionality)

1. **Property Value Serialization** (Data.ex)
   - Missing: UUID to string conversion
   - Missing: DateTime to RFC3339 conversion
   - Missing: GeoCoordinate struct to map conversion
   - Missing: PhoneNumber struct to map conversion

2. **Multi-dimensional Vector Support** (Batch, gRPC)
   - Missing: Support for `Sequence[Sequence[float]]` (multi-vectors per named vector)
   - Missing: Vector packing to bytes for gRPC efficiency

3. **Input Validation** (Data.ex, References.ex)
   - Missing: Runtime type validation similar to Python's `_validate_input`
   - Missing: Reserved property key validation (`id`, `vector`)

4. **UUID Extraction from URLs**
   - Missing: Extract UUID from Weaviate beacon URLs
   - Missing: Extract UUID from object URLs

### Medium Priority (Feature Parity)

5. **Typed Data Models**
   - Missing: Generic typed properties (`TypedDict` equivalent)
   - Missing: Typed references with compile-time checking

6. **CrossReference with Nested Objects**
   - Missing: `_CrossReference` type for retrieving referenced objects
   - Missing: `CrossReferenceAnnotation` for query metadata

7. **Chunked File Encoding**
   - Missing: Large file chunked reading for blob encoding

### Low Priority (Nice to Have)

8. **Datetime Timezone Handling**
   - Missing: Warning for naive datetime insertion

9. **is_one_to_many Helper**
   - Missing: Property to check if reference points to multiple objects

---

## Recommendations

### Immediate Actions (v0.8.0)

1. **Add property value serialization to `Payload` module:**
```elixir
defp serialize_value(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
defp serialize_value(%WeaviateEx.Types.GeoCoordinate{} = geo), do: GeoCoordinate.to_map(geo)
defp serialize_value(%WeaviateEx.Types.PhoneNumber{} = phone), do: PhoneNumber.to_map(phone)
defp serialize_value(uuid) when is_binary(uuid) and byte_size(uuid) == 36, do: uuid
defp serialize_value(value), do: value
```

2. **Add UUID extraction utilities:**
```elixir
def extract_from_beacon("weaviate://localhost/" <> rest) do
  rest |> String.split("/") |> List.last() |> validate()
end
```

3. **Add input validation module:**
```elixir
defmodule WeaviateEx.Validator do
  def validate_properties!(props) when is_map(props) do
    if Map.has_key?(props, "id") or Map.has_key?(props, "vector") do
      raise ArgumentError, "Properties cannot contain 'id' or 'vector' keys"
    end
    props
  end
end
```

### Future Enhancements (v0.9.0+)

4. **Multi-dimensional vector support in gRPC batch**

5. **Typed data model DSL:**
```elixir
defmodule MySchema do
  use WeaviateEx.Schema

  property :title, :text, required: true
  property :content, :text
  property :views, :int, default: 0
end
```

6. **CrossReference query support:**
```elixir
Query.fetch_objects("Article",
  return_references: [
    %QueryReference{link_on: "hasAuthor", return_properties: ["name"]}
  ]
)
```

---

## Appendix: File References

### Python Client Files Analyzed

| File | Purpose |
|------|---------|
| `/weaviate/types.py` | Type aliases, data type mappings |
| `/weaviate/collections/classes/types.py` | WeaviateField, GeoCoordinate, PhoneNumber |
| `/weaviate/collections/classes/data.py` | DataObject, DataReference |
| `/weaviate/collections/classes/internal.py` | _Reference, ReferenceToMulti, _CrossReference |
| `/weaviate/collections/data/executor.py` | CRUD operations, serialization |
| `/weaviate/collections/batch/grpc_batch.py` | Batch gRPC operations |
| `/weaviate/validator.py` | Input validation |
| `/weaviate/util.py` | UUID utilities, vector handling, datetime |

### Elixir Implementation Files Analyzed

| File | Purpose |
|------|---------|
| `/lib/weaviate_ex/types/data_type.ex` | Data type definitions |
| `/lib/weaviate_ex/types/geo_coordinate.ex` | GeoCoordinate struct |
| `/lib/weaviate_ex/types/phone_number.ex` | PhoneNumber struct |
| `/lib/weaviate_ex/types/blob.ex` | Blob encoding/decoding |
| `/lib/weaviate_ex/types/uuid.ex` | UUID generation/validation |
| `/lib/weaviate_ex/objects/payload.ex` | Payload preparation |
| `/lib/weaviate_ex/api/data.ex` | CRUD operations |
| `/lib/weaviate_ex/api/references.ex` | Reference operations |
| `/lib/weaviate_ex/api/batch.ex` | Batch operations |
| `/lib/weaviate_ex/data/reference_to_multi.ex` | Multi-target references |
| `/lib/weaviate_ex/property/nested.ex` | Nested property definitions |
