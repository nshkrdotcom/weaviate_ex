defmodule WeaviateEx.Protocol.HTTP.Client do
  @moduledoc """
  HTTP protocol implementation using Finch.
  """

  @behaviour WeaviateEx.Protocol

  alias WeaviateEx.Client
  alias WeaviateEx.Error

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

    # Get timeout from opts or config
    timeout = Keyword.get(opts, :timeout, config.timeout)

    # Execute request
    case Finch.request(finch_request, WeaviateEx.Finch, receive_timeout: timeout) do
      {:ok, %Finch.Response{status: status, body: response_body}}
      when status >= 200 and status < 300 ->
        parse_response(response_body)

      {:ok, %Finch.Response{status: status, body: response_body}} ->
        handle_error_response(status, response_body)

      {:error, %Mint.TransportError{reason: :econnrefused}} ->
        {:error, Error.exception(type: :connection_error, message: "Connection refused")}

      {:error, %Mint.TransportError{reason: :timeout}} ->
        {:error, Error.exception(type: :timeout_error, message: "Request timeout")}

      {:error, reason} ->
        {:error, Error.exception(type: :connection_error, message: inspect(reason))}
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

    headers
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
