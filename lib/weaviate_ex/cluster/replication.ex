defmodule WeaviateEx.Cluster.Replication do
  @moduledoc """
  Replication operation types and status.

  Weaviate supports shard replication to move or copy shards between nodes.
  This module provides types for tracking replication operations.

  ## Operation Types

  - `:copy` - Copy shard to target node (source remains)
  - `:move` - Move shard to target node (source is removed)

  ## Operation Status

  - `:pending` - Operation is queued
  - `:running` - Operation is in progress
  - `:completed` - Operation finished successfully
  - `:failed` - Operation failed
  - `:cancelled` - Operation was cancelled

  ## Examples

      # Create a replication operation
      op = %Replication.Operation{
        id: "uuid-123",
        collection: "Article",
        shard: "shard-0",
        source_node: "node-1",
        target_node: "node-2",
        type: :copy,
        status: :running,
        progress: 0.45
      }
  """

  @type operation_type :: :copy | :move
  @type status :: :pending | :running | :completed | :failed | :cancelled

  defmodule Operation do
    @moduledoc "A shard replication operation."

    @type t :: %__MODULE__{
            id: String.t(),
            collection: String.t(),
            shard: String.t(),
            source_node: String.t(),
            target_node: String.t(),
            type: atom(),
            status: atom(),
            progress: float() | nil,
            error: String.t() | nil,
            created_at: DateTime.t() | nil,
            completed_at: DateTime.t() | nil
          }

    defstruct [
      :id,
      :collection,
      :shard,
      :source_node,
      :target_node,
      :type,
      :status,
      :progress,
      :error,
      :created_at,
      :completed_at
    ]

    @doc """
    Parse operation from API response.

    ## Examples

        iex> Operation.from_api(%{"id" => "uuid-123", "status" => "RUNNING", "progress" => 0.5})
        %Operation{id: "uuid-123", status: :running, progress: 0.5}
    """
    @spec from_api(map()) :: t()
    def from_api(map) when is_map(map) do
      alias WeaviateEx.Cluster.Replication

      %__MODULE__{
        id: Map.get(map, "id"),
        collection: Map.get(map, "collection") || Map.get(map, "class"),
        shard: Map.get(map, "shard"),
        source_node: Map.get(map, "sourceNode"),
        target_node: Map.get(map, "targetNode"),
        type: Replication.type_from_api(Map.get(map, "type", "COPY")),
        status: Replication.status_from_api(Map.get(map, "status", "PENDING")),
        progress: Map.get(map, "progress"),
        error: Map.get(map, "error"),
        created_at: parse_datetime(Map.get(map, "createdAt")),
        completed_at: parse_datetime(Map.get(map, "completedAt"))
      }
    end

    @doc """
    Check if operation is complete (success, failure, or cancelled).

    ## Examples

        iex> Operation.completed?(%Operation{status: :completed})
        true

        iex> Operation.completed?(%Operation{status: :running})
        false
    """
    @spec completed?(t()) :: boolean()
    def completed?(%__MODULE__{status: status}) when status in [:completed, :failed, :cancelled],
      do: true

    def completed?(_), do: false

    @doc """
    Check if operation succeeded.

    ## Examples

        iex> Operation.success?(%Operation{status: :completed})
        true
    """
    @spec success?(t()) :: boolean()
    def success?(%__MODULE__{status: :completed}), do: true
    def success?(_), do: false

    @doc """
    Check if operation is still in progress.

    ## Examples

        iex> Operation.in_progress?(%Operation{status: :running})
        true
    """
    @spec in_progress?(t()) :: boolean()
    def in_progress?(%__MODULE__{status: status}) when status in [:pending, :running], do: true
    def in_progress?(_), do: false

    defp parse_datetime(nil), do: nil

    defp parse_datetime(datetime_string) when is_binary(datetime_string) do
      case DateTime.from_iso8601(datetime_string) do
        {:ok, datetime, _offset} -> datetime
        _ -> nil
      end
    end
  end

  @doc """
  Convert operation type to API string.

  ## Examples

      iex> Replication.type_to_api(:copy)
      "COPY"

      iex> Replication.type_to_api(:move)
      "MOVE"
  """
  @spec type_to_api(operation_type()) :: String.t()
  def type_to_api(:copy), do: "COPY"
  def type_to_api(:move), do: "MOVE"

  @doc """
  Parse operation type from API response.

  ## Examples

      iex> Replication.type_from_api("COPY")
      :copy

      iex> Replication.type_from_api("MOVE")
      :move
  """
  @spec type_from_api(String.t()) :: operation_type()
  def type_from_api("COPY"), do: :copy
  def type_from_api("MOVE"), do: :move
  def type_from_api(_), do: :copy

  @doc """
  Convert status to API string.

  ## Examples

      iex> Replication.status_to_api(:running)
      "RUNNING"
  """
  @spec status_to_api(status()) :: String.t()
  def status_to_api(:pending), do: "PENDING"
  def status_to_api(:running), do: "RUNNING"
  def status_to_api(:completed), do: "COMPLETED"
  def status_to_api(:failed), do: "FAILED"
  def status_to_api(:cancelled), do: "CANCELLED"

  @doc """
  Parse status from API response.

  ## Examples

      iex> Replication.status_from_api("RUNNING")
      :running

      iex> Replication.status_from_api("COMPLETED")
      :completed
  """
  @spec status_from_api(String.t()) :: status()
  def status_from_api("PENDING"), do: :pending
  def status_from_api("RUNNING"), do: :running
  def status_from_api("COMPLETED"), do: :completed
  def status_from_api("FAILED"), do: :failed
  def status_from_api("CANCELLED"), do: :cancelled
  def status_from_api(_), do: :pending
end
