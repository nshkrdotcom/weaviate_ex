defmodule WeaviateEx.Backup.Status do
  @moduledoc """
  Backup operation status types and response structs.

  ## Status Values

  - `:started` - Backup operation has started
  - `:transferring` - Data is being transferred
  - `:transferred` - Transfer complete, finalizing
  - `:success` - Operation completed successfully
  - `:failed` - Operation failed
  - `:canceled` - Operation was canceled

  ## Response Structs

  - `CreateResponse` - Response from backup create operation
  - `RestoreResponse` - Response from backup restore operation
  - `BackupInfo` - Backup metadata from list operation
  """

  alias WeaviateEx.Backup.Storage

  @type status :: :started | :transferring | :transferred | :success | :failed | :canceled

  @statuses [:started, :transferring, :transferred, :success, :failed, :canceled]
  @terminal_statuses [:success, :failed, :canceled]
  @in_progress_statuses [:started, :transferring, :transferred]

  defmodule CreateResponse do
    @moduledoc "Response from backup create operation"
    @type t :: %__MODULE__{
            id: String.t(),
            backend: atom(),
            status: atom(),
            path: String.t() | nil,
            collections: [String.t()],
            error: String.t() | nil
          }
    defstruct [:id, :backend, :status, :path, collections: [], error: nil]
  end

  defmodule RestoreResponse do
    @moduledoc "Response from backup restore operation"
    @type t :: %__MODULE__{
            id: String.t(),
            backend: atom(),
            status: atom(),
            path: String.t() | nil,
            collections: [String.t()],
            error: String.t() | nil
          }
    defstruct [:id, :backend, :status, :path, collections: [], error: nil]
  end

  defmodule BackupInfo do
    @moduledoc """
    Backup metadata from list operation.

    Includes timing information and size metrics when available:
    - `started_at` - When the backup started
    - `completed_at` - When the backup completed
    - `size_bytes` - Total size of the backup in bytes
    """
    @type t :: %__MODULE__{
            id: String.t(),
            backend: atom(),
            status: atom(),
            path: String.t(),
            collections: [String.t()],
            started_at: DateTime.t() | nil,
            completed_at: DateTime.t() | nil,
            size_bytes: non_neg_integer() | nil,
            error: String.t() | nil
          }
    defstruct [
      :id,
      :backend,
      :status,
      :path,
      :started_at,
      :completed_at,
      :size_bytes,
      :error,
      collections: []
    ]
  end

  @doc """
  List all status values.

  ## Examples

      iex> Status.all()
      [:started, :transferring, :transferred, :success, :failed, :canceled]
  """
  @spec all() :: [status()]
  def all, do: @statuses

  @doc """
  Convert status atom to API string.

  ## Examples

      iex> Status.to_api(:success)
      "SUCCESS"

      iex> Status.to_api(:transferring)
      "TRANSFERRING"
  """
  @spec to_api(status()) :: String.t()
  def to_api(:started), do: "STARTED"
  def to_api(:transferring), do: "TRANSFERRING"
  def to_api(:transferred), do: "TRANSFERRED"
  def to_api(:success), do: "SUCCESS"
  def to_api(:failed), do: "FAILED"
  def to_api(:canceled), do: "CANCELED"

  @doc """
  Parse status from API response.

  ## Examples

      iex> Status.from_api("SUCCESS")
      :success

      iex> Status.from_api("TRANSFERRING")
      :transferring
  """
  @spec from_api(String.t()) :: status()
  def from_api("STARTED"), do: :started
  def from_api("TRANSFERRING"), do: :transferring
  def from_api("TRANSFERRED"), do: :transferred
  def from_api("SUCCESS"), do: :success
  def from_api("FAILED"), do: :failed
  def from_api("CANCELED"), do: :canceled

  @doc """
  Check if status indicates completion.

  Returns true for `:success`, `:failed`, or `:canceled`.

  ## Examples

      iex> Status.completed?(:success)
      true

      iex> Status.completed?(:transferring)
      false
  """
  @spec completed?(status()) :: boolean()
  def completed?(status) when status in @terminal_statuses, do: true
  def completed?(_), do: false

  @doc """
  Check if status indicates success.

  ## Examples

      iex> Status.success?(:success)
      true

      iex> Status.success?(:failed)
      false
  """
  @spec success?(status()) :: boolean()
  def success?(:success), do: true
  def success?(_), do: false

  @doc """
  Check if status indicates operation is in progress.

  Returns true for `:started`, `:transferring`, or `:transferred`.

  ## Examples

      iex> Status.in_progress?(:transferring)
      true

      iex> Status.in_progress?(:success)
      false
  """
  @spec in_progress?(status()) :: boolean()
  def in_progress?(status) when status in @in_progress_statuses, do: true
  def in_progress?(_), do: false

  @doc """
  Parse CreateResponse from API response map.

  ## Examples

      iex> Status.create_response_from_api(%{"id" => "backup-1", "backend" => "s3", "status" => "SUCCESS"})
      {:ok, %Status.CreateResponse{id: "backup-1", backend: :s3, status: :success}}
  """
  @spec create_response_from_api(map()) :: {:ok, CreateResponse.t()}
  def create_response_from_api(map) when is_map(map) do
    {:ok, backend} = Storage.from_api(map["backend"])

    response = %CreateResponse{
      id: map["id"],
      backend: backend,
      status: from_api(map["status"]),
      path: map["path"],
      collections: map["classes"] || [],
      error: map["error"]
    }

    {:ok, response}
  end

  @doc """
  Parse RestoreResponse from API response map.

  ## Examples

      iex> Status.restore_response_from_api(%{"id" => "backup-1", "backend" => "gcs", "status" => "SUCCESS"})
      {:ok, %Status.RestoreResponse{id: "backup-1", backend: :gcs, status: :success}}
  """
  @spec restore_response_from_api(map()) :: {:ok, RestoreResponse.t()}
  def restore_response_from_api(map) when is_map(map) do
    {:ok, backend} = Storage.from_api(map["backend"])

    response = %RestoreResponse{
      id: map["id"],
      backend: backend,
      status: from_api(map["status"]),
      path: map["path"],
      collections: map["classes"] || [],
      error: map["error"]
    }

    {:ok, response}
  end

  @doc """
  Parse BackupInfo from API response map.

  ## Examples

      iex> Status.backup_info_from_api(%{"id" => "backup-1", "backend" => "azure", "status" => "SUCCESS"})
      {:ok, %Status.BackupInfo{id: "backup-1", backend: :azure, status: :success}}
  """
  @spec backup_info_from_api(map()) :: {:ok, BackupInfo.t()}
  def backup_info_from_api(map) when is_map(map) do
    {:ok, backend} = Storage.from_api(map["backend"])

    info = %BackupInfo{
      id: map["id"],
      backend: backend,
      status: from_api(map["status"]),
      path: map["path"],
      collections: map["classes"] || [],
      started_at: parse_datetime(map["startedAt"]),
      completed_at: parse_datetime(map["completedAt"]),
      size_bytes: map["sizeBytes"],
      error: map["error"]
    }

    {:ok, info}
  end

  # Parse ISO8601 datetime string to DateTime
  defp parse_datetime(nil), do: nil

  defp parse_datetime(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _offset} -> dt
      {:error, _} -> nil
    end
  end
end
