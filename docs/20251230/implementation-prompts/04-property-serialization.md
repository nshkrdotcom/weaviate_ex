# Prompt - Property Value Serialization

## Objective

Implement comprehensive property value serialization to ensure data integrity when sending complex Elixir types (DateTime, GeoCoordinate, PhoneNumber, nested objects) to Weaviate.

## Priority

P0 - Critical (Data integrity)

## Required Reading (Docs)

- `docs/20251229/deep-gap-analysis/09-data-types-objects.md`
- `README.md` (data types section)
- `CHANGELOG.md`

## Required Reading (Source/Tests)

- `lib/weaviate_ex/objects/payload.ex` - Current payload handling
- `lib/weaviate_ex/types/geo_coordinate.ex` - GeoCoordinate type
- `lib/weaviate_ex/types/phone_number.ex` - PhoneNumber type
- `lib/weaviate_ex/types/data_type.ex` - Data type definitions
- `lib/weaviate_ex/types/blob.ex` - Blob handling
- `lib/weaviate_ex/property.ex` - Property definitions
- `test/weaviate_ex/types/*` - Type tests
- `test/weaviate_ex/objects_test.exs`

## Required Reading (Python Reference)

- `../weaviate-python-client/weaviate/collections/classes/data.py` - Data serialization
- `../weaviate-python-client/weaviate/collections/classes/types.py` - Type definitions

## Context

### Current State
- Basic types (string, int, float, boolean) work correctly
- Complex types may not serialize correctly for Weaviate
- DateTime should be ISO8601 string
- GeoCoordinate should be `{latitude: float, longitude: float}`
- PhoneNumber should include country code
- Nested objects need recursive serialization

### Gap
Python automatically serializes:
```python
# DateTime -> ISO8601 string
datetime.datetime(2024, 1, 1) -> "2024-01-01T00:00:00Z"

# GeoCoordinate -> dict
GeoCoordinate(lat=1.0, lon=2.0) -> {"latitude": 1.0, "longitude": 2.0}

# PhoneNumber -> string with country
PhoneNumber(number="555-1234", country="US") -> "+1 555-1234"
```

## Implementation Instructions (TDD Required)

### Step 1: Create Serialization Protocol

Create `lib/weaviate_ex/types/serializable.ex`:

```elixir
defprotocol WeaviateEx.Types.Serializable do
  @moduledoc """
  Protocol for serializing Elixir types to Weaviate-compatible values.
  """

  @doc """
  Serializes a value to a Weaviate-compatible format.
  """
  @spec serialize(t()) :: any()
  def serialize(value)
end

# Implement for built-in types
defimpl WeaviateEx.Types.Serializable, for: DateTime do
  def serialize(dt), do: DateTime.to_iso8601(dt)
end

defimpl WeaviateEx.Types.Serializable, for: NaiveDateTime do
  def serialize(dt), do: NaiveDateTime.to_iso8601(dt) <> "Z"
end

defimpl WeaviateEx.Types.Serializable, for: Date do
  def serialize(d), do: Date.to_iso8601(d) <> "T00:00:00Z"
end

defimpl WeaviateEx.Types.Serializable, for: Any do
  def serialize(value), do: value
end
```

### Step 2: Implement for Custom Types

Update `lib/weaviate_ex/types/geo_coordinate.ex`:

```elixir
defimpl WeaviateEx.Types.Serializable, for: WeaviateEx.Types.GeoCoordinate do
  def serialize(%{latitude: lat, longitude: lon}) do
    %{"latitude" => lat, "longitude" => lon}
  end
end
```

Update `lib/weaviate_ex/types/phone_number.ex`:

```elixir
defimpl WeaviateEx.Types.Serializable, for: WeaviateEx.Types.PhoneNumber do
  def serialize(%{number: number, default_country: country}) do
    # Format with country code if available
    %{
      "input" => number,
      "defaultCountry" => country
    }
  end
end
```

Update `lib/weaviate_ex/types/blob.ex`:

```elixir
defimpl WeaviateEx.Types.Serializable, for: WeaviateEx.Types.Blob do
  def serialize(%{data: data}) when is_binary(data) do
    Base.encode64(data)
  end
end
```

### Step 3: Update Payload Module

Update `lib/weaviate_ex/objects/payload.ex`:

```elixir
defmodule WeaviateEx.Objects.Payload do
  alias WeaviateEx.Types.Serializable

  @doc """
  Serializes object properties for Weaviate API.
  """
  @spec serialize_properties(map()) :: map()
  def serialize_properties(properties) when is_map(properties) do
    properties
    |> Enum.map(fn {key, value} -> {to_string(key), serialize_value(value)} end)
    |> Map.new()
  end

  defp serialize_value(value) when is_list(value) do
    Enum.map(value, &serialize_value/1)
  end

  defp serialize_value(value) when is_map(value) and not is_struct(value) do
    serialize_properties(value)
  end

  defp serialize_value(%{__struct__: _} = struct) do
    Serializable.serialize(struct)
  end

  defp serialize_value(value), do: value
end
```

### Step 4: Add Deserialization

Create `lib/weaviate_ex/types/deserializable.ex`:

```elixir
defmodule WeaviateEx.Types.Deserialize do
  @moduledoc """
  Deserializes Weaviate response values to Elixir types.
  """

  alias WeaviateEx.Types.{GeoCoordinate, PhoneNumber}

  @spec deserialize(any(), atom() | nil) :: any()
  def deserialize(value, type \\ nil)

  def deserialize(%{"latitude" => lat, "longitude" => lon}, :geo_coordinate) do
    %GeoCoordinate{latitude: lat, longitude: lon}
  end

  def deserialize(value, :date) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _} -> dt
      _ -> value
    end
  end

  def deserialize(value, _), do: value
end
```

### Step 5: Wire into Objects Module

Update `lib/weaviate_ex/objects.ex` to use serialization:

```elixir
def create(client, collection, object) do
  serialized = %{object | properties: Payload.serialize_properties(object.properties)}
  # ... rest of create logic
end
```

## Tests to Write

### Serialization Tests (`test/weaviate_ex/types/serializable_test.exs`)

```elixir
describe "DateTime serialization" do
  test "serializes DateTime to ISO8601"
  test "serializes NaiveDateTime with Z suffix"
  test "serializes Date as midnight UTC"
end

describe "GeoCoordinate serialization" do
  test "serializes to latitude/longitude map"
  test "preserves float precision"
end

describe "PhoneNumber serialization" do
  test "serializes with input and defaultCountry"
  test "handles nil country code"
end

describe "Blob serialization" do
  test "base64 encodes binary data"
  test "handles empty binary"
end

describe "nested object serialization" do
  test "recursively serializes nested maps"
  test "serializes arrays of complex types"
  test "handles deeply nested structures"
end
```

### Deserialization Tests (`test/weaviate_ex/types/deserialize_test.exs`)

```elixir
describe "DateTime deserialization" do
  test "parses ISO8601 string to DateTime"
  test "handles timezone offsets"
end

describe "GeoCoordinate deserialization" do
  test "converts map to GeoCoordinate struct"
end
```

### Integration Tests

Update object creation tests to use complex types:

```elixir
test "creates object with DateTime property" do
  {:ok, _} = Objects.create(client, "Test", %{
    properties: %{
      created: ~U[2024-01-01 00:00:00Z]
    }
  })
end

test "creates object with GeoCoordinate property" do
  {:ok, _} = Objects.create(client, "Test", %{
    properties: %{
      location: %GeoCoordinate{latitude: 40.7128, longitude: -74.0060}
    }
  })
end
```

## Docs Updates

### README.md

Add section on data types:

```markdown
### Complex Data Types

WeaviateEx automatically serializes complex Elixir types:

\`\`\`elixir
# DateTime
%{created_at: ~U[2024-01-01 00:00:00Z]}
# -> {"created_at": "2024-01-01T00:00:00Z"}

# GeoCoordinate
%{location: %WeaviateEx.Types.GeoCoordinate{latitude: 40.71, longitude: -74.00}}
# -> {"location": {"latitude": 40.71, "longitude": -74.00}}

# PhoneNumber
%{phone: %WeaviateEx.Types.PhoneNumber{number: "555-1234", default_country: "US"}}
# -> {"phone": {"input": "555-1234", "defaultCountry": "US"}}

# Blob (binary data)
%{image: %WeaviateEx.Types.Blob{data: binary_data}}
# -> {"image": "<base64 encoded>"}
\`\`\`
```

## CHANGELOG Entry

Append to `## [0.7.3]` section:

```markdown
### Added
- `WeaviateEx.Types.Serializable` protocol for type serialization
- Automatic DateTime/NaiveDateTime/Date serialization to ISO8601
- GeoCoordinate serialization to Weaviate format
- PhoneNumber serialization with country code support
- Blob binary data base64 encoding
- Recursive nested object serialization
- `WeaviateEx.Types.Deserialize` module for response parsing

### Fixed
- Complex types now serialize correctly when creating objects
- Nested objects maintain proper structure through serialization
```

## Quality Gates

- [ ] All existing tests pass: `mix test`
- [ ] New serialization tests pass
- [ ] No warnings: `mix compile --warnings-as-errors`
- [ ] No Credo issues: `mix credo --strict`
- [ ] No Dialyzer errors: `mix dialyzer`
- [ ] README updated
- [ ] CHANGELOG entry added

## Acceptance Criteria

1. `Serializable` protocol implemented for all types
2. DateTime/Date types serialize to ISO8601
3. GeoCoordinate serializes to Weaviate format
4. PhoneNumber serializes with country code
5. Blob data base64 encoded
6. Nested objects recursively serialized
7. Deserialization available for responses
8. All quality gates pass
