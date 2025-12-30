defmodule WeaviateEx.Protocol.HTTP.Retry do
  @moduledoc """
  HTTP transport-level retry with exponential backoff.

  Retries on transient transport errors:
  - Connection refused (:econnrefused)
  - Connection reset (:econnreset)
  - Timeout (:timeout)
  - Connection closed (:closed)
  - DNS resolution failed (:nxdomain)

  This module provides transport-level retry similar to Python's httpx transport retries.
  It does NOT retry on HTTP error responses (4xx, 5xx) - those are application-level errors.

  ## Usage

      alias WeaviateEx.Protocol.HTTP.Retry

      result = Retry.with_retry(fn ->
        Finch.request(request, WeaviateEx.Finch, receive_timeout: timeout)
      end)

  ## Options

    * `:max_retries` - Maximum number of retry attempts (default: 3)
    * `:base_delay_ms` - Base delay in milliseconds for backoff calculation (default: 500)

  ## Backoff Strategy

  Uses exponential backoff: `min(2^attempt * base_delay_ms, 32000)` milliseconds.

  Attempt 0: 500ms
  Attempt 1: 1 second
  Attempt 2: 2 seconds
  Attempt 3: 4 seconds
  Attempt 4+: capped at 32 seconds
  """

  alias WeaviateEx.Error

  @default_max_retries 3
  @default_base_delay_ms 500
  @max_backoff_ms 32_000

  # Transport errors that are safe to retry
  @retryable_reasons [:econnrefused, :econnreset, :timeout, :closed, :nxdomain]

  @doc """
  Execute a function with automatic retry on transient transport errors.

  ## Options

    * `:max_retries` - Maximum retry attempts (default: 3)
    * `:base_delay_ms` - Base delay for exponential backoff (default: 500)

  ## Examples

      Retry.with_retry(fn ->
        Finch.request(request, WeaviateEx.Finch, receive_timeout: 30_000)
      end)

      Retry.with_retry(
        fn -> Finch.request(request, WeaviateEx.Finch, receive_timeout: 30_000) end,
        max_retries: 5
      )
  """
  @spec with_retry((-> result), keyword()) :: result when result: any()
  def with_retry(fun, opts \\ []) when is_function(fun, 0) do
    max_retries = Keyword.get(opts, :max_retries, @default_max_retries)
    base_delay_ms = Keyword.get(opts, :base_delay_ms, @default_base_delay_ms)

    do_retry(fun, 0, max_retries, base_delay_ms)
  end

  @doc """
  Calculate exponential backoff delay for a given attempt number.

  Returns delay in milliseconds, capped at 32 seconds.

  ## Examples

      Retry.calculate_backoff(0)  # => 500 (0.5 seconds)
      Retry.calculate_backoff(1)  # => 1000 (1 second)
      Retry.calculate_backoff(2)  # => 2000 (2 seconds)
      Retry.calculate_backoff(6)  # => 32000 (32 seconds, capped)
  """
  @spec calculate_backoff(non_neg_integer()) :: non_neg_integer()
  def calculate_backoff(attempt) when is_integer(attempt) and attempt >= 0 do
    delay = :math.pow(2, attempt) * @default_base_delay_ms
    min(trunc(delay), @max_backoff_ms)
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

  # Private implementation

  defp do_retry(fun, attempt, max_retries, base_delay_ms) do
    case fun.() do
      {:ok, _} = result ->
        result

      {:error, %Mint.TransportError{} = error} ->
        handle_transport_error(fun, error, attempt, max_retries, base_delay_ms)

      {:error, _} = error ->
        # Non-transport error, don't retry
        error

      other ->
        # Pass through non-standard responses (shouldn't happen with Finch)
        other
    end
  end

  defp handle_transport_error(fun, error, attempt, max_retries, base_delay_ms) do
    cond do
      retryable_transport_error?(error) and attempt < max_retries ->
        delay = calculate_backoff_with_base(attempt, base_delay_ms)
        Process.sleep(delay)
        do_retry(fun, attempt + 1, max_retries, base_delay_ms)

      retryable_transport_error?(error) ->
        # Exhausted all retries
        {:error, retry_exhausted_error(error, attempt, max_retries)}

      true ->
        # Not retryable (e.g., SSL certificate error)
        {:error, error}
    end
  end

  defp retry_exhausted_error(error, attempt, max_retries) do
    Error.exception(
      type: :retry_exhausted,
      message: "Exhausted #{max_retries} retry attempts. Last error: #{inspect(error.reason)}",
      details: %{
        attempts: attempt + 1,
        last_error: error.reason
      }
    )
  end

  defp calculate_backoff_with_base(attempt, base_delay_ms) do
    delay = :math.pow(2, attempt) * base_delay_ms
    min(trunc(delay), @max_backoff_ms)
  end
end
