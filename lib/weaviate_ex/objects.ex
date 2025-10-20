defmodule WeaviateEx.Objects do
  @moduledoc """
  Functions for managing individual objects in Weaviate.

  Objects are data records stored in collections with optional vector embeddings.

  ## Examples

      # Create an object
      {:ok, object} = WeaviateEx.Objects.create("Article", %{
        properties: %{
          title: "My Article",
          content: "Article content"
        },
        vector: [0.1, 0.2, 0.3, ...]  # Optional
      })

      # Get an object
      {:ok, object} = WeaviateEx.Objects.get("Article", uuid)

      # List objects
      {:ok, objects} = WeaviateEx.Objects.list("Article", limit: 10)

      # Fetch an object with tenant scoping and _additional metadata
      {:ok, object} =
        WeaviateEx.Objects.get("Article", uuid, tenant: "tenant-a", include: ["_additional"])

      # Update an object (full replacement)
      {:ok, updated} = WeaviateEx.Objects.update("Article", uuid, %{
        properties: %{title: "Updated Title"}
      })

      # Patch an object (partial update)
      {:ok, patched} = WeaviateEx.Objects.patch("Article", uuid, %{
        properties: %{title: "New Title"}
      })

      # Delete an object
      {:ok, _} = WeaviateEx.Objects.delete("Article", uuid)

      # Check if object exists
      {:ok, true} = WeaviateEx.Objects.exists?("Article", uuid)
  """

  import WeaviateEx, only: [request: 4]
  alias WeaviateEx.Objects.Payload

  @type collection_name :: String.t()
  @type object_id :: String.t()
  @type object_data :: map()

  @doc """
  Creates a new object in a collection.

  ## Parameters

  - `collection_name` - The collection to create the object in
  - `data` - Object data including properties and optional vector
  - `opts` - Additional options (consistency_level, etc.)

  ## Data Fields

  - `:id` - Optional UUID (auto-generated if not provided)
  - `:properties` - Object properties matching the collection schema
  - `:vector` - Optional vector embedding (if not using auto-vectorization)

  ## Examples

      # Simple object
      {:ok, obj} = Objects.create("Article", %{
        properties: %{title: "Hello"}
      })

      # With custom ID and vector
      {:ok, obj} = Objects.create("Article", %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        properties: %{title: "Hello"},
        vector: [0.1, 0.2, 0.3]
      })
  """
  @spec create(collection_name(), object_data(), Keyword.t()) :: WeaviateEx.api_response()
  def create(collection_name, data, opts \\ []) do
    payload_opts = Keyword.take(opts, [:auto_generate_id])

    body =
      data
      |> Payload.prepare_for_insert(collection_name, payload_opts)

    query_string = build_query_string(opts, [:consistency_level, :tenant])
    request(:post, "/v1/objects#{query_string}", body, opts)
  end

  @doc """
  Retrieves an object by collection name and ID.

  ## Parameters

  - `collection_name` - The collection containing the object
  - `id` - The object UUID
  - `opts` - Additional options (consistency_level, tenant, include)

  ## Examples

      {:ok, object} = Objects.get("Article", "550e8400-e29b-41d4-a716-446655440000")
  """
  @spec get(collection_name(), object_id(), Keyword.t()) :: WeaviateEx.api_response()
  def get(collection_name, id, opts \\ []) do
    query_string = build_query_string(opts, [:consistency_level, :tenant, :include])
    request(:get, "/v1/objects/#{collection_name}/#{id}#{query_string}", nil, opts)
  end

  @doc """
  Lists objects from a collection.

  ## Parameters

  - `collection_name` - The collection to list objects from
  - `opts` - Pagination and filtering options

  ## Options

  - `:limit` - Maximum number of objects to return
  - `:offset` - Number of objects to skip
  - `:after` - Cursor for pagination
  - `:include` - Additional fields to include (e.g., "vector", "classification")
  - `:sort` - Sort order
  - `:order` - Sort direction ("asc" or "desc")

  ## Examples

      # Get first 10 objects
      {:ok, result} = Objects.list("Article", limit: 10)

      # With pagination
      {:ok, result} = Objects.list("Article", limit: 10, offset: 20)

      # Include vectors
      {:ok, result} = Objects.list("Article", limit: 10, include: "vector")
  """
  @spec list(collection_name(), Keyword.t()) :: WeaviateEx.api_response()
  def list(collection_name, opts \\ []) do
    query_string =
      build_query_string(
        [{:class, collection_name} | opts],
        [:class, :limit, :offset, :after, :include, :sort, :order, :tenant, :consistency_level]
      )

    request(:get, "/v1/objects#{query_string}", nil, opts)
  end

  @doc """
  Updates an object (full replacement).

  This performs a PUT request which replaces the entire object.

  ## Examples

      {:ok, updated} = Objects.update("Article", uuid, %{
        properties: %{title: "New Title", content: "New Content"}
      })
  """
  @spec update(collection_name(), object_id(), object_data(), Keyword.t()) ::
          WeaviateEx.api_response()
  def update(collection_name, id, data, opts \\ []) do
    payload_opts = Keyword.take(opts, [:keep_vector])

    body =
      data
      |> Map.drop([:id, :class, "id", "class"])
      |> clean_properties_for_update()
      |> Payload.prepare_for_update(collection_name, id, payload_opts)

    query_string = build_query_string(opts, [:consistency_level, :tenant])
    request(:put, "/v1/objects/#{collection_name}/#{id}#{query_string}", body, opts)
  end

  # Clean properties map to remove id field if it exists
  defp clean_properties_for_update(%{properties: props} = data) when is_map(props) do
    cleaned_props = Map.drop(props, [:id, "id"])
    Map.put(data, :properties, cleaned_props)
  end

  defp clean_properties_for_update(data), do: data

  @doc """
  Patches an object (partial update).

  This performs a PATCH request which merges changes with existing data.
  After patching, the updated object is fetched and returned.

  NOTE: PATCH operations should not include vectors. If you need to update the vector,
  use update/4 (PUT) instead which replaces the entire object.

  ## Examples

      {:ok, patched} = Objects.patch("Article", uuid, %{
        properties: %{title: "Updated Title"}
      })
  """
  @spec patch(collection_name(), object_id(), object_data(), Keyword.t()) ::
          WeaviateEx.api_response()
  def patch(collection_name, id, data, opts \\ []) do
    # Drop immutable fields, class, and vector (not allowed in PATCH)
    body =
      data
      |> Map.drop([:id, :class, :vector, "id", "class", "vector"])
      |> Payload.prepare_for_patch()

    query_string = build_query_string(opts, [:consistency_level, :tenant])

    # Weaviate returns 204 No Content on successful PATCH, so we need to fetch the updated object
    case request(:patch, "/v1/objects/#{collection_name}/#{id}#{query_string}", body, opts) do
      {:ok, _} -> get(collection_name, id, opts)
      error -> error
    end
  end

  @doc """
  Deletes an object.

  ## Examples

      {:ok, _} = Objects.delete("Article", uuid)
  """
  @spec delete(collection_name(), object_id(), Keyword.t()) :: WeaviateEx.api_response()
  def delete(collection_name, id, opts \\ []) do
    query_string = build_query_string(opts, [:consistency_level, :tenant])
    request(:delete, "/v1/objects/#{collection_name}/#{id}#{query_string}", nil, opts)
  end

  @doc """
  Checks if an object exists (using HEAD request).

  Returns `{:ok, true}` if the object exists (204 status).
  Returns `{:error, ...}` if the object doesn't exist (404 status).

  ## Examples

      case Objects.exists?("Article", uuid) do
        {:ok, true} -> IO.puts("Object exists")
        {:error, %{status: 404}} -> IO.puts("Object not found")
      end
  """
  @spec exists?(collection_name(), object_id(), Keyword.t()) ::
          {:ok, boolean()} | {:error, term()}
  def exists?(collection_name, id, opts \\ []) do
    query_string = build_query_string(opts, [:consistency_level, :tenant])

    case request(:head, "/v1/objects/#{collection_name}/#{id}#{query_string}", nil, opts) do
      {:ok, _} -> {:ok, true}
      error -> error
    end
  end

  @doc """
  Validates an object without creating it.

  Useful for checking if object data is valid before insertion.

  ## Examples

      {:ok, result} = Objects.validate("Article", %{
        properties: %{title: "Test"}
      })
  """
  @spec validate(collection_name(), object_data(), Keyword.t()) :: WeaviateEx.api_response()
  def validate(collection_name, data, opts \\ []) do
    # Validate endpoint requires an ID - generate dummy UUID if not provided
    body =
      data
      |> Payload.normalize_keys()
      |> ensure_validation_id()
      |> Payload.ensure_class(collection_name)

    query_string = build_query_string(opts, [:consistency_level])
    request(:post, "/v1/objects/validate#{query_string}", body, opts)
  end

  # Helper to build query strings
  defp build_query_string(opts, allowed_keys) do
    params =
      opts
      |> Enum.filter(fn {key, _value} -> key in allowed_keys end)
      |> Enum.map(fn {key, value} -> "#{key}=#{encode_query_value(value)}" end)
      |> Enum.join("&")

    if params == "", do: "", else: "?#{params}"
  end

  defp encode_query_value(value) when is_list(value) do
    value
    |> Enum.map(&to_string/1)
    |> Enum.join(",")
    |> URI.encode_www_form()
  end

  defp encode_query_value(value) do
    value
    |> to_string()
    |> URI.encode_www_form()
  end

  defp ensure_validation_id(data) do
    cond do
      Map.has_key?(data, "id") -> data
      Map.has_key?(data, :id) -> data
      true -> Map.put(data, "id", "00000000-0000-0000-0000-000000000000")
    end
  end
end
