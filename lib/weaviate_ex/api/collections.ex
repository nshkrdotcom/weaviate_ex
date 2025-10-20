defmodule WeaviateEx.API.Collections do
  @moduledoc """
  Collection (schema) management API.
  """

  alias WeaviateEx.Client
  alias WeaviateEx.Error

  @type opts :: keyword()

  @doc """
  List all collections.

  ## Examples

      {:ok, collections} = WeaviateEx.API.Collections.list(client)
      ["Article", "Author"]

  ## Returns

    * `{:ok, [String.t()]}` - List of collection names
    * `{:error, Error.t()}` - Error if request fails
  """
  @spec list(Client.t()) :: {:ok, [String.t()]} | {:error, Error.t()}
  def list(client) do
    case Client.request(client, :get, "/v1/schema", nil, []) do
      {:ok, %{"classes" => classes}} when is_list(classes) ->
        names = Enum.map(classes, & &1["class"])
        {:ok, names}

      {:ok, %{"classes" => _}} ->
        {:ok, []}

      {:ok, _} ->
        {:ok, []}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Get a specific collection configuration.

  ## Examples

      {:ok, config} = WeaviateEx.API.Collections.get(client, "Article")

  ## Returns

    * `{:ok, map()}` - Collection configuration
    * `{:error, Error.t()}` - Error if not found
  """
  @spec get(Client.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def get(client, collection_name) do
    Client.request(client, :get, "/v1/schema/#{collection_name}", nil, [])
  end

  @doc """
  Create a new collection.

  ## Examples

      config = %{
        "class" => "Article",
        "vectorizer" => "text2vec-openai",
        "properties" => [
          %{"name" => "title", "dataType" => ["text"]}
        ]
      }
      {:ok, created} = WeaviateEx.API.Collections.create(client, config)

  ## Returns

    * `{:ok, map()}` - Created collection config
    * `{:error, Error.t()}` - Error if validation fails or exists
  """
  @spec create(Client.t(), map(), opts()) :: {:ok, map()} | {:error, Error.t()}
  def create(client, config, opts \\ []) do
    request_opts = Keyword.drop(opts, [:config_overrides])
    payload = merge_config(config, opts)
    Client.request(client, :post, "/v1/schema", payload, request_opts)
  end

  @doc "Delete a collection"
  @spec delete(Client.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def delete(client, collection_name) do
    Client.request(client, :delete, "/v1/schema/#{collection_name}", nil, [])
  end

  @doc "Update a collection"
  @spec update(Client.t(), String.t(), map(), opts()) :: {:ok, map()} | {:error, Error.t()}
  def update(client, collection_name, updates, opts \\ []) do
    request_opts = Keyword.drop(opts, [:config_overrides])
    payload = merge_config(updates, opts)
    Client.request(client, :put, "/v1/schema/#{collection_name}", payload, request_opts)
  end

  @doc "Add property to collection"
  @spec add_property(Client.t(), String.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def add_property(client, collection_name, property) do
    Client.request(client, :post, "/v1/schema/#{collection_name}/properties", property, [])
  end

  @doc "Check if collection exists"
  @spec exists?(Client.t(), String.t()) :: {:ok, boolean()}
  def exists?(client, collection_name) do
    case get(client, collection_name) do
      {:ok, _} -> {:ok, true}
      {:error, %Error{type: :not_found}} -> {:ok, false}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Delete all collections.

  ## Examples

      {:ok, result} = WeaviateEx.API.Collections.delete_all(client)
      # => {:ok, deleted_count: 5}

  ## Returns

    * `{:ok, keyword()}` - Result with deleted_count and optionally failed_count and failures
    * `{:error, Error.t()}` - Error if listing collections fails
  """
  @spec delete_all(Client.t()) :: {:ok, keyword()} | {:error, Error.t()}
  def delete_all(client) do
    case list(client) do
      {:ok, collections} ->
        results =
          Enum.map(collections, fn collection_name ->
            case delete(client, collection_name) do
              {:ok, _} -> {:ok, collection_name}
              {:error, error} -> {:error, collection_name, error}
            end
          end)

        deleted = Enum.count(results, &match?({:ok, _}, &1))
        failures = Enum.filter(results, &match?({:error, _, _}, &1))
        failed_count = length(failures)

        result = [deleted_count: deleted]

        result =
          if failed_count > 0, do: Keyword.put(result, :failed_count, failed_count), else: result

        result =
          if failed_count > 0 do
            failure_details =
              Enum.map(failures, fn {:error, name, error} ->
                [collection: name, error: error]
              end)

            Keyword.put(result, :failures, failure_details)
          else
            result
          end

        {:ok, result}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Enable or disable multi-tenancy for a collection.

  Returns the updated multi-tenancy configuration from the server.
  """
  @spec set_multi_tenancy(Client.t(), String.t(), boolean(), opts()) ::
          {:ok, map()} | {:error, Error.t()}
  def set_multi_tenancy(client, collection_name, enabled, opts \\ []) when is_boolean(enabled) do
    action = if enabled, do: "enable", else: "disable"
    path = "/v1/schema/#{collection_name}/multi-tenancy/#{action}"
    body = %{"enabled" => enabled}
    Client.request(client, :post, path, body, opts)
  end

  @doc """
  Retrieve shard information for a collection.

  Supports tenant-aware inspection by passing `tenant: "tenant-name"` in options.
  """
  @spec get_shards(Client.t(), String.t(), opts()) :: {:ok, list()} | {:error, Error.t()}
  def get_shards(client, collection_name, opts \\ []) do
    path = build_path("/v1/schema/#{collection_name}/shards", opts, [:tenant])
    Client.request(client, :get, path, nil, opts)
  end

  defp merge_config(config, opts) when is_map(config) do
    overrides =
      opts
      |> Keyword.get(:config_overrides, %{})
      |> normalize_value()

    deep_merge(normalize_value(config), overrides)
  end

  defp merge_config(config, _opts), do: config

  defp deep_merge(map, overrides) when is_map(map) and is_map(overrides) do
    Map.merge(map, overrides, fn _key, left, right -> deep_merge(left, right) end)
  end

  defp deep_merge(_map, override), do: override

  defp build_path(base, opts, allowed_keys) do
    query =
      opts
      |> Enum.filter(fn {key, _} -> key in allowed_keys end)
      |> Enum.map(&encode_param/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.join("&")

    if query == "", do: base, else: base <> "?" <> query
  end

  defp encode_param({key, value}) do
    encoded_value =
      value
      |> normalize_value()
      |> encode_value()

    "#{key}=#{encoded_value}"
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

  defp normalize_value(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_map(value) ->
        {normalize_key(key), normalize_value(value)}

      {key, value} when is_list(value) ->
        {normalize_key(key), Enum.map(value, &normalize_value/1)}

      {key, value} ->
        {normalize_key(key), value}
    end)
  end

  defp normalize_value(value), do: value

  defp normalize_key(key) when is_atom(key), do: Atom.to_string(key)
  defp normalize_key(key), do: key
end
