defmodule WeaviateEx.Protocol.HTTP.Retry do
  @moduledoc """
  HTTP transport-level retry with exponential backoff and jitter.

  Mirrors gRPC retry behavior for HTTP operations. Retries on:

  ## Transport Errors
  - Connection refused (:econnrefused)
  - Connection reset (:econnreset)
  - Timeout (:timeout)
  - Connection closed (:closed)
  - DNS resolution failed (:nxdomain)

  ## HTTP Status Codes
  - 408 Request Timeout
  - 429 Too Many Requests (rate limit)
  - 500 Internal Server Error
  - 502 Bad Gateway
  - 503 Service Unavailable
  - 504 Gateway Timeout

  ## Usage

      alias WeaviateEx.Protocol.HTTP.Retry

      result = Retry.with_retry(fn ->
        Finch.request(request, WeaviateEx.Finch, receive_timeout: timeout)
      end)

  ## Options

    * `:max_retries` - Maximum number of retry attempts (default: 3)
    * `:base_delay_ms` - Base delay in milliseconds for backoff calculation (default: 100)
    * `:max_delay_ms` - Maximum delay cap in milliseconds (default: 5000)

  ## Backoff Strategy

  Uses exponential backoff with jitter: `min(2^attempt * base_delay_ms, max_delay_ms)`
  plus random jitter of ±10%.

  Attempt 0: ~100ms (with jitter)
  Attempt 1: ~200ms (with jitter)
  Attempt 2: ~400ms (with jitter)
  Attempt 3: ~800ms (with jitter)
  ...capped at max_delay_ms
  """

  alias WeaviateEx.Error

  @default_max_retries 3
  @default_base_delay_ms 100
  @default_max_delay_ms 5_000

  # Transport errors that are safe to retry
  @retryable_reasons [:econnrefused, :econnreset, :timeout, :closed, :nxdomain]

  # HTTP status codes that are safe to retry
  @retryable_status_codes [408, 429, 500, 502, 503, 504]

  @type retry_opts :: [
          max_retries: non_neg_integer(),
          base_delay_ms: non_neg_integer(),
          max_delay_ms: non_neg_integer()
        ]

  @doc """
  Execute a function with automatic retry on transient errors.

  Retries on transport errors (connection refused, timeout, etc.) and
  retryable HTTP status codes (429, 500, 502, 503, 504, 408).

  ## Options

    * `:max_retries` - Maximum retry attempts (default: 3)
    * `:base_delay_ms` - Base delay for exponential backoff (default: 100)
    * `:max_delay_ms` - Maximum delay cap (default: 5000)

  ## Examples

      Retry.with_retry(fn ->
        Finch.request(request, WeaviateEx.Finch, receive_timeout: 30_000)
      end)

      Retry.with_retry(
        fn -> Finch.request(request, WeaviateEx.Finch, receive_timeout: 30_000) end,
        max_retries: 5,
        base_delay_ms: 200,
        max_delay_ms: 10_000
      )
  """
  @spec with_retry((-> result), retry_opts()) :: result when result: any()
  def with_retry(fun, opts \\ []) when is_function(fun, 0) do
    max_retries = Keyword.get(opts, :max_retries, @default_max_retries)
    base_delay_ms = Keyword.get(opts, :base_delay_ms, @default_base_delay_ms)
    max_delay_ms = Keyword.get(opts, :max_delay_ms, @default_max_delay_ms)

    do_retry(fun, 0, max_retries, base_delay_ms, max_delay_ms)
  end

  @doc """
  Calculate exponential backoff delay with jitter for a given attempt number.

  Returns delay in milliseconds with ±10% jitter, capped at max_delay_ms.

  ## Examples

      Retry.calculate_backoff(0)  # => ~100ms (with jitter)
      Retry.calculate_backoff(1)  # => ~200ms (with jitter)
      Retry.calculate_backoff(2)  # => ~400ms (with jitter)
      Retry.calculate_backoff(10) # => ~5000ms (capped at max_delay_ms)
  """
  @spec calculate_backoff(non_neg_integer()) :: non_neg_integer()
  def calculate_backoff(attempt) when is_integer(attempt) and attempt >= 0 do
    calculate_backoff_with_jitter(attempt, @default_base_delay_ms, @default_max_delay_ms)
  end

  @doc """
  Check if an error is a retryable transport error.

  Returns true for transient transport errors that are safe to retry:
  - Connection refused
  - Connection reset
  - Timeout
  - Connection closed
  - DNS resolution failed

  ## Examples

      Retry.retryable_transport_error?(%Mint.TransportError{reason: :econnrefused})  # => true
      Retry.retryable_transport_error?(%Mint.TransportError{reason: :invalid_cert})  # => false
      Retry.retryable_transport_error?({:error, %Mint.TransportError{reason: :timeout}})  # => true
  """
  @spec retryable_transport_error?(term()) :: boolean()
  def retryable_transport_error?({:error, error}) do
    retryable_transport_error?(error)
  end

  def retryable_transport_error?(%Mint.TransportError{reason: reason}) do
    reason in @retryable_reasons
  end

  def retryable_transport_error?(_other) do
    false
  end

  @doc """
  Check if an HTTP status code is retryable.

  Retryable status codes: 408, 429, 500, 502, 503, 504

  ## Examples

      Retry.retryable_status_code?(503)  # => true
      Retry.retryable_status_code?(429)  # => true
      Retry.retryable_status_code?(400)  # => false
      Retry.retryable_status_code?(404)  # => false
  """
  @spec retryable_status_code?(integer()) :: boolean()
  def retryable_status_code?(status) when is_integer(status) do
    status in @retryable_status_codes
  end

  @doc """
  Returns the list of retryable HTTP status codes.

  ## Examples

      Retry.retryable_status_codes()
      # => [408, 429, 500, 502, 503, 504]
  """
  @spec retryable_status_codes() :: [integer()]
  def retryable_status_codes, do: @retryable_status_codes

  @doc """
  Returns the default retry options.

  ## Examples

      Retry.default_retry_opts()
      # => [max_retries: 3, base_delay_ms: 100, max_delay_ms: 5000]
  """
  @spec default_retry_opts() :: retry_opts()
  def default_retry_opts do
    [
      max_retries: @default_max_retries,
      base_delay_ms: @default_base_delay_ms,
      max_delay_ms: @default_max_delay_ms
    ]
  end

  # Private implementation

  defp do_retry(fun, attempt, max_retries, base_delay_ms, max_delay_ms) do
    case fun.() do
      {:ok, %Finch.Response{status: status} = response} ->
        handle_http_response(
          fun,
          response,
          status,
          attempt,
          max_retries,
          base_delay_ms,
          max_delay_ms
        )

      {:ok, response} ->
        {:ok, response}

      {:error, %Mint.TransportError{} = error} ->
        handle_transport_error(fun, error, attempt, max_retries, base_delay_ms, max_delay_ms)

      {:error, _} = error ->
        # Non-transport error, don't retry
        error

      other ->
        # Pass through non-standard responses
        other
    end
  end

  defp handle_http_response(
         fun,
         response,
         status,
         attempt,
         max_retries,
         base_delay_ms,
         max_delay_ms
       ) do
    cond do
      status >= 200 and status < 300 ->
        # Success
        {:ok, response}

      retryable_status_code?(status) and attempt < max_retries ->
        # Retryable status code, retry with backoff
        delay = calculate_backoff_with_jitter(attempt, base_delay_ms, max_delay_ms)
        Process.sleep(delay)
        do_retry(fun, attempt + 1, max_retries, base_delay_ms, max_delay_ms)

      retryable_status_code?(status) ->
        # Exhausted all retries for HTTP status error
        {:error, retry_exhausted_http_error(response, status, attempt, max_retries)}

      true ->
        # Non-retryable status code (4xx client errors, etc.)
        {:ok, response}
    end
  end

  defp handle_transport_error(fun, error, attempt, max_retries, base_delay_ms, max_delay_ms) do
    cond do
      retryable_transport_error?(error) and attempt < max_retries ->
        delay = calculate_backoff_with_jitter(attempt, base_delay_ms, max_delay_ms)
        Process.sleep(delay)
        do_retry(fun, attempt + 1, max_retries, base_delay_ms, max_delay_ms)

      retryable_transport_error?(error) ->
        # Exhausted all retries
        {:error, retry_exhausted_transport_error(error, attempt, max_retries)}

      true ->
        # Not retryable (e.g., SSL certificate error)
        {:error, error}
    end
  end

  defp retry_exhausted_transport_error(error, attempt, max_retries) do
    Error.exception(
      type: :retry_exhausted,
      message: "Exhausted #{max_retries} retry attempts. Last error: #{inspect(error.reason)}",
      details: %{
        attempts: attempt + 1,
        last_error: error.reason
      }
    )
  end

  defp retry_exhausted_http_error(_response, status, attempt, max_retries) do
    Error.exception(
      type: :retry_exhausted,
      message: "Exhausted #{max_retries} retry attempts. Last status: #{status}",
      details: %{
        attempts: attempt + 1,
        last_status: status
      }
    )
  end

  defp calculate_backoff_with_jitter(attempt, base_delay_ms, max_delay_ms) do
    # Exponential backoff: base_delay_ms * 2^attempt
    delay = (base_delay_ms * :math.pow(2, attempt)) |> trunc()

    # Cap at max_delay
    delay = min(delay, max_delay_ms)

    # Add jitter (+/- 10%)
    add_jitter(delay)
  end

  defp add_jitter(delay) do
    jitter = delay * 0.1
    jitter_amount = :rand.uniform() * jitter * 2 - jitter
    trunc(delay + jitter_amount)
  end
end
