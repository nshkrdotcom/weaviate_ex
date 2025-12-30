# Gap Analysis: Data Types and Object Handling

This document provides a comprehensive comparison of data types and object handling between the canonical Python client and the Elixir port.

## Executive Summary

The Elixir port has solid implementations for most data types and basic object CRUD operations but lacks several advanced features from the Python client including:
- ORM/typed property support
- Advanced vector type handling (numpy, torch, tensorflow)
- Complete reference management operations
- Rich output types with metadata

| Feature Area | Python Status | Elixir Status | Gap Severity |
|-------------|---------------|---------------|--------------|
| Primitive Types | Complete | Complete | None |
| Complex Types | Complete | Complete | None |
| Vector Types | Advanced | Basic | Medium |
| Reference Types | Complete | Partial | Medium |
| UUID Handling | Complete | Complete | Minor |
| Object CRUD | Complete | Complete | Minor |
| Object Validation | Complete | Partial | Medium |
| Property Serialization | Complete | Partial | Minor |
| Nested Objects | Complete | Basic | Minor |

---

## 1. Primitive Data Types

### 1.1 Python Implementation

Python defines primitive types in `weaviate/types.py` and `weaviate/collections/classes/types.py`:

```python
# types.py
PRIMITIVE = Union[str, int, float, bool, datetime.datetime, uuid_package.UUID]

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
}

# types.py - WeaviateField type alias
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

### 1.2 Elixir Implementation

Elixir defines types in `lib/weaviate_ex/types/data_type.ex`:

```elixir
@type t ::
        :text
        | :text_array
        | :int
        | :int_array
        | :boolean
        | :boolean_array
        | :number
        | :number_array
        | :date
        | :date_array
        | :uuid
        | :uuid_array
        | :geo_coordinates
        | :blob
        | :phone_number
        | :object
        | :object_array

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

### 1.3 Gap Analysis

| Type | Python | Elixir | Gap |
|------|--------|--------|-----|
| text | `str` | `:text` | None |
| int | `int` | `:int` | None |
| number | `float` | `:number` | None |
| boolean | `bool` | `:boolean` | None |
| date | `datetime.datetime` | `:date` | None |
| text[] | `List[str]` | `:text_array` | None |
| int[] | `List[int]` | `:int_array` | None |
| number[] | `List[float]` | `:number_array` | None |
| boolean[] | `List[bool]` | `:boolean_array` | None |
| date[] | `List[datetime]` | `:date_array` | None |

**Status: COMPLETE** - All primitive types supported with array variants.

---

## 2. Complex Types

### 2.1 GeoCoordinates

#### Python Implementation (`types.py`)

```python
class GeoCoordinate(_WeaviateInput):
    """Input for the geo-coordinate datatype."""
    latitude: float = Field(default=..., le=90, ge=-90)
    longitude: float = Field(default=..., le=180, ge=-180)

    def _to_dict(self) -> Dict[str, float]:
        return self.model_dump(exclude_none=True)
```

#### Elixir Implementation (`types/geo_coordinate.ex`)

```elixir
@type t :: %__MODULE__{
        latitude: float(),
        longitude: float()
      }

@spec new(number(), number()) :: {:ok, t()} | {:error, String.t()}
def new(latitude, longitude)
    when is_number(latitude) and is_number(longitude) and
           latitude >= -90 and latitude <= 90 and
           longitude >= -180 and longitude <= 180 do
  {:ok, %__MODULE__{latitude: latitude, longitude: longitude}}
end

@spec to_map(t()) :: map()
def to_map(%__MODULE__{latitude: lat, longitude: lon}) do
  %{"latitude" => lat, "longitude" => lon}
end

@spec from_map(map()) :: {:ok, t()} | {:error, String.t()}
def from_map(%{"latitude" => lat, "longitude" => lon}) do
  new(lat, lon)
end
```

**Status: COMPLETE** - Full parity with validation and serialization.

### 2.2 PhoneNumber

#### Python Implementation (`types.py`)

```python
class PhoneNumber(_PhoneNumberBase):
    """Input for the phone number datatype."""
    default_country: Optional[str] = Field(default=None)

    def _to_dict(self) -> Mapping[str, str]:
        out: Dict[str, str] = {"input": self.number}
        if self.default_country is not None:
            out["defaultCountry"] = self.default_country
        return out

class _PhoneNumber(_PhoneNumberBase):
    """Output for the phone number datatype."""
    country_code: int
    default_country: str
    international_formatted: str
    national: int
    national_formatted: str
    valid: bool
```

#### Elixir Implementation (`types/phone_number.ex`)

```elixir
@type t :: %__MODULE__{
        number: String.t(),
        default_country: String.t() | nil
      }

defmodule Output do
  @type t :: %__MODULE__{
          input: String.t() | nil,
          country_code: integer() | nil,
          default_country: String.t() | nil,
          international_formatted: String.t() | nil,
          national: integer() | nil,
          national_formatted: String.t() | nil,
          valid: boolean() | nil
        }
end

@spec to_map(t()) :: map()
def to_map(%__MODULE__{number: num, default_country: nil}) do
  %{"input" => num}
end

def to_map(%__MODULE__{number: num, default_country: country}) do
  %{"input" => num, "defaultCountry" => country}
end
```

**Status: COMPLETE** - Full parity including separate input/output types.

### 2.3 Blob

#### Python Implementation (`util.py`)

```python
def file_encoder_b64(file_or_file_path: Union[str, Path, io.BufferedReader]) -> str:
    """Encode a file in a Weaviate understandable format."""
    # Supports str path, Path, and BufferedReader
    # Handles chunked reading for large files

def parse_blob(media: BLOB_INPUT) -> str:
    """Parse a blob input to a base64 encoded string."""
    if isinstance(media, str):
        if os.path.isfile(media):
            return file_encoder_b64(media)
        else:
            return media  # assume already encoded
```

#### Elixir Implementation (`types/blob.ex`)

```elixir
@spec encode(binary()) :: String.t()
def encode(data) when is_binary(data) do
  Base.encode64(data)
end

@spec encode_file(Path.t()) :: {:ok, String.t()} | {:error, File.posix()}
def encode_file(path) do
  case File.read(path) do
    {:ok, data} -> {:ok, encode(data)}
    {:error, reason} -> {:error, reason}
  end
end

@spec decode_to_file(String.t(), Path.t()) :: :ok | {:error, term()}
def decode_to_file(encoded, path)
```

**Status: COMPLETE** - Full parity including file operations.

**Minor Gap**: Python supports `BufferedReader` and chunked reading for large files. Elixir reads entire file into memory.

---

## 3. Vector Types

### 3.1 Python Implementation

Python supports multiple vector input formats in `util.py`:

```python
def get_vector(vector: Sequence) -> Sequence[float]:
    """Supported types: list, numpy.ndarray, torch.Tensor, tf.Tensor, pd.Series, pl.Series"""
    if isinstance(vector, list):
        return vector
    try:
        return vector.squeeze().tolist()  # numpy/torch
    except AttributeError:
        pass
    try:
        return vector.numpy().squeeze().tolist()  # tf.Tensor
    except AttributeError:
        pass
    try:
        return vector.to_list()  # pandas/polars
    except AttributeError:
        pass
```

Named vectors in `data/executor.py`:

```python
def __parse_vector(self, obj: Dict[str, Any], vector: VECTORS) -> Dict[str, Any]:
    if isinstance(vector, dict):
        obj["vectors"] = {key: _get_vector_v4(val) for key, val in vector.items()}
    else:
        obj["vector"] = _get_vector_v4(vector)
    return obj
```

Types definition (`types.py`):

```python
VECTORS = Union[
    Mapping[str, Union[Sequence[NUMBER], Sequence[Sequence[NUMBER]]]],  # named vectors
    Sequence[NUMBER]  # single vector
]
INCLUDE_VECTOR = Union[bool, str, List[str]]
```

### 3.2 Elixir Implementation (`types/vector.ex`)

```elixir
@type t :: list(float()) | list(list(float()))

@spec validate(term()) :: :ok | {:error, String.t()}
def validate(vector) when is_list(vector) do
  cond do
    vector == [] -> {:error, "Vector cannot be empty"}
    Enum.all?(vector, &is_number/1) -> :ok  # 1D
    all_lists?(vector) and all_numeric_lists?(vector) ->
      validate_multi_dimensional(vector)  # 2D/ColBERT
    true -> {:error, "Invalid vector format"}
  end
end

@spec shape(t()) :: {non_neg_integer()} | {non_neg_integer(), non_neg_integer()}
def shape(vector)

@spec normalize(list(float())) :: list(float())
def normalize(vector)  # L2 normalization

@spec dot_product(list(float()), list(float())) :: float()
def dot_product(v1, v2)

@spec cosine_similarity(list(float()), list(float())) :: float()
def cosine_similarity(v1, v2)
```

Named vectors in `objects/payload.ex`:

```elixir
defp validate_vectors!(data) do
  has_vector = Map.has_key?(data, "vector") and data["vector"] != nil
  has_vectors = Map.has_key?(data, "vectors") and data["vectors"] != nil and data["vectors"] != %{}

  if has_vector and has_vectors do
    raise ArgumentError, "cannot specify both 'vector' and 'vectors'"
  end
  data
end

defp handle_vectors(data) do
  cond do
    has_non_empty_vectors?(data) -> Map.delete(data, "vector")
    Map.has_key?(data, "vector") -> Map.delete(data, "vectors")
    true -> data |> Map.delete("vector") |> Map.delete("vectors")
  end
end
```

### 3.3 Gap Analysis

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| List vectors | Yes | Yes | None |
| Named vectors | Yes | Yes | None |
| Multi-vectors (ColBERT) | Yes | Yes | None |
| numpy.ndarray | Yes | No | **CRITICAL** |
| torch.Tensor | Yes | No | **CRITICAL** |
| tf.Tensor | Yes | No | **CRITICAL** |
| pandas.Series | Yes | No | Minor |
| polars.Series | Yes | No | Minor |
| Vector validation | Basic | Good | None |
| Normalize/dot product | No | Yes | Elixir has more |
| INCLUDE_VECTOR types | Yes | Partial | Minor |

**Critical Gaps**:
1. No support for ML framework tensor types (numpy, torch, tensorflow) - These are Python-specific libraries
2. No automatic conversion from Nx tensors (Elixir's numeric library)

**Recommendation**: Add Nx tensor support for Elixir ML ecosystem compatibility:
```elixir
def from_nx(tensor) when is_struct(tensor, Nx.Tensor) do
  Nx.to_flat_list(tensor)
end
```

---

## 4. Reference Types

### 4.1 Python Implementation

#### Reference Input Types (`internal.py`)

```python
@dataclass
class ReferenceToMulti(_WeaviateInput):
    """Multi-target reference property."""
    target_collection: str
    uuids: UUIDS

    def _to_beacons(self) -> List[Dict[str, str]]:
        return _to_beacons(self.uuids, self.target_collection)

class _Reference:
    def __init__(self, target_collection: Optional[str], uuids: UUIDS):
        self.__target_collection = target_collection if target_collection else ""
        self.__uuids = uuids

    def _to_beacons(self) -> List[Dict[str, str]]:
        return _to_beacons(self.__uuids, self.__target_collection)

    @property
    def is_one_to_many(self) -> bool:
        return self.__uuids is not None and isinstance(self.__uuids, list) and len(self.__uuids) > 1

SingleReferenceInput = Union[UUID, ReferenceToMulti]
ReferenceInput: TypeAlias = Union[UUID, Sequence[UUID], ReferenceToMulti]
ReferenceInputs: TypeAlias = Mapping[str, ReferenceInput]
```

#### Reference Operations (`data/executor.py`)

```python
def reference_add(self, from_uuid: UUID, from_property: str, to: SingleReferenceInput)
def reference_add_many(self, refs: List[DataReferences])
def reference_delete(self, from_uuid: UUID, from_property: str, to: SingleReferenceInput)
def reference_replace(self, from_uuid: UUID, from_property: str, to: ReferenceInput)
```

#### Cross-Reference Output Types

```python
class _CrossReference(Generic[Properties, IReferences]):
    def __init__(self, objects: Optional[List[Object[Properties, IReferences]]]):
        self.__objects = objects

    @property
    def objects(self) -> List[Object[Properties, IReferences]]:
        return self.__objects or []

CrossReference: TypeAlias = _CrossReference[Properties, IReferences]
CrossReferences = Mapping[str, _CrossReference[WeaviateProperties, "CrossReferences"]]
```

### 4.2 Elixir Implementation (`types/reference.ex`)

```elixir
@type t :: %__MODULE__{
        beacon: String.t(),
        target_collection: String.t() | nil,
        target_vectors: list(String.t())
      }

@spec to(String.t(), String.t(), keyword()) :: t()
def to(collection, id, opts \\ []) do
  %__MODULE__{
    beacon: "weaviate://localhost/#{collection}/#{id}",
    target_collection: collection,
    target_vectors: Keyword.get(opts, :target_vectors, [])
  }
end

@spec multi_target(String.t(), String.t(), list(String.t())) :: t()
def multi_target(collection, id, target_vectors)

@spec to_map(t()) :: map()
def to_map(%__MODULE__{} = ref) do
  base = %{"beacon" => ref.beacon}
  if ref.target_vectors != [] do
    Map.put(base, "targetVectors", ref.target_vectors)
  else
    base
  end
end
```

Inline references in `objects/payload.ex`:

```elixir
# Merge references into properties as beacon format
defp merge_references(data) do
  case Map.get(data, "references") do
    nil -> data
    %{} = refs when map_size(refs) == 0 -> Map.delete(data, "references")
    %{} = refs ->
      properties = Map.get(data, "properties", %{})
      updated_properties = convert_references_to_beacons(refs, properties)
      data |> Map.put("properties", updated_properties) |> Map.delete("references")
  end
end

defp build_beacons(uuid) when is_binary(uuid) do
  [%{"beacon" => "weaviate://localhost/#{uuid}"}]
end

defp build_beacons(%{target_collection: collection, uuids: uuids})
```

### 4.3 Gap Analysis

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| Simple reference (UUID) | Yes | Yes | None |
| Multi-target reference | Yes | Yes | None |
| Target vectors | Yes | Yes | None |
| Beacon generation | Yes | Yes | None |
| `reference_add` | Yes | **No** | **CRITICAL** |
| `reference_add_many` | Yes | **No** | **CRITICAL** |
| `reference_delete` | Yes | **No** | **CRITICAL** |
| `reference_replace` | Yes | **No** | **CRITICAL** |
| Inline references on insert | Yes | Yes | None |
| CrossReference output type | Yes | **No** | Medium |
| Reference resolution | Yes | **No** | Medium |

**Critical Gaps**:
1. **Missing reference CRUD operations**: Python provides dedicated methods for managing references after object creation:
   - `reference_add()` - Add a reference to an existing object
   - `reference_add_many()` - Batch add references
   - `reference_delete()` - Remove a reference
   - `reference_replace()` - Replace all references on a property

2. **Missing CrossReference output type**: Python has typed output for resolved cross-references in query results.

**Recommended Implementation**:
```elixir
defmodule WeaviateEx.API.References do
  def add(client, collection, from_uuid, property, to_uuid, opts \\ [])
  def add_many(client, collection, refs)
  def delete(client, collection, from_uuid, property, to_uuid, opts \\ [])
  def replace(client, collection, from_uuid, property, to_uuids, opts \\ [])
end
```

---

## 5. UUID Handling

### 5.1 Python Implementation (`util.py`)

```python
def get_valid_uuid(uuid: Union[str, uuid_lib.UUID]) -> str:
    """Validate and extract UUID from string, beacon URL, or href."""
    if isinstance(uuid, uuid_lib.UUID):
        return str(uuid)

    # Handle beacon URLs: weaviate://localhost/Class/uuid
    _is_weaviate_url = is_weaviate_object_url(uuid)
    # Handle href URLs: /v1/objects/Class/uuid
    _is_object_url = is_object_url(uuid)

    if _is_weaviate_url or _is_object_url:
        _uuid = uuid.split("/")[-1]
    try:
        _uuid = str(uuid_lib.UUID(_uuid))
    except ValueError:
        raise ValueError("Not valid 'uuid' or 'uuid' can not be extracted")
    return _uuid

def generate_uuid5(identifier: Any, namespace: Any = "") -> str:
    """Generate deterministic UUID v5."""
    return str(uuid_lib.uuid5(uuid_lib.NAMESPACE_DNS, str(namespace) + str(identifier)))
```

### 5.2 Elixir Implementation (`types/uuid.ex`)

```elixir
@spec generate() :: String.t()
def generate do
  # UUID v4 using :crypto.strong_rand_bytes
end

@spec validate(String.t()) :: {:ok, String.t()} | {:error, String.t()}
def validate(uuid) when is_binary(uuid) do
  if Regex.match?(@uuid_regex, uuid) do
    {:ok, String.downcase(uuid)}
  else
    {:error, "Invalid UUID format: #{uuid}"}
  end
end

@spec valid?(String.t()) :: boolean()
def valid?(uuid)

@spec from_string(String.t(), String.t()) :: String.t()
def from_string(namespace, name) do
  # UUID v5 using SHA-1 hash
end

@spec extract_from_beacon(String.t()) :: {:ok, String.t()} | {:error, String.t()}
def extract_from_beacon("weaviate://localhost/" <> rest) do
  uuid = rest |> String.split("/") |> List.last()
  validate(uuid)
end
```

### 5.3 Gap Analysis

| Feature | Python | Elixir | Gap |
|---------|--------|--------|-----|
| UUID v4 generation | Yes | Yes | None |
| UUID v5 deterministic | Yes | Yes | None |
| UUID validation | Yes | Yes | None |
| Beacon URL extraction | Yes | Yes | None |
| Object URL extraction | Yes | **No** | Minor |
| Accept python UUID type | Yes | N/A | N/A |
| Case normalization | Yes | Yes | None |

**Minor Gap**: Elixir doesn't support extracting UUID from object URLs (`/v1/objects/Class/uuid`).

**Status: NEAR COMPLETE**

---

## 6. Object CRUD Operations

### 6.1 Python Implementation (`data/executor.py`)

```python
def insert(self, properties: Properties, references: Optional[ReferenceInputs] = None,
           uuid: Optional[UUID] = None, vector: Optional[VECTORS] = None) -> uuid_package.UUID

def insert_many(self, objects: Sequence[Union[Properties, DataObject[...]]]) -> BatchObjectReturn

def exists(self, uuid: UUID) -> bool

def replace(self, uuid: UUID, properties: Properties,
            references: Optional[ReferenceInputs] = None,
            vector: Optional[VECTORS] = None) -> None

def update(self, uuid: UUID, properties: Optional[Properties] = None,
           references: Optional[ReferenceInputs] = None,
           vector: Optional[VECTORS] = None) -> None

def delete_by_id(self, uuid: UUID) -> bool

def delete_many(self, where: _Filters, *, verbose: bool = False, dry_run: bool = False) -> DeleteManyReturn
```

### 6.2 Elixir Implementation (`api/data.ex`)

```elixir
@spec insert(Client.t(), collection_name(), object_data(), opts()) :: {:ok, map()} | {:error, Error.t()}
def insert(client, collection_name, data, opts \\ [])

@spec get_by_id(Client.t(), collection_name(), object_id(), opts()) :: {:ok, map()} | {:error, Error.t()}
def get_by_id(client, collection_name, id, opts \\ [])

@spec update(Client.t(), collection_name(), object_id(), object_data(), opts()) :: {:ok, map()} | {:error, Error.t()}
def update(client, collection_name, id, data, opts \\ [])

@spec replace(Client.t(), collection_name(), object_id(), object_data(), opts()) :: {:ok, map()} | {:error, Error.t()}
def replace(client, collection_name, id, data, opts \\ [])

@spec patch(Client.t(), collection_name(), object_id(), object_data(), opts()) :: {:ok, map()} | {:error, Error.t()}
def patch(client, collection_name, id, data, opts \\ [])

@spec delete_by_id(Client.t(), collection_name(), object_id(), opts()) :: {:ok, map()} | {:error, Error.t()}
def delete_by_id(client, collection_name, id, opts \\ [])

@spec exists?(Client.t(), collection_name(), object_id(), opts()) :: {:ok, boolean()}
def exists?(client, collection_name, id, opts \\ [])

@spec validate(Client.t(), collection_name(), object_data(), opts()) :: {:ok, map()} | {:error, Error.t()}
def validate(client, collection_name, data, opts \\ [])
```

### 6.3 Gap Analysis

| Operation | Python | Elixir | Gap |
|-----------|--------|--------|-----|
| insert | Yes | Yes | None |
| insert_many (batch) | Yes | Separate module | None |
| get_by_id | Yes (via query) | Yes | None |
| update (PATCH) | Yes | Yes (`patch`) | None |
| replace (PUT) | Yes | Yes | None |
| delete_by_id | Yes | Yes | None |
| delete_many | Yes | **Separate** | None |
| exists | Yes | Yes | None |
| validate | No direct | Yes | Elixir has more |
| Multi-tenancy support | Yes | Yes | None |
| Consistency level | Yes | Yes | None |

**Status: COMPLETE** - All core operations available with slightly different organization.

**Differences**:
- Python has `update` (PATCH), Elixir has both `update` (PUT) and `patch` (PATCH)
- Elixir has explicit `validate` endpoint
- Batch operations in separate module in Elixir

---

## 7. Object Validation

### 7.1 Python Implementation

Python validates at runtime in `data/executor.py`:

```python
if self._validate_arguments:
    _validate_input([
        _ValidateArgument(expected=[UUID, None], name="uuid", value=uuid),
        _ValidateArgument(expected=[Mapping], name="properties", value=properties),
        _ValidateArgument(expected=[Mapping, None], name="references", value=references),
    ])

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
    # ... raises WeaviateInvalidInputError for unknown types
```

### 7.2 Elixir Implementation (`validation/property.ex`)

```elixir
@spec validate(term(), atom() | String.t()) :: validation_result()
def validate(nil, _), do: :ok

def validate(value, "text") when is_binary(value), do: :ok
def validate(value, "text"), do: {:error, "Expected string for text type, got #{inspect(value)}"}

def validate(value, "int") when is_integer(value), do: :ok
def validate(value, "int"), do: {:error, "Expected integer for int type, got #{inspect(value)}"}

# ... validation for all types including geo, phone, date, uuid, blob

@spec validate_object(map(), map()) :: :ok | {:error, list(String.t())}
def validate_object(object, schema) do
  # Validates properties against schema definition
end
```

### 7.3 Gap Analysis

| Validation Feature | Python | Elixir | Gap |
|--------------------|--------|--------|-----|
| Type validation | Runtime | Explicit | None |
| UUID format | Yes | Yes | None |
| Date format | Yes | Yes | None |
| Geo coordinate bounds | Yes (Pydantic) | Yes | None |
| Phone number format | Basic | Basic | None |
| Blob base64 | No | Yes | Elixir better |
| Schema-based validation | No | Yes | Elixir better |
| Array element validation | Yes | Yes | None |
| Nested object validation | Partial | Basic | Minor |

**Status: GOOD** - Elixir has explicit validation module with schema support.

**Note**: Python relies more on Pydantic for model validation; Elixir has explicit validator functions.

---

## 8. Property Serialization/Deserialization

### 8.1 Python Implementation (`data/executor.py`)

```python
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
    if isinstance(value, Mapping):
        return {key: self.__serialize_primitive(val) for key, val in value.items()}
    if isinstance(value, Sequence):
        return [self.__serialize_primitive(val) for val in value]
    if value is None:
        return value
    raise WeaviateInvalidInputError(f"Cannot serialize value of type {type(value)}")
```

DateTime serialization (`util.py`):
```python
def _datetime_to_string(value: TIME) -> str:
    if value.tzinfo is None:
        _Warnings.datetime_insertion_with_no_specified_timezone(value)
        value = value.replace(tzinfo=datetime.timezone.utc)
    return value.isoformat(sep="T", timespec="microseconds")

def _datetime_from_weaviate_str(string: str) -> datetime.datetime:
    # Handles various formats including 9-digit microseconds
```

### 8.2 Elixir Implementation (`objects/payload.ex`)

```elixir
# DateTime -> RFC3339 format
defp serialize_value(%DateTime{} = dt) do
  DateTime.to_iso8601(dt)
end

# NaiveDateTime -> RFC3339 format (without timezone)
defp serialize_value(%NaiveDateTime{} = dt) do
  NaiveDateTime.to_iso8601(dt)
end

# GeoCoordinate struct -> map
defp serialize_value(%WeaviateEx.Types.GeoCoordinate{latitude: lat, longitude: lon}) do
  %{"latitude" => lat, "longitude" => lon}
end

# PhoneNumber struct -> map
defp serialize_value(%WeaviateEx.Types.PhoneNumber{number: num, default_country: nil}) do
  %{"input" => num}
end

# Arrays - recursively serialize
defp serialize_value(list) when is_list(list) do
  Enum.map(list, &serialize_value/1)
end

# Nested maps - recursively serialize
defp serialize_value(map) when is_map(map) and not is_struct(map) do
  serialize_values(map)
end

defp serialize_value(other), do: other
```

### 8.3 Gap Analysis

| Serialization Feature | Python | Elixir | Gap |
|-----------------------|--------|--------|-----|
| Primitives | Yes | Yes | None |
| DateTime with tz | Yes (microseconds) | Yes (ISO8601) | Minor format |
| DateTime warning | Yes | No | Minor |
| NaiveDateTime | Adds UTC | Keeps naive | Different behavior |
| GeoCoordinate | Yes | Yes | None |
| PhoneNumber | Yes | Yes | None |
| Nested maps | Yes | Yes | None |
| Arrays | Yes | Yes | None |
| UUID to string | Yes | No explicit | Minor |
| Unknown type error | Yes | Pass through | Different |

**Minor Gaps**:
1. Python adds timezone warning for naive datetimes
2. Python uses microsecond precision explicitly
3. Elixir passes through unknown types; Python raises error

---

## 9. Nested Object Properties

### 9.1 Python Implementation (`internal.py`)

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

### 9.2 Elixir Implementation

Elixir handles nested objects in `validation/property.ex`:

```elixir
# Object type (nested)
def validate(value, "object") when is_map(value), do: :ok
def validate(value, "object"), do: {:error, "Expected map for object type"}
```

And in `objects/payload.ex`:

```elixir
# Nested maps - recursively serialize
defp serialize_value(map) when is_map(map) and not is_struct(map) do
  serialize_values(map)
end
```

### 9.3 Gap Analysis

| Nested Feature | Python | Elixir | Gap |
|----------------|--------|--------|-----|
| Basic nested maps | Yes | Yes | None |
| Nested array objects | Yes | Yes | None |
| `Nested` type annotation | Yes | **No** | Medium |
| QueryNested for queries | Yes | **No** | Medium |
| Nested property extraction | Yes | **No** | Medium |
| Recursive serialization | Yes | Yes | None |
| Nested validation | Limited | Limited | None |

**Medium Gaps**:
1. **Missing `Nested` type annotation**: Python uses `Annotated[Type, "NESTED"]` to mark nested properties for automatic query generation.
2. **Missing QueryNested support**: For querying specific properties within nested objects.

---

## 10. Output Types

### 10.1 Python Implementation (`internal.py`)

Python provides rich typed output objects:

```python
@dataclass
class MetadataReturn:
    creation_time: Optional[datetime.datetime] = None
    last_update_time: Optional[datetime.datetime] = None
    distance: Optional[float] = None
    certainty: Optional[float] = None
    score: Optional[float] = None
    explain_score: Optional[str] = None
    is_consistent: Optional[bool] = None
    rerank_score: Optional[float] = None

@dataclass
class Object(Generic[P, R], _Object[P, R, MetadataReturn]):
    """A single Weaviate object returned by a query."""

@dataclass
class ObjectSingleReturn(Generic[P, R], _Object[P, R, MetadataSingleObjectReturn]):
    """Object returned by fetch_object_by_id."""

@dataclass
class QueryReturn(Generic[P, R]):
    objects: List[Object[P, R]]

@dataclass
class DataObject(Generic[P, R]):
    properties: P = None
    uuid: Optional[UUID] = None
    vector: Optional[VECTORS] = None
    references: R = None
```

### 10.2 Elixir Implementation

Elixir returns raw maps from API responses:

```elixir
@spec get_by_id(Client.t(), collection_name(), object_id(), opts()) ::
        {:ok, map()} | {:error, Error.t()}
```

### 10.3 Gap Analysis

| Output Feature | Python | Elixir | Gap |
|----------------|--------|--------|-----|
| Typed Object response | Yes | No (raw map) | **Medium** |
| MetadataReturn struct | Yes | **No** | Medium |
| QueryReturn wrapper | Yes | **No** | Minor |
| DataObject for batch | Yes | **No** | Medium |
| Generic typing | Yes | N/A | N/A |

**Medium Gap**: Elixir returns raw API response maps without structured types. Consider adding:

```elixir
defmodule WeaviateEx.Objects.Object do
  @type t :: %__MODULE__{
    uuid: String.t(),
    class: String.t(),
    properties: map(),
    vector: list(float()) | nil,
    creation_time: DateTime.t() | nil,
    last_update_time: DateTime.t() | nil
  }
end
```

---

## Summary of Critical Gaps

### Must Implement (Critical)

1. **Reference CRUD Operations** (`reference_add`, `reference_delete`, `reference_replace`, `reference_add_many`)
   - Required for managing references after object creation
   - Python location: `data/executor.py`

### Should Implement (Medium Priority)

2. **Typed Output Structs**
   - `Object`, `MetadataReturn`, `QueryReturn` equivalents
   - Provides better developer experience and documentation

3. **QueryNested Support**
   - For querying nested object properties
   - Required for complex schema designs

4. **CrossReference Output Type**
   - For properly typed resolved references

### Nice to Have (Low Priority)

5. **Nx Tensor Support**
   - For Elixir ML ecosystem compatibility
   - Convert Nx tensors to vector lists

6. **Object URL Extraction**
   - Extract UUID from `/v1/objects/Class/uuid` format

7. **DateTime Timezone Warnings**
   - Match Python behavior for naive datetime handling

---

## API Differences Summary

| Area | Python API | Elixir API | Notes |
|------|------------|------------|-------|
| Insert | `collection.data.insert()` | `Data.insert(client, collection, data)` | Elixir is functional |
| Update | `update` (PATCH) | `patch` (PATCH), `update` (PUT) | Different naming |
| Validation | Runtime via Pydantic | Explicit `validate/2` | Both valid approaches |
| Types | Pydantic models | Elixir structs | Language-appropriate |
| References | Dedicated methods | Inline on insert | Gap for post-insert |
| Return types | Typed dataclasses | Raw maps | Gap for ergonomics |

---

## Recommendations

### Immediate Actions

1. Add `WeaviateEx.API.References` module:
```elixir
defmodule WeaviateEx.API.References do
  def add(client, collection, from_uuid, property, to, opts \\ [])
  def add_many(client, refs)
  def delete(client, collection, from_uuid, property, to, opts \\ [])
  def replace(client, collection, from_uuid, property, to_uuids, opts \\ [])
end
```

### Short-term Improvements

2. Add structured output types:
```elixir
defmodule WeaviateEx.Objects.Response do
  defmodule Object do
    defstruct [:uuid, :class, :properties, :vector, :creation_time, :last_update_time]
  end

  defmodule QueryResult do
    defstruct [:objects, :metadata]
  end
end
```

3. Add Nx tensor support in Vector module:
```elixir
def from_nx(tensor) when is_struct(tensor, Nx.Tensor) do
  Nx.to_flat_list(tensor)
end
```

### Long-term Enhancements

4. Consider TypedStruct-based schemas for compile-time validation
5. Add QueryNested support for nested property queries
6. Document all API differences clearly for users migrating from Python
