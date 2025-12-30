defmodule WeaviateEx.Client.Config do
  @moduledoc """
  Client configuration for WeaviateEx.

  ## Configuration Options

    * `:base_url` - HTTP base URL for schema operations (default: "http://localhost:8080")
    * `:grpc_host` - gRPC host for data operations (default: derived from base_url or "localhost")
    * `:grpc_port` - gRPC port (default: 50051)
    * `:api_key` - API key for authentication (optional)
    * `:timeout` - Default timeout in milliseconds (default: 60000)
    * `:grpc_max_message_size` - Max gRPC message size in bytes (default: 100MB)
    * `:additional_headers` - Extra headers to include in HTTP/gRPC requests (default: %{})
      Common use cases: X-OpenAI-Api-Key, X-Cohere-Api-Key for vectorizer/generative modules

  ## Examples

      # Local Weaviate
      Config.new(base_url: "http://localhost:8080")

      # Weaviate Cloud
      Config.new(
        base_url: "https://my-cluster.weaviate.network",
        grpc_host: "grpc-my-cluster.weaviate.network",
        grpc_port: 443,
        api_key: "your-api-key"
      )
  """

  @default_grpc_port 50_051
  @default_timeout 60_000
  # 100MB
  @default_grpc_max_message_size 104_858_000

  @type t :: %__MODULE__{
          base_url: String.t(),
          grpc_host: String.t(),
          grpc_port: integer(),
          api_key: String.t() | nil,
          timeout: integer(),
          grpc_max_message_size: integer(),
          additional_headers: %{optional(String.t()) => String.t()}
        }

  defstruct base_url: "http://localhost:8080",
            grpc_host: "localhost",
            grpc_port: @default_grpc_port,
            api_key: nil,
            timeout: @default_timeout,
            grpc_max_message_size: @default_grpc_max_message_size,
            additional_headers: %{}

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

    %__MODULE__{
      base_url: base_url,
      grpc_host: grpc_host,
      grpc_port: grpc_port,
      api_key: Keyword.get(opts, :api_key),
      timeout: Keyword.get(opts, :timeout, @default_timeout),
      grpc_max_message_size:
        Keyword.get(opts, :grpc_max_message_size, @default_grpc_max_message_size),
      additional_headers: additional_headers
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
    uri.host || "localhost"
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
end
