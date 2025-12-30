defmodule WeaviateEx.Types.Deserialize do
  @moduledoc """
  Deserializes Weaviate response values to Elixir types.

  This module provides functions to convert Weaviate API response data
  back into rich Elixir types like `DateTime`, `GeoCoordinate`, etc.

  ## Usage

  You can deserialize individual values with a type hint:

      # Date strings
      {:ok, dt} = Deserialize.deserialize("2024-01-01T00:00:00Z", :date)
      # => {:ok, ~U[2024-01-01 00:00:00Z]}

      # GeoCoordinates
      {:ok, geo} = Deserialize.deserialize(%{"latitude" => 52.37, "longitude" => 4.90}, :geo_coordinates)
      # => {:ok, %GeoCoordinate{latitude: 52.37, longitude: 4.90}}

  Or deserialize entire property maps with schema hints:

      schema = %{"created_at" => :date, "location" => :geo_coordinates}
      {:ok, props} = Deserialize.deserialize_properties(raw_props, schema)

  ## Type Hints

  - `:date` - Parse ISO8601 string to DateTime
  - `:geo_coordinates` - Parse coordinate map to GeoCoordinate struct
  - `:phone_number` - Parse phone map to PhoneNumber.Output struct
  - `:blob` - Parse base64 string to Blob struct
  - `:auto` - Attempt automatic detection based on value structure
  """

  alias WeaviateEx.Types.{Blob, GeoCoordinate, PhoneNumber}

  @type type_hint ::
          :date
          | :geo_coordinates
          | :phone_number
          | :blob
          | :auto
          | nil

  @type schema :: %{optional(String.t()) => type_hint()}

  @doc """
  Deserializes a value based on the provided type hint.

  Returns `{:ok, value}` on success or `{:error, reason}` on failure.

  ## Examples

      iex> Deserialize.deserialize("2024-01-01T00:00:00Z", :date)
      {:ok, ~U[2024-01-01 00:00:00Z]}

      iex> Deserialize.deserialize(%{"latitude" => 52.37, "longitude" => 4.90}, :geo_coordinates)
      {:ok, %GeoCoordinate{latitude: 52.37, longitude: 4.90}}
  """
  @spec deserialize(any(), type_hint()) :: {:ok, any()} | {:error, String.t()}
  def deserialize(value, type \\ nil)

  def deserialize(nil, _type), do: {:ok, nil}

  # Date/DateTime parsing
  def deserialize(value, :date) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _offset} ->
        {:ok, dt}

      {:error, _} ->
        # Try NaiveDateTime if no timezone
        case NaiveDateTime.from_iso8601(value) do
          {:ok, ndt} -> {:ok, ndt}
          {:error, reason} -> {:error, "Failed to parse date: #{inspect(reason)}"}
        end
    end
  end

  # GeoCoordinate parsing
  def deserialize(%{"latitude" => lat, "longitude" => lon}, :geo_coordinates)
      when is_number(lat) and is_number(lon) do
    GeoCoordinate.new(lat, lon)
  end

  def deserialize(%{latitude: lat, longitude: lon}, :geo_coordinates)
      when is_number(lat) and is_number(lon) do
    GeoCoordinate.new(lat, lon)
  end

  # PhoneNumber parsing (from Weaviate response format)
  def deserialize(value, :phone_number) when is_map(value) do
    {:ok, PhoneNumber.Output.from_map(value)}
  end

  # Blob parsing (base64 to binary)
  def deserialize(value, :blob) when is_binary(value) do
    Blob.from_base64(value)
  end

  # Auto-detection based on value structure
  def deserialize(value, :auto) do
    cond do
      # Looks like a geo coordinate
      is_map(value) and Map.has_key?(value, "latitude") and Map.has_key?(value, "longitude") ->
        deserialize(value, :geo_coordinates)

      # Looks like a phone number response
      is_map(value) and Map.has_key?(value, "input") ->
        deserialize(value, :phone_number)

      # Looks like an ISO8601 date string
      is_binary(value) and String.match?(value, ~r/^\d{4}-\d{2}-\d{2}T/) ->
        deserialize(value, :date)

      # Pass through unchanged
      true ->
        {:ok, value}
    end
  end

  # No type hint - pass through unchanged
  def deserialize(value, nil), do: {:ok, value}

  # Type mismatch
  def deserialize(value, type) do
    {:error, "Cannot deserialize #{inspect(value)} as #{inspect(type)}"}
  end

  @doc """
  Deserializes a value, raising on error.

  ## Examples

      iex> Deserialize.deserialize!("2024-01-01T00:00:00Z", :date)
      ~U[2024-01-01 00:00:00Z]
  """
  @spec deserialize!(any(), type_hint()) :: any()
  def deserialize!(value, type \\ nil) do
    case deserialize(value, type) do
      {:ok, result} -> result
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @doc """
  Deserializes a map of properties using a schema that maps property names to types.

  ## Examples

      schema = %{
        "created_at" => :date,
        "location" => :geo_coordinates,
        "phone" => :phone_number
      }

      {:ok, props} = Deserialize.deserialize_properties(raw_props, schema)
  """
  @spec deserialize_properties(map(), schema()) :: {:ok, map()} | {:error, String.t()}
  def deserialize_properties(properties, schema) when is_map(properties) and is_map(schema) do
    result =
      Enum.reduce_while(properties, {:ok, %{}}, fn {key, value}, {:ok, acc} ->
        type_hint = Map.get(schema, key) || Map.get(schema, to_string(key))

        case deserialize(value, type_hint) do
          {:ok, deserialized} -> {:cont, {:ok, Map.put(acc, key, deserialized)}}
          {:error, reason} -> {:halt, {:error, "Error deserializing #{key}: #{reason}"}}
        end
      end)

    result
  end

  @doc """
  Deserializes properties, raising on error.
  """
  @spec deserialize_properties!(map(), schema()) :: map()
  def deserialize_properties!(properties, schema) do
    case deserialize_properties(properties, schema) do
      {:ok, result} -> result
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @doc """
  Attempts to auto-deserialize all properties in a map.

  Uses heuristics to detect types automatically.
  """
  @spec auto_deserialize(map()) :: {:ok, map()} | {:error, String.t()}
  def auto_deserialize(properties) when is_map(properties) do
    result =
      Enum.reduce_while(properties, {:ok, %{}}, fn {key, value}, {:ok, acc} ->
        case deserialize(value, :auto) do
          {:ok, deserialized} -> {:cont, {:ok, Map.put(acc, key, deserialized)}}
          {:error, reason} -> {:halt, {:error, "Error deserializing #{key}: #{reason}"}}
        end
      end)

    result
  end
end
