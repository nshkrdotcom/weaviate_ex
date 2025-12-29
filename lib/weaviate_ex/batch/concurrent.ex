defmodule WeaviateEx.Batch.Concurrent do
  @moduledoc """
  Concurrent batch operations for high-throughput data insertion.

  Provides parallel batch processing using `Task.async_stream` to maximize
  insertion throughput while managing concurrency limits.

  ## Features

  - Configurable concurrency level
  - Automatic batch splitting
  - Result aggregation
  - Optional ordered results
  - Graceful partial failure handling

  ## Examples

      # Insert many objects concurrently
      objects = [
        %{class: "Article", properties: %{title: "First"}},
        %{class: "Article", properties: %{title: "Second"}}
      ]

      {:ok, result} = Concurrent.insert_many(client, "Article", objects,
        max_concurrency: 4,
        batch_size: 100
      )

      IO.puts("Inserted: \#{result.successful_count}")
      IO.puts("Failed: \#{result.failed_count}")
  """

  alias WeaviateEx.API.Batch
  alias WeaviateEx.Client

  defmodule Result do
    @moduledoc """
    Result of a concurrent batch operation.
    """

    defstruct [
      :successful,
      :failed,
      :successful_count,
      :failed_count,
      :batch_errors,
      :total_batches,
      :execution_time_ms
    ]

    @type t :: %__MODULE__{
            successful: [map()],
            failed: [map()],
            successful_count: non_neg_integer(),
            failed_count: non_neg_integer(),
            batch_errors: non_neg_integer(),
            total_batches: non_neg_integer(),
            execution_time_ms: non_neg_integer()
          }

    @doc """
    Checks if all objects were inserted successfully.
    """
    @spec all_successful?(t()) :: boolean()
    def all_successful?(%__MODULE__{failed_count: 0, batch_errors: 0}), do: true
    def all_successful?(%__MODULE__{}), do: false

    @doc """
    Checks if there were any failures.
    """
    @spec has_failures?(t()) :: boolean()
    def has_failures?(%__MODULE__{} = result) do
      result.failed_count > 0 or result.batch_errors > 0
    end

    @doc """
    Returns a summary of the batch operation.
    """
    @spec summary(t()) :: String.t()
    def summary(%__MODULE__{} = result) do
      "Inserted #{result.successful_count}/#{result.successful_count + result.failed_count} objects " <>
        "in #{result.total_batches} batches (#{result.execution_time_ms}ms). " <>
        "Failures: #{result.failed_count}, Batch errors: #{result.batch_errors}"
    end
  end

  @default_options [
    max_concurrency: 4,
    batch_size: 100,
    ordered: false,
    timeout: 30_000
  ]

  @doc """
  Returns the default options for concurrent batch operations.
  """
  @spec default_options() :: keyword()
  def default_options, do: @default_options

  @doc """
  Merges custom options with defaults.
  """
  @spec merge_options(keyword()) :: keyword()
  def merge_options(opts) do
    Keyword.merge(@default_options, opts)
  end

  @doc """
  Inserts many objects concurrently using parallel batch requests.

  ## Options

    - `:max_concurrency` - Number of parallel batch requests (default: 4)
    - `:batch_size` - Objects per request (default: 100)
    - `:ordered` - Maintain insertion order in results (default: false)
    - `:timeout` - Timeout per batch in milliseconds (default: 30_000)

  ## Examples

      {:ok, result} = Concurrent.insert_many(client, "Article", objects)
      {:ok, result} = Concurrent.insert_many(client, "Article", objects,
        max_concurrency: 8,
        batch_size: 50
      )
  """
  @spec insert_many(Client.t(), String.t(), [map()], keyword()) ::
          {:ok, Result.t()} | {:error, term()}
  def insert_many(client, collection, objects, opts \\ []) do
    opts = merge_options(opts)
    start_time = System.monotonic_time(:millisecond)

    batches = split_into_batches(objects, opts)
    total_batches = length(batches)

    # Execute batches concurrently
    batch_results =
      batches
      |> Enum.with_index()
      |> Task.async_stream(
        fn {batch, index} ->
          execute_batch(client, collection, batch, index, opts)
        end,
        max_concurrency: opts[:max_concurrency],
        timeout: opts[:timeout],
        on_timeout: :kill_task
      )
      |> Enum.map(fn
        {:ok, result} -> result
        {:exit, :timeout} -> {:error, %{message: "Batch timeout"}}
        {:exit, reason} -> {:error, %{message: "Batch failed: #{inspect(reason)}"}}
      end)

    end_time = System.monotonic_time(:millisecond)
    execution_time = end_time - start_time

    result = aggregate_results(batch_results, opts)
    result = %{result | total_batches: total_batches, execution_time_ms: execution_time}

    {:ok, result}
  end

  @doc """
  Splits objects into batches based on batch_size option.
  """
  @spec split_into_batches([map()], keyword()) :: [[map()]]
  def split_into_batches(objects, opts) do
    batch_size = Keyword.get(opts, :batch_size, 100)
    Enum.chunk_every(objects, batch_size)
  end

  @doc """
  Aggregates results from multiple batch operations.
  """
  @spec aggregate_results([{:ok, map()} | {:error, term()}], keyword()) :: Result.t()
  def aggregate_results(batch_results, opts \\ []) do
    ordered = Keyword.get(opts, :ordered, false)

    initial = %{
      successful: [],
      failed: [],
      successful_count: 0,
      failed_count: 0,
      batch_errors: 0
    }

    aggregated =
      Enum.reduce(batch_results, initial, fn
        {:ok, %{successful: successful, failed: failed}}, acc ->
          %{
            acc
            | successful: acc.successful ++ successful,
              failed: acc.failed ++ failed,
              successful_count: acc.successful_count + length(successful),
              failed_count: acc.failed_count + length(failed)
          }

        {:error, _reason}, acc ->
          %{acc | batch_errors: acc.batch_errors + 1}
      end)

    # Sort by batch index if ordered
    successful =
      if ordered do
        Enum.sort_by(aggregated.successful, &Map.get(&1, :_batch_index, 0))
      else
        aggregated.successful
      end

    %Result{
      successful: successful,
      failed: aggregated.failed,
      successful_count: aggregated.successful_count,
      failed_count: aggregated.failed_count,
      batch_errors: aggregated.batch_errors,
      total_batches: 0,
      execution_time_ms: 0
    }
  end

  @doc """
  Checks if an error is retryable.
  """
  @spec retryable_error?(term()) :: boolean()
  def retryable_error?({:error, %{status: status}}) when status in [429, 500, 502, 503, 504] do
    true
  end

  def retryable_error?({:error, %{message: message}}) when is_binary(message) do
    String.contains?(message, ["timeout", "connection", "UNAVAILABLE"])
  end

  def retryable_error?(_), do: false

  # Execute a single batch
  defp execute_batch(client, collection, objects, batch_index, opts) do
    # Prepare objects for batch insert
    prepared_objects =
      objects
      |> Enum.map(fn obj ->
        obj
        |> Map.put_new("class", collection)
        |> Map.put(:_batch_index, batch_index)
      end)

    # Use the Batch API to insert
    case Batch.create_objects(client, prepared_objects, opts) do
      {:ok, %Batch.Result{} = result} ->
        # Batch.Result has successful and errors lists
        successful =
          result.successful
          |> Enum.map(&Map.put(&1, :_batch_index, batch_index))

        failed =
          result.errors
          |> Enum.map(fn err ->
            %{
              id: err.id,
              error: Enum.join(err.messages, "; "),
              raw: err.raw,
              _batch_index: batch_index
            }
          end)

        {:ok, %{successful: successful, failed: failed}}

      {:ok, result} when is_map(result) ->
        # Handle other map results
        {:ok, %{successful: [Map.put(result, :_batch_index, batch_index)], failed: []}}

      {:error, _} = error ->
        error
    end
  end
end
