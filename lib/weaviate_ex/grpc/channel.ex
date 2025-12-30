defmodule WeaviateEx.GRPC.Channel do
  @moduledoc """
  Manages gRPC channel connections to Weaviate server.

  This module provides functions for establishing, managing, and disconnecting
  gRPC channels to Weaviate's gRPC endpoint.

  ## Usage

      config = %{
        grpc_host: "localhost",
        grpc_port: 50051,
        api_key: "your-api-key"
      }

      {:ok, channel} = WeaviateEx.GRPC.Channel.connect(config)

      # Use the channel for RPC calls...

      :ok = WeaviateEx.GRPC.Channel.disconnect(channel)
  """

  alias WeaviateEx.Error

  @default_timeout 30_000
  # 100MB
  @default_max_message_size 104_858_000

  alias WeaviateEx.Auth.TokenManager

  @type config :: %{
          required(:grpc_host) => String.t(),
          required(:grpc_port) => non_neg_integer(),
          required(:api_key) => String.t() | nil,
          optional(:tls) => boolean(),
          optional(:max_message_size) => non_neg_integer(),
          optional(:auth) => WeaviateEx.Auth.t() | nil,
          optional(:token_manager) => GenServer.server() | nil,
          optional(:additional_headers) => map(),
          optional(:connection) => WeaviateEx.Config.Connection.t() | nil,
          optional(:proxy) => WeaviateEx.Config.Proxy.t() | nil
        }

  @doc """
  Establishes a gRPC channel connection to the Weaviate server.

  ## Options

    * `:timeout` - Connection timeout in milliseconds (default: 30000)

  ## Examples

      {:ok, channel} = Channel.connect(%{grpc_host: "localhost", grpc_port: 50051, api_key: nil})
      {:error, error} = Channel.connect(%{grpc_host: "invalid", grpc_port: 50051, api_key: nil})
  """
  @spec connect(config(), keyword()) :: {:ok, GRPC.Channel.t()} | {:error, Error.t()}
  def connect(config, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    tls = Map.get(config, :tls, false)
    max_message_size = Map.get(config, :max_message_size, @default_max_message_size)
    connection = Map.get(config, :connection)
    proxy = Map.get(config, :proxy)

    host = "#{config.grpc_host}:#{config.grpc_port}"

    channel_opts = build_channel_opts(tls, max_message_size, timeout, connection, proxy)

    case GRPC.Stub.connect(host, channel_opts) do
      {:ok, channel} ->
        {:ok, channel}

      {:error, reason} ->
        {:error, connection_error(reason)}
    end
  rescue
    e in [ArgumentError, RuntimeError] ->
      {:error, Error.exception(type: :connection_error, message: Exception.message(e))}
  catch
    :exit, reason ->
      {:error, connection_error(reason)}
  end

  @doc """
  Disconnects a gRPC channel.

  ## Examples

      :ok = Channel.disconnect(channel)
  """
  @spec disconnect(GRPC.Channel.t()) :: :ok
  def disconnect(channel) do
    GRPC.Stub.disconnect(channel)
    :ok
  rescue
    _ -> :ok
  end

  @doc """
  Checks if a channel is connected.

  ## Examples

      true = Channel.connected?(channel)
  """
  @spec connected?(GRPC.Channel.t()) :: boolean()
  def connected?(channel) do
    case channel do
      %GRPC.Channel{adapter_payload: %{conn_pid: pid}} when is_pid(pid) ->
        Process.alive?(pid)

      %GRPC.Channel{adapter_payload: %{conn_pid: ref}} when is_reference(ref) ->
        # gun uses references
        true

      _ ->
        false
    end
  end

  @doc """
  Builds gRPC metadata from config.

  Adds authorization header if API key is present.
  Includes additional_headers with lowercased keys.
  Accepts either a map or keyword list.

  ## Examples

      %{"authorization" => "Bearer key"} = Channel.build_metadata(%{api_key: "key"})
      %{"authorization" => "Bearer key"} = Channel.build_metadata(api_key: "key")
      %{} = Channel.build_metadata(%{api_key: nil})

      # With additional headers (keys are lowercased for gRPC)
      config = %{api_key: "key", additional_headers: %{"X-OpenAI-Api-Key" => "sk-123"}}
      metadata = Channel.build_metadata(config)
      # => %{"authorization" => "Bearer key", "x-openai-api-key" => "sk-123"}
  """
  @spec build_metadata(config() | map() | keyword()) :: map()
  def build_metadata(config) when is_list(config) do
    build_metadata(Map.new(config))
  end

  def build_metadata(config) when is_map(config) do
    auth_metadata =
      case resolve_auth_token(config) do
        nil -> %{}
        "" -> %{}
        token -> %{"authorization" => "Bearer #{token}"}
      end

    additional_metadata =
      config
      |> Map.get(:additional_headers, %{})
      |> lowercase_header_keys()

    Map.merge(auth_metadata, additional_metadata)
  end

  # Lowercase header keys for gRPC metadata
  defp lowercase_header_keys(headers) when is_map(headers) do
    Map.new(headers, fn {key, value} ->
      {String.downcase(to_string(key)), value}
    end)
  end

  # Private functions

  defp build_channel_opts(tls, _max_message_size, timeout, connection, proxy) do
    {adapter, adapter_opts} = build_adapter_opts(timeout, connection, proxy)

    base_opts = [
      adapter: adapter,
      adapter_opts: adapter_opts
    ]

    cred_opts =
      if tls do
        [cred: GRPC.Credential.new(ssl: [])]
      else
        []
      end

    # Add message size options
    interceptors = [
      {GRPC.Client.Interceptors.Logger, level: :debug}
    ]

    base_opts ++ cred_opts ++ [interceptors: interceptors]
  end

  defp build_adapter_opts(timeout, connection, proxy) do
    proxy_tuple = grpc_proxy_tuple(proxy)

    if proxy_tuple do
      adapter_opts =
        [transport_opts: [timeout: timeout], config_options: [proxy: proxy_tuple]]
        |> maybe_add_mint_settings(connection)

      {GRPC.Client.Adapters.Mint, adapter_opts}
    else
      adapter_opts =
        [transport_opts: [timeout: timeout]]
        |> maybe_add_gun_http2_opts(connection)

      {GRPC.Client.Adapters.Gun, adapter_opts}
    end
  end

  defp maybe_add_mint_settings(adapter_opts, nil), do: adapter_opts

  defp maybe_add_mint_settings(adapter_opts, %WeaviateEx.Config.Connection{} = connection) do
    settings = [max_concurrent_streams: connection.max_connections]
    Keyword.put(adapter_opts, :client_settings, settings)
  end

  defp maybe_add_gun_http2_opts(adapter_opts, nil), do: adapter_opts

  defp maybe_add_gun_http2_opts(adapter_opts, %WeaviateEx.Config.Connection{} = connection) do
    http2_opts =
      %{}
      |> maybe_put_http2_opt(:max_concurrent_streams, connection.max_connections)
      |> maybe_put_http2_opt(:keepalive, connection.max_idle_time)

    if map_size(http2_opts) == 0 do
      adapter_opts
    else
      Keyword.put(adapter_opts, :http2_opts, http2_opts)
    end
  end

  defp maybe_put_http2_opt(opts, _key, value) when not is_integer(value) or value <= 0, do: opts
  defp maybe_put_http2_opt(opts, key, value), do: Map.put(opts, key, value)

  defp grpc_proxy_tuple(nil), do: nil

  defp grpc_proxy_tuple(%WeaviateEx.Config.Proxy{grpc: nil}), do: nil

  defp grpc_proxy_tuple(%WeaviateEx.Config.Proxy{grpc: url}) when is_binary(url) do
    uri = URI.parse(url)

    scheme =
      case uri.scheme do
        "http" -> :http
        "https" -> :https
        "grpc" -> :http
        _ -> nil
      end

    if scheme && is_binary(uri.host) do
      port = uri.port || if(scheme == :https, do: 443, else: 80)
      {scheme, uri.host, port, []}
    else
      nil
    end
  end

  defp resolve_auth_token(%{token_manager: token_manager}) when not is_nil(token_manager) do
    case TokenManager.get_access_token(token_manager) do
      {:ok, access_token} -> access_token
      {:error, _} -> nil
    end
  end

  defp resolve_auth_token(%{auth: %{type: :api_key, api_key: api_key}}) when is_binary(api_key),
    do: api_key

  defp resolve_auth_token(%{auth: %{type: :bearer_token, access_token: token}})
       when is_binary(token),
       do: token

  defp resolve_auth_token(%{access_token: token}) when is_binary(token), do: token

  defp resolve_auth_token(%{api_key: api_key}) when is_binary(api_key), do: api_key

  defp resolve_auth_token(_), do: nil

  defp connection_error(:timeout) do
    Error.exception(type: :timeout_error, message: "Connection timeout")
  end

  defp connection_error({:shutdown, :econnrefused}) do
    Error.exception(type: :connection_error, message: "Connection refused")
  end

  defp connection_error({:shutdown, {:tls_alert, _}}) do
    Error.exception(type: :connection_error, message: "TLS handshake failed")
  end

  defp connection_error({:error, :nxdomain}) do
    Error.exception(type: :connection_error, message: "Host not found")
  end

  defp connection_error({:shutdown, :nxdomain}) do
    Error.exception(type: :connection_error, message: "Host not found")
  end

  defp connection_error(reason) do
    Error.exception(type: :connection_error, message: inspect(reason))
  end
end
