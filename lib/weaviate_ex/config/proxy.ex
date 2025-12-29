defmodule WeaviateEx.Config.Proxy do
  @moduledoc """
  Proxy configuration for HTTP, HTTPS, and gRPC connections.

  This module provides proxy support for Weaviate client connections,
  reading from environment variables or explicit configuration.

  ## Environment Variables

  The following environment variables are read (case-insensitive):
  - `HTTP_PROXY` / `http_proxy` - HTTP proxy URL
  - `HTTPS_PROXY` / `https_proxy` - HTTPS proxy URL
  - `GRPC_PROXY` / `grpc_proxy` - gRPC proxy URL

  Uppercase variables take precedence over lowercase.

  ## Examples

      # From environment variables
      proxy = Proxy.from_env()

      # Explicit configuration
      proxy = Proxy.new(
        http: "http://proxy.example.com:8080",
        https: "https://proxy.example.com:8443",
        grpc: "grpc://proxy.example.com:50051"
      )

      # Check if proxy is configured
      Proxy.configured?(proxy)
      # => true

      # Get proxy for a specific URL
      Proxy.http_proxy_for(proxy, "https://weaviate.example.com")
      # => "https://proxy.example.com:8443"

      # Get Finch HTTP client options
      Proxy.to_finch_opts(proxy)
      # => [proxy: {:https, "proxy.example.com", 8443, []}]

      # Get gRPC channel options
      Proxy.to_grpc_opts(proxy)
      # => [http_proxy: "grpc://proxy.example.com:50051"]
  """

  @type t :: %__MODULE__{
          http: String.t() | nil,
          https: String.t() | nil,
          grpc: String.t() | nil
        }

  defstruct http: nil, https: nil, grpc: nil

  @doc """
  Create a new proxy configuration from explicit options.

  ## Options

  - `:http` - HTTP proxy URL (e.g., "http://proxy:8080")
  - `:https` - HTTPS proxy URL (e.g., "https://proxy:8443")
  - `:grpc` - gRPC proxy URL (e.g., "http://proxy:8080")

  ## Examples

      Proxy.new(
        http: "http://proxy.example.com:8080",
        https: "https://proxy.example.com:8443"
      )
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      http: Keyword.get(opts, :http),
      https: Keyword.get(opts, :https),
      grpc: Keyword.get(opts, :grpc)
    }
  end

  @doc """
  Create proxy configuration from environment variables.

  Reads from the following environment variables (case-insensitive):
  - `HTTP_PROXY` / `http_proxy`
  - `HTTPS_PROXY` / `https_proxy`
  - `GRPC_PROXY` / `grpc_proxy`

  Uppercase variables take precedence over lowercase.

  ## Examples

      # With HTTP_PROXY=http://proxy:8080 set
      proxy = Proxy.from_env()
      proxy.http
      # => "http://proxy:8080"
  """
  @spec from_env() :: t()
  def from_env do
    %__MODULE__{
      http: get_env_case_insensitive("HTTP_PROXY"),
      https: get_env_case_insensitive("HTTPS_PROXY"),
      grpc: get_env_case_insensitive("GRPC_PROXY")
    }
  end

  @doc """
  Check if any proxy is configured.

  ## Examples

      proxy = Proxy.new()
      Proxy.configured?(proxy)
      # => false

      proxy = Proxy.new(http: "http://proxy:8080")
      Proxy.configured?(proxy)
      # => true
  """
  @spec configured?(t()) :: boolean()
  def configured?(%__MODULE__{http: nil, https: nil, grpc: nil}), do: false
  def configured?(%__MODULE__{}), do: true

  @doc """
  Get the appropriate HTTP proxy for a given URL.

  Returns the HTTPS proxy for https:// URLs and HTTP proxy for http:// URLs.
  Falls back to HTTP proxy if HTTPS proxy is not configured.

  ## Examples

      proxy = Proxy.new(http: "http://proxy:8080", https: "https://proxy:8443")

      Proxy.http_proxy_for(proxy, "http://api.example.com")
      # => "http://proxy:8080"

      Proxy.http_proxy_for(proxy, "https://api.example.com")
      # => "https://proxy:8443"
  """
  @spec http_proxy_for(t(), String.t()) :: String.t() | nil
  def http_proxy_for(%__MODULE__{} = proxy, url) when is_binary(url) do
    if String.starts_with?(url, "https://") do
      # For HTTPS, prefer HTTPS proxy, fall back to HTTP
      proxy.https || proxy.http
    else
      proxy.http
    end
  end

  @doc """
  Convert proxy configuration to Finch HTTP client options.

  Returns options suitable for passing to Finch.build/3.

  ## Examples

      proxy = Proxy.new(https: "https://proxy.example.com:8443")
      Proxy.to_finch_opts(proxy)
      # => [proxy: {:https, "proxy.example.com", 8443, []}]
  """
  @spec to_finch_opts(t()) :: keyword()
  def to_finch_opts(%__MODULE__{http: nil, https: nil}), do: []

  def to_finch_opts(%__MODULE__{} = proxy) do
    # Prefer HTTPS proxy over HTTP
    proxy_url = proxy.https || proxy.http

    case parse_proxy_url(proxy_url) do
      {:ok, scheme, host, port} ->
        [proxy: {scheme, host, port, []}]

      :error ->
        []
    end
  end

  @doc """
  Convert proxy configuration to gRPC channel options.

  Returns options suitable for passing to GRPC.Stub.connect/2.

  ## Examples

      proxy = Proxy.new(grpc: "http://grpc-proxy.example.com:8080")
      Proxy.to_grpc_opts(proxy)
      # => [http_proxy: "http://grpc-proxy.example.com:8080"]
  """
  @spec to_grpc_opts(t()) :: keyword()
  def to_grpc_opts(%__MODULE__{grpc: nil}), do: []

  def to_grpc_opts(%__MODULE__{grpc: grpc_proxy}) do
    [http_proxy: grpc_proxy]
  end

  # Read environment variable case-insensitively (uppercase takes precedence)
  defp get_env_case_insensitive(uppercase_key) do
    lowercase_key = String.downcase(uppercase_key)

    System.get_env(uppercase_key) || System.get_env(lowercase_key)
  end

  # Parse proxy URL into {scheme, host, port}
  defp parse_proxy_url(nil), do: :error

  defp parse_proxy_url(url) when is_binary(url) do
    uri = URI.parse(url)

    case {uri.scheme, uri.host, uri.port} do
      {scheme, host, port}
      when scheme in ["http", "https"] and is_binary(host) and is_integer(port) ->
        {:ok, String.to_atom(scheme), host, port}

      {scheme, host, nil} when scheme in ["http", "https"] and is_binary(host) ->
        default_port = if scheme == "https", do: 443, else: 80
        {:ok, String.to_atom(scheme), host, default_port}

      _ ->
        :error
    end
  end
end
