defmodule WeaviateEx.Validation.Property do
  @moduledoc """
  Property value validation against schema data types.

  Validates that property values conform to their declared data types
  before sending to Weaviate, providing early error detection.

  ## Supported Data Types

  - `text` - String values
  - `int` - Integer values
  - `number` - Numeric values (integer or float)
  - `boolean` - Boolean values
  - `date` - ISO8601 date/datetime strings or DateTime/Date structs
  - `uuid` - UUID strings
  - `blob` - Base64-encoded binary data
  - `geoCoordinates` - Geographic coordinates
  - `phoneNumber` - Phone number objects
  - `object` - Nested object (map)
  - Arrays - Append `[]` to any type (e.g., `text[]`, `int[]`)

  ## Examples

      # Validate a single value
      :ok = Property.validate("hello", "text")
      {:error, msg} = Property.validate(123, "text")

      # Validate an entire object against a schema
      schema = %{"properties" => [
        %{"name" => "title", "dataType" => ["text"]},
        %{"name" => "count", "dataType" => ["int"]}
      ]}
      object = %{"properties" => %{"title" => "Hello", "count" => 42}}
      :ok = Property.validate_object(object, schema)
  """

  alias WeaviateEx.Types.UUID

  @type validation_result :: :ok | {:error, String.t()}

  @doc """
  Validates a property value against its declared data type.

  ## Examples

      Property.validate("hello", "text")
      # => :ok

      Property.validate(123, "text")
      # => {:error, "Expected string for text type, got 123"}

      Property.validate([1, 2, 3], "int[]")
      # => :ok
  """
  @spec validate(term(), atom() | String.t()) :: validation_result()
  def validate(value, data_type) when is_atom(data_type) do
    validate(value, Atom.to_string(data_type))
  end

  # Null values are always valid
  def validate(nil, _), do: :ok

  # Text type
  def validate(value, "text") when is_binary(value), do: :ok

  def validate(value, "text"),
    do: {:error, "Expected string for text type, got #{inspect(value)}"}

  # Integer type
  def validate(value, "int") when is_integer(value), do: :ok
  def validate(value, "int"), do: {:error, "Expected integer for int type, got #{inspect(value)}"}

  # Number type (includes both integer and float)
  def validate(value, "number") when is_number(value), do: :ok

  def validate(value, "number"),
    do: {:error, "Expected number for number type, got #{inspect(value)}"}

  # Boolean type
  def validate(value, "boolean") when is_boolean(value), do: :ok

  def validate(value, "boolean"),
    do: {:error, "Expected boolean for boolean type, got #{inspect(value)}"}

  # Date type
  def validate(value, "date") when is_binary(value) do
    cond do
      valid_iso8601_datetime?(value) -> :ok
      valid_iso8601_date?(value) -> :ok
      true -> {:error, "Invalid date format: #{value}"}
    end
  end

  def validate(%DateTime{}, "date"), do: :ok
  def validate(%Date{}, "date"), do: :ok
  def validate(%NaiveDateTime{}, "date"), do: :ok
  def validate(value, "date"), do: {:error, "Expected date for date type, got #{inspect(value)}"}

  # UUID type
  def validate(value, "uuid") when is_binary(value) do
    if UUID.valid?(value) do
      :ok
    else
      {:error, "Invalid UUID format: #{value}"}
    end
  end

  def validate(value, "uuid"), do: {:error, "Expected UUID string, got #{inspect(value)}"}

  # Blob type (base64 encoded)
  def validate(value, "blob") when is_binary(value) do
    case Base.decode64(value) do
      {:ok, _} -> :ok
      :error -> {:error, "Invalid base64 encoding for blob type"}
    end
  end

  def validate(value, "blob"),
    do: {:error, "Expected base64 string for blob type, got #{inspect(value)}"}

  # GeoCoordinates type
  def validate(%{"latitude" => lat, "longitude" => lon}, "geoCoordinates")
      when is_number(lat) and is_number(lon) and lat >= -90 and lat <= 90 and lon >= -180 and
             lon <= 180 do
    :ok
  end

  def validate(%WeaviateEx.Types.GeoCoordinate{}, "geoCoordinates"), do: :ok

  def validate(value, "geoCoordinates"),
    do: {:error, "Invalid geo coordinates: #{inspect(value)}"}

  # PhoneNumber type
  def validate(%{"input" => input}, "phoneNumber") when is_binary(input), do: :ok
  def validate(%WeaviateEx.Types.PhoneNumber{}, "phoneNumber"), do: :ok
  def validate(value, "phoneNumber"), do: {:error, "Invalid phone number: #{inspect(value)}"}

  # Object type (nested)
  def validate(value, "object") when is_map(value), do: :ok

  def validate(value, "object"),
    do: {:error, "Expected map for object type, got #{inspect(value)}"}

  # Array types
  def validate(value, type) when is_list(value) and is_binary(type) do
    if String.ends_with?(type, "[]") do
      base_type = String.slice(type, 0..-3//1)
      validate_array(value, base_type)
    else
      {:error, "Expected non-array type #{type}, got list"}
    end
  end

  # Unknown type
  def validate(_, unknown_type), do: {:error, "Unknown data type: #{unknown_type}"}

  defp validate_array(values, base_type) do
    Enum.reduce_while(values, :ok, fn item, :ok ->
      case validate(item, base_type) do
        :ok -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  @doc """
  Validates all properties in an object against a schema.

  ## Examples

      schema = %{"properties" => [
        %{"name" => "title", "dataType" => ["text"]},
        %{"name" => "count", "dataType" => ["int"]}
      ]}
      object = %{"properties" => %{"title" => "Hello", "count" => 42}}
      Property.validate_object(object, schema)
      # => :ok

      object = %{"properties" => %{"title" => 123, "count" => "not an int"}}
      Property.validate_object(object, schema)
      # => {:error, ["title: Expected string for text type, got 123", "count: Expected integer..."]}
  """
  @spec validate_object(map(), map()) :: :ok | {:error, list(String.t())}
  def validate_object(object, schema) do
    properties = get_nested(object, ["properties"]) || %{}
    schema_props = get_nested(schema, ["properties"]) || []

    errors =
      Enum.flat_map(schema_props, fn prop ->
        prop_name = prop["name"]
        data_type = List.first(prop["dataType"] || [])
        value = Map.get(properties, prop_name) || Map.get(properties, String.to_atom(prop_name))

        case validate(value, data_type) do
          :ok -> []
          {:error, msg} -> ["#{prop_name}: #{msg}"]
        end
      end)

    if errors == [], do: :ok, else: {:error, errors}
  end

  # Helper to get nested value from map with string or atom keys
  defp get_nested(map, []), do: map

  defp get_nested(map, [key | rest]) when is_map(map) do
    value = Map.get(map, key) || Map.get(map, String.to_atom(key))
    get_nested(value, rest)
  end

  defp get_nested(_, _), do: nil

  defp valid_iso8601_datetime?(str) do
    case DateTime.from_iso8601(str) do
      {:ok, _, _} -> true
      _ -> false
    end
  end

  defp valid_iso8601_date?(str) do
    case Date.from_iso8601(str) do
      {:ok, _} -> true
      _ -> false
    end
  end
end
