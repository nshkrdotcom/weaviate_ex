defmodule WeaviateEx.Types.Beacon do
  @moduledoc """
  Utilities for parsing and building Weaviate beacon URLs.

  Beacon URLs are Weaviate's way of referencing objects and have the format:
  - `weaviate://localhost/<uuid>` - Simple reference
  - `weaviate://localhost/<collection>/<uuid>` - Reference with target collection

  Multi-target references (properties that can point to multiple collections)
  require the collection to be specified in the beacon.

  ## Examples

      # Parse a beacon
      Beacon.parse("weaviate://localhost/Person/uuid-123")
      # => %{collection: "Person", uuid: "uuid-123"}

      # Build a beacon
      Beacon.build("uuid-123", "Person")
      # => "weaviate://localhost/Person/uuid-123"

      # Create beacon map for API
      Beacon.to_map("uuid-123", "Person")
      # => %{"beacon" => "weaviate://localhost/Person/uuid-123"}
  """

  @type parsed :: %{collection: String.t() | nil, uuid: String.t()}

  @beacon_prefix "weaviate://localhost/"

  @doc """
  Parses a Weaviate beacon URL.

  Extracts the collection (if present) and UUID from a beacon URL.

  ## Examples

      Beacon.parse("weaviate://localhost/Person/uuid-123")
      # => %{collection: "Person", uuid: "uuid-123"}

      Beacon.parse("weaviate://localhost/uuid-123")
      # => %{collection: nil, uuid: "uuid-123"}
  """
  @spec parse(String.t()) :: parsed()
  def parse(@beacon_prefix <> rest) when byte_size(rest) > 0 do
    case String.split(rest, "/") do
      [uuid] ->
        %{collection: nil, uuid: uuid}

      [collection, uuid] ->
        %{collection: collection, uuid: uuid}

      _ ->
        %{collection: nil, uuid: rest}
    end
  end

  def parse(beacon) do
    %{collection: nil, uuid: beacon}
  end

  @doc """
  Builds a beacon URL from a UUID and optional collection.

  ## Examples

      Beacon.build("uuid-123")
      # => "weaviate://localhost/uuid-123"

      Beacon.build("uuid-123", "Person")
      # => "weaviate://localhost/Person/uuid-123"
  """
  @spec build(String.t(), String.t() | nil) :: String.t()
  def build(uuid, collection \\ nil)

  def build(uuid, nil) when is_binary(uuid) do
    @beacon_prefix <> uuid
  end

  def build(uuid, collection) when is_binary(uuid) and is_binary(collection) do
    @beacon_prefix <> collection <> "/" <> uuid
  end

  @doc """
  Creates a beacon map suitable for the Weaviate API.

  ## Examples

      Beacon.to_map("uuid-123")
      # => %{"beacon" => "weaviate://localhost/uuid-123"}

      Beacon.to_map("uuid-123", "Person")
      # => %{"beacon" => "weaviate://localhost/Person/uuid-123"}
  """
  @spec to_map(String.t(), String.t() | nil) :: map()
  def to_map(uuid, collection \\ nil) do
    %{"beacon" => build(uuid, collection)}
  end

  @doc """
  Extracts the UUID from a beacon URL.

  ## Examples

      Beacon.extract_uuid("weaviate://localhost/Person/uuid-123")
      # => {:ok, "uuid-123"}

      Beacon.extract_uuid("invalid")
      # => {:error, "Invalid beacon URL: invalid"}
  """
  @spec extract_uuid(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def extract_uuid(@beacon_prefix <> rest) when byte_size(rest) > 0 do
    uuid =
      rest
      |> String.split("/")
      |> List.last()

    {:ok, uuid}
  end

  def extract_uuid(beacon) do
    {:error, "Invalid beacon URL: #{beacon}"}
  end

  @doc """
  Extracts the collection name from a beacon URL.

  Only succeeds for beacons that include a collection.

  ## Examples

      Beacon.extract_collection("weaviate://localhost/Person/uuid-123")
      # => {:ok, "Person"}

      Beacon.extract_collection("weaviate://localhost/uuid-123")
      # => {:error, "No collection in beacon"}
  """
  @spec extract_collection(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def extract_collection(@beacon_prefix <> rest) when byte_size(rest) > 0 do
    case String.split(rest, "/") do
      [collection, _uuid] ->
        {:ok, collection}

      [_uuid] ->
        {:error, "No collection in beacon: #{@beacon_prefix}#{rest}"}

      _ ->
        {:error, "Invalid beacon format: #{@beacon_prefix}#{rest}"}
    end
  end

  def extract_collection(beacon) do
    {:error, "Invalid beacon URL: #{beacon}"}
  end

  @doc """
  Checks if a string is a valid Weaviate beacon URL.

  ## Examples

      Beacon.valid?("weaviate://localhost/Person/uuid-123")
      # => true

      Beacon.valid?("https://example.com")
      # => false
  """
  @spec valid?(String.t()) :: boolean()
  def valid?(@beacon_prefix <> rest) when byte_size(rest) > 0 do
    case String.split(rest, "/") do
      parts when length(parts) in [1, 2] -> true
      _ -> false
    end
  end

  def valid?(_), do: false
end
