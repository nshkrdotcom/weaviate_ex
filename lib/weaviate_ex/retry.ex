defmodule WeaviateEx.Retry do
  @moduledoc """
  Retry logic with exponential backoff for Weaviate operations.

  Automatically retries operations that fail with transient errors
  (rate limits, service unavailable, timeouts) using exponential
  backoff with jitter.

  ## Examples

      Retry.with_exponential_backoff(fn ->
        WeaviateEx.Client.request(client, :post, "/v1/objects", object)
      end)

      Retry.with_exponential_backoff(
        fn -> expensive_operation() end,
        max_retries: 5,
        base_delay: 200,
        max_delay: 10_000
      )
  """

  @type error :: map() | term()
  @type retry_opts :: [
          max_retries: pos_integer(),
          base_delay: pos_integer(),
          max_delay: pos_integer()
        ]

  @default_max_retries 3
  @default_base_delay 100
  @default_max_delay 5_000

  # Retryable HTTP status codes
  @retryable_statuses [429, 502, 503, 504]

  # Retryable error reasons
  @retryable_reasons [:timeout, :econnrefused, :econnreset, :closed, :nxdomain]

  @doc """
  Execute function with exponential backoff retry.

  ## Options

    - `:max_retries` - Maximum retry attempts (default: 3)
    - `:base_delay` - Initial delay in milliseconds (default: 100)
    - `:max_delay` - Maximum delay cap in milliseconds (default: 5000)

  ## Examples

      Retry.with_exponential_backoff(fn ->
        {:ok, result}
      end)

      Retry.with_exponential_backoff(
        fn -> risky_operation() end,
        max_retries: 5,
        base_delay: 200
      )
  """
  @spec with_exponential_backoff((-> {:ok, term()} | {:error, term()}), retry_opts()) ::
          {:ok, term()} | {:error, term()}
  def with_exponential_backoff(fun, opts \\ []) when is_function(fun, 0) do
    max_retries = Keyword.get(opts, :max_retries, @default_max_retries)
    base_delay = Keyword.get(opts, :base_delay, @default_base_delay)
    max_delay = Keyword.get(opts, :max_delay, @default_max_delay)

    do_retry(fun, 0, max_retries, base_delay, max_delay)
  end

  @doc """
  Check if an error is retryable.

  Retryable errors include:
  - HTTP 429 (Rate Limited)
  - HTTP 502 (Bad Gateway)
  - HTTP 503 (Service Unavailable)
  - HTTP 504 (Gateway Timeout)
  - Connection errors (timeout, connection refused, etc.)

  ## Examples

      Retry.retryable?(%{status: 429})
      # => true

      Retry.retryable?(%{status: 400})
      # => false

      Retry.retryable?(%{reason: :timeout})
      # => true
  """
  @spec retryable?(error()) :: boolean()
  def retryable?(%{status: status}) when status in @retryable_statuses, do: true
  def retryable?(%{reason: reason}) when reason in @retryable_reasons, do: true
  def retryable?(_error), do: false

  @doc """
  Calculate delay for retry attempt with jitter.

  Uses exponential backoff: `base_delay * 2^attempt` with +/- 10% jitter,
  capped at max_delay.

  ## Examples

      Retry.calculate_delay(0, 100, 5000)
      # => ~100 (with jitter)

      Retry.calculate_delay(3, 100, 5000)
      # => ~800 (with jitter)
  """
  @spec calculate_delay(non_neg_integer(), pos_integer(), pos_integer()) :: pos_integer()
  def calculate_delay(attempt, base_delay, max_delay) do
    # Exponential backoff: base_delay * 2^attempt
    delay = (base_delay * :math.pow(2, attempt)) |> trunc()

    # Cap at max_delay
    delay = min(delay, max_delay)

    # Add jitter (+/- 10%)
    jitter = delay * 0.1
    jitter_amount = :rand.uniform() * jitter * 2 - jitter
    trunc(delay + jitter_amount)
  end

  # Private implementation

  defp do_retry(fun, attempt, max_retries, base_delay, max_delay) do
    case fun.() do
      {:ok, result} ->
        {:ok, result}

      {:error, error} = err ->
        if attempt < max_retries and retryable?(error) do
          delay = calculate_delay(attempt, base_delay, max_delay)
          Process.sleep(delay)
          do_retry(fun, attempt + 1, max_retries, base_delay, max_delay)
        else
          err
        end

      other ->
        other
    end
  end
end
