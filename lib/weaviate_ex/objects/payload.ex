defmodule WeaviateEx.Objects.Payload do
  @moduledoc """
  Utilities for preparing object payloads for Weaviate requests.

  These helpers keep UUID generation, key normalization, and class assignments
  consistent between the high-level `WeaviateEx.Objects` module and the lower-level
  `WeaviateEx.API.Data` module.
  """

  alias WeaviateEx.Types.{Blob, GeoCoordinate, PhoneNumber, Serializable}

  @type data :: map()
  @type opts :: keyword()

  @doc """
  Normalizes a payload by converting atom keys to strings and recursively normalizing
  nested maps or lists.

  Structs are passed through unchanged (they will be serialized later by
  `serialize_properties/1`).
  """
  @spec normalize_keys(data()) :: data()
  def normalize_keys(data) when is_struct(data) do
    # Pass structs through unchanged - they will be serialized by serialize_properties
    data
  end

  def normalize_keys(data) when is_map(data) do
    Map.new(data, fn
      {key, value} when is_struct(value) ->
        # Pass structs through unchanged
        {normalize_key(key), value}

      {key, value} when is_map(value) ->
        {normalize_key(key), normalize_keys(value)}

      {key, value} when is_list(value) ->
        {normalize_key(key), Enum.map(value, &normalize_nested/1)}

      {key, value} ->
        {normalize_key(key), value}
    end)
  end

  def normalize_keys(other), do: other

  @doc """
  Ensures a UUID is present on the payload. By default a new UUID is generated
  using `Uniq.UUID`. Use `auto_generate_id: false` to skip automatic generation.
  """
  @spec ensure_id(data(), opts()) :: data()
  def ensure_id(data, opts \\ []) when is_map(data) do
    cond do
      Map.has_key?(data, "id") -> data
      Map.has_key?(data, :id) -> data
      Keyword.get(opts, :auto_generate_id, true) -> Map.put(data, "id", Uniq.UUID.uuid4())
      true -> data
    end
  end

  @doc """
  Removes any existing class markers and sets the provided class on the payload.
  """
  @spec ensure_class(data(), String.t()) :: data()
  def ensure_class(data, class_name) when is_map(data) do
    data
    |> Map.delete(:class)
    |> Map.delete("class")
    |> Map.put("class", class_name)
  end

  @doc """
  Removes any existing id markers and sets the provided id on the payload.
  """
  @spec ensure_id_value(data(), String.t()) :: data()
  def ensure_id_value(data, id) when is_map(data) do
    data
    |> Map.delete(:id)
    |> Map.delete("id")
    |> Map.put("id", id)
  end

  @doc """
  Prepares a payload for insertion by normalizing keys, generating an id when
  necessary, applying the collection class, handling vectors, and merging references.

  ## Vector Support

  Supports both single vector and named vectors (mutually exclusive):

    * `:vector` - Single vector for the default vector
    * `:vectors` - Map of named vectors (e.g., `%{"title_vector" => [0.1, 0.2]}`)

  Raises `ArgumentError` if both `:vector` and `:vectors` are provided.

  ## Reference Support

  Supports inline references via the `:references` key:

    * Single UUID: `%{"hasAuthor" => "uuid-123"}`
    * Multiple UUIDs: `%{"hasAuthors" => ["uuid-1", "uuid-2"]}`
    * Multi-target: `%{"relatedTo" => %{target_collection: "Category", uuids: "cat-uuid"}}`

  References are converted to beacon format and merged into properties.

  ## Property Value Serialization

  Special types are automatically serialized to Weaviate-compatible formats
  via the `WeaviateEx.Types.Serializable` protocol:

    * `DateTime` - RFC3339 format (ISO8601 with timezone)
    * `NaiveDateTime` - RFC3339 format (without timezone)
    * `Date` - ISO8601 date at midnight UTC
    * `GeoCoordinate` - `%{"latitude" => lat, "longitude" => lon}`
    * `PhoneNumber` - `%{"input" => number, "defaultCountry" => country}`
    * `Blob` - Base64-encoded string

  Nested objects and arrays are recursively serialized.
  """
  @spec prepare_for_insert(data(), String.t(), opts()) :: data()
  def prepare_for_insert(data, class_name, opts \\ []) do
    data
    |> normalize_keys()
    |> validate_required_properties!("insert")
    |> validate_vectors!()
    |> handle_vectors()
    |> merge_references()
    |> validate_reserved_property_names!()
    |> serialize_properties()
    |> ensure_id(opts)
    |> ensure_class(class_name)
  end

  @doc """
  Prepares a payload for update requests by normalizing keys, forcing the id,
  applying the collection class, and handling vectors.

  ## Vector Support

  Supports both single vector and named vectors (mutually exclusive):

    * `:vector` - Single vector for the default vector
    * `:vectors` - Map of named vectors (e.g., `%{"title_vector" => [0.1, 0.2]}`)

  Raises `ArgumentError` if both `:vector` and `:vectors` are provided.
  """
  @spec prepare_for_update(data(), String.t(), String.t(), opts()) :: data()
  def prepare_for_update(data, class_name, id, opts \\ []) do
    data
    |> normalize_keys()
    |> validate_required_properties!("update")
    |> validate_vectors!()
    |> handle_vectors()
    |> validate_reserved_property_names!()
    |> ensure_id_value(id)
    |> ensure_class(class_name)
    |> maybe_preserve_vector(opts)
  end

  @doc """
  Normalizes a payload for patch operations (class/id handled by the server).
  """
  @spec prepare_for_patch(data()) :: data()
  def prepare_for_patch(data) do
    data
    |> normalize_keys()
    |> validate_reserved_property_names!()
    |> Map.delete("class")
    |> Map.delete("id")
  end

  defp normalize_nested(value) when is_struct(value), do: value
  defp normalize_nested(value) when is_map(value), do: normalize_keys(value)
  defp normalize_nested(value), do: value

  defp normalize_key(key) when is_atom(key), do: Atom.to_string(key)
  defp normalize_key(key), do: key

  defp maybe_preserve_vector(data, opts) do
    case Keyword.get(opts, :keep_vector, true) do
      true -> data
      false -> Map.delete(data, "vector")
    end
  end

  # Validate that both vector and vectors are not provided at the same time
  defp validate_vectors!(data) do
    has_vector = Map.has_key?(data, "vector") and data["vector"] != nil

    has_vectors =
      Map.has_key?(data, "vectors") and data["vectors"] != nil and data["vectors"] != %{}

    if has_vector and has_vectors do
      raise ArgumentError,
            "cannot specify both 'vector' and 'vectors' - use 'vector' for single vector " <>
              "or 'vectors' for named vectors"
    end

    data
  end

  # Handle vector/vectors in payload - ensure proper format
  defp handle_vectors(data) do
    cond do
      # Named vectors provided - keep vectors, remove vector key
      has_non_empty_vectors?(data) ->
        data
        |> Map.delete("vector")

      # Single vector provided - keep as is
      Map.has_key?(data, "vector") ->
        data
        |> Map.delete("vectors")

      # No vectors - clean up empty keys
      true ->
        data
        |> Map.delete("vector")
        |> Map.delete("vectors")
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

  # Merge references into properties as beacon format
  defp merge_references(data) do
    case Map.get(data, "references") do
      nil ->
        data

      %{} = refs when map_size(refs) == 0 ->
        Map.delete(data, "references")

      %{} = refs ->
        properties = Map.get(data, "properties", %{})
        updated_properties = convert_references_to_beacons(refs, properties)

        data
        |> Map.put("properties", updated_properties)
        |> Map.delete("references")
    end
  end

  # Convert reference definitions to beacon format and merge with properties
  defp convert_references_to_beacons(refs, properties) do
    Enum.reduce(refs, properties, fn {ref_property, ref_value}, props ->
      beacons = build_beacons(ref_value)
      Map.put(props, ref_property, beacons)
    end)
  end

  # Build beacon list from reference value
  defp build_beacons(uuid) when is_binary(uuid) do
    [%{"beacon" => "weaviate://localhost/#{uuid}"}]
  end

  defp build_beacons(uuids) when is_list(uuids) do
    Enum.map(uuids, fn uuid ->
      %{"beacon" => "weaviate://localhost/#{uuid}"}
    end)
  end

  # Multi-target reference with target_collection
  defp build_beacons(%{target_collection: collection, uuids: uuids})
       when is_binary(uuids) do
    [%{"beacon" => "weaviate://localhost/#{collection}/#{uuids}"}]
  end

  defp build_beacons(%{target_collection: collection, uuids: uuids})
       when is_list(uuids) do
    Enum.map(uuids, fn uuid ->
      %{"beacon" => "weaviate://localhost/#{collection}/#{uuid}"}
    end)
  end

  # Handle string keys for multi-target reference
  defp build_beacons(%{"target_collection" => collection, "uuids" => uuids})
       when is_binary(uuids) do
    [%{"beacon" => "weaviate://localhost/#{collection}/#{uuids}"}]
  end

  defp build_beacons(%{"target_collection" => collection, "uuids" => uuids})
       when is_list(uuids) do
    Enum.map(uuids, fn uuid ->
      %{"beacon" => "weaviate://localhost/#{collection}/#{uuid}"}
    end)
  end

  # Serialize property values to Weaviate API format
  defp serialize_properties(data) do
    case Map.get(data, "properties") do
      nil -> data
      %{} = props -> Map.put(data, "properties", serialize_values(props))
    end
  end

  # Recursively serialize a map's values
  defp serialize_values(map) when is_map(map) and not is_struct(map) do
    Map.new(map, fn {k, v} -> {k, serialize_value(v)} end)
  end

  defp serialize_values(other), do: other

  # Structs implementing Serializable protocol
  defp serialize_value(%DateTime{} = dt) do
    Serializable.serialize(dt)
  end

  defp serialize_value(%NaiveDateTime{} = dt) do
    Serializable.serialize(dt)
  end

  defp serialize_value(%Date{} = d) do
    Serializable.serialize(d)
  end

  defp serialize_value(%GeoCoordinate{} = geo) do
    Serializable.serialize(geo)
  end

  defp serialize_value(%PhoneNumber{} = phone) do
    Serializable.serialize(phone)
  end

  defp serialize_value(%Blob{} = blob) do
    Serializable.serialize(blob)
  end

  # Arrays - recursively serialize
  defp serialize_value(list) when is_list(list) do
    Enum.map(list, &serialize_value/1)
  end

  # Nested maps - recursively serialize
  defp serialize_value(map) when is_map(map) and not is_struct(map) do
    serialize_values(map)
  end

  # Pass through primitives and other values unchanged
  defp serialize_value(other), do: other

  defp validate_required_properties!(data, action) when is_map(data) do
    properties = Map.get(data, "properties")

    cond do
      is_map(properties) ->
        data

      is_nil(properties) ->
        raise ArgumentError, "properties are required for #{action} operations"

      true ->
        raise ArgumentError, "properties must be a map for #{action} operations"
    end
  end

  @reserved_property_names ["id", "vector"]

  defp validate_reserved_property_names!(data) when is_map(data) do
    case Map.get(data, "properties") do
      nil ->
        data

      properties when is_map(properties) ->
        case Enum.find(@reserved_property_names, &Map.has_key?(properties, &1)) do
          nil ->
            data

          reserved ->
            raise ArgumentError, "reserved property name '#{reserved}' is not allowed"
        end

      _ ->
        raise ArgumentError, "properties must be a map"
    end
  end
end
