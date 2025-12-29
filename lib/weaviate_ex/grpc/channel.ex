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

  @type config :: %{
          required(:grpc_host) => String.t(),
          required(:grpc_port) => non_neg_integer(),
          required(:api_key) => String.t() | nil,
          optional(:tls) => boolean(),
          optional(:max_message_size) => non_neg_integer()
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

    host = "#{config.grpc_host}:#{config.grpc_port}"

    channel_opts = build_channel_opts(tls, max_message_size, timeout)

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
  Accepts either a map or keyword list.

  ## Examples

      %{"authorization" => "Bearer key"} = Channel.build_metadata(%{api_key: "key"})
      %{"authorization" => "Bearer key"} = Channel.build_metadata(api_key: "key")
      %{} = Channel.build_metadata(%{api_key: nil})
  """
  @spec build_metadata(config() | map() | keyword()) :: map()
  def build_metadata(config) when is_list(config) do
    case Keyword.get(config, :api_key) do
      nil -> %{}
      "" -> %{}
      api_key -> %{"authorization" => "Bearer #{api_key}"}
    end
  end

  def build_metadata(config) when is_map(config) do
    case Map.get(config, :api_key) do
      nil -> %{}
      "" -> %{}
      api_key -> %{"authorization" => "Bearer #{api_key}"}
    end
  end

  # Private functions

  defp build_channel_opts(tls, _max_message_size, timeout) do
    base_opts = [
      adapter: GRPC.Client.Adapters.Gun,
      adapter_opts: %{
        transport_opts: %{
          timeout: timeout
        }
      }
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
