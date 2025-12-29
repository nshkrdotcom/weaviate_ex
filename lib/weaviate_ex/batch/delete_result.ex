defmodule WeaviateEx.Batch.DeleteResult do
  @moduledoc """
  Typed result for batch delete operations.

  Contains information about the delete operation including matches,
  successes, failures, and optionally the deleted objects.

  ## Examples

      # Parse a delete response
      {:ok, result} = DeleteResult.from_api(response)

      # Check statistics
      result.matches    # Total objects matching filter
      result.successful # Successfully deleted count
      result.failed     # Failed deletion count

      # Access deleted objects (if verbose output requested)
      Enum.each(result.objects, fn obj ->
        IO.puts("Deleted: \#{obj.uuid}")
      end)
  """

  alias __MODULE__.DeletedObject

  @type t :: %__MODULE__{
          matches: non_neg_integer(),
          limit: non_neg_integer(),
          successful: non_neg_integer(),
          failed: non_neg_integer(),
          objects: [DeletedObject.t()],
          dry_run: boolean()
        }

  defstruct matches: 0,
            limit: 0,
            successful: 0,
            failed: 0,
            objects: [],
            dry_run: false

  @doc """
  Parse a delete result from the Weaviate API response.

  ## Examples

      response = %{
        "match" => %{"matches" => 10, "limit" => 10000},
        "output" => "verbose",
        "results" => %{
          "successful" => 10,
          "failed" => 0,
          "objects" => [%{"id" => "uuid-1", "status" => "SUCCESS"}]
        }
      }
      {:ok, result} = DeleteResult.from_api(response)
  """
  @spec from_api(map()) :: {:ok, t()} | {:error, term()}
  def from_api(response) when is_map(response) do
    match = Map.get(response, "match", %{})
    results = Map.get(response, "results", %{})
    dry_run = Map.get(response, "dryRun", false)

    objects =
      results
      |> Map.get("objects", [])
      |> Enum.map(&DeletedObject.from_api/1)

    result = %__MODULE__{
      matches: Map.get(match, "matches", 0),
      limit: Map.get(match, "limit", 0),
      successful: Map.get(results, "successful", 0),
      failed: Map.get(results, "failed", 0),
      objects: objects,
      dry_run: dry_run
    }

    {:ok, result}
  rescue
    e -> {:error, {:parse_error, e}}
  end

  def from_api(nil), do: {:error, :empty_response}
  def from_api(_), do: {:error, :invalid_response}

  @doc """
  Check if all matched objects were successfully deleted.
  """
  @spec all_successful?(t()) :: boolean()
  def all_successful?(%__MODULE__{} = result) do
    result.failed == 0 and result.successful == result.matches
  end

  @doc """
  Check if any deletions failed.
  """
  @spec has_failures?(t()) :: boolean()
  def has_failures?(%__MODULE__{} = result) do
    result.failed > 0
  end

  @doc """
  Get objects that failed to delete.
  """
  @spec failed_objects(t()) :: [DeletedObject.t()]
  def failed_objects(%__MODULE__{} = result) do
    Enum.filter(result.objects, &DeletedObject.failed?/1)
  end

  @doc """
  Get objects that were successfully deleted.
  """
  @spec successful_objects(t()) :: [DeletedObject.t()]
  def successful_objects(%__MODULE__{} = result) do
    Enum.filter(result.objects, &DeletedObject.success?/1)
  end

  @doc """
  Get a summary of the delete operation.
  """
  @spec summary(t()) :: String.t()
  def summary(%__MODULE__{} = result) do
    status =
      cond do
        result.dry_run -> "DRY RUN"
        all_successful?(result) -> "SUCCESS"
        has_failures?(result) -> "PARTIAL"
        true -> "COMPLETE"
      end

    "#{status}: #{result.successful}/#{result.matches} deleted, #{result.failed} failed"
  end

  defmodule DeletedObject do
    @moduledoc """
    Represents a single object from a batch delete operation.
    """

    @type status :: :success | :failed | :dry_run

    @type t :: %__MODULE__{
            uuid: String.t(),
            status: status(),
            errors: [map()] | nil
          }

    defstruct [:uuid, :status, :errors]

    @doc """
    Parse a deleted object from the API response.
    """
    @spec from_api(map()) :: t()
    def from_api(map) when is_map(map) do
      %__MODULE__{
        uuid: Map.get(map, "id"),
        status: parse_status(Map.get(map, "status")),
        errors: Map.get(map, "errors")
      }
    end

    @doc """
    Check if the object was successfully deleted.
    """
    @spec success?(t()) :: boolean()
    def success?(%__MODULE__{status: :success}), do: true
    def success?(%__MODULE__{}), do: false

    @doc """
    Check if the object deletion failed.
    """
    @spec failed?(t()) :: boolean()
    def failed?(%__MODULE__{status: :failed}), do: true
    def failed?(%__MODULE__{}), do: false

    @doc """
    Check if this was a dry run (object not actually deleted).
    """
    @spec dry_run?(t()) :: boolean()
    def dry_run?(%__MODULE__{status: :dry_run}), do: true
    def dry_run?(%__MODULE__{}), do: false

    defp parse_status("SUCCESS"), do: :success
    defp parse_status("FAILED"), do: :failed
    defp parse_status("DRYRUN"), do: :dry_run
    defp parse_status(_), do: :failed
  end
end
