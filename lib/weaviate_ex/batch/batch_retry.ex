defmodule WeaviateEx.Batch.BatchRetry do
  @moduledoc """
  Retry logic for batch operations with rate limit detection.

  Provides exponential backoff and automatic retry for transient failures,
  especially rate limit errors from vectorizer APIs (OpenAI, Cohere, etc.).

  ## Examples

      if BatchRetry.should_retry?(error_message, retry_count) do
        Process.sleep(BatchRetry.calculate_backoff(retry_count))
        retry_operation()
      end
  """

  @max_retries 5
  @max_backoff_ms 30_000

  @doc """
  Check if an error message indicates a rate limit error.

  Detects rate limit errors from various vectorizer APIs including
  OpenAI, Cohere, and others.
  """
  @spec rate_limit_error?(String.t() | nil) :: boolean()
  def rate_limit_error?(nil), do: false

  def rate_limit_error?(message) when is_binary(message) do
    patterns = [
      ~r/rate limit/i,
      ~r/Rate limit reached/i,
      ~r/tokens per min/i,
      ~r/support@cohere\.com/,
      ~r/503 error/i,
      ~r/too many requests/i,
      ~r/retry after/i
    ]

    Enum.any?(patterns, &Regex.match?(&1, message))
  end

  @doc """
  Calculate the backoff delay in milliseconds for a given retry attempt.

  Uses exponential backoff: 2^attempt * 1000 ms, capped at max_backoff.
  """
  @spec calculate_backoff(non_neg_integer()) :: non_neg_integer()
  def calculate_backoff(attempt) when is_integer(attempt) and attempt >= 0 do
    delay = trunc(:math.pow(2, attempt) * 1000)
    min(delay, @max_backoff_ms)
  end

  @doc """
  Determine if an operation should be retried based on the error and attempt count.

  Only rate limit errors are eligible for retry, and only up to max_retries.
  """
  @spec should_retry?(String.t() | nil, non_neg_integer()) :: boolean()
  def should_retry?(error_message, retry_count) do
    retry_count < @max_retries and rate_limit_error?(error_message)
  end

  @doc """
  Get the maximum number of retry attempts.
  """
  @spec max_retries() :: non_neg_integer()
  def max_retries, do: @max_retries

  @doc """
  Execute a function with automatic retry on rate limit errors.

  ## Options

    - `:max_retries` - Maximum retry attempts (default: 5)
    - `:on_retry` - Callback function called before each retry with (attempt, error)

  ## Examples

      BatchRetry.with_retry(fn ->
        send_batch(objects)
      end)
  """
  @spec with_retry((-> {:ok, term()} | {:error, term()}), keyword()) ::
          {:ok, term()} | {:error, term()}
  def with_retry(fun, opts \\ []) when is_function(fun, 0) do
    max = Keyword.get(opts, :max_retries, @max_retries)
    on_retry = Keyword.get(opts, :on_retry)

    do_retry(fun, 0, max, on_retry)
  end

  defp do_retry(_fun, attempt, max, _on_retry) when attempt >= max do
    {:error, :max_retries_exceeded}
  end

  defp do_retry(fun, attempt, max, on_retry) do
    case fun.() do
      {:ok, result} ->
        {:ok, result}

      {:error, %{message: message} = error} when is_binary(message) ->
        maybe_retry(fun, attempt, max, on_retry, message, error)

      {:error, message} when is_binary(message) ->
        maybe_retry(fun, attempt, max, on_retry, message, message)

      {:error, _reason} = error ->
        error
    end
  end

  defp maybe_retry(fun, attempt, max, on_retry, message, error) do
    if rate_limit_error?(message) do
      if on_retry, do: on_retry.(attempt, error)
      Process.sleep(calculate_backoff(attempt))
      do_retry(fun, attempt + 1, max, on_retry)
    else
      {:error, error}
    end
  end
end
