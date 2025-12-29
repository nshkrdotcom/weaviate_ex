defmodule WeaviateEx.Client do
  @moduledoc """
  WeaviateEx client with hybrid gRPC/HTTP support.

  The client uses:
  - **gRPC** for data operations (search, batch, aggregate, tenants)
  - **HTTP** for schema operations (collections management)

  This hybrid approach is necessary because Weaviate's gRPC API doesn't
  include schema management operations.

  ## Usage

      # Connect to local Weaviate
      {:ok, client} = WeaviateEx.Client.connect(base_url: "http://localhost:8080")

      # Connect to Weaviate Cloud
      {:ok, client} = WeaviateEx.Client.connect(
        base_url: "https://my-cluster.weaviate.network",
        api_key: "your-api-key"
      )

      # Use the client
      {:ok, results} = WeaviateEx.Query.near_text(client, "Article", "machine learning")

      # Disconnect when done
      :ok = WeaviateEx.Client.disconnect(client)
  """

  alias WeaviateEx.Client.Config
  alias WeaviateEx.Error
  alias WeaviateEx.GRPC.Channel
  alias WeaviateEx.Protocol

  @type t :: %__MODULE__{
          config: Config.t(),
          grpc_channel: GRPC.Channel.t() | nil,
          protocol_impl: module()
        }

  defstruct [:config, :grpc_channel, :protocol_impl]

  @doc """
  Connect to a Weaviate instance.

  Establishes both gRPC channel (for data operations) and HTTP client
  (for schema operations).

  ## Options

    * `:base_url` - HTTP base URL (default: "http://localhost:8080")
    * `:grpc_host` - gRPC host (default: derived from base_url)
    * `:grpc_port` - gRPC port (default: 50051, or 443 for HTTPS)
    * `:api_key` - API key for authentication
    * `:timeout` - Connection timeout in milliseconds (default: 30000)
    * `:skip_grpc` - Skip gRPC connection (use HTTP only)

  ## Examples

      {:ok, client} = WeaviateEx.Client.connect(
        base_url: "http://localhost:8080",
        api_key: "secret-key"
      )
  """
  @spec connect(keyword()) :: {:ok, t()} | {:error, Error.t()}
  def connect(opts \\ []) do
    config = Config.new(opts)
    skip_grpc = Keyword.get(opts, :skip_grpc, false)

    protocol_impl =
      Keyword.get(opts, :protocol_impl) ||
        Application.get_env(:weaviate_ex, :protocol_impl) ||
        WeaviateEx.Protocol.HTTP.Client

    # Establish gRPC channel unless skipped
    grpc_result =
      if skip_grpc do
        {:ok, nil}
      else
        grpc_config = %{
          grpc_host: config.grpc_host,
          grpc_port: config.grpc_port,
          api_key: config.api_key,
          tls: Config.use_tls?(config),
          max_message_size: config.grpc_max_message_size
        }

        timeout = Keyword.get(opts, :timeout, 30_000)
        Channel.connect(grpc_config, timeout: timeout)
      end

    case grpc_result do
      {:ok, grpc_channel} ->
        client = %__MODULE__{
          config: config,
          grpc_channel: grpc_channel,
          protocol_impl: protocol_impl
        }

        {:ok, client}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Create a new client without establishing connections.

  This is a lightweight alternative to `connect/1` that doesn't establish
  the gRPC channel upfront. Useful for testing or when you need to
  configure the client before connecting.

  ## Examples

      {:ok, client} = WeaviateEx.Client.new(
        base_url: "http://localhost:8080",
        api_key: "secret-key"
      )
  """
  @spec new(keyword()) :: {:ok, t()}
  def new(opts \\ []) do
    config = Config.new(opts)

    protocol_impl =
      Keyword.get(opts, :protocol_impl) ||
        Application.get_env(:weaviate_ex, :protocol_impl) ||
        WeaviateEx.Protocol.HTTP.Client

    client = %__MODULE__{
      config: config,
      grpc_channel: nil,
      protocol_impl: protocol_impl
    }

    {:ok, client}
  end

  @doc """
  Disconnect the client.

  Closes the gRPC channel if one is established.

  ## Examples

      :ok = WeaviateEx.Client.disconnect(client)
  """
  @spec disconnect(t()) :: :ok
  def disconnect(%__MODULE__{grpc_channel: nil}), do: :ok

  def disconnect(%__MODULE__{grpc_channel: channel}) do
    Channel.disconnect(channel)
  end

  @doc """
  Check if the client has an active gRPC connection.

  ## Examples

      true = WeaviateEx.Client.grpc_connected?(client)
  """
  @spec grpc_connected?(t()) :: boolean()
  def grpc_connected?(%__MODULE__{grpc_channel: nil}), do: false

  def grpc_connected?(%__MODULE__{grpc_channel: channel}) do
    Channel.connected?(channel)
  end

  @doc """
  Get the gRPC channel from the client.

  Returns `nil` if no gRPC channel is established.

  ## Examples

      channel = WeaviateEx.Client.grpc_channel(client)
  """
  @spec grpc_channel(t()) :: GRPC.Channel.t() | nil
  def grpc_channel(%__MODULE__{grpc_channel: channel}), do: channel

  @doc """
  Make an HTTP request using the configured protocol.

  Used for schema/collection operations which don't have gRPC equivalents.

  ## Examples

      {:ok, response} = WeaviateEx.Client.request(client, :get, "/v1/schema", nil, [])
  """
  @spec request(t(), Protocol.method(), Protocol.path(), Protocol.body(), Protocol.opts()) ::
          Protocol.response()
  def request(%__MODULE__{protocol_impl: impl} = client, method, path, body, opts) do
    impl.request(client, method, path, body, opts)
  end

  @doc """
  Build gRPC metadata from client config.

  Includes authorization header if API key is set.

  ## Examples

      metadata = WeaviateEx.Client.grpc_metadata(client)
  """
  @spec grpc_metadata(t()) :: map()
  def grpc_metadata(%__MODULE__{config: config}) do
    Channel.build_metadata(%{api_key: config.api_key})
  end

  @doc """
  Execute a GraphQL query against Weaviate.

  Used for queries that require GraphQL features not available in gRPC,
  such as generative search.

  ## Examples

      {:ok, response} = WeaviateEx.Client.graphql(client, "{ Get { Article { title } } }")
  """
  @spec graphql(t(), String.t()) :: Protocol.response()
  def graphql(%__MODULE__{} = client, query) when is_binary(query) do
    request(client, :post, "/v1/graphql", %{query: query}, [])
  end
end
