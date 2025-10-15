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
    body = Map.put(data, :class, collection_name)
    query_string = build_query_string(opts, [:consistency_level])
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
        [:class, :limit, :offset, :after, :include, :sort, :order]
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
    body = Map.put(data, :class, collection_name)
    query_string = build_query_string(opts, [:consistency_level])
    request(:put, "/v1/objects/#{collection_name}/#{id}#{query_string}", body, opts)
  end

  @doc """
  Patches an object (partial update).

  This performs a PATCH request which merges changes with existing data.

  ## Examples

      {:ok, patched} = Objects.patch("Article", uuid, %{
        properties: %{title: "Updated Title"}
      })
  """
  @spec patch(collection_name(), object_id(), object_data(), Keyword.t()) ::
          WeaviateEx.api_response()
  def patch(collection_name, id, data, opts \\ []) do
    query_string = build_query_string(opts, [:consistency_level])
    request(:patch, "/v1/objects/#{collection_name}/#{id}#{query_string}", data, opts)
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
    body = Map.put(data, :class, collection_name)
    query_string = build_query_string(opts, [:consistency_level])
    request(:post, "/v1/objects/validate#{query_string}", body, opts)
  end

  # Helper to build query strings
  defp build_query_string(opts, allowed_keys) do
    params =
      opts
      |> Enum.filter(fn {key, _value} -> key in allowed_keys end)
      |> Enum.map(fn {key, value} -> "#{key}=#{value}" end)
      |> Enum.join("&")

    if params == "", do: "", else: "?#{params}"
  end
end
