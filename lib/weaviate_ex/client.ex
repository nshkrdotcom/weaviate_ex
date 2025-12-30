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

  alias WeaviateEx.Auth.TokenManager
  alias WeaviateEx.Client.{Config, State}
  alias WeaviateEx.Config.Connection
  alias WeaviateEx.Config.Proxy
  alias WeaviateEx.Config.Timeout
  alias WeaviateEx.Error
  alias WeaviateEx.GRPC.Channel
  alias WeaviateEx.GRPC.Services.Health, as: GRPCHealth
  alias WeaviateEx.Protocol
  alias WeaviateEx.Version

  @type t :: %__MODULE__{
          config: Config.t(),
          grpc_channel: GRPC.Channel.t() | nil,
          protocol_impl: module(),
          state: State.t()
        }

  defstruct [:config, :grpc_channel, :protocol_impl, :state]

  @doc """
  Connect to a Weaviate instance.

  Establishes both gRPC channel (for data operations) and HTTP client
  (for schema operations).

  ## Options

    * `:base_url` - HTTP base URL (default: "http://localhost:8080")
    * `:grpc_host` - gRPC host (default: derived from base_url)
    * `:grpc_port` - gRPC port (default: 50051, or 443 for HTTPS)
    * `:api_key` - API key for authentication
    * `:auth` - Authentication config (`WeaviateEx.Auth`) for API key, bearer token, or OIDC
    * `:timeout` - Connection timeout in milliseconds (default: 30000)
    * `:skip_grpc` - Skip gRPC connection (use HTTP only)
    * `:skip_init_checks` - Skip meta/version/gRPC health checks (default: false)
    * `:connection` - Connection pool settings (`WeaviateEx.Config.Connection` or keyword list)
    * `:proxy` - Proxy settings (`WeaviateEx.Config.Proxy`, keyword list, or `:env`)

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
    skip_init_checks = Keyword.get(opts, :skip_init_checks, false)

    protocol_impl =
      Keyword.get(opts, :protocol_impl) ||
        Application.get_env(:weaviate_ex, :protocol_impl) ||
        WeaviateEx.Protocol.HTTP.Client

    with {:ok, config} <- maybe_start_token_manager(config, opts),
         {:ok, config} <- maybe_start_finch(config),
         {:ok, grpc_channel} <- maybe_connect_grpc(config, skip_grpc, opts) do
      state = State.new() |> State.connected()

      client = %__MODULE__{
        config: config,
        grpc_channel: grpc_channel,
        protocol_impl: protocol_impl,
        state: state
      }

      case maybe_run_init_checks(client, skip_init_checks, skip_grpc, opts) do
        :ok ->
          {:ok, client}

        {:error, error} ->
          cleanup_resources(config, grpc_channel)
          {:error, error}
      end
    else
      {:error, error} ->
        cleanup_resources(config, nil)
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

    state = State.new() |> State.connected()

    client = %__MODULE__{
      config: config,
      grpc_channel: nil,
      protocol_impl: protocol_impl,
      state: state
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
    Channel.build_metadata(%{
      api_key: config.api_key,
      auth: config.auth,
      token_manager: config.token_manager,
      additional_headers: config.additional_headers
    })
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
    request(client, :post, "/v1/graphql", %{"query" => query}, [])
  end

  ## Lifecycle Management

  @doc """
  Close the client and release all connections.

  This marks the client as closed and disconnects any active connections.
  Once closed, a client cannot be reused - create a new client instead.

  ## Examples

      :ok = Client.close(client)
  """
  @spec close(t()) :: :ok
  def close(%__MODULE__{state: %State{status: :closed}}), do: :ok

  def close(%__MODULE__{} = client) do
    # Disconnect gRPC channel if present
    disconnect(client)

    maybe_stop_token_manager(client.config)
    maybe_stop_finch(client.config)

    # Update client state (note: since structs are immutable, we use process dictionary)
    # In a real application, you might want to use ETS or another mechanism
    key = client_state_key(client)
    Process.put(key, State.closed(client.state))

    :ok
  end

  @doc """
  Check if client has been closed.

  ## Examples

      false = Client.closed?(client)
      Client.close(client)
      true = Client.closed?(client)
  """
  @spec closed?(t()) :: boolean()
  def closed?(%__MODULE__{state: %State{status: :closed}}), do: true

  def closed?(%__MODULE__{} = client) do
    key = client_state_key(client)

    case Process.get(key) do
      %State{status: :closed} -> true
      _ -> false
    end
  end

  @doc """
  Get current client status.

  Returns one of:
  - `:initializing` - Client is being set up
  - `:connected` - Client is connected and ready
  - `:disconnected` - Client is disconnected but not closed
  - `:closed` - Client has been closed and cannot be reused

  ## Examples

      :connected = Client.status(client)
  """
  @spec status(t()) :: State.status()
  def status(%__MODULE__{} = client) do
    if closed?(client) do
      :closed
    else
      client.state.status
    end
  end

  @doc """
  Get client statistics.

  Returns state information including request counts, error counts,
  and timestamps.

  ## Examples

      stats = Client.stats(client)
      IO.puts("Requests: \#{stats.request_count}")
  """
  @spec stats(t()) :: State.t()
  def stats(%__MODULE__{} = client) do
    key = client_state_key(client)

    case Process.get(key) do
      nil -> client.state
      state -> state
    end
  end

  @doc """
  Execute a function with an auto-managed client.

  Creates a client, executes the function, and ensures cleanup even if
  the function raises an error.

  ## Examples

      result = Client.with_client([base_url: url], fn client ->
        WeaviateEx.Objects.list(client, "Article")
      end)
  """
  @spec with_client(keyword(), (t() -> result)) :: result when result: term()
  def with_client(opts, fun) when is_function(fun, 1) do
    # new/1 always succeeds, so we can directly pattern match
    {:ok, client} = new(opts)

    try do
      fun.(client)
    after
      close(client)
    end
  end

  # Private helpers

  defp client_state_key(%__MODULE__{config: config}) do
    # Use base_url as part of the key to distinguish clients
    {:weaviate_client_state, config.base_url}
  end

  defp maybe_start_token_manager(%Config{token_manager: token_manager} = config, _opts)
       when not is_nil(token_manager) do
    {:ok, config}
  end

  defp maybe_start_token_manager(%Config{auth: %{type: type}} = config, opts)
       when type in [:oidc_client_credentials, :oidc_password] do
    issuer_url = oidc_issuer_url_from_opts(opts, config.base_url)
    oidc_config = Keyword.get(opts, :oidc_config)

    token_opts =
      if oidc_config do
        [oidc_config: oidc_config, auth: config.auth]
      else
        [issuer_url: issuer_url, auth: config.auth]
      end

    case TokenManager.start_link(token_opts) do
      {:ok, pid} ->
        {:ok, %{config | token_manager: pid, token_manager_owner: true}}

      {:error, reason} ->
        {:error,
         Error.exception(
           type: :authentication_failed,
           message: "Failed to start OIDC token manager: #{inspect(reason)}"
         )}
    end
  end

  defp maybe_start_token_manager(%Config{} = config, _opts), do: {:ok, config}

  defp oidc_issuer_url_from_opts(opts, base_url) do
    case Keyword.get(opts, :auth) do
      %{issuer_url: issuer_url} when is_binary(issuer_url) ->
        issuer_url

      _ ->
        Keyword.get(opts, :oidc_issuer_url) ||
          Keyword.get(opts, :issuer_url) ||
          default_oidc_issuer_url(base_url)
    end
  end

  defp default_oidc_issuer_url(base_url) do
    String.trim_trailing(base_url, "/") <> "/v1"
  end

  defp maybe_start_finch(%Config{finch_name: finch_name} = config)
       when finch_name != WeaviateEx.Finch do
    {:ok, config}
  end

  defp maybe_start_finch(%Config{} = config) do
    if needs_custom_finch?(config) do
      start_custom_finch(config)
    else
      {:ok, config}
    end
  end

  defp needs_custom_finch?(%Config{connection: nil, proxy: nil}), do: false

  defp needs_custom_finch?(%Config{connection: connection, proxy: proxy}) do
    not is_nil(connection) or proxy_requires_finch?(proxy)
  end

  defp proxy_requires_finch?(nil), do: false

  defp proxy_requires_finch?(proxy) do
    Proxy.to_finch_opts(proxy) != []
  end

  defp start_custom_finch(%Config{} = config) do
    finch_name = :"weaviate_ex_finch_#{System.unique_integer([:positive])}"
    pool_opts = build_finch_pool_opts(config)

    case Finch.start_link(name: finch_name, pools: %{default: pool_opts}) do
      {:ok, _pid} ->
        {:ok, %{config | finch_name: finch_name, finch_owner: true}}

      {:error, {:already_started, _pid}} ->
        {:ok, %{config | finch_name: finch_name, finch_owner: false}}

      {:error, reason} ->
        {:error,
         Error.exception(
           type: :connection_error,
           message: "Failed to start Finch pool: #{inspect(reason)}"
         )}
    end
  end

  defp build_finch_pool_opts(%Config{connection: connection, proxy: proxy}) do
    connection = connection || Connection.new()
    pool_opts = Connection.to_finch_opts(connection)

    base_opts =
      pool_opts
      |> Keyword.take([:size, :count, :conn_max_idle_time])

    proxy_opts =
      case proxy do
        nil -> []
        _ -> Proxy.to_finch_opts(proxy)
      end

    if proxy_opts == [] do
      base_opts
    else
      Keyword.put(base_opts, :conn_opts, proxy_opts)
    end
  end

  defp maybe_connect_grpc(_config, true, _opts), do: {:ok, nil}

  defp maybe_connect_grpc(%Config{} = config, false, opts) do
    grpc_config = %{
      grpc_host: config.grpc_host,
      grpc_port: config.grpc_port,
      api_key: config.api_key,
      tls: Config.use_tls?(config),
      max_message_size: config.grpc_max_message_size,
      connection: config.connection,
      proxy: config.proxy,
      auth: config.auth,
      token_manager: config.token_manager,
      additional_headers: config.additional_headers
    }

    timeout = Keyword.get(opts, :timeout, 30_000)
    Channel.connect(grpc_config, timeout: timeout)
  end

  defp maybe_run_init_checks(_client, true, _skip_grpc, _opts), do: :ok

  defp maybe_run_init_checks(%__MODULE__{} = client, false, skip_grpc, _opts) do
    timeout = init_timeout(client.config)

    with :ok <- maybe_wait_for_token(client.config, timeout),
         {:ok, meta} <- request(client, :get, "/v1/meta", nil, timeout: timeout),
         :ok <- validate_server_version(meta) do
      maybe_check_grpc(client, meta, skip_grpc, timeout)
    end
  end

  defp init_timeout(%Config{timeout_config: %Timeout{} = timeout_config}) do
    Timeout.for_method(timeout_config, :init)
  end

  defp init_timeout(%Config{}), do: Timeout.for_method(Timeout.new(), :init)

  defp maybe_wait_for_token(%Config{token_manager: nil}, _timeout), do: :ok

  defp maybe_wait_for_token(%Config{token_manager: token_manager}, timeout)
       when not is_nil(token_manager) do
    wait_for_access_token(token_manager, timeout)
  end

  defp wait_for_access_token(token_manager, timeout) do
    deadline = System.monotonic_time(:millisecond) + timeout
    do_wait_for_access_token(token_manager, deadline)
  end

  defp do_wait_for_access_token(token_manager, deadline) do
    case TokenManager.get_access_token(token_manager) do
      {:ok, _access_token} ->
        :ok

      {:error, :no_token} ->
        if System.monotonic_time(:millisecond) < deadline do
          Process.sleep(50)
          do_wait_for_access_token(token_manager, deadline)
        else
          {:error,
           Error.exception(
             type: :authentication_failed,
             message: "OIDC access token not available"
           )}
        end
    end
  end

  defp validate_server_version(meta) do
    case Version.check_compatibility(meta) do
      :ok ->
        :ok

      {:error, message} ->
        {:error, Error.exception(type: :version_error, message: message)}
    end
  end

  defp maybe_check_grpc(%__MODULE__{grpc_channel: nil}, _meta, _skip_grpc, _timeout), do: :ok

  defp maybe_check_grpc(_client, _meta, true, _timeout), do: :ok

  defp maybe_check_grpc(%__MODULE__{grpc_channel: channel}, meta, _skip_grpc, timeout) do
    case Version.get_server_version(meta) do
      {:ok, version} ->
        check_grpc_version_and_health(channel, version, timeout)

      _ ->
        :ok
    end
  end

  defp check_grpc_version_and_health(channel, version, timeout) do
    if Version.supports_grpc?(version) do
      check_grpc_health(channel, timeout)
    else
      {:error,
       Error.exception(
         type: :version_error,
         message:
           "Weaviate server version #{Version.format_version(version)} does not support gRPC (requires #{Version.format_version(Version.grpc_minimum_version())}+)"
       )}
    end
  end

  defp check_grpc_health(channel, timeout) do
    case GRPCHealth.check(channel, timeout: timeout) do
      {:ok, :serving} -> :ok
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  defp cleanup_resources(config, grpc_channel) do
    if grpc_channel do
      Channel.disconnect(grpc_channel)
    end

    maybe_stop_token_manager(config)
    maybe_stop_finch(config)
  end

  defp maybe_stop_token_manager(%Config{token_manager_owner: true, token_manager: token_manager})
       when is_pid(token_manager) do
    if Process.alive?(token_manager) do
      GenServer.stop(token_manager)
    end

    :ok
  end

  defp maybe_stop_token_manager(%Config{token_manager_owner: true, token_manager: token_manager})
       when is_atom(token_manager) do
    if Process.whereis(token_manager) do
      GenServer.stop(token_manager)
    end

    :ok
  end

  defp maybe_stop_token_manager(_), do: :ok

  defp maybe_stop_finch(%Config{finch_owner: true, finch_name: finch_name})
       when is_atom(finch_name) do
    if Process.whereis(finch_name) do
      Supervisor.stop(finch_name)
    end

    :ok
  end

  defp maybe_stop_finch(_), do: :ok
end
