defmodule WeaviateEx.Protocol.HTTP.Client do
  @moduledoc """
  HTTP protocol implementation using Finch.

  Includes transport-level retry for transient errors (connection refused, timeout, etc.)
  and per-operation timeouts based on HTTP method.
  """

  @behaviour WeaviateEx.Protocol

  alias WeaviateEx.Client
  alias WeaviateEx.Config.Timeout
  alias WeaviateEx.Error
  alias WeaviateEx.Protocol.HTTP.Retry

  @default_pool_timeout 5_000

  @impl true
  def request(%Client{config: config} = _client, method, path, body, opts) do
    # Build full URL
    url = build_url(config.base_url, path)

    # Build headers
    headers = build_headers(config, body)

    # Encode body if present
    encoded_body = encode_body(body)

    # Build Finch request
    finch_request = Finch.build(method, url, headers, encoded_body)

    # Get timeout using Timeout module for per-operation timeouts
    timeout = get_operation_timeout(config, method, path, opts)

    # Build Finch options with pool_timeout
    finch_opts = [
      receive_timeout: timeout,
      pool_timeout: @default_pool_timeout
    ]

    # Execute request with retry wrapper for transport errors
    execute_with_retry(finch_request, finch_opts, opts)
  end

  # Execute request with automatic retry on transport errors
  defp execute_with_retry(finch_request, finch_opts, opts) do
    retry_opts = Keyword.take(opts, [:max_retries, :base_delay_ms])

    Retry.with_retry(
      fn -> Finch.request(finch_request, WeaviateEx.Finch, finch_opts) end,
      retry_opts
    )
    |> handle_response()
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
        # Use Timeout module for per-operation timeouts
        timeout_config = Map.get(config, :timeout_config) || Timeout.new()

        # Determine if this is a GraphQL query (POST to /v1/graphql)
        if method == :post and String.contains?(path, "graphql") do
          timeout_config.query
        else
          Timeout.for_method(timeout_config, method)
        end

      explicit_timeout ->
        explicit_timeout
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

    headers =
      if config.api_key do
        [{"authorization", "Bearer #{config.api_key}"} | headers]
      else
        headers
      end

    headers =
      if body do
        [{"accept", "application/json"} | headers]
      else
        headers
      end

    # Add additional_headers from config
    headers = add_additional_headers(headers, config)

    headers
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
end
