defmodule WeaviateEx.API.Data do
  @moduledoc """
  Data operations API for CRUD operations on objects.

  This module provides a clean, protocol-based API for managing data objects
  in Weaviate collections with support for:
  - Custom UUIDs
  - Vector embeddings
  - Multi-tenancy
  - Consistency levels
  - Named vectors (future)

  ## Examples

      # Create an object
      {:ok, object} = Data.insert(client, "Article", %{
        properties: %{"title" => "Hello", "content" => "World"}
      })

      # Create with custom UUID
      {:ok, object} = Data.insert(client, "Article", %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        properties: %{"title" => "Hello"}
      })

      # Create with vector
      {:ok, object} = Data.insert(client, "Article", %{
        properties: %{"title" => "Hello"},
        vector: [0.1, 0.2, 0.3]
      })

      # Get object
      {:ok, object} = Data.get_by_id(client, "Article", uuid)

      # Update (full replacement)
      {:ok, updated} = Data.update(client, "Article", uuid, %{
        properties: %{"title" => "Updated"}
      })

      # Patch (partial update)
      {:ok, patched} = Data.patch(client, "Article", uuid, %{
        properties: %{"title" => "Patched"}
      })

      # Delete
      {:ok, _} = Data.delete_by_id(client, "Article", uuid)

      # Check existence
      {:ok, true} = Data.exists?(client, "Article", uuid)

      # Validate before insert
      {:ok, result} = Data.validate(client, "Article", %{
        properties: %{"title" => "Test"}
      })
  """

  alias WeaviateEx.Client
  alias WeaviateEx.Error
  alias WeaviateEx.Objects.Payload

  @type collection_name :: String.t()
  @type object_id :: String.t()
  @type object_data :: map()
  @type opts :: keyword()

  @doc """
  Insert a new object into a collection.

  ## Parameters
    * `client` - WeaviateEx client
    * `collection_name` - Name of the collection
    * `data` - Object data map with `:properties` and optionally `:id`, `:vector`
    * `opts` - Options (`:tenant`, `:consistency_level`)

  ## Examples

      Data.insert(client, "Article", %{
        properties: %{"title" => "Hello"}
      })

      Data.insert(client, "Article", %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        properties: %{"title" => "Hello"},
        vector: [0.1, 0.2, 0.3]
      }, tenant: "TenantA")

  ## Returns
    * `{:ok, object}` - Created object with UUID
    * `{:error, Error.t()}` - Error if creation fails
  """
  @spec insert(Client.t(), collection_name(), object_data(), opts()) ::
          {:ok, map()} | {:error, Error.t()}
  def insert(client, collection_name, data, opts \\ []) do
    payload_opts = Keyword.take(opts, [:auto_generate_id])

    body =
      data
      |> Payload.prepare_for_insert(collection_name, payload_opts)

    path = "/v1/objects" <> build_query_string(opts, [:tenant, :consistency_level])
    Client.request(client, :post, path, body, opts)
  end

  @doc """
  Get an object by its UUID.

  ## Parameters
    * `client` - WeaviateEx client
    * `collection_name` - Name of the collection
    * `id` - Object UUID
    * `opts` - Options (`:tenant`, `:consistency_level`, `:include`)

  ## Examples

      Data.get_by_id(client, "Article", "550e8400-e29b-41d4-a716-446655440000")

      Data.get_by_id(client, "Article", uuid,
        tenant: "TenantA",
        include: "vector"
      )

  ## Returns
    * `{:ok, object}` - Retrieved object
    * `{:error, Error.t()}` - Error if not found
  """
  @spec get_by_id(Client.t(), collection_name(), object_id(), opts()) ::
          {:ok, map()} | {:error, Error.t()}
  def get_by_id(client, collection_name, id, opts \\ []) do
    path =
      "/v1/objects/#{collection_name}/#{id}" <>
        build_query_string(opts, [:tenant, :consistency_level, :include])

    Client.request(client, :get, path, nil, opts)
  end

  @doc """
  Update an object (full replacement).

  This replaces the entire object with new data.

  ## Parameters
    * `client` - WeaviateEx client
    * `collection_name` - Name of the collection
    * `id` - Object UUID
    * `data` - New object data
    * `opts` - Options (`:tenant`, `:consistency_level`)

  ## Examples

      Data.update(client, "Article", uuid, %{
        properties: %{"title" => "New Title", "content" => "New Content"}
      })

  ## Returns
    * `{:ok, object}` - Updated object
    * `{:error, Error.t()}` - Error if update fails
  """
  @spec update(Client.t(), collection_name(), object_id(), object_data(), opts()) ::
          {:ok, map()} | {:error, Error.t()}
  def update(client, collection_name, id, data, opts \\ []) do
    payload_opts = Keyword.take(opts, [:keep_vector])

    body = Payload.prepare_for_update(data, collection_name, id, payload_opts)

    path =
      "/v1/objects/#{collection_name}/#{id}" <>
        build_query_string(opts, [:tenant, :consistency_level])

    Client.request(client, :put, path, body, opts)
  end

  @doc """
  Patch an object (partial update).

  This merges changes with existing data.

  ## Parameters
    * `client` - WeaviateEx client
    * `collection_name` - Name of the collection
    * `id` - Object UUID
    * `data` - Partial object data
    * `opts` - Options (`:tenant`, `:consistency_level`)

  ## Examples

      Data.patch(client, "Article", uuid, %{
        properties: %{"title" => "Updated Title"}
      })

  ## Returns
    * `{:ok, object}` - Updated object (retrieved after patch)
    * `{:error, Error.t()}` - Error if patch fails
  """
  @spec patch(Client.t(), collection_name(), object_id(), object_data(), opts()) ::
          {:ok, map()} | {:error, Error.t()}
  def patch(client, collection_name, id, data, opts \\ []) do
    body =
      data
      |> Payload.prepare_for_patch()
      |> Map.drop(["vector", :vector])

    path =
      "/v1/objects/#{collection_name}/#{id}" <>
        build_query_string(opts, [:tenant, :consistency_level])

    # PATCH returns 204 No Content, so we need to GET the updated object
    case Client.request(client, :patch, path, body, opts) do
      {:ok, _} -> get_by_id(client, collection_name, id, opts)
      error -> error
    end
  end

  @doc """
  Delete an object by its UUID.

  ## Parameters
    * `client` - WeaviateEx client
    * `collection_name` - Name of the collection
    * `id` - Object UUID
    * `opts` - Options (`:tenant`, `:consistency_level`)

  ## Examples

      Data.delete_by_id(client, "Article", uuid)

      Data.delete_by_id(client, "Article", uuid, tenant: "TenantA")

  ## Returns
    * `{:ok, map()}` - Empty map on success
    * `{:error, Error.t()}` - Error if deletion fails
  """
  @spec delete_by_id(Client.t(), collection_name(), object_id(), opts()) ::
          {:ok, map()} | {:error, Error.t()}
  def delete_by_id(client, collection_name, id, opts \\ []) do
    path =
      "/v1/objects/#{collection_name}/#{id}" <>
        build_query_string(opts, [:tenant, :consistency_level])

    Client.request(client, :delete, path, nil, opts)
  end

  @doc """
  Check if an object exists.

  ## Parameters
    * `client` - WeaviateEx client
    * `collection_name` - Name of the collection
    * `id` - Object UUID
    * `opts` - Options (`:tenant`, `:consistency_level`)

  ## Examples

      Data.exists?(client, "Article", uuid)
      # => {:ok, true}

      Data.exists?(client, "Article", "non-existent")
      # => {:ok, false}

  ## Returns
    * `{:ok, boolean()}` - True if exists, false otherwise
  """
  @spec exists?(Client.t(), collection_name(), object_id(), opts()) ::
          {:ok, boolean()}
  def exists?(client, collection_name, id, opts \\ []) do
    path =
      "/v1/objects/#{collection_name}/#{id}" <>
        build_query_string(opts, [:tenant, :consistency_level])

    case Client.request(client, :head, path, nil, opts) do
      {:ok, _} -> {:ok, true}
      {:error, %Error{type: :not_found}} -> {:ok, false}
      {:error, _} -> {:ok, false}
    end
  end

  @doc """
  Validate object data without creating it.

  Useful for checking if object data is valid before insertion.

  ## Parameters
    * `client` - WeaviateEx client
    * `collection_name` - Name of the collection
    * `data` - Object data to validate
    * `opts` - Options

  ## Examples

      Data.validate(client, "Article", %{
        properties: %{"title" => "Test"}
      })

  ## Returns
    * `{:ok, result}` - Validation result
    * `{:error, Error.t()}` - Validation error
  """
  @spec validate(Client.t(), collection_name(), object_data(), opts()) ::
          {:ok, map()} | {:error, Error.t()}
  def validate(client, collection_name, data, opts \\ []) do
    body =
      data
      |> Payload.normalize_keys()
      |> maybe_put_validation_id()
      |> Payload.ensure_class(collection_name)

    path = "/v1/objects/validate" <> build_query_string(opts, [:consistency_level])
    Client.request(client, :post, path, body, opts)
  end

  ## Private Helpers

  defp maybe_put_validation_id(data) do
    cond do
      Map.has_key?(data, "id") -> data
      Map.has_key?(data, :id) -> data
      true -> Map.put(data, "id", "00000000-0000-0000-0000-000000000000")
    end
  end

  defp build_query_string(opts, allowed_keys) do
    params =
      opts
      |> Enum.filter(fn {key, _value} -> key in allowed_keys end)
      |> Enum.map(&encode_param/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.join("&")

    if params == "", do: "", else: "?#{params}"
  end

  defp encode_param({key, value}) do
    "#{key}=#{encode_value(value)}"
  end

  defp encode_value(value) when is_list(value) do
    value
    |> Enum.map(&to_string/1)
    |> Enum.join(",")
    |> URI.encode_www_form()
  end

  defp encode_value(value) do
    value
    |> to_string()
    |> URI.encode_www_form()
  end
end
