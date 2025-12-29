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
    """

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
    """
    @spec add_success(t(), non_neg_integer(), String.t()) :: t()
    def add_success(%__MODULE__{} = results, index, uuid) do
      %{results | successful_uuids: Map.put(results.successful_uuids, index, uuid)}
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
  end
end
