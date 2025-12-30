defmodule WeaviateEx.Connect do
  @moduledoc """
  Connection configuration factory for Weaviate.

  Provides factory functions for creating connection configurations
  for different Weaviate deployment types.

  ## Examples

      # Weaviate Cloud
      config = Connect.to_weaviate_cloud(
        cluster_url: "my-cluster.weaviate.network",
        api_key: "my-api-key"
      )

      # Local instance
      config = Connect.to_local()
      config = Connect.to_local(host: "192.168.1.100", port: 9080)

      # Custom deployment
      config = Connect.to_custom(
        http_host: "weaviate.example.com",
        http_port: 443,
        http_secure: true
      )

      # Embedded (for testing)
      config = Connect.to_embedded(version: "1.30.5")
  """

  @type connection_config :: %{
          :base_url => String.t(),
          :grpc_host => String.t() | nil,
          :grpc_port => pos_integer() | nil,
          :grpc_secure => boolean(),
          :api_key => String.t() | nil,
          :headers => [{String.t(), String.t()}],
          :embedded => boolean(),
          :version => String.t() | nil,
          optional(:binary_path) => String.t() | nil
        }

  @doc """
  Create connection config for Weaviate Cloud.

  ## Options

    - `:cluster_url` - Weaviate Cloud cluster URL (required)
    - `:api_key` - API key for authentication
    - `:headers` - Additional HTTP headers

  ## Examples

      Connect.to_weaviate_cloud(
        cluster_url: "my-cluster.weaviate.network",
        api_key: "my-api-key"
      )
  """
  @spec to_weaviate_cloud(keyword()) :: connection_config()
  def to_weaviate_cloud(opts) do
    cluster_url =
      opts
      |> Keyword.fetch!(:cluster_url)
      |> normalize_cluster_url()

    # Extract hostname for gRPC
    grpc_host =
      cluster_url
      |> extract_hostname()
      |> derive_wcs_grpc_host()

    %{
      base_url: cluster_url,
      grpc_host: grpc_host,
      grpc_port: 443,
      grpc_secure: true,
      api_key: Keyword.get(opts, :api_key),
      headers: Keyword.get(opts, :headers, []),
      embedded: false,
      version: nil
    }
  end

  @doc """
  Create connection config for local Weaviate instance.

  ## Options

    - `:host` - Hostname (default: "localhost")
    - `:port` - HTTP port (default: 8080)
    - `:grpc_port` - gRPC port (default: 50051)
    - `:api_key` - API key for authentication
    - `:headers` - Additional HTTP headers

  ## Examples

      Connect.to_local()
      Connect.to_local(host: "192.168.1.100", port: 9080)
  """
  @spec to_local(keyword()) :: connection_config()
  def to_local(opts \\ []) do
    host = Keyword.get(opts, :host, "localhost")
    port = Keyword.get(opts, :port, 8080)
    grpc_port = Keyword.get(opts, :grpc_port, 50_051)

    %{
      base_url: "http://#{host}:#{port}",
      grpc_host: host,
      grpc_port: grpc_port,
      grpc_secure: false,
      api_key: Keyword.get(opts, :api_key),
      headers: Keyword.get(opts, :headers, []),
      embedded: false,
      version: nil
    }
  end

  @doc """
  Create connection config for custom Weaviate deployment.

  ## Options

    - `:http_host` - HTTP hostname (required)
    - `:http_port` - HTTP port (default: 8080)
    - `:http_secure` - Use HTTPS (default: false)
    - `:grpc_host` - gRPC hostname (optional)
    - `:grpc_port` - gRPC port (optional)
    - `:grpc_secure` - Use secure gRPC (default: false)
    - `:api_key` - API key for authentication
    - `:headers` - Additional HTTP headers

  ## Examples

      Connect.to_custom(
        http_host: "weaviate.example.com",
        http_port: 443,
        http_secure: true
      )
  """
  @spec to_custom(keyword()) :: connection_config()
  def to_custom(opts) do
    http_host = Keyword.fetch!(opts, :http_host)
    http_port = Keyword.get(opts, :http_port, 8080)
    http_secure = Keyword.get(opts, :http_secure, false)

    scheme = if http_secure, do: "https", else: "http"

    %{
      base_url: "#{scheme}://#{http_host}:#{http_port}",
      grpc_host: Keyword.get(opts, :grpc_host),
      grpc_port: Keyword.get(opts, :grpc_port),
      grpc_secure: Keyword.get(opts, :grpc_secure, false),
      api_key: Keyword.get(opts, :api_key),
      headers: Keyword.get(opts, :headers, []),
      embedded: false,
      version: nil
    }
  end

  @doc """
  Create connection config for embedded Weaviate.

  Used for testing and development with embedded Weaviate binary.

  ## Options

    - `:port` - HTTP port (default: 8079)
    - `:grpc_port` - gRPC port (default: 50050)
    - `:version` - Weaviate version to use
    - `:binary_path` - Path to Weaviate binary (optional)

  ## Examples

      Connect.to_embedded()
      Connect.to_embedded(version: "1.30.5", port: 8090)
  """
  @spec to_embedded(keyword()) :: connection_config()
  def to_embedded(opts \\ []) do
    port = Keyword.get(opts, :port, 8079)
    grpc_port = Keyword.get(opts, :grpc_port, 50_050)

    %{
      base_url: "http://127.0.0.1:#{port}",
      grpc_host: "127.0.0.1",
      grpc_port: grpc_port,
      grpc_secure: false,
      api_key: nil,
      headers: [],
      embedded: true,
      version: Keyword.get(opts, :version),
      binary_path: Keyword.get(opts, :binary_path)
    }
  end

  # Private helpers

  defp normalize_cluster_url(url) do
    url = String.trim(url)

    if String.starts_with?(url, "http://") or String.starts_with?(url, "https://") do
      url
    else
      "https://#{url}"
    end
  end

  defp extract_hostname(url) do
    uri =
      case URI.parse(url) do
        %URI{host: nil} -> URI.parse("https://#{url}")
        parsed -> parsed
      end

    uri.host ||
      url
      |> String.replace(~r{^https?://}, "")
      |> String.split("/")
      |> List.first()
  end

  defp derive_wcs_grpc_host(host) do
    if String.ends_with?(host, ".weaviate.network") do
      case String.split(host, ".", parts: 2) do
        [ident, domain] -> "#{ident}.grpc.#{domain}"
        _ -> "grpc-#{host}"
      end
    else
      "grpc-#{host}"
    end
  end
end
