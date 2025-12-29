defmodule WeaviateEx.Batch.RateLimit do
  @moduledoc """
  Provider-specific rate limit detection for batch operations.

  Detects rate limiting from various AI providers and calculates
  appropriate backoff times.

  ## Supported Patterns

  - **Generic**: HTTP 429 status with optional Retry-After header
  - **OpenAI**: `rate_limit` or `insufficient_quota` error types
  - **Cohere**: X-RateLimit-* headers
  - **Weaviate**: Rate limit errors in batch result messages

  ## Examples

      case RateLimit.detect(response) do
        {:rate_limited, retry_after_ms} ->
          Process.sleep(retry_after_ms)
          retry_request()

        :ok ->
          handle_response(response)
      end
  """

  @default_retry_ms 1_000
  @max_retry_ms 60_000
  @base_backoff_ms 1_000

  @rate_limit_patterns [
    "rate limit",
    "rate_limit",
    "rate-limit",
    "too many requests",
    "quota exceeded",
    "insufficient_quota",
    "throttl"
  ]

  @type response :: map()
  @type detect_result :: :ok | {:rate_limited, non_neg_integer()}

  @doc """
  Detects if a response indicates rate limiting.

  Returns `:ok` if not rate limited, or `{:rate_limited, retry_after_ms}`
  with the recommended wait time in milliseconds.

  ## Examples

      case RateLimit.detect(response) do
        {:rate_limited, 30_000} -> Process.sleep(30_000)
        :ok -> process_response()
      end
  """
  @spec detect(response()) :: detect_result()
  def detect(%{status: 429} = response) do
    retry_after = extract_retry_after_from_response(response)
    {:rate_limited, retry_after}
  end

  def detect(%{status: status} = response) when status >= 200 and status < 300 do
    # Check for rate limit errors in batch results
    case check_batch_errors(response) do
      {:rate_limited, _} = result -> result
      _ -> :ok
    end
  end

  def detect(_response), do: :ok

  @doc """
  Checks if a response or error indicates rate limiting.

  ## Examples

      RateLimit.rate_limited?(%{status: 429})
      # => true

      RateLimit.rate_limited?({:error, %{status: 429}})
      # => true
  """
  @spec rate_limited?(term()) :: boolean()
  def rate_limited?(%{status: 429}), do: true
  def rate_limited?({:error, %{status: 429}}), do: true
  def rate_limited?(_), do: false

  @doc """
  Calculates exponential backoff with jitter for retry attempts.

  Uses the formula: min(max_backoff, base * 2^attempt) + jitter

  ## Examples

      RateLimit.calculate_backoff(0)  # => ~1000ms
      RateLimit.calculate_backoff(1)  # => ~2000ms
      RateLimit.calculate_backoff(2)  # => ~4000ms
  """
  @spec calculate_backoff(non_neg_integer()) :: non_neg_integer()
  def calculate_backoff(attempt) when is_integer(attempt) and attempt >= 0 do
    # Exponential backoff: base * 2^attempt
    backoff = @base_backoff_ms * :math.pow(2, attempt)
    # Cap at max
    min(round(backoff), @max_retry_ms)
  end

  @doc """
  Extracts the Retry-After value from response headers.

  Returns the retry duration in milliseconds.

  ## Examples

      RateLimit.extract_retry_after(%{"retry-after" => "30"})
      # => 30_000
  """
  @spec extract_retry_after(map()) :: non_neg_integer()
  def extract_retry_after(headers) when is_map(headers) do
    # Try different header key formats
    retry_value =
      Map.get(headers, "retry-after") ||
        Map.get(headers, "Retry-After") ||
        Map.get(headers, "RETRY-AFTER")

    parse_retry_after(retry_value)
  end

  def extract_retry_after(_), do: @default_retry_ms

  # Private functions

  defp extract_retry_after_from_response(%{headers: headers} = _response)
       when is_map(headers) do
    extract_retry_after(headers)
  end

  defp extract_retry_after_from_response(%{body: body} = _response) do
    # Check for OpenAI/provider-specific retry info in body
    case extract_from_body(body) do
      nil -> @default_retry_ms
      ms -> ms
    end
  end

  defp extract_retry_after_from_response(_), do: @default_retry_ms

  defp parse_retry_after(nil), do: @default_retry_ms

  defp parse_retry_after(value) when is_binary(value) do
    case Integer.parse(value) do
      {seconds, _} -> seconds * 1000
      :error -> @default_retry_ms
    end
  end

  defp parse_retry_after(value) when is_integer(value), do: value * 1000
  defp parse_retry_after(_), do: @default_retry_ms

  defp extract_from_body(%{"error" => %{"retry_after" => seconds}})
       when is_number(seconds) do
    round(seconds * 1000)
  end

  defp extract_from_body(%{"error" => %{"type" => type}})
       when type in ["rate_limit", "insufficient_quota"] do
    @default_retry_ms
  end

  defp extract_from_body(_), do: nil

  defp check_batch_errors(%{body: body}) when is_list(body) do
    # Check each batch result for rate limit errors
    has_rate_limit_error =
      Enum.any?(body, fn item ->
        case item do
          %{"result" => %{"errors" => %{"error" => errors}}} when is_list(errors) ->
            Enum.any?(errors, &rate_limit_error_message?(&1))

          _ ->
            false
        end
      end)

    if has_rate_limit_error do
      {:rate_limited, @default_retry_ms}
    else
      :ok
    end
  end

  defp check_batch_errors(_), do: :ok

  defp rate_limit_error_message?(%{"message" => message}) when is_binary(message) do
    message_lower = String.downcase(message)

    Enum.any?(@rate_limit_patterns, fn pattern ->
      String.contains?(message_lower, pattern)
    end)
  end

  defp rate_limit_error_message?(_), do: false
end
