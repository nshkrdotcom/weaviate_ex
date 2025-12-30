defmodule WeaviateEx.Debug do
  @moduledoc """
  Debug utilities for troubleshooting Weaviate operations.

  Provides REST-based object retrieval for comparison with gRPC results,
  request/response logging, and diagnostic helpers.

  ## Features

  - **Protocol Comparison**: Compare objects retrieved via REST vs gRPC
  - **Request Logging**: Track all requests for debugging
  - **Connection Info**: Inspect current connection state

  ## Example

      # Compare REST and gRPC responses
      {:ok, result} = Debug.compare_protocols(client, "Article", uuid)
      if result.match do
        IO.puts("Responses match!")
      else
        IO.puts(Debug.ObjectCompare.format_diff(result.differences))
      end

      # Get connection details
      {:ok, info} = Debug.connection_info(client)
      IO.puts("Connected to: \#{info.base_url}")
  """

  alias WeaviateEx.Client
  alias WeaviateEx.Client.Config, as: ClientConfig
  alias WeaviateEx.Debug.ObjectCompare
  alias WeaviateEx.Error
  alias WeaviateEx.GRPC.Channel
  alias WeaviateEx.GRPC.Services.Search, as: GRPCSearch

  @type client :: Client.t()
  @type uuid :: String.t()
  @type collection :: String.t()

  @type connection_info :: %{
          base_url: String.t(),
          grpc_host: String.t(),
          grpc_port: non_neg_integer(),
          grpc_connected: boolean(),
          tls_enabled: boolean(),
          api_key_configured: boolean()
        }

  @type comparison_result :: ObjectCompare.comparison_result()

  @doc """
  Retrieve object via REST API (bypasses gRPC for comparison).

  ## Parameters

    * `client` - WeaviateEx client
    * `collection` - Collection name
    * `uuid` - Object UUID
    * `opts` - Options:
      * `:tenant` - Tenant name for multi-tenant collections
      * `:include` - List of additional fields to include (e.g., ["vector"])
      * `:node_name` - Target node for debug reads in clustered setups
      * `:consistency_level` - Read consistency level (e.g., "ONE", "QUORUM", "ALL")

  ## Example

      {:ok, object} = Debug.get_object_rest(client, "Article", uuid)
      {:ok, object} = Debug.get_object_rest(client, "Article", uuid, tenant: "tenant-a")
  """
  @spec get_object_rest(client(), collection(), uuid(), keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def get_object_rest(client, collection, uuid, opts \\ []) do
    path = build_object_path(collection, uuid, opts)

    case client.protocol_impl.request(client, :get, path, nil, opts) do
      {:ok, object} -> {:ok, object}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Retrieve object via gRPC API.

  ## Parameters

    * `client` - WeaviateEx client
    * `collection` - Collection name
    * `uuid` - Object UUID
    * `opts` - Options:
      * `:tenant` - Tenant name for multi-tenant collections
      * `:include` - List of additional fields to include

  ## Example

      {:ok, object} = Debug.get_object_grpc(client, "Article", uuid)
  """
  @spec get_object_grpc(client(), collection(), uuid(), keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def get_object_grpc(client, collection, uuid, opts \\ []) do
    case client.grpc_channel do
      nil ->
        {:error, Error.exception(type: :connection_error, message: "No gRPC channel available")}

      channel ->
        get_object_via_grpc(channel, client, collection, uuid, opts)
    end
  end

  @doc """
  Fetch object via both protocols and compare results.

  Returns a comparison result showing whether the objects match and
  detailing any differences found.

  ## Parameters

    * `client` - WeaviateEx client
    * `collection` - Collection name
    * `uuid` - Object UUID
    * `opts` - Options passed to both REST and gRPC calls

  ## Example

      {:ok, result} = Debug.compare_protocols(client, "Article", uuid)
      if result.match do
        IO.puts("Objects are identical")
      else
        IO.puts(ObjectCompare.format_diff(result.differences))
      end
  """
  @spec compare_protocols(client(), collection(), uuid(), keyword()) ::
          {:ok, comparison_result()} | {:error, Error.t()}
  def compare_protocols(client, collection, uuid, opts \\ []) do
    with {:ok, rest_object} <- get_object_rest(client, collection, uuid, opts),
         {:ok, grpc_object} <- get_object_grpc(client, collection, uuid, opts) do
      {:ok, ObjectCompare.compare(rest_object, grpc_object)}
    else
      {:error, %Error{type: :connection_error} = error} ->
        # If gRPC is unavailable, try to return partial comparison
        case get_object_rest(client, collection, uuid, opts) do
          {:ok, rest_object} ->
            {:ok,
             %{
               match: false,
               rest_object: rest_object,
               grpc_object: nil,
               differences: [
                 %{
                   path: ["*"],
                   rest_value: "available",
                   grpc_value: "unavailable (#{error.message})"
                 }
               ]
             }}

          {:error, rest_error} ->
            {:error, rest_error}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Get current connection state and configuration.

  Returns information about the client's connection including:
    * HTTP base URL
    * gRPC host and port
    * Whether gRPC is connected
    * TLS status
    * API key configuration status

  ## Example

      {:ok, info} = Debug.connection_info(client)
      IO.puts("Base URL: \#{info.base_url}")
      IO.puts("gRPC connected: \#{info.grpc_connected}")
  """
  @spec connection_info(client()) :: {:ok, connection_info()} | {:error, Error.t()}
  def connection_info(client) do
    config = client.config

    grpc_connected =
      case client.grpc_channel do
        nil -> false
        channel -> Channel.connected?(channel)
      end

    info = %{
      base_url: config.base_url,
      grpc_host: config.grpc_host,
      grpc_port: config.grpc_port,
      grpc_connected: grpc_connected,
      tls_enabled: ClientConfig.use_tls?(config),
      api_key_configured: config.api_key != nil and config.api_key != ""
    }

    {:ok, info}
  end

  # Private functions

  defp build_object_path(collection, uuid, opts) do
    base_path = "/v1/objects/#{collection}/#{uuid}"

    query_params =
      opts
      |> Keyword.take([:tenant, :include, :node_name, :consistency_level])
      |> Enum.map(fn
        {:tenant, tenant} ->
          "tenant=#{tenant}"

        {:include, include} when is_list(include) ->
          "include=#{Enum.join(include, ",")}"

        {:include, include} ->
          "include=#{include}"

        {:node_name, node_name} ->
          "node_name=#{node_name}"

        {:consistency_level, consistency_level} ->
          "consistency_level=#{consistency_level}"
      end)

    if query_params == [] do
      base_path
    else
      base_path <> "?" <> Enum.join(query_params, "&")
    end
  end

  defp get_object_via_grpc(channel, client, collection, uuid, opts) do
    # Build gRPC search request to get object by ID
    tenant = Keyword.get(opts, :tenant)
    metadata = Channel.build_metadata(client.config)

    request = %{
      collection: collection,
      filters: %{
        operator: :equal,
        path: ["id"],
        value_text: uuid
      },
      limit: 1,
      tenant: tenant
    }

    # Use the Search service to query by ID
    case GRPCSearch.search(channel, collection, request, metadata: metadata) do
      {:ok, %{results: [result | _]}} ->
        {:ok, grpc_result_to_object(result, collection)}

      {:ok, %{results: []}} ->
        {:error, Error.exception(type: :not_found, message: "Object not found")}

      {:error, error} ->
        {:error, error}
    end
  rescue
    _ ->
      {:error, Error.exception(type: :connection_error, message: "gRPC call failed")}
  end

  defp grpc_result_to_object(result, collection) do
    %{
      "id" => Map.get(result, :uuid),
      "class" => collection,
      "properties" => Map.get(result, :properties, %{}),
      "vector" => Map.get(result, :vector)
    }
  end
end
