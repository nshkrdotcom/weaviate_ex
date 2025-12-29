# Gap Analysis: Vector Configuration and Data Types

## Executive Summary

This document analyzes the gaps between the Python Weaviate client and the Elixir WeaviateEx client for vector configuration and data types. The Python client is significantly more mature, providing:

- **30+ vectorizer configurations** vs ~15 in Elixir
- **Comprehensive named vectors support** with proper builder pattern vs basic implementation in Elixir
- **Complete data type system** with GeoCoordinates, PhoneNumber, Blob handling vs none in Elixir
- **4 quantization methods** (PQ, BQ, SQ, RQ) vs 3 in Elixir (missing RQ)
- **Multi-vector support** (ColBERT embeddings) completely missing in Elixir
- **Property builder with nested objects** missing in Elixir

### Gap Summary by Priority

| Priority | Category | Gap Count | Estimated Effort |
|----------|----------|-----------|------------------|
| Critical | Named Vectors Builder | 5 | 3 days |
| Critical | Data Types | 6 | 2 days |
| High | Missing Vectorizers | 15 | 3 days |
| High | Quantization (RQ) | 1 | 0.5 days |
| High | Multi-Vector Support | 3 | 2 days |
| Medium | Property Builder | 4 | 1 day |
| Medium | Vector Index Updates | 3 | 1 day |
| Low | Model Type Enums | 8 | 1 day |

**Total Estimated Effort: 13.5 days**

---

## Detailed Gap Analysis

### 1. Named Vectors Configuration (Critical)

The Python client has a sophisticated named vectors system through `Configure.NamedVectors` and `Configure.Vectors`.

#### Python Implementation

```python
import weaviate.classes as wvc

# Create collection with multiple named vectors
client.collections.create(
    "Article",
    vectorizer_config=[
        wvc.config.Configure.NamedVectors.text2vec_openai(
            name="title_vector",
            source_properties=["title"],
            model="text-embedding-3-small"
        ),
        wvc.config.Configure.NamedVectors.text2vec_openai(
            name="content_vector",
            source_properties=["content"],
            model="text-embedding-3-large",
            dimensions=1024
        ),
        wvc.config.Configure.NamedVectors.self_provided(
            name="custom_vector"
        )
    ]
)

# Update named vector configuration
client.collections.update(
    "Article",
    vectorizer_config=[
        wvc.config.Reconfigure.NamedVectors.update(
            name="title_vector",
            vector_index_config=wvc.config.Reconfigure.VectorIndex.hnsw(
                ef=200
            )
        )
    ]
)
```

#### Current Elixir Implementation

```elixir
# Basic support exists but lacks:
# - Named vectors in vectorizer_config list format
# - Per-vector source_properties
# - Update configuration
# - Proper integration with collection builder

config = VectorConfig.new("Article")
|> VectorConfig.with_named_vectors(%{
  "title_vector" => %{vectorizer: "text2vec-openai"},
  "content_vector" => %{vectorizer: "text2vec-openai"}
})
```

#### Proposed Elixir Implementation

```elixir
defmodule WeaviateEx.API.NamedVectors do
  @moduledoc """
  Named vectors configuration for multi-vector collections.
  """

  @doc """
  Create a self-provided named vector (no automatic vectorization).
  """
  def self_provided(opts \\ []) do
    %{
      "name" => Keyword.fetch!(opts, :name),
      "vectorizer" => %{"none" => %{}},
      "vectorIndexType" => Keyword.get(opts, :vector_index_type, "hnsw"),
      "vectorIndexConfig" => build_vector_index_config(opts)
    }
    |> maybe_add_quantizer(opts)
  end

  @doc """
  Create a text2vec-openai named vector.

  ## Options
    - `:name` - Vector name (required)
    - `:source_properties` - Properties to vectorize
    - `:model` - OpenAI model name
    - `:dimensions` - Output dimensions
    - `:base_url` - Custom API endpoint
    - `:vectorize_collection_name` - Whether to include collection name
  """
  def text2vec_openai(opts) do
    %{
      "name" => Keyword.fetch!(opts, :name),
      "vectorizer" => %{
        "text2vec-openai" => %{
          "vectorizeClassName" => Keyword.get(opts, :vectorize_collection_name, true)
        }
        |> maybe_put("model", Keyword.get(opts, :model))
        |> maybe_put("dimensions", Keyword.get(opts, :dimensions))
        |> maybe_put("baseURL", Keyword.get(opts, :base_url))
      },
      "vectorIndexType" => Keyword.get(opts, :vector_index_type, "hnsw"),
      "vectorIndexConfig" => build_vector_index_config(opts)
    }
    |> maybe_add_source_properties(opts)
    |> maybe_add_quantizer(opts)
  end

  @doc """
  Create a text2vec-cohere named vector.
  """
  def text2vec_cohere(opts) do
    # Similar implementation for each vectorizer
  end

  # ... implementations for all 30+ vectorizers

  defp build_vector_index_config(opts) do
    case Keyword.get(opts, :vector_index_type, :hnsw) do
      :hnsw -> VectorConfig.hnsw_index(Keyword.get(opts, :hnsw_opts, []))
      :flat -> VectorConfig.flat_index(Keyword.get(opts, :flat_opts, []))
      :dynamic -> VectorConfig.dynamic_index(Keyword.get(opts, :dynamic_opts, []))
      _ -> %{}
    end
    |> Map.get("vectorIndexConfig", %{})
  end

  defp maybe_add_source_properties(config, opts) do
    case Keyword.get(opts, :source_properties) do
      nil -> config
      props -> put_in(config, ["vectorizer", Access.all(), "properties"], props)
    end
  end

  defp maybe_add_quantizer(config, opts) do
    case Keyword.get(opts, :quantizer) do
      nil -> config
      quantizer -> Map.put(config, "quantizer", quantizer)
    end
  end
end
```

---

### 2. Data Types (Critical)

The Python client has comprehensive data type support. Elixir has none.

#### 2.1 DataType Enum

**Python:**
```python
class DataType(str, BaseEnum):
    TEXT = "text"
    TEXT_ARRAY = "text[]"
    INT = "int"
    INT_ARRAY = "int[]"
    BOOL = "boolean"
    BOOL_ARRAY = "boolean[]"
    NUMBER = "number"
    NUMBER_ARRAY = "number[]"
    DATE = "date"
    DATE_ARRAY = "date[]"
    UUID = "uuid"
    UUID_ARRAY = "uuid[]"
    GEO_COORDINATES = "geoCoordinates"
    BLOB = "blob"
    PHONE_NUMBER = "phoneNumber"
    OBJECT = "object"
    OBJECT_ARRAY = "object[]"
```

**Proposed Elixir:**
```elixir
defmodule WeaviateEx.DataType do
  @moduledoc """
  Weaviate data types for property definitions.
  """

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

  @doc "Convert atom to Weaviate data type string"
  def to_string(type) when is_atom(type) do
    Map.fetch!(@data_types, type)
  end

  @doc "Convert Weaviate data type string to atom"
  def from_string(str) when is_binary(str) do
    @data_types
    |> Enum.find(fn {_k, v} -> v == str end)
    |> case do
      {key, _} -> {:ok, key}
      nil -> {:error, {:unknown_data_type, str}}
    end
  end

  @doc "List all supported data types"
  def all, do: Map.keys(@data_types)
end
```

#### 2.2 GeoCoordinates

**Python:**
```python
class GeoCoordinate(_WeaviateInput):
    latitude: float = Field(default=..., le=90, ge=-90)
    longitude: float = Field(default=..., le=180, ge=-180)

    def _to_dict(self) -> Dict[str, float]:
        return self.model_dump(exclude_none=True)

# Usage
properties = {
    "location": GeoCoordinate(latitude=52.3676, longitude=4.9041)
}
```

**Proposed Elixir:**
```elixir
defmodule WeaviateEx.Types.GeoCoordinate do
  @moduledoc """
  Represents a geographic coordinate (latitude/longitude).

  ## Example

      coord = GeoCoordinate.new(52.3676, 4.9041)
      GeoCoordinate.to_map(coord)
      # => %{"latitude" => 52.3676, "longitude" => 4.9041}
  """

  @type t :: %__MODULE__{
          latitude: float(),
          longitude: float()
        }

  defstruct [:latitude, :longitude]

  @doc """
  Create a new GeoCoordinate.

  ## Parameters
    - `latitude` - Latitude value (-90 to 90)
    - `longitude` - Longitude value (-180 to 180)

  ## Example

      {:ok, coord} = GeoCoordinate.new(52.3676, 4.9041)
  """
  @spec new(float(), float()) :: {:ok, t()} | {:error, String.t()}
  def new(latitude, longitude)
      when is_number(latitude) and is_number(longitude) and
             latitude >= -90 and latitude <= 90 and
             longitude >= -180 and longitude <= 180 do
    {:ok, %__MODULE__{latitude: latitude, longitude: longitude}}
  end

  def new(latitude, longitude) when is_number(latitude) and is_number(longitude) do
    cond do
      latitude < -90 or latitude > 90 ->
        {:error, "Latitude must be between -90 and 90, got: #{latitude}"}

      longitude < -180 or longitude > 180 ->
        {:error, "Longitude must be between -180 and 180, got: #{longitude}"}
    end
  end

  def new(_, _), do: {:error, "Latitude and longitude must be numbers"}

  @doc "Create GeoCoordinate, raising on invalid input"
  @spec new!(float(), float()) :: t()
  def new!(latitude, longitude) do
    case new(latitude, longitude) do
      {:ok, coord} -> coord
      {:error, msg} -> raise ArgumentError, msg
    end
  end

  @doc "Convert to map for Weaviate API"
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{latitude: lat, longitude: lon}) do
    %{"latitude" => lat, "longitude" => lon}
  end

  @doc "Parse from Weaviate API response"
  @spec from_map(map()) :: {:ok, t()} | {:error, String.t()}
  def from_map(%{"latitude" => lat, "longitude" => lon}) do
    new(lat, lon)
  end

  def from_map(_), do: {:error, "Invalid geo coordinate format"}
end
```

#### 2.3 PhoneNumber

**Python:**
```python
class PhoneNumber(_PhoneNumberBase):
    number: str
    default_country: Optional[str] = Field(default=None)

    def _to_dict(self) -> Mapping[str, str]:
        out: Dict[str, str] = {"input": self.number}
        if self.default_country is not None:
            out["defaultCountry"] = self.default_country
        return out

# Output type
class _PhoneNumber(_PhoneNumberBase):
    country_code: int
    default_country: str
    international_formatted: str
    national: int
    national_formatted: str
    valid: bool
```

**Proposed Elixir:**
```elixir
defmodule WeaviateEx.Types.PhoneNumber do
  @moduledoc """
  Phone number type for Weaviate.

  Input format is simple, output includes parsed data.

  ## Example

      # Input
      phone = PhoneNumber.new("+1 650-253-0000")
      PhoneNumber.to_map(phone)
      # => %{"input" => "+1 650-253-0000"}

      # With default country
      phone = PhoneNumber.new("650-253-0000", default_country: "US")
      PhoneNumber.to_map(phone)
      # => %{"input" => "650-253-0000", "defaultCountry" => "US"}
  """

  @type input :: %__MODULE__.Input{
          number: String.t(),
          default_country: String.t() | nil
        }

  @type output :: %__MODULE__.Output{
          input: String.t(),
          country_code: integer(),
          default_country: String.t(),
          international_formatted: String.t(),
          national: integer(),
          national_formatted: String.t(),
          valid: boolean()
        }

  defmodule Input do
    @moduledoc "Phone number input for Weaviate"
    defstruct [:number, :default_country]

    @doc "Create a new phone number input"
    def new(number, opts \\ []) when is_binary(number) do
      %__MODULE__{
        number: number,
        default_country: Keyword.get(opts, :default_country)
      }
    end

    @doc "Convert to map for Weaviate API"
    def to_map(%__MODULE__{number: num, default_country: nil}) do
      %{"input" => num}
    end

    def to_map(%__MODULE__{number: num, default_country: country}) do
      %{"input" => num, "defaultCountry" => country}
    end
  end

  defmodule Output do
    @moduledoc "Parsed phone number from Weaviate"
    defstruct [
      :input,
      :country_code,
      :default_country,
      :international_formatted,
      :national,
      :national_formatted,
      :valid
    ]

    @doc "Parse from Weaviate API response"
    def from_map(map) when is_map(map) do
      %__MODULE__{
        input: map["input"],
        country_code: map["countryCode"],
        default_country: map["defaultCountry"],
        international_formatted: map["internationalFormatted"],
        national: map["national"],
        national_formatted: map["nationalFormatted"],
        valid: map["valid"]
      }
    end
  end

  # Convenience functions
  def new(number, opts \\ []), do: Input.new(number, opts)
  def to_map(input), do: Input.to_map(input)
  def from_map(map), do: Output.from_map(map)
end
```

#### 2.4 Blob Handling

**Python Usage:**
```python
import base64

# Store blob
with open("image.jpg", "rb") as f:
    image_data = base64.b64encode(f.read()).decode('utf-8')

client.collections.get("Article").data.insert({
    "image": image_data  # base64 encoded string
})
```

**Proposed Elixir:**
```elixir
defmodule WeaviateEx.Types.Blob do
  @moduledoc """
  Binary/Blob data handling for Weaviate.

  Weaviate stores blobs as base64-encoded strings.

  ## Example

      # Encode file
      {:ok, encoded} = Blob.encode_file("/path/to/image.jpg")

      # Encode binary
      encoded = Blob.encode(<<binary_data>>)

      # Decode
      {:ok, binary} = Blob.decode(encoded)
  """

  @doc "Encode binary data to base64 string for Weaviate"
  @spec encode(binary()) :: String.t()
  def encode(data) when is_binary(data) do
    Base.encode64(data)
  end

  @doc "Encode file contents to base64 string"
  @spec encode_file(Path.t()) :: {:ok, String.t()} | {:error, term()}
  def encode_file(path) do
    case File.read(path) do
      {:ok, data} -> {:ok, encode(data)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Encode file contents, raising on error"
  @spec encode_file!(Path.t()) :: String.t()
  def encode_file!(path) do
    path
    |> File.read!()
    |> encode()
  end

  @doc "Decode base64 string to binary"
  @spec decode(String.t()) :: {:ok, binary()} | {:error, term()}
  def decode(encoded) when is_binary(encoded) do
    Base.decode64(encoded)
  end

  @doc "Decode base64 string, raising on error"
  @spec decode!(String.t()) :: binary()
  def decode!(encoded) when is_binary(encoded) do
    Base.decode64!(encoded)
  end

  @doc "Write decoded blob to file"
  @spec decode_to_file(String.t(), Path.t()) :: :ok | {:error, term()}
  def decode_to_file(encoded, path) do
    case decode(encoded) do
      {:ok, data} -> File.write(path, data)
      {:error, reason} -> {:error, reason}
    end
  end
end
```

#### 2.5 UUID Generation

**Python:**
```python
import uuid

# Weaviate accepts UUID strings or uuid.UUID objects
client.collections.get("Article").data.insert(
    properties={"title": "Hello"},
    uuid=uuid.uuid4()  # or uuid string
)
```

**Proposed Elixir:**
```elixir
defmodule WeaviateEx.Types.UUID do
  @moduledoc """
  UUID utilities for Weaviate objects.

  ## Example

      # Generate new UUID
      uuid = UUID.generate()

      # Validate UUID
      {:ok, uuid} = UUID.validate("550e8400-e29b-41d4-a716-446655440000")

      # Generate deterministic UUID from string
      uuid = UUID.from_string("Article", "my-unique-id")
  """

  @uuid_regex ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

  @doc "Generate a new random UUID v4"
  @spec generate() :: String.t()
  def generate do
    :crypto.strong_rand_bytes(16)
    |> format_uuid()
  end

  @doc "Validate a UUID string"
  @spec validate(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def validate(uuid) when is_binary(uuid) do
    if Regex.match?(@uuid_regex, uuid) do
      {:ok, String.downcase(uuid)}
    else
      {:error, "Invalid UUID format: #{uuid}"}
    end
  end

  @doc "Check if string is valid UUID"
  @spec valid?(String.t()) :: boolean()
  def valid?(uuid) when is_binary(uuid) do
    Regex.match?(@uuid_regex, uuid)
  end

  @doc """
  Generate a deterministic UUID v5 from namespace and name.
  Useful for creating reproducible UUIDs.
  """
  @spec from_string(String.t(), String.t()) :: String.t()
  def from_string(namespace, name) when is_binary(namespace) and is_binary(name) do
    # UUID v5 (SHA-1 based)
    namespace_uuid =
      :crypto.hash(:sha, namespace)
      |> binary_part(0, 16)

    :crypto.hash(:sha, namespace_uuid <> name)
    |> binary_part(0, 16)
    |> format_uuid()
  end

  defp format_uuid(<<a::32, b::16, c::16, d::16, e::48>>) do
    [a, b, c, d, e]
    |> Enum.map(&Integer.to_string(&1, 16))
    |> Enum.map(&String.pad_leading(&1, 8, "0"))
    |> Enum.join("-")
    |> String.downcase()
  end

  defp format_uuid(<<bytes::binary-size(16)>>) do
    <<a::32, b::16, c::16, d::16, e::48>> = bytes
    format_uuid(<<a::32, b::16, c::16, d::16, e::48>>)
  end
end
```

#### 2.6 Nested Objects

**Python:**
```python
# Define nested object property
client.collections.create(
    "Article",
    properties=[
        wvc.config.Property(
            name="author",
            data_type=wvc.config.DataType.OBJECT,
            nested_properties=[
                wvc.config.Property(name="name", data_type=wvc.config.DataType.TEXT),
                wvc.config.Property(name="email", data_type=wvc.config.DataType.TEXT),
                wvc.config.Property(
                    name="address",
                    data_type=wvc.config.DataType.OBJECT,
                    nested_properties=[
                        wvc.config.Property(name="city", data_type=wvc.config.DataType.TEXT),
                        wvc.config.Property(name="country", data_type=wvc.config.DataType.TEXT),
                    ]
                )
            ]
        )
    ]
)
```

**Proposed Elixir:**
```elixir
defmodule WeaviateEx.Property do
  @moduledoc """
  Property builder for collection schemas.
  """

  @type t :: %{
          name: String.t(),
          dataType: [String.t()],
          description: String.t() | nil,
          nestedProperties: [t()] | nil,
          indexFilterable: boolean() | nil,
          indexSearchable: boolean() | nil,
          indexInverted: boolean() | nil,
          tokenization: String.t() | nil,
          moduleConfig: map() | nil
        }

  @doc """
  Create a new property definition.

  ## Options
    - `:description` - Property description
    - `:index_filterable` - Enable filtering on this property
    - `:index_searchable` - Enable full-text search
    - `:index_inverted` - Include in inverted index
    - `:tokenization` - Tokenization strategy (word, whitespace, field, etc.)
    - `:skip_vectorization` - Don't include in vectorization
    - `:vectorize_property_name` - Include property name in vector
    - `:nested_properties` - For object/object[] types
  """
  @spec new(String.t(), atom() | String.t(), keyword()) :: t()
  def new(name, data_type, opts \\ []) do
    %{
      "name" => name,
      "dataType" => [normalize_data_type(data_type)]
    }
    |> maybe_put("description", Keyword.get(opts, :description))
    |> maybe_put("indexFilterable", Keyword.get(opts, :index_filterable))
    |> maybe_put("indexSearchable", Keyword.get(opts, :index_searchable))
    |> maybe_put("indexInverted", Keyword.get(opts, :index_inverted))
    |> maybe_put("tokenization", normalize_tokenization(Keyword.get(opts, :tokenization)))
    |> maybe_add_nested_properties(Keyword.get(opts, :nested_properties))
    |> maybe_add_module_config(opts)
  end

  @doc """
  Create a text property.
  """
  def text(name, opts \\ []) do
    new(name, :text, opts)
  end

  @doc """
  Create an integer property.
  """
  def int(name, opts \\ []) do
    new(name, :int, opts)
  end

  @doc """
  Create a number (float) property.
  """
  def number(name, opts \\ []) do
    new(name, :number, opts)
  end

  @doc """
  Create a boolean property.
  """
  def boolean(name, opts \\ []) do
    new(name, :boolean, opts)
  end

  @doc """
  Create a date property.
  """
  def date(name, opts \\ []) do
    new(name, :date, opts)
  end

  @doc """
  Create a UUID property.
  """
  def uuid(name, opts \\ []) do
    new(name, :uuid, opts)
  end

  @doc """
  Create a blob property.
  """
  def blob(name, opts \\ []) do
    new(name, :blob, Keyword.put(opts, :index_filterable, false))
  end

  @doc """
  Create a geo coordinates property.
  """
  def geo_coordinates(name, opts \\ []) do
    new(name, :geo_coordinates, opts)
  end

  @doc """
  Create a phone number property.
  """
  def phone_number(name, opts \\ []) do
    new(name, :phone_number, opts)
  end

  @doc """
  Create a nested object property.

  ## Example

      Property.object("author", [
        Property.text("name"),
        Property.text("email"),
        Property.object("address", [
          Property.text("city"),
          Property.text("country")
        ])
      ])
  """
  def object(name, nested_properties, opts \\ []) do
    new(name, :object, Keyword.put(opts, :nested_properties, nested_properties))
  end

  @doc """
  Create a nested object array property.
  """
  def object_array(name, nested_properties, opts \\ []) do
    new(name, :object_array, Keyword.put(opts, :nested_properties, nested_properties))
  end

  @doc """
  Create a cross-reference property.
  """
  def reference(name, target_collection, opts \\ []) do
    %{
      "name" => name,
      "dataType" => [target_collection]
    }
    |> maybe_put("description", Keyword.get(opts, :description))
  end

  # Private helpers
  defp normalize_data_type(type) when is_atom(type) do
    WeaviateEx.DataType.to_string(type)
  end

  defp normalize_data_type(type) when is_binary(type), do: type

  defp normalize_tokenization(nil), do: nil
  defp normalize_tokenization(:word), do: "word"
  defp normalize_tokenization(:whitespace), do: "whitespace"
  defp normalize_tokenization(:lowercase), do: "lowercase"
  defp normalize_tokenization(:field), do: "field"
  defp normalize_tokenization(:gse), do: "gse"
  defp normalize_tokenization(:trigram), do: "trigram"
  defp normalize_tokenization(:kagome_ja), do: "kagome_ja"
  defp normalize_tokenization(:kagome_kr), do: "kagome_kr"
  defp normalize_tokenization(t) when is_binary(t), do: t

  defp maybe_add_nested_properties(prop, nil), do: prop

  defp maybe_add_nested_properties(prop, nested) when is_list(nested) do
    Map.put(prop, "nestedProperties", nested)
  end

  defp maybe_add_module_config(prop, opts) do
    skip_vectorization = Keyword.get(opts, :skip_vectorization)
    vectorize_property_name = Keyword.get(opts, :vectorize_property_name)

    case {skip_vectorization, vectorize_property_name} do
      {nil, nil} ->
        prop

      _ ->
        module_config = %{}
        |> maybe_put("skip", skip_vectorization)
        |> maybe_put("vectorizePropertyName", vectorize_property_name)

        Map.put(prop, "moduleConfig", module_config)
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
```

---

### 3. Missing Vectorizers (High Priority)

#### Comparison Table

| Vectorizer | Python | Elixir | Priority |
|------------|--------|--------|----------|
| text2vec-openai | Yes | Yes | - |
| text2vec-cohere | Yes | Yes | - |
| text2vec-huggingface | Yes | Yes | - |
| text2vec-transformers | Yes | Yes | - |
| text2vec-aws | Yes | Yes | - |
| text2vec-aws-bedrock | Yes | Yes | - |
| text2vec-aws-sagemaker | Yes | Yes | - |
| text2vec-google-vertex | Yes | Yes | - |
| text2vec-google-gemini | Yes | Yes | - |
| text2vec-ollama | Yes | **Missing** | High |
| text2vec-mistral | Yes | **Missing** | High |
| text2vec-nvidia | Yes | **Missing** | High |
| text2vec-weaviate | Yes | **Missing** | High |
| text2vec-voyageai | Yes | Yes | - |
| text2vec-jinaai | Yes | **Missing** | High |
| text2vec-databricks | Yes | **Missing** | High |
| text2vec-model2vec | Yes | Yes | - |
| text2vec-morph | Yes | Yes | - |
| text2vec-azure-openai | Yes | **Missing** | High |
| multi2vec-clip | Yes | Yes | - |
| multi2vec-bind | Yes | Yes | - |
| multi2vec-google | Yes | **Missing** | High |
| multi2vec-cohere | Yes | **Missing** | High |
| multi2vec-jinaai | Yes | **Missing** | High |
| multi2vec-voyageai | Yes | **Missing** | High |
| multi2vec-nvidia | Yes | **Missing** | High |
| multi2vec-aws | Yes | **Missing** | High |
| img2vec-neural | Yes | **Missing** | Medium |
| ref2vec-centroid | Yes | **Missing** | Medium |
| text2colbert-jinaai | Yes | **Missing** | High |
| multi2multivec-jinaai | Yes | Yes | - |

#### Missing Vectorizer Implementations

**text2vec-ollama:**
```elixir
@doc """
Configure text2vec-ollama vectorizer.

## Options
  - `:model` - Ollama model name
  - `:api_endpoint` - Ollama API endpoint (default: http://localhost:11434)
  - `:vectorize_collection_name` - Whether to vectorize collection name
"""
def text2vec_ollama(opts \\ []) do
  config =
    %{
      "vectorizeClassName" => Keyword.get(opts, :vectorize_collection_name, true)
    }
    |> maybe_put("model", Keyword.get(opts, :model))
    |> maybe_put("apiEndpoint", Keyword.get(opts, :api_endpoint))

  %{
    "vectorizer" => "text2vec-ollama",
    "moduleConfig" => %{
      "text2vec-ollama" => config
    }
  }
end
```

**text2vec-jinaai:**
```elixir
@doc """
Configure text2vec-jinaai vectorizer.

## Options
  - `:model` - Jina model (e.g., "jina-embeddings-v3", "jina-embeddings-v4")
  - `:base_url` - API base URL
  - `:dimensions` - Output dimensions
  - `:vectorize_collection_name` - Whether to vectorize collection name
"""
def text2vec_jinaai(opts \\ []) do
  config =
    %{
      "vectorizeClassName" => Keyword.get(opts, :vectorize_collection_name, true)
    }
    |> maybe_put("model", Keyword.get(opts, :model))
    |> maybe_put("baseURL", Keyword.get(opts, :base_url))
    |> maybe_put("dimensions", Keyword.get(opts, :dimensions))

  %{
    "vectorizer" => "text2vec-jinaai",
    "moduleConfig" => %{
      "text2vec-jinaai" => config
    }
  }
end
```

**multi2vec-google:**
```elixir
@doc """
Configure multi2vec-google (Palm) for multimodal embeddings.

## Options
  - `:project_id` - Google Cloud project ID (required)
  - `:location` - Model location (required)
  - `:model` - Model ID
  - `:dimensions` - Output dimensions
  - `:image_fields` - Image property fields
  - `:text_fields` - Text property fields
  - `:video_fields` - Video property fields
  - `:video_interval_seconds` - Video sampling interval
"""
def multi2vec_google(opts) do
  config =
    %{
      "projectId" => Keyword.fetch!(opts, :project_id),
      "location" => Keyword.fetch!(opts, :location)
    }
    |> maybe_put("modelId", Keyword.get(opts, :model))
    |> maybe_put("dimensions", Keyword.get(opts, :dimensions))
    |> maybe_put("imageFields", format_multi2vec_fields(Keyword.get(opts, :image_fields)))
    |> maybe_put("textFields", format_multi2vec_fields(Keyword.get(opts, :text_fields)))
    |> maybe_put("videoFields", format_multi2vec_fields(Keyword.get(opts, :video_fields)))
    |> maybe_put("videoIntervalSeconds", Keyword.get(opts, :video_interval_seconds))

  %{
    "vectorizer" => "multi2vec-palm",
    "moduleConfig" => %{
      "multi2vec-palm" => config
    }
  }
end

defp format_multi2vec_fields(nil), do: nil
defp format_multi2vec_fields(fields) when is_list(fields) do
  Enum.map(fields, fn
    field when is_binary(field) -> %{"name" => field}
    %{name: name} = field -> %{"name" => name} |> maybe_put("weight", field[:weight])
    field when is_map(field) -> field
  end)
end
```

---

### 4. Quantization - Missing RQ (High Priority)

#### Python RQ Support

```python
# Rotational Quantization (RQ)
client.collections.create(
    "Article",
    vector_index_config=wvc.config.Configure.VectorIndex.hnsw(
        quantizer=wvc.config.Configure.VectorIndex.Quantizer.rq(
            cache=True,
            bits=8,
            rescore_limit=200
        )
    )
)
```

#### Proposed Elixir Implementation

```elixir
@doc """
Configure Rotational Quantization (RQ).

RQ is an advanced quantization method that uses rotational transformations.

## Options
  - `:enabled` - Enable RQ (default: true)
  - `:cache` - Enable cache
  - `:bits` - Number of bits for quantization (default: 8)
  - `:rescore_limit` - Number of candidates to rescore

## Example

    VectorConfig.hnsw_index(
      quantizer: VectorConfig.rotational_quantization(bits: 8, cache: true)
    )
"""
def rotational_quantization(opts \\ []) do
  rq_config =
    %{
      "enabled" => Keyword.get(opts, :enabled, true)
    }
    |> maybe_put("cache", Keyword.get(opts, :cache))
    |> maybe_put("bits", Keyword.get(opts, :bits))
    |> maybe_put("rescoreLimit", Keyword.get(opts, :rescore_limit))

  %{"rq" => rq_config}
end

# Also add to hnsw_index:
defp maybe_add_quantization(config, opts) do
  config
  |> maybe_add_pq(opts)
  |> maybe_add_bq(opts)
  |> maybe_add_sq(opts)
  |> maybe_add_rq(opts)  # Add RQ support
end

defp maybe_add_rq(config, opts) do
  case Keyword.get(opts, :rq) do
    nil ->
      if Keyword.get(opts, :rq_enabled) do
        Map.merge(config, rotational_quantization(enabled: true))
      else
        config
      end
    rq_opts when is_list(rq_opts) ->
      Map.merge(config, rotational_quantization(rq_opts))
    rq_config when is_map(rq_config) ->
      Map.merge(config, %{"rq" => rq_config})
  end
end
```

---

### 5. Multi-Vector Support (High Priority)

Multi-vector support enables ColBERT-style embeddings where each document produces multiple vectors.

#### Python Multi-Vector

```python
# Multi-vector with text2colbert-jinaai
client.collections.create(
    "Article",
    vectorizer_config=[
        wvc.config.Configure.MultiVectors.text2vec_jinaai(
            name="colbert_vector",
            model="jina-colbert-v2",
            encoding=wvc.config.Configure.VectorIndex.MultiVector.Encoding.muvera(
                ksim=64,
                dprojections=128
            ),
            multi_vector_config=wvc.config.Configure.VectorIndex.MultiVector.multi_vector(
                aggregation=wvc.config.MultiVectorAggregation.MAX_SIM
            )
        )
    ]
)

# Self-provided multi-vectors
wvc.config.Configure.MultiVectors.self_provided(
    name="custom_multivec",
    encoding=wvc.config.Configure.VectorIndex.MultiVector.Encoding.muvera()
)
```

#### Proposed Elixir Implementation

```elixir
defmodule WeaviateEx.API.MultiVector do
  @moduledoc """
  Multi-vector configuration for ColBERT-style embeddings.

  Multi-vectors allow storing multiple vectors per document,
  enabling late interaction retrieval methods.
  """

  @type aggregation :: :max_sim

  @doc """
  Configure Muvera encoding for multi-vectors.

  ## Options
    - `:ksim` - Number of similar vectors to consider
    - `:dprojections` - Dimension of projections
    - `:repetitions` - Number of repetitions
  """
  def muvera_encoding(opts \\ []) do
    config =
      %{"enabled" => true}
      |> maybe_put("ksim", Keyword.get(opts, :ksim))
      |> maybe_put("dprojections", Keyword.get(opts, :dprojections))
      |> maybe_put("repetitions", Keyword.get(opts, :repetitions))

    %{"muvera" => config}
  end

  @doc """
  Configure multi-vector aggregation.

  ## Options
    - `:aggregation` - Aggregation method (:max_sim)
  """
  def multi_vector_config(opts \\ []) do
    aggregation =
      case Keyword.get(opts, :aggregation) do
        :max_sim -> "maxSim"
        nil -> nil
        agg when is_binary(agg) -> agg
      end

    %{}
    |> maybe_put("aggregation", aggregation)
  end

  @doc """
  Create a self-provided multi-vector configuration.
  """
  def self_provided(opts) do
    %{
      "name" => Keyword.fetch!(opts, :name),
      "vectorizer" => %{"none" => %{}},
      "vectorIndexType" => "hnsw",
      "vectorIndexConfig" => build_multi_vector_index_config(opts)
    }
  end

  @doc """
  Create a text2colbert-jinaai multi-vector configuration.
  """
  def text2colbert_jinaai(opts) do
    vectorizer_config =
      %{
        "vectorizeClassName" => Keyword.get(opts, :vectorize_collection_name, true)
      }
      |> maybe_put("model", Keyword.get(opts, :model))
      |> maybe_put("dimensions", Keyword.get(opts, :dimensions))

    %{
      "name" => Keyword.fetch!(opts, :name),
      "vectorizer" => %{"text2colbert-jinaai" => vectorizer_config},
      "vectorIndexType" => "hnsw",
      "vectorIndexConfig" => build_multi_vector_index_config(opts)
    }
    |> maybe_add_source_properties(opts)
  end

  defp build_multi_vector_index_config(opts) do
    base_config = VectorConfig.hnsw_index(Keyword.get(opts, :hnsw_opts, []))
    |> Map.get("vectorIndexConfig", %{})

    multivector_config = build_multivector_section(opts)

    Map.put(base_config, "multivector", multivector_config)
  end

  defp build_multivector_section(opts) do
    mv_config = Keyword.get(opts, :multi_vector_config, %{})
    encoding = Keyword.get(opts, :encoding)

    config =
      %{"enabled" => true}
      |> Map.merge(mv_config)

    case encoding do
      nil -> config
      enc when is_map(enc) -> Map.merge(config, enc)
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_add_source_properties(config, opts) do
    case Keyword.get(opts, :source_properties) do
      nil -> config
      props ->
        vectorizer_key = config["vectorizer"] |> Map.keys() |> List.first()
        put_in(config, ["vectorizer", vectorizer_key, "properties"], props)
    end
  end
end
```

---

### 6. Vector Index Updates (Medium Priority)

#### Python Update Support

```python
# Update HNSW configuration
client.collections.update(
    "Article",
    vector_index_config=wvc.config.Reconfigure.VectorIndex.hnsw(
        ef=300,
        dynamic_ef_factor=10,
        filter_strategy=wvc.config.VectorFilterStrategy.ACORN
    )
)

# Update named vector configuration
client.collections.update(
    "Article",
    vector_config=[
        wvc.config.Reconfigure.Vectors.update(
            name="title_vector",
            vector_index_config=wvc.config.Reconfigure.VectorIndex.hnsw(ef=200)
        )
    ]
)
```

#### Proposed Elixir Implementation

```elixir
defmodule WeaviateEx.API.VectorConfig.Reconfigure do
  @moduledoc """
  Vector index reconfiguration for existing collections.
  """

  @doc """
  Create HNSW update configuration.

  ## Updatable Options
    - `:ef` - Query time ef parameter
    - `:dynamic_ef_min` - Minimum dynamic ef
    - `:dynamic_ef_max` - Maximum dynamic ef
    - `:dynamic_ef_factor` - Dynamic ef factor
    - `:filter_strategy` - Filter strategy (:sweeping or :acorn)
    - `:flat_search_cutoff` - Flat search cutoff
    - `:vector_cache_max_objects` - Vector cache size
  """
  def hnsw(opts \\ []) do
    %{
      "vectorIndexType" => "hnsw",
      "vectorIndexConfig" =>
        %{}
        |> maybe_put("ef", Keyword.get(opts, :ef))
        |> maybe_put("dynamicEfMin", Keyword.get(opts, :dynamic_ef_min))
        |> maybe_put("dynamicEfMax", Keyword.get(opts, :dynamic_ef_max))
        |> maybe_put("dynamicEfFactor", Keyword.get(opts, :dynamic_ef_factor))
        |> maybe_put("filterStrategy", format_filter_strategy(Keyword.get(opts, :filter_strategy)))
        |> maybe_put("flatSearchCutoff", Keyword.get(opts, :flat_search_cutoff))
        |> maybe_put("vectorCacheMaxObjects", Keyword.get(opts, :vector_cache_max_objects))
        |> maybe_add_quantizer_update(opts)
    }
  end

  @doc """
  Create Flat index update configuration.
  """
  def flat(opts \\ []) do
    %{
      "vectorIndexType" => "flat",
      "vectorIndexConfig" =>
        %{}
        |> maybe_put("vectorCacheMaxObjects", Keyword.get(opts, :vector_cache_max_objects))
        |> maybe_add_quantizer_update(opts)
    }
  end

  @doc """
  Create named vector update configuration.
  """
  def update_vector(opts) do
    %{
      "name" => Keyword.fetch!(opts, :name),
      "vectorIndexConfig" => Keyword.fetch!(opts, :vector_index_config)
    }
  end

  defp format_filter_strategy(nil), do: nil
  defp format_filter_strategy(:sweeping), do: "sweeping"
  defp format_filter_strategy(:acorn), do: "acorn"
  defp format_filter_strategy(s) when is_binary(s), do: s

  defp maybe_add_quantizer_update(config, opts) do
    case Keyword.get(opts, :quantizer) do
      nil -> config
      %{"pq" => pq} -> Map.put(config, "pq", pq)
      %{"bq" => bq} -> Map.put(config, "bq", bq)
      %{"sq" => sq} -> Map.put(config, "sq", sq)
      %{"rq" => rq} -> Map.put(config, "rq", rq)
      q -> Map.merge(config, q)
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
```

---

### 7. Model Type Enums (Low Priority)

The Python client provides strict type checking through Literal types and enums.

#### Python Model Types

```python
CohereModel: TypeAlias = Literal[
    "embed-v4.0", "embed-multilingual-v2.0", "embed-multilingual-v3.0", ...
]
OpenAIModel: TypeAlias = Literal[
    "text-embedding-3-small", "text-embedding-3-large", "text-embedding-ada-002"
]
JinaModel: TypeAlias = Literal[
    "jina-embeddings-v2-base-en", "jina-embeddings-v3", "jina-embeddings-v4"
]
VoyageModel: TypeAlias = Literal["voyage-3.5", "voyage-3-large", ...]
```

#### Proposed Elixir Implementation

```elixir
defmodule WeaviateEx.Models do
  @moduledoc """
  Known model identifiers for various vectorizer providers.
  These are provided for convenience but strings are also accepted.
  """

  defmodule OpenAI do
    @models [
      :text_embedding_3_small,
      :text_embedding_3_large,
      :text_embedding_ada_002
    ]

    @model_strings %{
      text_embedding_3_small: "text-embedding-3-small",
      text_embedding_3_large: "text-embedding-3-large",
      text_embedding_ada_002: "text-embedding-ada-002"
    }

    def all, do: @models
    def to_string(model), do: Map.get(@model_strings, model, Atom.to_string(model))
  end

  defmodule Cohere do
    @models [
      :embed_v4_0,
      :embed_multilingual_v3_0,
      :embed_english_v3_0,
      :embed_english_light_v3_0
    ]

    @model_strings %{
      embed_v4_0: "embed-v4.0",
      embed_multilingual_v3_0: "embed-multilingual-v3.0",
      embed_english_v3_0: "embed-english-v3.0",
      embed_english_light_v3_0: "embed-english-light-v3.0"
    }

    def all, do: @models
    def to_string(model), do: Map.get(@model_strings, model, Atom.to_string(model))
  end

  defmodule Jina do
    @models [
      :jina_embeddings_v2_base_en,
      :jina_embeddings_v3,
      :jina_embeddings_v4,
      :jina_clip_v1,
      :jina_clip_v2
    ]

    @model_strings %{
      jina_embeddings_v2_base_en: "jina-embeddings-v2-base-en",
      jina_embeddings_v3: "jina-embeddings-v3",
      jina_embeddings_v4: "jina-embeddings-v4",
      jina_clip_v1: "jina-clip-v1",
      jina_clip_v2: "jina-clip-v2"
    }

    def all, do: @models
    def to_string(model), do: Map.get(@model_strings, model, Atom.to_string(model))
  end

  defmodule Voyage do
    @models [
      :voyage_3_5,
      :voyage_3_5_lite,
      :voyage_3_large,
      :voyage_3,
      :voyage_code_2
    ]

    @model_strings %{
      voyage_3_5: "voyage-3.5",
      voyage_3_5_lite: "voyage-3.5-lite",
      voyage_3_large: "voyage-3-large",
      voyage_3: "voyage-3",
      voyage_code_2: "voyage-code-2"
    }

    def all, do: @models
    def to_string(model), do: Map.get(@model_strings, model, Atom.to_string(model))
  end
end
```

---

## Implementation Roadmap

### Phase 1: Critical Gaps (Week 1)
1. **Data Types Module** (2 days)
   - DataType enum
   - GeoCoordinate type
   - PhoneNumber type
   - Blob utilities
   - UUID utilities

2. **Named Vectors Builder** (3 days)
   - NamedVectors module
   - All vectorizer functions with name parameter
   - Source properties support
   - Integration with collection builder

### Phase 2: High Priority (Week 2)
1. **Missing Vectorizers** (3 days)
   - text2vec-ollama
   - text2vec-jinaai
   - text2vec-nvidia
   - text2vec-azure-openai
   - multi2vec-google
   - multi2vec-cohere
   - multi2vec-jinaai
   - All remaining multi2vec variants

2. **Multi-Vector Support** (2 days)
   - MultiVector module
   - Muvera encoding
   - text2colbert-jinaai
   - Self-provided multi-vectors

3. **RQ Quantization** (0.5 days)
   - Add rotational_quantization function
   - Update hnsw_index to support RQ

### Phase 3: Medium Priority (Week 3)
1. **Property Builder** (1 day)
   - Property module with all data types
   - Nested object support
   - Module config for vectorization options

2. **Vector Index Updates** (1 day)
   - Reconfigure module
   - HNSW update config
   - Flat update config
   - Named vector updates

### Phase 4: Low Priority (Week 4)
1. **Model Type Enums** (1 day)
   - OpenAI models
   - Cohere models
   - Jina models
   - Voyage models

2. **Testing & Documentation** (2 days)
   - Unit tests for all new modules
   - Integration tests
   - Documentation updates

---

## File Locations

| Component | Python Location | Proposed Elixir Location |
|-----------|-----------------|--------------------------|
| Named Vectors | `config_named_vectors.py` | `lib/weaviate_ex/api/named_vectors.ex` |
| Vector Config | `config_vectors.py` | `lib/weaviate_ex/api/vector_config.ex` (existing) |
| Data Types | `types.py` | `lib/weaviate_ex/types/` directory |
| Quantizers | `config_vector_index.py` | `lib/weaviate_ex/api/vector_config.ex` (existing) |
| Multi-Vector | `config_vector_index.py` | `lib/weaviate_ex/api/multi_vector.ex` |
| Property | `config.py` | `lib/weaviate_ex/property.ex` |
| Models | `config_vectorizers.py` | `lib/weaviate_ex/models.ex` |

---

## Summary

The Elixir WeaviateEx client has a solid foundation but requires significant additions to achieve feature parity with the Python client for vector configuration and data types. The most critical gaps are:

1. **Named Vectors with proper builder pattern** - Essential for modern Weaviate usage
2. **Data Type system** - GeoCoordinates, PhoneNumber, Blob, nested objects
3. **Missing vectorizers** - 15+ vectorizers not yet implemented
4. **Multi-vector support** - ColBERT embeddings completely missing
5. **RQ Quantization** - Newest quantization method not implemented

Following the proposed implementation roadmap would bring the Elixir client to near-parity with Python for these features in approximately 3-4 weeks of development effort.
