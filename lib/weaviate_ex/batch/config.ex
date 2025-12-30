defmodule WeaviateEx.Batch.Config do
  @moduledoc """
  Configuration options for batch operations.

  This module provides centralized configuration for batch safety features
  including MAX_STORED_RESULTS limits, auto-retry settings, and callbacks.

  ## Examples

      # Create config with defaults
      config = Batch.Config.new()

      # Customize options
      config = Batch.Config.new(
        max_stored_results: 50_000,
        auto_retry: true,
        max_retries: 5,
        retry_delay_ms: 2000,
        on_permanent_failure: fn objects ->
          Logger.error("Permanent failures: \#{length(objects)}")
        end
      )

      # Use with batch operations
      {:ok, results} = Batch.with_batch(client, [config: config], fn batch ->
        batch |> Batch.add_object("Article", %{title: "Test"})
      end)
  """

  @default_max_stored_results 100_000
  @default_auto_retry true
  @default_max_retries 3
  @default_retry_delay_ms 1000
  @default_max_retry_delay_ms 60_000

  @type t :: %__MODULE__{
          max_stored_results: pos_integer(),
          auto_retry: boolean(),
          max_retries: pos_integer(),
          retry_delay_ms: pos_integer(),
          max_retry_delay_ms: pos_integer(),
          on_permanent_failure: ([map()] -> any()) | nil,
          on_retry: ([map()], non_neg_integer() -> any()) | nil
        }

  defstruct max_stored_results: @default_max_stored_results,
            auto_retry: @default_auto_retry,
            max_retries: @default_max_retries,
            retry_delay_ms: @default_retry_delay_ms,
            max_retry_delay_ms: @default_max_retry_delay_ms,
            on_permanent_failure: nil,
            on_retry: nil

  @doc """
  Create a new batch configuration with optional overrides.

  ## Options

    - `:max_stored_results` - Maximum stored result UUIDs (default: 100,000)
    - `:auto_retry` - Automatically re-queue failed objects (default: true)
    - `:max_retries` - Maximum retry attempts per object (default: 3)
    - `:retry_delay_ms` - Base delay for retry backoff in ms (default: 1000)
    - `:max_retry_delay_ms` - Maximum retry delay in ms (default: 60,000)
    - `:on_permanent_failure` - Callback for objects exceeding max_retries
    - `:on_retry` - Callback when objects are retried

  ## Examples

      config = Config.new(max_retries: 5)
      config = Config.new(auto_retry: false)
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      max_stored_results: Keyword.get(opts, :max_stored_results, @default_max_stored_results),
      auto_retry: Keyword.get(opts, :auto_retry, @default_auto_retry),
      max_retries: Keyword.get(opts, :max_retries, @default_max_retries),
      retry_delay_ms: Keyword.get(opts, :retry_delay_ms, @default_retry_delay_ms),
      max_retry_delay_ms: Keyword.get(opts, :max_retry_delay_ms, @default_max_retry_delay_ms),
      on_permanent_failure: Keyword.get(opts, :on_permanent_failure),
      on_retry: Keyword.get(opts, :on_retry)
    }
  end

  @doc """
  Get the default maximum stored results.
  """
  @spec default_max_stored_results() :: pos_integer()
  def default_max_stored_results, do: @default_max_stored_results

  @doc """
  Get the default retry delay in milliseconds.
  """
  @spec default_retry_delay_ms() :: pos_integer()
  def default_retry_delay_ms, do: @default_retry_delay_ms

  @doc """
  Get the default maximum retries.
  """
  @spec default_max_retries() :: pos_integer()
  def default_max_retries, do: @default_max_retries

  @doc """
  Check if auto-retry is enabled in the config.
  """
  @spec auto_retry_enabled?(t()) :: boolean()
  def auto_retry_enabled?(%__MODULE__{auto_retry: auto_retry}), do: auto_retry

  @doc """
  Merge two configurations, with the second taking precedence.
  """
  @spec merge(t(), t() | keyword()) :: t()
  def merge(%__MODULE__{} = base, %__MODULE__{} = override) do
    merge(base, Map.to_list(override))
  end

  def merge(%__MODULE__{} = base, opts) when is_list(opts) do
    Enum.reduce(opts, base, fn
      {:__struct__, _}, acc -> acc
      {_key, nil}, acc -> acc
      {key, value}, acc -> Map.put(acc, key, value)
    end)
  end

  @doc """
  Convert config to keyword list (for passing to functions).
  """
  @spec to_keyword(t()) :: keyword()
  def to_keyword(%__MODULE__{} = config) do
    config
    |> Map.from_struct()
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Keyword.new()
  end
end
