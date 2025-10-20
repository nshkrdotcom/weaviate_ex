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

  defp build_query_string(opts, allowed_keys) do
    params =
      opts
      |> Enum.filter(fn {key, _} -> key in allowed_keys end)
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
end
