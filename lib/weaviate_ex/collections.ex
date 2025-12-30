defmodule WeaviateEx.Collections do
  @moduledoc """
  Functions for managing Weaviate collections (schema classes).

  Collections define the structure of your data including properties,
  vectorization settings, and indexing configuration.

  ## Examples

      # List all collections
      {:ok, schema} = WeaviateEx.Collections.list()

      # Get a specific collection
      {:ok, collection} = WeaviateEx.Collections.get("Article")

      # Create a new collection
      {:ok, collection} = WeaviateEx.Collections.create("Article", %{
        description: "A collection for articles",
        properties: [
          %{name: "title", dataType: ["text"]},
          %{name: "content", dataType: ["text"]},
          %{name: "publishedAt", dataType: ["date"]}
        ],
        vectorizer: "text2vec-openai"
      })

      # Update a collection
      {:ok, collection} = WeaviateEx.Collections.update("Article", %{
        description: "Updated description"
      })

      # Delete a collection
      {:ok, _} = WeaviateEx.Collections.delete("Article")

      # Delete all collections
      {:ok, deleted_count: 3} = WeaviateEx.Collections.delete_all()

      # Add a property to an existing collection
      {:ok, property} = WeaviateEx.Collections.add_property("Article", %{
        name: "author",
        dataType: ["text"]
      })

      # Enable multi-tenancy and confirm the collection exists
      {:ok, %{"enabled" => true}} = WeaviateEx.Collections.set_multi_tenancy("Article", true)
      {:ok, true} = WeaviateEx.Collections.exists?("Article")
  """

  import WeaviateEx, only: [request: 4]

  @type collection_name :: String.t()
  @type collection_config :: map()
  @type property :: map()
  @type opts :: Keyword.t()

  @doc """
  Lists all collections in the schema.

  ## Examples

      iex> WeaviateEx.Collections.list()
      {:ok, %{"classes" => [...]}}
  """
  @spec list(Keyword.t()) :: WeaviateEx.api_response()
  def list(opts \\ []) do
    request(:get, "/v1/schema", nil, opts)
  end

  @doc """
  Gets a specific collection by name.

  ## Parameters

  - `name` - The name of the collection
  - `opts` - Additional options

  ## Examples

      iex> WeaviateEx.Collections.get("Article")
      {:ok, %{"class" => "Article", "properties" => [...]}}
  """
  @spec get(collection_name(), Keyword.t()) :: WeaviateEx.api_response()
  def get(name, opts \\ []) do
    request(:get, "/v1/schema/#{name}", nil, opts)
  end

  @doc """
  Creates a new collection.

  ## Parameters

  - `name` - The name of the collection (must start with uppercase)
  - `config` - Collection configuration including properties, vectorizer, etc.
  - `opts` - Additional options

  ## Configuration Options

  - `:description` - Human-readable description
  - `:properties` - List of property definitions
  - `:vectorizer` - Vectorizer module to use (e.g., "text2vec-openai", "none")
  - `:vectorIndexType` - Vector index type (default: "hnsw")
  - `:vectorIndexConfig` - Vector index configuration
  - `:invertedIndexConfig` - Inverted index configuration
  - `:replicationConfig` - Replication settings
  - `:multiTenancyConfig` - Multi-tenancy settings

  ## Examples

      iex> WeaviateEx.Collections.create("Article", %{
      ...>   properties: [
      ...>     %{name: "title", dataType: ["text"]},
      ...>     %{name: "content", dataType: ["text"]}
      ...>   ],
      ...>   vectorizer: "none"
      ...> })
      {:ok, %{"class" => "Article", ...}}
  """
  @spec create(collection_name(), collection_config(), Keyword.t()) :: WeaviateEx.api_response()
  def create(name, config, opts \\ []) do
    request_opts = Keyword.drop(opts, [:config_overrides])

    body =
      config
      |> merge_config(opts)
      |> Map.put("class", name)

    request(:post, "/v1/schema", body, request_opts)
  end

  @doc """
  Updates an existing collection.

  Note: Not all fields can be updated after creation. Check Weaviate
  documentation for updateable fields.

  ## Examples

      iex> WeaviateEx.Collections.update("Article", %{
      ...>   description: "Updated description"
      ...> })
      {:ok, %{"class" => "Article", ...}}
  """
  @spec update(collection_name(), collection_config(), Keyword.t()) :: WeaviateEx.api_response()
  def update(name, config, opts \\ []) do
    request_opts = Keyword.drop(opts, [:config_overrides])

    body =
      config
      |> merge_config(opts)
      |> Map.put("class", name)

    request(:put, "/v1/schema/#{name}", body, request_opts)
  end

  @doc """
  Deletes a collection and all its objects.

  **Warning**: This operation is irreversible and will delete all data
  in the collection.

  ## Examples

      iex> WeaviateEx.Collections.delete("Article")
      {:ok, %{}}
  """
  @spec delete(collection_name(), Keyword.t()) :: WeaviateEx.api_response()
  def delete(name, opts \\ []) do
    request(:delete, "/v1/schema/#{name}", nil, opts)
  end

  @doc """
  Adds a new property to an existing collection.

  ## Parameters

  - `collection_name` - The name of the collection
  - `property` - Property definition
  - `opts` - Additional options

  ## Property Definition

  - `:name` - Property name (required)
  - `:dataType` - Data type(s) (required, e.g., ["text"], ["int"], ["Article"])
  - `:description` - Human-readable description
  - `:moduleConfig` - Module-specific configuration
  - `:indexFilterable` - Whether to index for filtering (default: true)
  - `:indexSearchable` - Whether to index for searching (default: true)
  - `:tokenization` - Tokenization method for text (e.g., "word", "field")

  ## Examples

      iex> WeaviateEx.Collections.add_property("Article", %{
      ...>   name: "author",
      ...>   dataType: ["text"],
      ...>   description: "The article author"
      ...> })
      {:ok, %{"name" => "author", ...}}
  """
  @spec add_property(collection_name(), property(), Keyword.t()) :: WeaviateEx.api_response()
  def add_property(collection_name, property, opts \\ []) do
    request(:post, "/v1/schema/#{collection_name}/properties", property, opts)
  end

  @doc """
  Gets the shards for a collection.

  Shards are used in distributed setups to partition data.

  ## Examples

      iex> WeaviateEx.Collections.get_shards("Article")
      {:ok, [...]}
  """
  @spec get_shards(collection_name(), Keyword.t()) :: WeaviateEx.api_response()
  def get_shards(collection_name, opts \\ []) do
    path = "/v1/schema/#{collection_name}/shards" <> build_query_string(opts, [:tenant])
    request(:get, path, nil, opts)
  end

  @doc """
  Updates a shard status.

  ## Parameters

  - `collection_name` - The name of the collection
  - `shard_name` - The name of the shard
  - `status` - New status ("READY", "READONLY")
  - `opts` - Additional options

  ## Examples

      iex> WeaviateEx.Collections.update_shard("Article", "shard-1", "READONLY")
      {:ok, %{"status" => "READONLY"}}
  """
  @spec update_shard(collection_name(), String.t(), String.t(), Keyword.t()) ::
          WeaviateEx.api_response()
  def update_shard(collection_name, shard_name, status, opts \\ []) do
    body = %{"status" => status}

    path =
      "/v1/schema/#{collection_name}/shards/#{shard_name}" <> build_query_string(opts, [:tenant])

    request(:put, path, body, opts)
  end

  @doc """
  Gets tenants for a multi-tenant collection.

  ## Examples

      iex> WeaviateEx.Collections.get_tenants("Article")
      {:ok, [...]}
  """
  @spec get_tenants(collection_name(), Keyword.t()) :: WeaviateEx.api_response()
  def get_tenants(collection_name, opts \\ []) do
    request(:get, "/v1/schema/#{collection_name}/tenants", nil, opts)
  end

  @doc """
  Adds tenants to a multi-tenant collection.

  ## Examples

      iex> WeaviateEx.Collections.add_tenants("Article", [
      ...>   %{name: "tenant1"},
      ...>   %{name: "tenant2"}
      ...> ])
      {:ok, [...]}
  """
  @spec add_tenants(collection_name(), list(map()), Keyword.t()) :: WeaviateEx.api_response()
  def add_tenants(collection_name, tenants, opts \\ []) when is_list(tenants) do
    request(:post, "/v1/schema/#{collection_name}/tenants", tenants, opts)
  end

  @doc """
  Removes tenants from a multi-tenant collection.

  ## Examples

      iex> WeaviateEx.Collections.remove_tenants("Article", ["tenant1", "tenant2"])
      {:ok, %{}}
  """
  @spec remove_tenants(collection_name(), list(String.t()), Keyword.t()) ::
          WeaviateEx.api_response()
  def remove_tenants(collection_name, tenant_names, opts \\ []) when is_list(tenant_names) do
    request(:delete, "/v1/schema/#{collection_name}/tenants", tenant_names, opts)
  end

  @doc """
  Checks whether a collection exists.

  Returns `{:ok, true}` when the collection is present, `{:ok, false}` when the
  server returns a not-found response, or `{:error, %WeaviateEx.Error{}}` if another
  error occurs.
  """
  @spec exists?(collection_name(), Keyword.t()) :: {:ok, boolean()} | {:error, term()}
  def exists?(name, opts \\ []) do
    case request(:get, "/v1/schema/#{name}", nil, opts) do
      {:ok, _} -> {:ok, true}
      {:error, %WeaviateEx.Error{type: :not_found} = _error} -> {:ok, false}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Enable or disable multi-tenancy for a collection.

  ## Examples

      iex> WeaviateEx.Collections.set_multi_tenancy("Article", true)
      {:ok, %{"enabled" => true}}
  """
  @spec set_multi_tenancy(collection_name(), boolean(), Keyword.t()) ::
          WeaviateEx.api_response()
  def set_multi_tenancy(name, enabled, opts \\ []) when is_boolean(enabled) do
    action = if enabled, do: "enable", else: "disable"
    path = "/v1/schema/#{name}/multi-tenancy/#{action}"
    body = %{"enabled" => enabled}
    request(:post, path, body, opts)
  end

  @doc """
  Deletes all collections from the schema.

  This operation lists all collections and then deletes each one.
  Returns a result with the count of successfully deleted collections.

  **Warning**: This operation is irreversible and will delete all data
  in all collections.

  ## Options

  - All standard connection options (`:base_url`, `:api_key`, etc.)

  ## Return Value

  Returns `{:ok, keyword()}` with the following keys:
  - `:deleted_count` - Number of collections successfully deleted
  - `:failed_count` - Number of collections that failed to delete (only present if > 0)
  - `:failures` - List of failure details (only present if there were failures)

  ## Examples

      # Delete all collections
      {:ok, deleted_count: 3} = WeaviateEx.Collections.delete_all()

      # With partial failures
      {:ok, [deleted_count: 2, failed_count: 1, failures: [...]]} = WeaviateEx.Collections.delete_all()

      # Handle connection errors
      {:error, %WeaviateEx.Error{type: :connection_error}} = WeaviateEx.Collections.delete_all()
  """
  @spec delete_all(Keyword.t()) :: {:ok, keyword()} | {:error, WeaviateEx.Error.t()}
  def delete_all(opts \\ []) do
    case list(opts) do
      {:ok, %{"classes" => classes}} when is_list(classes) ->
        collection_names = Enum.map(classes, & &1["class"])
        {:ok, build_delete_result(collection_names, opts)}

      {:ok, _} ->
        {:ok, [deleted_count: 0]}

      {:error, error} ->
        {:error, error}
    end
  end

  defp build_delete_result(collection_names, opts) do
    results = Enum.map(collection_names, &delete_collection(&1, opts))

    deleted = Enum.count(results, &match?({:ok, _}, &1))
    failures = Enum.filter(results, &match?({:error, _, _}, &1))
    failed_count = length(failures)

    [deleted_count: deleted]
    |> maybe_add_failed_count(failed_count)
    |> maybe_add_failures(failures, failed_count)
  end

  defp delete_collection(collection_name, opts) do
    case delete(collection_name, opts) do
      {:ok, _} -> {:ok, collection_name}
      {:error, error} -> {:error, collection_name, error}
    end
  end

  defp maybe_add_failed_count(result, 0), do: result
  defp maybe_add_failed_count(result, count), do: Keyword.put(result, :failed_count, count)

  defp maybe_add_failures(result, _failures, 0), do: result

  defp maybe_add_failures(result, failures, _count) do
    failure_details =
      Enum.map(failures, fn {:error, name, error} ->
        [collection: name, error: error]
      end)

    Keyword.put(result, :failures, failure_details)
  end

  defp merge_config(config, opts) when is_map(config) do
    overrides =
      opts
      |> Keyword.get(:config_overrides, %{})
      |> normalize_map()

    config
    |> normalize_map()
    |> deep_merge(overrides)
  end

  defp merge_config(config, _opts), do: config

  defp deep_merge(map, overrides) when is_map(map) and is_map(overrides) do
    Map.merge(map, overrides, fn _key, left, right -> deep_merge(left, right) end)
  end

  defp deep_merge(_map, override), do: override

  defp normalize_map(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_map(value) ->
        {normalize_key(key), normalize_map(value)}

      {key, value} when is_list(value) ->
        {normalize_key(key), Enum.map(value, &normalize_collection_value/1)}

      {key, value} ->
        {normalize_key(key), value}
    end)
  end

  defp normalize_map(value), do: value

  defp normalize_collection_value(value) when is_map(value), do: normalize_map(value)
  defp normalize_collection_value(value), do: value

  defp normalize_key(key) when is_atom(key), do: Atom.to_string(key)
  defp normalize_key(key), do: key

  @doc """
  Insert multiple objects into a collection in a single batch operation.

  This is a convenience wrapper around batch insert that automatically
  adds the collection name to each object.

  ## Parameters

    - `collection_name` - Name of the collection
    - `objects` - List of property maps or object maps with optional `:uuid`, `:vector`
    - `opts` - Additional options

  ## Options

    - `:tenant` - Tenant name for multi-tenant collections
    - `:consistency_level` - Consistency level for the operation
    - `:return_summary` - Return a summary with success/failure counts

  ## Object Format

  Each object can be:
    - A simple properties map: `%{title: "My Article", content: "..."}`
    - A map with `:properties`, optional `:uuid`, `:vector`: `%{properties: %{...}, uuid: "..."}`

  ## Examples

      # Simple properties
      {:ok, result} = Collections.insert_many("Article", [
        %{title: "Article 1", content: "Content 1"},
        %{title: "Article 2", content: "Content 2"}
      ])

      # With custom UUIDs
      {:ok, result} = Collections.insert_many("Article", [
        %{properties: %{title: "Article 1"}, uuid: "custom-uuid-1"},
        %{properties: %{title: "Article 2"}, uuid: "custom-uuid-2"}
      ])

      # With tenant
      {:ok, result} = Collections.insert_many("Article", objects, tenant: "tenant-a")

      # Get summary
      {:ok, summary} = Collections.insert_many("Article", objects, return_summary: true)
  """
  @spec insert_many(collection_name(), list(map()), Keyword.t()) :: WeaviateEx.api_response()
  def insert_many(collection_name, objects, opts \\ []) when is_list(objects) do
    formatted_objects = format_batch_objects(collection_name, objects, opts)
    WeaviateEx.Batch.create_objects(formatted_objects, opts)
  end

  defp format_batch_objects(collection_name, objects, opts) do
    tenant = Keyword.get(opts, :tenant)
    Enum.map(objects, &format_single_batch_object(&1, collection_name, tenant))
  end

  defp format_single_batch_object(obj, collection_name, default_tenant) do
    %{class: collection_name}
    |> Map.put(:properties, extract_properties(obj))
    |> maybe_put_batch(:id, get_object_id(obj))
    |> maybe_put_batch(:vector, get_any_key(obj, [:vector, "vector"]))
    |> maybe_put_batch(:tenant, get_any_key(obj, [:tenant, "tenant"]) || default_tenant)
  end

  defp extract_properties(obj) do
    get_any_key(obj, [:properties, "properties"]) || obj
  end

  defp get_object_id(obj) do
    get_any_key(obj, [:uuid, "uuid", :id, "id"])
  end

  defp get_any_key(map, keys) do
    Enum.find_value(keys, fn key -> Map.get(map, key) end)
  end

  defp maybe_put_batch(map, _key, nil), do: map
  defp maybe_put_batch(map, key, value), do: Map.put(map, key, value)

  defp build_query_string(opts, allowed_keys) do
    params =
      opts
      |> Enum.filter(fn {key, _} -> key in allowed_keys end)
      |> Enum.map_join("&", fn {key, value} -> "#{key}=#{encode_query_value(value)}" end)

    if params == "", do: "", else: "?#{params}"
  end

  defp encode_query_value(value) when is_list(value) do
    value
    |> Enum.map_join(",", &to_string/1)
    |> URI.encode_www_form()
  end

  defp encode_query_value(value) do
    value
    |> to_string()
    |> URI.encode_www_form()
  end
end
