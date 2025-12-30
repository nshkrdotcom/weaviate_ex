defprotocol WeaviateEx.Types.Serializable do
  @moduledoc """
  Protocol for serializing Elixir types to Weaviate-compatible values.

  This protocol enables automatic serialization of complex Elixir types
  when creating or updating objects in Weaviate. Types implementing this
  protocol will be automatically converted to the appropriate format.

  ## Built-in Implementations

  - `DateTime` -> ISO8601 string with timezone (RFC3339)
  - `NaiveDateTime` -> ISO8601 string without timezone
  - `Date` -> ISO8601 date at midnight UTC
  - `GeoCoordinate` -> `%{"latitude" => lat, "longitude" => lon}`
  - `PhoneNumber` -> `%{"input" => number, "defaultCountry" => country}`
  - `Blob` -> Base64-encoded string

  ## Examples

      # DateTime serialization
      iex> Serializable.serialize(~U[2024-01-01 00:00:00Z])
      "2024-01-01T00:00:00Z"

      # GeoCoordinate serialization
      iex> {:ok, geo} = WeaviateEx.Types.GeoCoordinate.new(52.37, 4.90)
      iex> Serializable.serialize(geo)
      %{"latitude" => 52.37, "longitude" => 4.90}

  ## Custom Types

  You can implement this protocol for your own types:

      defimpl WeaviateEx.Types.Serializable, for: MyApp.CustomType do
        def serialize(%MyApp.CustomType{value: v}), do: v
      end
  """

  @doc """
  Serializes a value to a Weaviate-compatible format.

  Returns the serialized value suitable for the Weaviate API.
  """
  @spec serialize(t()) :: any()
  def serialize(value)
end

# DateTime -> RFC3339 format (ISO8601 with timezone)
defimpl WeaviateEx.Types.Serializable, for: DateTime do
  def serialize(dt), do: DateTime.to_iso8601(dt)
end

# NaiveDateTime -> ISO8601 format (without timezone)
defimpl WeaviateEx.Types.Serializable, for: NaiveDateTime do
  def serialize(dt), do: NaiveDateTime.to_iso8601(dt)
end

# Date -> ISO8601 date at midnight UTC
defimpl WeaviateEx.Types.Serializable, for: Date do
  def serialize(d), do: Date.to_iso8601(d) <> "T00:00:00Z"
end

# GeoCoordinate -> Weaviate format
defimpl WeaviateEx.Types.Serializable, for: WeaviateEx.Types.GeoCoordinate do
  def serialize(%{latitude: lat, longitude: lon}) do
    %{"latitude" => lat, "longitude" => lon}
  end
end

# PhoneNumber -> Weaviate format
defimpl WeaviateEx.Types.Serializable, for: WeaviateEx.Types.PhoneNumber do
  def serialize(%{number: number, default_country: nil}) do
    %{"input" => number}
  end

  def serialize(%{number: number, default_country: country}) do
    %{"input" => number, "defaultCountry" => country}
  end
end

# Blob -> Base64-encoded string
defimpl WeaviateEx.Types.Serializable, for: WeaviateEx.Types.Blob do
  def serialize(%{data: data}) when is_binary(data) do
    Base.encode64(data)
  end

  def serialize(%{data: nil}), do: nil
end
