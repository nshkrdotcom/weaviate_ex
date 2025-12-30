defmodule WeaviateEx.Protocol.HTTP.Client do
  @moduledoc """
  HTTP protocol implementation using Finch.

  Includes transport-level and HTTP status code retry for transient errors
  and per-operation timeouts based on HTTP method and operation type.

  ## Retry Behavior

  Automatically retries on:
  - Transport errors: connection refused, reset, timeout, closed, DNS failure
  - HTTP status codes: 408, 429, 500, 502, 503, 504

  ## Timeout Behavior

  Uses per-operation timeouts:
  - Query operations (GET, GraphQL): 30s default
  - Insert operations (POST, PUT, PATCH, DELETE): 90s default
  - Batch operations: 900s (insert × 10)

  ## Options

  Requests accept the following options:
  - `:timeout` - Override the automatic timeout (milliseconds)
  - `:operation` - Operation type (:query, :insert, :batch, etc.)
  - `:max_retries` - Maximum retry attempts (default: 3)
  - `:base_delay_ms` - Base delay for backoff (default: 100)
  - `:max_delay_ms` - Maximum delay cap (default: 5000)
  """

  @behaviour WeaviateEx.Protocol

  alias WeaviateEx.Auth.TokenManager
  alias WeaviateEx.Client
  alias WeaviateEx.Config.Timeout
  alias WeaviateEx.Error
  alias WeaviateEx.Protocol.HTTP.Retry
  alias WeaviateEx.Protocol.HTTP.Timeout, as: HTTPTimeout

  @default_pool_timeout 5_000

  @impl true
  def request(%Client{config: config} = _client, method, path, body, opts) do
    # Build full URL
    url = build_url(config.base_url, path)

    with {:ok, headers} <- build_headers(config, body) do
      # Encode body if present
      encoded_body = encode_body(body)

      # Build Finch request
      finch_request = Finch.build(method, url, headers, encoded_body)

      # Get timeout using Timeout module for per-operation timeouts
      timeout = get_operation_timeout(config, method, path, opts)

      # Build Finch options with pool_timeout
      finch_opts = [
        receive_timeout: timeout,
        pool_timeout: pool_timeout(config)
      ]

      # Execute request with retry wrapper
      execute_with_retry(finch_request, finch_opts, config.finch_name, config, opts)
    end
  end

  # Execute request with automatic retry on transport and HTTP status errors
  defp execute_with_retry(finch_request, finch_opts, finch_name, config, opts) do
    # Get retry options from opts or config
    retry_opts = build_retry_opts(config, opts)

    Retry.with_retry(
      fn -> Finch.request(finch_request, finch_name, finch_opts) end,
      retry_opts
    )
    |> handle_response()
  end

  # Build retry options from config and opts
  defp build_retry_opts(config, opts) do
    # Get retry config from client config if available
    config_retry_opts = Map.get(config, :retry, [])

    # Merge with explicit opts (opts take precedence)
    Keyword.merge(
      config_retry_opts,
      Keyword.take(opts, [:max_retries, :base_delay_ms, :max_delay_ms])
    )
  end

  # Handle Finch response
  defp handle_response({:ok, %Finch.Response{status: status, body: response_body}})
       when status >= 200 and status < 300 do
    parse_response(response_body)
  end

  defp handle_response({:ok, %Finch.Response{status: status, body: response_body}}) do
    handle_error_response(status, response_body)
  end

  defp handle_response({:error, %Mint.TransportError{reason: :econnrefused}}) do
    {:error, Error.exception(type: :connection_error, message: "Connection refused")}
  end

  defp handle_response({:error, %Mint.TransportError{reason: :timeout}}) do
    {:error, Error.exception(type: :timeout_error, message: "Request timeout")}
  end

  defp handle_response({:error, %WeaviateEx.Error{} = error}) do
    # Pass through retry exhausted errors
    {:error, error}
  end

  defp handle_response({:error, reason}) do
    {:error, Error.exception(type: :connection_error, message: inspect(reason))}
  end

  # Get operation-specific timeout
  defp get_operation_timeout(config, method, path, opts) do
    # Check if explicit timeout in opts
    case Keyword.get(opts, :timeout) do
      nil ->
        # Get timeout config
        timeout_config = Map.get(config, :timeout_config) || Timeout.new()

        # Check for explicit operation type
        case Keyword.get(opts, :operation) do
          nil ->
            # Infer operation from method and path
            infer_timeout(timeout_config, method, path)

          operation ->
            # Use explicit operation type
            HTTPTimeout.for_operation(timeout_config, operation)
        end

      explicit_timeout ->
        explicit_timeout
    end
  end

  # Infer timeout from HTTP method and path
  defp infer_timeout(timeout_config, method, path) do
    cond do
      # GraphQL queries use query timeout
      method == :post and String.contains?(path, "graphql") ->
        timeout_config.query

      # Batch endpoints get extended timeout
      String.contains?(path, "/batch") ->
        HTTPTimeout.for_operation(timeout_config, :batch)

      # Use method-based timeout
      true ->
        Timeout.for_method(timeout_config, method)
    end
  end

  defp build_url(base_url, path) do
    # Remove trailing slash from base_url and leading slash from path if both present
    base = String.trim_trailing(base_url, "/")
    path = if String.starts_with?(path, "/"), do: path, else: "/#{path}"
    base <> path
  end

  defp build_headers(config, body) do
    headers = [{"content-type", "application/json"}]

    with {:ok, auth_headers} <- auth_headers(config) do
      headers = auth_headers ++ headers

      headers =
        if body do
          [{"accept", "application/json"} | headers]
        else
          headers
        end

      # Add additional_headers from config
      headers = add_additional_headers(headers, config)

      {:ok, headers}
    end
  end

  defp add_additional_headers(headers, config) do
    additional = Map.get(config, :additional_headers, %{})

    Enum.reduce(additional, headers, fn {key, value}, acc ->
      [{key, value} | acc]
    end)
  end

  defp encode_body(nil), do: nil
  defp encode_body(body) when is_map(body), do: Jason.encode!(body)
  defp encode_body(body) when is_list(body), do: Jason.encode!(body)
  defp encode_body(body) when is_binary(body), do: body

  defp parse_response(""), do: {:ok, %{}}

  defp parse_response(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, _} -> {:ok, %{"body" => body}}
    end
  end

  defp handle_error_response(status, body) do
    parsed_body =
      case Jason.decode(body) do
        {:ok, decoded} -> decoded
        {:error, _} -> %{"message" => body}
      end

    error = Error.from_status_code(status, parsed_body)
    {:error, error}
  end

  defp pool_timeout(%{connection: %{pool_timeout: pool_timeout}})
       when is_integer(pool_timeout) and pool_timeout > 0 do
    pool_timeout
  end

  defp pool_timeout(_config), do: @default_pool_timeout

  defp auth_headers(%{token_manager: token_manager}) when not is_nil(token_manager) do
    case TokenManager.get_access_token(token_manager) do
      {:ok, access_token} ->
        {:ok, [{"authorization", "Bearer #{access_token}"}]}

      {:error, :no_token} ->
        {:error,
         Error.exception(
           type: :authentication_failed,
           message: "OIDC access token not available"
         )}
    end
  end

  defp auth_headers(%{auth: %{type: :api_key, api_key: api_key}}) when is_binary(api_key) do
    {:ok, [{"authorization", "Bearer #{api_key}"}]}
  end

  defp auth_headers(%{auth: %{type: :bearer_token, access_token: token}})
       when is_binary(token) do
    {:ok, [{"authorization", "Bearer #{token}"}]}
  end

  defp auth_headers(%{api_key: api_key}) when is_binary(api_key) and api_key != "" do
    {:ok, [{"authorization", "Bearer #{api_key}"}]}
  end

  defp auth_headers(_config), do: {:ok, []}
end
