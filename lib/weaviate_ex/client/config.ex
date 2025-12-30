defmodule WeaviateEx.Client.Config do
  @moduledoc """
  Client configuration for WeaviateEx.

  ## Configuration Options

    * `:base_url` - HTTP base URL for schema operations (default: "http://localhost:8080")
    * `:grpc_host` - gRPC host for data operations (default: derived from base_url or "localhost")
    * `:grpc_port` - gRPC port (default: 50051)
    * `:api_key` - API key for authentication (optional)
    * `:auth` - Authentication config (`WeaviateEx.Auth`) for API key, bearer token, or OIDC
    * `:timeout` - Default timeout in milliseconds (default: 60000)
    * `:grpc_max_message_size` - Max gRPC message size in bytes (default: 100MB)
    * `:additional_headers` - Extra headers to include in HTTP/gRPC requests (default: %{})
      Common use cases: X-OpenAI-Api-Key, X-Cohere-Api-Key for vectorizer/generative modules
    * `:skip_wcs_headers` - Skip auto-detection of WCS headers (default: false)
    * `:connection` - Connection pool settings (`WeaviateEx.Config.Connection` or keyword list)
    * `:proxy` - Proxy settings (`WeaviateEx.Config.Proxy`, keyword list, or `:env`)
    * `:finch_name` - Finch instance name to use (default: `WeaviateEx.Finch`)
    * `:token_manager` - Existing OIDC TokenManager to attach (optional)

  ## WCS Auto-Detection

  When connecting to Weaviate Cloud Services (WCS) instances, the client automatically
  detects the cluster URL and adds appropriate headers. This is controlled by detecting
  known WCS domains in the base_url.

  ## Examples

      # Local Weaviate
      Config.new(base_url: "http://localhost:8080")

      # Weaviate Cloud
      Config.new(
        base_url: "https://my-cluster.weaviate.network",
        grpc_host: "my-cluster.grpc.weaviate.network",
        grpc_port: 443,
        api_key: "your-api-key"
      )
  """

  @default_grpc_port 50_051
  @default_timeout 60_000
  # 100MB
  @default_grpc_max_message_size 104_858_000

  # Known WCS domains for auto-detection
  @wcs_domains ["weaviate.network", "wcs.api.weaviate.io", "semi.network", "weaviate.cloud"]

  alias WeaviateEx.Config.{Connection, Proxy}

  @type t :: %__MODULE__{
          base_url: String.t(),
          grpc_host: String.t(),
          grpc_port: integer(),
          api_key: String.t() | nil,
          auth: WeaviateEx.Auth.t() | nil,
          token_manager: GenServer.server() | nil,
          token_manager_owner: boolean(),
          timeout: integer(),
          timeout_config: WeaviateEx.Config.Timeout.t() | nil,
          grpc_max_message_size: integer(),
          additional_headers: %{optional(String.t()) => String.t()},
          connection: Connection.t() | nil,
          proxy: Proxy.t() | nil,
          finch_name: atom(),
          finch_owner: boolean()
        }

  defstruct base_url: "http://localhost:8080",
            grpc_host: "localhost",
            grpc_port: @default_grpc_port,
            api_key: nil,
            auth: nil,
            token_manager: nil,
            token_manager_owner: false,
            timeout: @default_timeout,
            timeout_config: nil,
            grpc_max_message_size: @default_grpc_max_message_size,
            additional_headers: %{},
            connection: nil,
            proxy: nil,
            finch_name: WeaviateEx.Finch,
            finch_owner: false

  @doc """
  Create config from keyword list.

  If `grpc_host` is not provided, it will be derived from `base_url`.

  ## Examples

      Config.new(base_url: "http://localhost:8080")
      # => %Config{grpc_host: "localhost", grpc_port: 50051, ...}

      Config.new(base_url: "https://my-cluster.weaviate.network")
      # => %Config{grpc_host: "my-cluster.weaviate.network", grpc_port: 443, ...}
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    base_url = Keyword.get(opts, :base_url, "http://localhost:8080")

    # Derive gRPC host from base_url if not provided
    grpc_host = Keyword.get(opts, :grpc_host) || derive_grpc_host(base_url)
    grpc_port = Keyword.get(opts, :grpc_port) || derive_grpc_port(base_url)

    additional_headers = Keyword.get(opts, :additional_headers, %{})
    validate_additional_headers!(additional_headers)

    auth = normalize_auth(Keyword.get(opts, :auth))
    api_key = normalize_api_key(auth, Keyword.get(opts, :api_key))

    %__MODULE__{
      base_url: base_url,
      grpc_host: grpc_host,
      grpc_port: grpc_port,
      api_key: api_key,
      auth: auth,
      token_manager: Keyword.get(opts, :token_manager),
      timeout: Keyword.get(opts, :timeout, @default_timeout),
      timeout_config: Keyword.get(opts, :timeout_config),
      grpc_max_message_size:
        Keyword.get(opts, :grpc_max_message_size, @default_grpc_max_message_size),
      additional_headers: additional_headers,
      connection: normalize_connection(Keyword.get(opts, :connection)),
      proxy: normalize_proxy(Keyword.get(opts, :proxy)),
      finch_name: Keyword.get(opts, :finch_name, WeaviateEx.Finch)
    }
  end

  @doc """
  Check if TLS should be used for gRPC connection.

  Returns true if the base_url uses HTTPS or grpc_port is 443.
  """
  @spec use_tls?(t()) :: boolean()
  def use_tls?(%__MODULE__{base_url: base_url, grpc_port: port}) do
    String.starts_with?(base_url, "https://") or port == 443
  end

  # Derive gRPC host from base URL
  defp derive_grpc_host(base_url) do
    uri = URI.parse(base_url)
    host = uri.host || "localhost"

    cond do
      not wcs_host?(host) -> host
      String.ends_with?(host, ".weaviate.network") -> derive_weaviate_network_grpc_host(host)
      true -> "grpc-#{host}"
    end
  end

  # Derive gRPC host for .weaviate.network domains
  defp derive_weaviate_network_grpc_host(host) do
    case String.split(host, ".", parts: 2) do
      [ident, domain] -> "#{ident}.grpc.#{domain}"
      _ -> "grpc-#{host}"
    end
  end

  # Derive gRPC port - use 443 for HTTPS, 50051 for HTTP
  defp derive_grpc_port(base_url) do
    if String.starts_with?(base_url, "https://") do
      443
    else
      @default_grpc_port
    end
  end

  # Validate additional_headers - all values must be non-nil strings
  defp validate_additional_headers!(headers) when is_map(headers) do
    Enum.each(headers, fn
      {key, nil} ->
        raise ArgumentError,
              "Header values cannot be nil. Found nil value for header: #{key}"

      {_key, value} when is_binary(value) ->
        :ok

      {key, value} ->
        raise ArgumentError,
              "Header values must be strings. Found #{inspect(value)} for header: #{key}"
    end)
  end

  defp validate_additional_headers!(other) do
    raise ArgumentError,
          "additional_headers must be a map, got: #{inspect(other)}"
  end

  defp normalize_auth(nil), do: nil

  defp normalize_auth(%{issuer_url: _issuer_url, auth: auth}) when is_map(auth) do
    auth
  end

  defp normalize_auth(auth) when is_map(auth), do: auth

  defp normalize_auth(other) do
    raise ArgumentError, "auth must be a WeaviateEx.Auth map, got: #{inspect(other)}"
  end

  defp normalize_api_key(%{type: :api_key, api_key: api_key}, _), do: api_key
  defp normalize_api_key(%{type: :bearer_token, access_token: token}, _), do: token
  defp normalize_api_key(_auth, api_key), do: api_key

  defp normalize_connection(nil), do: nil
  defp normalize_connection(%Connection{} = connection), do: connection
  defp normalize_connection(opts) when is_list(opts), do: Connection.new(opts)

  defp normalize_connection(other) do
    raise ArgumentError,
          "connection must be a WeaviateEx.Config.Connection or keyword list, got: #{inspect(other)}"
  end

  defp normalize_proxy(nil), do: nil
  defp normalize_proxy(:env), do: normalize_proxy(Proxy.from_env())
  defp normalize_proxy(:from_env), do: normalize_proxy(Proxy.from_env())

  defp normalize_proxy(%Proxy{} = proxy) do
    if Proxy.configured?(proxy), do: proxy, else: nil
  end

  defp normalize_proxy(opts) when is_list(opts), do: normalize_proxy(Proxy.new(opts))

  defp normalize_proxy(other) do
    raise ArgumentError,
          "proxy must be a WeaviateEx.Config.Proxy, keyword list, or :env, got: #{inspect(other)}"
  end

  @doc """
  Detects if the host is a Weaviate Cloud Services instance.

  ## Examples

      iex> Config.wcs_host?("https://my-cluster.weaviate.network")
      true

      iex> Config.wcs_host?("http://localhost:8080")
      false
  """
  @spec wcs_host?(String.t()) :: boolean()
  def wcs_host?(host) when is_binary(host) do
    uri = URI.parse(host)
    domain = uri.host || host

    Enum.any?(@wcs_domains, &String.contains?(domain, &1))
  end

  def wcs_host?(_), do: false

  @doc """
  Adds WCS-specific headers if the host is a WCS instance.

  Returns the config with updated `additional_headers` including the
  `X-Weaviate-Cluster-URL` header for WCS instances.

  ## Examples

      config = Config.new(base_url: "https://my-cluster.weaviate.network")
      config = Config.maybe_add_wcs_headers(config)
      # config.additional_headers now contains X-Weaviate-Cluster-URL
  """
  @spec maybe_add_wcs_headers(t()) :: t()
  def maybe_add_wcs_headers(%__MODULE__{base_url: base_url, additional_headers: headers} = config) do
    if wcs_host?(base_url) do
      updated_headers = Map.put(headers, "X-Weaviate-Cluster-URL", base_url)
      %{config | additional_headers: updated_headers}
    else
      config
    end
  end

  @doc """
  Creates a new config with automatic WCS header detection.

  This is equivalent to calling `new/1` followed by `maybe_add_wcs_headers/1`.

  ## Options

  All options from `new/1` plus:
    * `:skip_wcs_headers` - Skip WCS header auto-detection (default: false)

  ## Examples

      config = Config.new_with_wcs_detection(base_url: "https://my-cluster.weaviate.network")
      # WCS headers are automatically added
  """
  @spec new_with_wcs_detection(keyword()) :: t()
  def new_with_wcs_detection(opts \\ []) do
    skip_wcs = Keyword.get(opts, :skip_wcs_headers, false)
    config = new(opts)

    if skip_wcs do
      config
    else
      maybe_add_wcs_headers(config)
    end
  end
end
