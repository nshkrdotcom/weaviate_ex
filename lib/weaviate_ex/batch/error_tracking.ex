defmodule WeaviateEx.Batch.ErrorTracking do
  @moduledoc """
  Error tracking structures for batch operations.

  Provides detailed error information for failed objects and references
  during batch operations.

  ## Examples

      alias WeaviateEx.Batch.ErrorTracking.{ErrorObject, Results}

      results = Results.new()
        |> Results.add_success(0, "uuid-123")
        |> Results.add_error(%ErrorObject{message: "Invalid", object: %{title: "Bad"}})

      Results.has_errors?(results)  # => true
      Results.number_errors(results)  # => 1
  """

  defmodule ErrorObject do
    @moduledoc """
    Represents a failed object in a batch operation.

    ## Fields

      - `:message` - Error message from the server
      - `:object` - The original object that failed
      - `:original_uuid` - The UUID that was attempted (if provided)
      - `:retry_count` - Number of retry attempts made
    """

    @enforce_keys [:message, :object]
    defstruct [:message, :object, :original_uuid, :retry_count]

    @type t :: %__MODULE__{
            message: String.t(),
            object: map(),
            original_uuid: String.t() | nil,
            retry_count: non_neg_integer() | nil
          }
  end

  defmodule ErrorReference do
    @moduledoc """
    Represents a failed reference in a batch operation.

    ## Fields

      - `:message` - Error message from the server
      - `:reference` - The reference that failed (from/to/property info)
    """

    @enforce_keys [:message, :reference]
    defstruct [:message, :reference]

    @type t :: %__MODULE__{
            message: String.t(),
            reference: map()
          }
  end

  defmodule Results do
    @moduledoc """
    Aggregated results from a batch operation.

    Tracks both successful and failed operations.

    ## Memory Safety

    To prevent memory exhaustion with very large batches, a maximum of
    100,000 successful UUIDs are stored. When the limit is exceeded,
    oldest entries (lowest indices) are evicted using a rolling window
    strategy. Use `max_stored_results/0` to get the current limit.
    """

    # Maximum number of stored results to prevent memory exhaustion
    # Same as Python client's MAX_STORED_RESULTS
    @max_stored_results 100_000

    defstruct failed_objects: [],
              failed_references: [],
              successful_uuids: %{},
              elapsed_seconds: 0.0

    @type t :: %__MODULE__{
            failed_objects: [ErrorObject.t()],
            failed_references: [ErrorReference.t()],
            successful_uuids: %{non_neg_integer() => String.t()},
            elapsed_seconds: float()
          }

    @doc """
    Get the maximum number of stored results.

    Results beyond this limit will have oldest entries evicted.
    """
    @spec max_stored_results() :: pos_integer()
    def max_stored_results, do: @max_stored_results

    @doc """
    Create a new empty results struct.
    """
    @spec new() :: t()
    def new do
      %__MODULE__{}
    end

    @doc """
    Add an error (object or reference) to the results.
    """
    @spec add_error(t(), ErrorObject.t() | ErrorReference.t()) :: t()
    def add_error(%__MODULE__{} = results, %ErrorObject{} = error) do
      %{results | failed_objects: [error | results.failed_objects]}
    end

    def add_error(%__MODULE__{} = results, %ErrorReference{} = error) do
      %{results | failed_references: [error | results.failed_references]}
    end

    @doc """
    Record a successful object insertion with its index and UUID.

    When the number of stored results exceeds the maximum (100,000),
    oldest entries (lowest indices) are evicted to prevent memory exhaustion.
    """
    @spec add_success(t(), non_neg_integer(), String.t()) :: t()
    def add_success(%__MODULE__{} = results, index, uuid) do
      new_uuids = Map.put(results.successful_uuids, index, uuid)

      if map_size(new_uuids) > @max_stored_results do
        %{results | successful_uuids: evict_oldest(new_uuids)}
      else
        %{results | successful_uuids: new_uuids}
      end
    end

    @doc """
    Check if results are within the maximum stored limit.
    """
    @spec results_within_limit?(t()) :: boolean()
    def results_within_limit?(%__MODULE__{successful_uuids: uuids}) do
      map_size(uuids) <= @max_stored_results
    end

    # Evict oldest entries (lowest indices) to bring map back to limit
    defp evict_oldest(uuids) when map_size(uuids) <= @max_stored_results, do: uuids

    defp evict_oldest(uuids) do
      # Find how many entries to remove
      excess = map_size(uuids) - @max_stored_results

      # Get sorted keys (indices) and remove the lowest ones
      keys_to_remove =
        uuids
        |> Map.keys()
        |> Enum.sort()
        |> Enum.take(excess)

      Map.drop(uuids, keys_to_remove)
    end

    @doc """
    Check if any errors occurred during the batch operation.
    """
    @spec has_errors?(t()) :: boolean()
    def has_errors?(%__MODULE__{} = results) do
      length(results.failed_objects) > 0 or length(results.failed_references) > 0
    end

    @doc """
    Get the total number of errors (objects + references).
    """
    @spec number_errors(t()) :: non_neg_integer()
    def number_errors(%__MODULE__{} = results) do
      length(results.failed_objects) + length(results.failed_references)
    end

    @doc """
    Set the elapsed time for the batch operation.
    """
    @spec set_elapsed(t(), float()) :: t()
    def set_elapsed(%__MODULE__{} = results, seconds) when is_number(seconds) do
      %{results | elapsed_seconds: seconds}
    end

    @doc """
    Get statistics summary for the results.

    Returns a map with processed, successful, and failed counts.
    """
    @spec statistics(t()) :: %{
            processed: non_neg_integer(),
            successful: non_neg_integer(),
            failed: non_neg_integer()
          }
    def statistics(%__MODULE__{} = results) do
      successful = map_size(results.successful_uuids)
      failed = length(results.failed_objects) + length(results.failed_references)

      %{
        processed: successful + failed,
        successful: successful,
        failed: failed
      }
    end

    @doc """
    Get errors list.
    """
    @spec errors(t()) :: [ErrorObject.t() | ErrorReference.t()]
    def errors(%__MODULE__{} = results) do
      results.failed_objects ++ results.failed_references
    end
  end
end
