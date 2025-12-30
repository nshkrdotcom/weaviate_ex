defmodule WeaviateEx.GRPC.Retry do
  @moduledoc """
  Exponential backoff retry mechanism for gRPC calls.

  Automatically retries gRPC calls that fail with transient errors:
  - UNAVAILABLE (14)
  - RESOURCE_EXHAUSTED (8)
  - ABORTED (10)
  - DEADLINE_EXCEEDED (4)

  ## Usage

      alias WeaviateEx.GRPC.Retry

      result = Retry.with_retry(fn ->
        WeaviateStub.search(channel, request, opts)
      end)

  ## Options

    * `:max_retries` - Maximum number of retry attempts (default: 4)
    * `:base_delay_ms` - Base delay in milliseconds for backoff calculation (default: 1000)

  ## Backoff Strategy

  Uses exponential backoff: `min(2^attempt * base_delay_ms, 32000)` milliseconds.

  Attempt 0: 1 second
  Attempt 1: 2 seconds
  Attempt 2: 4 seconds
  Attempt 3: 8 seconds
  Attempt 4+: 32 seconds (capped)
  """

  alias WeaviateEx.Error

  @default_max_retries 4
  @default_base_delay_ms 1000
  @max_backoff_ms 32_000

  # gRPC status codes that are retryable
  @unavailable 14
  @resource_exhausted 8
  @aborted 10
  @deadline_exceeded 4

  @doc """
  Execute a function with automatic retry on transient gRPC errors.

  ## Options

    * `:max_retries` - Maximum retry attempts (default: 4)
    * `:base_delay_ms` - Base delay for exponential backoff (default: 1000)

  ## Examples

      Retry.with_retry(fn ->
        WeaviateStub.search(channel, request, opts)
      end)

      Retry.with_retry(
        fn -> WeaviateStub.search(channel, request, opts) end,
        max_retries: 3
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

      Retry.calculate_backoff(0)  # => 1000 (1 second)
      Retry.calculate_backoff(1)  # => 2000 (2 seconds)
      Retry.calculate_backoff(2)  # => 4000 (4 seconds)
      Retry.calculate_backoff(5)  # => 32000 (32 seconds, capped)
  """
  @spec calculate_backoff(non_neg_integer()) :: non_neg_integer()
  def calculate_backoff(attempt) when is_integer(attempt) and attempt >= 0 do
    delay = :math.pow(2, attempt) * 1000
    min(trunc(delay), @max_backoff_ms)
  end

  @doc """
  Check if a gRPC error is retryable.

  ## Examples

      Retry.retryable?(%GRPC.RPCError{status: 14})  # => true (unavailable)
      Retry.retryable?(%GRPC.RPCError{status: 3})   # => false (invalid argument)
  """
  @spec retryable?(GRPC.RPCError.t()) :: boolean()
  def retryable?(%GRPC.RPCError{status: status}) do
    retryable_status?(status)
  end

  @doc """
  Check if a gRPC status code is retryable.

  Retryable status codes:
  - 4: DEADLINE_EXCEEDED
  - 8: RESOURCE_EXHAUSTED
  - 10: ABORTED
  - 14: UNAVAILABLE

  ## Examples

      Retry.retryable_status?(14)  # => true
      Retry.retryable_status?(3)   # => false
  """
  @spec retryable_status?(integer()) :: boolean()
  def retryable_status?(status) when is_integer(status) do
    status in [@unavailable, @resource_exhausted, @aborted, @deadline_exceeded]
  end

  # Private implementation

  defp do_retry(fun, attempt, max_retries, base_delay_ms) do
    case fun.() do
      {:ok, result} ->
        {:ok, result}

      {:error, %GRPC.RPCError{} = error} ->
        handle_grpc_error(fun, error, attempt, max_retries, base_delay_ms)

      other ->
        # Pass through non-standard responses
        other
    end
  end

  defp handle_grpc_error(fun, error, attempt, max_retries, base_delay_ms) do
    cond do
      retryable?(error) and attempt < max_retries ->
        delay = calculate_backoff_with_base(attempt, base_delay_ms)
        Process.sleep(delay)
        do_retry(fun, attempt + 1, max_retries, base_delay_ms)

      retryable?(error) ->
        # Exhausted all retries
        {:error, retry_exhausted_error(error, attempt, max_retries)}

      true ->
        # Not retryable, return the original error
        {:error, error}
    end
  end

  defp retry_exhausted_error(error, attempt, max_retries) do
    Error.exception(
      type: :retry_exhausted,
      message: "Exhausted #{max_retries} retry attempts. Last error: #{error.message}",
      details: %{
        attempts: attempt + 1,
        last_status: error.status,
        last_message: error.message
      }
    )
  end

  defp calculate_backoff_with_base(attempt, base_delay_ms) do
    delay = :math.pow(2, attempt) * base_delay_ms
    min(trunc(delay), @max_backoff_ms)
  end
end
