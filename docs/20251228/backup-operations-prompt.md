# WeaviateEx: Backup Operations Implementation Prompt

**Date:** 2025-12-28
**Objective:** Implement complete Backup module with all storage backends. Full TDD approach.
**Version Bump:** 0.x.0 → 0.(x+1).0

---

## Pre-Implementation Required Reading

### 1. Python Client Reference (Implementation Guide)

```
# Backup Module
weaviate-python-client/weaviate/backup/
├── __init__.py              # Module exports
├── executor.py              # Main backup operations
├── backup_location.py       # Storage backend location classes
├── sync.py                  # Synchronous operations
└── async_.py                # Async operations

# Backup Types/Models
weaviate-python-client/weaviate/backup/
├── BackupStorage            # Enum: FILESYSTEM, S3, GCS, AZURE
├── BackupConfigCreate       # cpu_percentage, compression_level
├── BackupConfigRestore      # cpu_percentage
├── BackupCompressionLevel   # Enum: DEFAULT, BEST_SPEED, BEST_COMPRESSION
└── BackupStatus             # Enum: STARTED, TRANSFERRING, TRANSFERRED, SUCCESS, FAILED, CANCELED

# Backup Location Classes
weaviate-python-client/weaviate/backup/backup_location.py
├── BackupLocation.FileSystem(path)
├── BackupLocation.S3(bucket, path, endpoint, region, credentials)
├── BackupLocation.GCP(bucket, path, credentials)
└── BackupLocation.Azure(container, path, credentials)
```

### 2. Elixir Client Current State

```
# No backup implementation exists
# Pattern to follow from existing API modules:
lib/weaviate_ex/api/schema.ex           # CRUD pattern
lib/weaviate_ex/api/objects.ex          # Operations pattern
lib/weaviate_ex/api/tenants.ex          # Status-based operations

# Types pattern
lib/weaviate_ex/types/*.ex

# Error handling
lib/weaviate_ex/error.ex
```

### 3. Gap Analysis Documentation

```
docs/20251228/weaviate-client-gap-analysis/
├── backup-cluster-tenants.md    # PRIMARY - Backup gaps
└── gap-analysis-summary.md      # Overall priorities
```

### 4. Weaviate Backup REST API Documentation

```
# Endpoints to implement
POST   /v1/backups/{backend}                           # Create backup
GET    /v1/backups/{backend}/{backup_id}               # Get backup status
POST   /v1/backups/{backend}/{backup_id}/restore       # Restore backup
GET    /v1/backups/{backend}/{backup_id}/restore       # Get restore status
GET    /v1/backups/{backend}                           # List backups
DELETE /v1/backups/{backend}/{backup_id}               # Cancel backup
```

### 5. Weaviate Backup Server Configuration

Weaviate must be configured with backup modules enabled:

```yaml
# Filesystem
BACKUP_FILESYSTEM_PATH: /var/weaviate/backups

# S3
BACKUP_S3_BUCKET: my-bucket
BACKUP_S3_PATH: /backups
BACKUP_S3_ENDPOINT: s3.amazonaws.com  # or custom
BACKUP_S3_USE_SSL: true

# GCS
BACKUP_GCS_BUCKET: my-bucket
BACKUP_GCS_PATH: /backups

# Azure
BACKUP_AZURE_CONTAINER: my-container
BACKUP_AZURE_PATH: /backups
```

---

## Context

### Features to Implement (~15 operations)

| Category | Operations | Priority |
|----------|------------|----------|
| Core Backup | 6 operations | Critical |
| Storage Backends | 4 location types | Critical |
| Configuration | 3 config types | High |
| Status Polling | 2 status types | High |

### Module Structure

```
lib/weaviate_ex/
├── backup/
│   ├── storage.ex           # BackupStorage enum (filesystem, s3, gcs, azure)
│   ├── location.ex          # BackupLocation structs for each backend
│   ├── config.ex            # BackupConfigCreate, BackupConfigRestore
│   ├── status.ex            # BackupStatus, BackupStatusResponse
│   └── compression.ex       # BackupCompressionLevel enum
└── api/
    └── backup.ex            # Main backup operations API
```

---

## Implementation Instructions

### Phase 1: Enums and Basic Types (TDD)

#### 1.1 Create Storage Backend Enum

Create `lib/weaviate_ex/backup/storage.ex`:

```elixir
defmodule WeaviateEx.Backup.Storage do
  @moduledoc """
  Backup storage backend types.

  ## Available Backends

  - `:filesystem` - Local filesystem storage
  - `:s3` - Amazon S3 or S3-compatible storage
  - `:gcs` - Google Cloud Storage
  - `:azure` - Azure Blob Storage
  """

  @type t :: :filesystem | :s3 | :gcs | :azure

  @backends [:filesystem, :s3, :gcs, :azure]

  @doc "List all available storage backends"
  @spec all() :: [t()]
  def all, do: @backends

  @doc "Check if backend is valid"
  @spec valid?(atom()) :: boolean()
  def valid?(backend) when backend in @backends, do: true
  def valid?(_), do: false

  @doc "Convert to API path segment"
  @spec to_api_path(t()) :: String.t()
  def to_api_path(:filesystem), do: "filesystem"
  def to_api_path(:s3), do: "s3"
  def to_api_path(:gcs), do: "gcs"
  def to_api_path(:azure), do: "azure"

  @doc "Parse from API response"
  @spec from_api(String.t()) :: {:ok, t()} | {:error, :invalid_backend}
  def from_api("filesystem"), do: {:ok, :filesystem}
  def from_api("s3"), do: {:ok, :s3}
  def from_api("gcs"), do: {:ok, :gcs}
  def from_api("azure"), do: {:ok, :azure}
  def from_api(_), do: {:error, :invalid_backend}
end
```

**Tests first** in `test/weaviate_ex/backup/storage_test.exs`:
- `test "all/0 returns all four backends"`
- `test "valid?/1 returns true for valid backends"`
- `test "valid?/1 returns false for invalid backends"`
- `test "to_api_path/1 converts all backends correctly"`
- `test "from_api/1 parses all backend strings"`
- `test "from_api/1 returns error for invalid string"`

#### 1.2 Create Compression Level Enum

Create `lib/weaviate_ex/backup/compression.ex`:

```elixir
defmodule WeaviateEx.Backup.Compression do
  @moduledoc """
  Backup compression level options.

  ## Levels

  - `:default` - Balanced compression (default)
  - `:best_speed` - Faster compression, larger files
  - `:best_compression` - Slower compression, smaller files
  """

  @type t :: :default | :best_speed | :best_compression

  @doc "Convert to API format"
  @spec to_api(t()) :: String.t()
  def to_api(:default), do: "DefaultCompression"
  def to_api(:best_speed), do: "BestSpeed"
  def to_api(:best_compression), do: "BestCompression"

  @doc "Parse from API response"
  @spec from_api(String.t()) :: {:ok, t()} | {:error, :invalid_compression}
  def from_api("DefaultCompression"), do: {:ok, :default}
  def from_api("BestSpeed"), do: {:ok, :best_speed}
  def from_api("BestCompression"), do: {:ok, :best_compression}
  def from_api(_), do: {:error, :invalid_compression}
end
```

**Tests first** in `test/weaviate_ex/backup/compression_test.exs`:
- `test "to_api/1 converts all levels correctly"`
- `test "from_api/1 parses all level strings"`
- `test "from_api/1 returns error for invalid string"`

#### 1.3 Create Backup Status Types

Create `lib/weaviate_ex/backup/status.ex`:

```elixir
defmodule WeaviateEx.Backup.Status do
  @moduledoc """
  Backup operation status types and response structs.
  """

  @type status :: :started | :transferring | :transferred | :success | :failed | :canceled

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
    defstruct [:id, :backend, :status, :path, :collections, :error]
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
    defstruct [:id, :backend, :status, :path, :collections, :error]
  end

  defmodule BackupInfo do
    @moduledoc "Backup metadata from list operation"
    @type t :: %__MODULE__{
      id: String.t(),
      backend: atom(),
      status: atom(),
      path: String.t(),
      collections: [String.t()]
    }
    defstruct [:id, :backend, :status, :path, :collections]
  end

  @doc "Convert status atom to API string"
  @spec to_api(status()) :: String.t()
  def to_api(:started), do: "STARTED"
  def to_api(:transferring), do: "TRANSFERRING"
  def to_api(:transferred), do: "TRANSFERRED"
  def to_api(:success), do: "SUCCESS"
  def to_api(:failed), do: "FAILED"
  def to_api(:canceled), do: "CANCELED"

  @doc "Parse status from API response"
  @spec from_api(String.t()) :: status()
  def from_api("STARTED"), do: :started
  def from_api("TRANSFERRING"), do: :transferring
  def from_api("TRANSFERRED"), do: :transferred
  def from_api("SUCCESS"), do: :success
  def from_api("FAILED"), do: :failed
  def from_api("CANCELED"), do: :canceled

  @doc "Check if status indicates completion"
  @spec completed?(status()) :: boolean()
  def completed?(status) when status in [:success, :failed, :canceled], do: true
  def completed?(_), do: false

  @doc "Check if status indicates success"
  @spec success?(status()) :: boolean()
  def success?(:success), do: true
  def success?(_), do: false

  @doc "Parse CreateResponse from API"
  def create_response_from_api(map)

  @doc "Parse RestoreResponse from API"
  def restore_response_from_api(map)

  @doc "Parse BackupInfo from API"
  def backup_info_from_api(map)
end
```

**Tests first** in `test/weaviate_ex/backup/status_test.exs`:
- `test "to_api/1 converts all statuses"`
- `test "from_api/1 parses all status strings"`
- `test "completed?/1 returns true for terminal states"`
- `test "completed?/1 returns false for in-progress states"`
- `test "success?/1 returns true only for :success"`
- `test "create_response_from_api/1 parses full response"`
- `test "restore_response_from_api/1 parses full response"`
- `test "backup_info_from_api/1 parses backup metadata"`

### Phase 2: Configuration Structs (TDD)

#### 2.1 Create Backup Configuration

Create `lib/weaviate_ex/backup/config.ex`:

```elixir
defmodule WeaviateEx.Backup.Config do
  @moduledoc """
  Configuration options for backup operations.

  ## Create Configuration

      config = Config.create(
        cpu_percentage: 50,
        compression: :best_compression
      )

  ## Restore Configuration

      config = Config.restore(cpu_percentage: 80)
  """

  alias WeaviateEx.Backup.Compression

  defmodule Create do
    @moduledoc "Configuration for backup creation"
    @type t :: %__MODULE__{
      cpu_percentage: pos_integer() | nil,
      compression: Compression.t() | nil
    }
    defstruct [:cpu_percentage, :compression]

    @doc "Create new backup create config"
    @spec new(keyword()) :: t()
    def new(opts \\ []) do
      %__MODULE__{
        cpu_percentage: Keyword.get(opts, :cpu_percentage),
        compression: Keyword.get(opts, :compression)
      }
    end

    @doc "Convert to API format"
    @spec to_api(t()) :: map()
    def to_api(%__MODULE__{} = config) do
      %{}
      |> maybe_put(:CPUPercentage, config.cpu_percentage)
      |> maybe_put(:CompressionLevel, config.compression && Compression.to_api(config.compression))
    end

    defp maybe_put(map, _key, nil), do: map
    defp maybe_put(map, key, value), do: Map.put(map, key, value)
  end

  defmodule Restore do
    @moduledoc "Configuration for backup restoration"
    @type t :: %__MODULE__{
      cpu_percentage: pos_integer() | nil
    }
    defstruct [:cpu_percentage]

    @doc "Create new backup restore config"
    @spec new(keyword()) :: t()
    def new(opts \\ []) do
      %__MODULE__{
        cpu_percentage: Keyword.get(opts, :cpu_percentage)
      }
    end

    @doc "Convert to API format"
    @spec to_api(t()) :: map()
    def to_api(%__MODULE__{cpu_percentage: nil}), do: %{}
    def to_api(%__MODULE__{cpu_percentage: pct}), do: %{CPUPercentage: pct}
  end

  @doc "Create backup creation config"
  @spec create(keyword()) :: Create.t()
  def create(opts \\ []), do: Create.new(opts)

  @doc "Create backup restoration config"
  @spec restore(keyword()) :: Restore.t()
  def restore(opts \\ []), do: Restore.new(opts)
end
```

**Tests first** in `test/weaviate_ex/backup/config_test.exs`:
- `test "Create.new/1 with all options"`
- `test "Create.new/1 with no options"`
- `test "Create.to_api/1 excludes nil values"`
- `test "Create.to_api/1 converts compression level"`
- `test "Restore.new/1 with cpu_percentage"`
- `test "Restore.to_api/1 returns empty map when no config"`

### Phase 3: Storage Location Structs (TDD)

#### 3.1 Create Backup Location Types

Create `lib/weaviate_ex/backup/location.ex`:

```elixir
defmodule WeaviateEx.Backup.Location do
  @moduledoc """
  Backup storage location configurations.

  ## Examples

      # Local filesystem
      Location.filesystem("/var/backups")

      # Amazon S3
      Location.s3("my-bucket", "/backups",
        endpoint: "s3.us-west-2.amazonaws.com",
        region: "us-west-2"
      )

      # Google Cloud Storage
      Location.gcs("my-bucket", "/backups",
        credentials: %{...}
      )

      # Azure Blob Storage
      Location.azure("my-container", "/backups",
        connection_string: "..."
      )
  """

  defmodule Filesystem do
    @moduledoc "Local filesystem backup location"
    @type t :: %__MODULE__{
      path: String.t()
    }
    defstruct [:path]

    def new(path), do: %__MODULE__{path: path}

    def to_api(%__MODULE__{path: path}), do: %{path: path}
  end

  defmodule S3 do
    @moduledoc "Amazon S3 backup location"
    @type t :: %__MODULE__{
      bucket: String.t(),
      path: String.t(),
      endpoint: String.t() | nil,
      region: String.t() | nil,
      access_key_id: String.t() | nil,
      secret_access_key: String.t() | nil,
      use_ssl: boolean()
    }
    defstruct [:bucket, :path, :endpoint, :region, :access_key_id, :secret_access_key, use_ssl: true]

    def new(bucket, path, opts \\ []) do
      %__MODULE__{
        bucket: bucket,
        path: path,
        endpoint: Keyword.get(opts, :endpoint),
        region: Keyword.get(opts, :region),
        access_key_id: Keyword.get(opts, :access_key_id),
        secret_access_key: Keyword.get(opts, :secret_access_key),
        use_ssl: Keyword.get(opts, :use_ssl, true)
      }
    end

    def to_api(%__MODULE__{} = loc) do
      %{bucket: loc.bucket, path: loc.path}
      |> maybe_put(:endpoint, loc.endpoint)
      |> maybe_put(:region, loc.region)
      |> maybe_put(:accessKeyId, loc.access_key_id)
      |> maybe_put(:secretAccessKey, loc.secret_access_key)
      |> Map.put(:useSSL, loc.use_ssl)
    end

    defp maybe_put(map, _key, nil), do: map
    defp maybe_put(map, key, value), do: Map.put(map, key, value)
  end

  defmodule GCS do
    @moduledoc "Google Cloud Storage backup location"
    @type t :: %__MODULE__{
      bucket: String.t(),
      path: String.t(),
      project_id: String.t() | nil,
      credentials: map() | nil
    }
    defstruct [:bucket, :path, :project_id, :credentials]

    def new(bucket, path, opts \\ []) do
      %__MODULE__{
        bucket: bucket,
        path: path,
        project_id: Keyword.get(opts, :project_id),
        credentials: Keyword.get(opts, :credentials)
      }
    end

    def to_api(%__MODULE__{} = loc) do
      %{bucket: loc.bucket, path: loc.path}
      |> maybe_put(:projectId, loc.project_id)
      |> maybe_put(:credentials, loc.credentials)
    end

    defp maybe_put(map, _key, nil), do: map
    defp maybe_put(map, key, value), do: Map.put(map, key, value)
  end

  defmodule Azure do
    @moduledoc "Azure Blob Storage backup location"
    @type t :: %__MODULE__{
      container: String.t(),
      path: String.t(),
      connection_string: String.t() | nil
    }
    defstruct [:container, :path, :connection_string]

    def new(container, path, opts \\ []) do
      %__MODULE__{
        container: container,
        path: path,
        connection_string: Keyword.get(opts, :connection_string)
      }
    end

    def to_api(%__MODULE__{} = loc) do
      %{container: loc.container, path: loc.path}
      |> maybe_put(:connectionString, loc.connection_string)
    end

    defp maybe_put(map, _key, nil), do: map
    defp maybe_put(map, key, value), do: Map.put(map, key, value)
  end

  @type t :: Filesystem.t() | S3.t() | GCS.t() | Azure.t()

  @doc "Create filesystem location"
  @spec filesystem(String.t()) :: Filesystem.t()
  def filesystem(path), do: Filesystem.new(path)

  @doc "Create S3 location"
  @spec s3(String.t(), String.t(), keyword()) :: S3.t()
  def s3(bucket, path, opts \\ []), do: S3.new(bucket, path, opts)

  @doc "Create GCS location"
  @spec gcs(String.t(), String.t(), keyword()) :: GCS.t()
  def gcs(bucket, path, opts \\ []), do: GCS.new(bucket, path, opts)

  @doc "Create Azure location"
  @spec azure(String.t(), String.t(), keyword()) :: Azure.t()
  def azure(container, path, opts \\ []), do: Azure.new(container, path, opts)

  @doc "Get storage backend type from location"
  @spec backend(t()) :: atom()
  def backend(%Filesystem{}), do: :filesystem
  def backend(%S3{}), do: :s3
  def backend(%GCS{}), do: :gcs
  def backend(%Azure{}), do: :azure

  @doc "Convert location to API format"
  @spec to_api(t()) :: map()
  def to_api(%Filesystem{} = loc), do: Filesystem.to_api(loc)
  def to_api(%S3{} = loc), do: S3.to_api(loc)
  def to_api(%GCS{} = loc), do: GCS.to_api(loc)
  def to_api(%Azure{} = loc), do: Azure.to_api(loc)
end
```

**Tests first** in `test/weaviate_ex/backup/location_test.exs`:
- `test "filesystem/1 creates Filesystem struct"`
- `test "Filesystem.to_api/1 returns correct map"`
- `test "s3/3 creates S3 struct with all options"`
- `test "S3.to_api/1 includes all provided fields"`
- `test "S3.to_api/1 excludes nil fields"`
- `test "gcs/3 creates GCS struct"`
- `test "GCS.to_api/1 handles credentials"`
- `test "azure/3 creates Azure struct"`
- `test "Azure.to_api/1 handles connection string"`
- `test "backend/1 returns correct backend for each type"`

### Phase 4: Main Backup API Module (TDD)

#### 4.1 Create Backup API

Create `lib/weaviate_ex/api/backup.ex`:

```elixir
defmodule WeaviateEx.API.Backup do
  @moduledoc """
  Backup and restore operations for Weaviate.

  ## Creating a Backup

      # Simple backup to filesystem
      {:ok, status} = Backup.create(client, "my-backup", :filesystem)

      # Backup specific collections to S3
      {:ok, status} = Backup.create(client, "my-backup", :s3,
        include_collections: ["Article", "Author"],
        wait_for_completion: true
      )

      # Backup with configuration
      {:ok, status} = Backup.create(client, "my-backup", :filesystem,
        config: Config.create(cpu_percentage: 50, compression: :best_compression)
      )

  ## Restoring a Backup

      # Simple restore
      {:ok, status} = Backup.restore(client, "my-backup", :filesystem)

      # Restore with wait
      {:ok, status} = Backup.restore(client, "my-backup", :s3,
        wait_for_completion: true
      )

  ## Checking Status

      {:ok, status} = Backup.get_create_status(client, "my-backup", :filesystem)
      {:ok, status} = Backup.get_restore_status(client, "my-backup", :s3)

  ## Listing and Canceling

      {:ok, backups} = Backup.list(client, :filesystem)
      :ok = Backup.cancel(client, "my-backup", :filesystem)
  """

  alias WeaviateEx.Backup.{Storage, Status, Config, Location}

  @default_poll_interval 1000
  @default_timeout 300_000

  @doc """
  Create a new backup.

  ## Options

  - `:include_collections` - List of collections to include (default: all)
  - `:exclude_collections` - List of collections to exclude
  - `:wait_for_completion` - Wait for backup to complete (default: false)
  - `:config` - Backup configuration (see `WeaviateEx.Backup.Config`)
  - `:poll_interval` - Status poll interval in ms (default: 1000)
  - `:timeout` - Maximum wait time in ms (default: 300000)

  ## Examples

      {:ok, status} = Backup.create(client, "daily-backup", :filesystem)

      {:ok, status} = Backup.create(client, "daily-backup", :s3,
        include_collections: ["Article"],
        wait_for_completion: true,
        config: Config.create(compression: :best_speed)
      )
  """
  @spec create(client :: term(), backup_id :: String.t(), backend :: Storage.t(), keyword()) ::
    {:ok, Status.CreateResponse.t()} | {:error, term()}
  def create(client, backup_id, backend, opts \\ [])

  @doc """
  Get the status of a backup creation.

  ## Examples

      {:ok, status} = Backup.get_create_status(client, "my-backup", :filesystem)
      if Status.completed?(status.status) do
        IO.puts("Backup complete!")
      end
  """
  @spec get_create_status(client :: term(), backup_id :: String.t(), backend :: Storage.t()) ::
    {:ok, Status.CreateResponse.t()} | {:error, term()}
  def get_create_status(client, backup_id, backend)

  @doc """
  Restore a backup.

  ## Options

  - `:include_collections` - List of collections to restore (default: all)
  - `:exclude_collections` - List of collections to exclude
  - `:wait_for_completion` - Wait for restore to complete (default: false)
  - `:config` - Restore configuration (see `WeaviateEx.Backup.Config`)
  - `:poll_interval` - Status poll interval in ms (default: 1000)
  - `:timeout` - Maximum wait time in ms (default: 300000)

  ## Examples

      {:ok, status} = Backup.restore(client, "daily-backup", :filesystem)

      {:ok, status} = Backup.restore(client, "daily-backup", :s3,
        include_collections: ["Article"],
        wait_for_completion: true
      )
  """
  @spec restore(client :: term(), backup_id :: String.t(), backend :: Storage.t(), keyword()) ::
    {:ok, Status.RestoreResponse.t()} | {:error, term()}
  def restore(client, backup_id, backend, opts \\ [])

  @doc """
  Get the status of a backup restoration.

  ## Examples

      {:ok, status} = Backup.get_restore_status(client, "my-backup", :filesystem)
  """
  @spec get_restore_status(client :: term(), backup_id :: String.t(), backend :: Storage.t()) ::
    {:ok, Status.RestoreResponse.t()} | {:error, term()}
  def get_restore_status(client, backup_id, backend)

  @doc """
  List all backups for a storage backend.

  ## Examples

      {:ok, backups} = Backup.list(client, :filesystem)
      Enum.each(backups, fn backup ->
        IO.puts("\#{backup.id}: \#{backup.status}")
      end)
  """
  @spec list(client :: term(), backend :: Storage.t()) ::
    {:ok, [Status.BackupInfo.t()]} | {:error, term()}
  def list(client, backend)

  @doc """
  Cancel an in-progress backup.

  ## Examples

      :ok = Backup.cancel(client, "my-backup", :filesystem)
  """
  @spec cancel(client :: term(), backup_id :: String.t(), backend :: Storage.t()) ::
    :ok | {:error, term()}
  def cancel(client, backup_id, backend)

  @doc """
  Wait for a backup operation to complete.

  Used internally when `wait_for_completion: true` is set.

  ## Options

  - `:poll_interval` - How often to check status (default: 1000ms)
  - `:timeout` - Maximum wait time (default: 300000ms)
  """
  @spec wait_for_completion(
    client :: term(),
    backup_id :: String.t(),
    backend :: Storage.t(),
    operation :: :create | :restore,
    keyword()
  ) :: {:ok, term()} | {:error, term()}
  def wait_for_completion(client, backup_id, backend, operation, opts \\ [])

  # Private implementation functions
  defp build_create_body(backup_id, opts)
  defp build_restore_body(opts)
  defp do_wait_for_completion(client, backup_id, backend, operation, poll_interval, deadline)
end
```

**Tests first** in `test/weaviate_ex/api/backup_test.exs`:

```elixir
describe "create/4" do
  test "creates backup with minimal options"
  test "creates backup with include_collections"
  test "creates backup with exclude_collections"
  test "creates backup with config"
  test "returns error for invalid backend"
  test "returns error when backup already exists"
end

describe "create/4 with wait_for_completion" do
  test "waits and returns final status on success"
  test "waits and returns error on failure"
  test "times out after specified duration"
end

describe "get_create_status/3" do
  test "returns status for existing backup"
  test "returns error for non-existent backup"
  test "returns correct status enum values"
end

describe "restore/4" do
  test "restores backup with minimal options"
  test "restores backup with include_collections"
  test "restores backup with exclude_collections"
  test "restores backup with config"
  test "returns error for non-existent backup"
end

describe "restore/4 with wait_for_completion" do
  test "waits and returns final status on success"
  test "waits and returns error on failure"
end

describe "get_restore_status/3" do
  test "returns status for active restore"
  test "returns error when no restore in progress"
end

describe "list/2" do
  test "returns empty list when no backups"
  test "returns list of BackupInfo structs"
  test "filters by backend correctly"
end

describe "cancel/3" do
  test "cancels in-progress backup"
  test "returns error for completed backup"
  test "returns error for non-existent backup"
end

describe "wait_for_completion/5" do
  test "polls until completion"
  test "respects poll_interval option"
  test "returns timeout error when exceeded"
end
```

### Phase 5: Main Module Integration

#### 5.1 Update Main WeaviateEx Module

Add to `lib/weaviate_ex.ex`:

```elixir
defmodule WeaviateEx do
  # ... existing code ...

  # Backup convenience functions
  defdelegate create_backup(client, backup_id, backend, opts \\ []), to: WeaviateEx.API.Backup, as: :create
  defdelegate restore_backup(client, backup_id, backend, opts \\ []), to: WeaviateEx.API.Backup, as: :restore
  defdelegate list_backups(client, backend), to: WeaviateEx.API.Backup, as: :list
  defdelegate cancel_backup(client, backup_id, backend), to: WeaviateEx.API.Backup, as: :cancel
  defdelegate get_backup_status(client, backup_id, backend), to: WeaviateEx.API.Backup, as: :get_create_status
end
```

### Phase 6: Error Handling Updates

#### 6.1 Add Backup-Specific Error Types

Update `lib/weaviate_ex/error.ex`:

```elixir
# Add backup-specific error constructors
def backup_not_found(backup_id, backend) do
  %__MODULE__{
    type: :not_found,
    message: "Backup '#{backup_id}' not found in #{backend} storage",
    details: %{category: :backup, backup_id: backup_id, backend: backend}
  }
end

def backup_already_exists(backup_id, backend) do
  %__MODULE__{
    type: :conflict,
    message: "Backup '#{backup_id}' already exists in #{backend} storage",
    details: %{category: :backup, backup_id: backup_id, backend: backend}
  }
end

def backup_failed(backup_id, reason) do
  %__MODULE__{
    type: :backup_failed,
    message: "Backup '#{backup_id}' failed: #{reason}",
    details: %{category: :backup, backup_id: backup_id}
  }
end

def restore_failed(backup_id, reason) do
  %__MODULE__{
    type: :restore_failed,
    message: "Restore of '#{backup_id}' failed: #{reason}",
    details: %{category: :backup, backup_id: backup_id}
  }
end

def backup_timeout(backup_id, operation) do
  %__MODULE__{
    type: :timeout_error,
    message: "#{operation} operation for backup '#{backup_id}' timed out",
    details: %{category: :backup, backup_id: backup_id, operation: operation}
  }
end

def invalid_backend(backend) do
  %__MODULE__{
    type: :bad_request,
    message: "Invalid backup backend: #{inspect(backend)}",
    details: %{category: :backup}
  }
end
```

**Tests first** in `test/weaviate_ex/error_test.exs`:
- `test "backup_not_found/2 creates correct error"`
- `test "backup_already_exists/2 creates correct error"`
- `test "backup_failed/2 creates correct error"`
- `test "restore_failed/2 creates correct error"`
- `test "backup_timeout/2 creates correct error"`

### Phase 7: Documentation Updates

#### 7.1 Update README.md

Add Backup section:

```markdown
## Backup & Restore

WeaviateEx provides full backup and restore capabilities with multiple storage backends.

### Creating Backups

```elixir
alias WeaviateEx.Backup.{Config, Location}

# Simple filesystem backup
{:ok, status} = WeaviateEx.create_backup(client, "daily-backup", :filesystem)

# S3 backup with specific collections
{:ok, status} = WeaviateEx.create_backup(client, "daily-backup", :s3,
  include_collections: ["Article", "Author"],
  wait_for_completion: true,
  config: Config.create(compression: :best_compression)
)

# Check backup status
{:ok, status} = WeaviateEx.get_backup_status(client, "daily-backup", :filesystem)
IO.puts("Status: #{status.status}")
```

### Restoring Backups

```elixir
# Restore all collections
{:ok, status} = WeaviateEx.restore_backup(client, "daily-backup", :filesystem,
  wait_for_completion: true
)

# Restore specific collections
{:ok, status} = WeaviateEx.restore_backup(client, "daily-backup", :s3,
  include_collections: ["Article"]
)
```

### Storage Backends

- `:filesystem` - Local filesystem (requires `BACKUP_FILESYSTEM_PATH` on server)
- `:s3` - Amazon S3 or S3-compatible storage
- `:gcs` - Google Cloud Storage
- `:azure` - Azure Blob Storage

### Listing and Managing Backups

```elixir
# List all backups
{:ok, backups} = WeaviateEx.list_backups(client, :filesystem)

# Cancel in-progress backup
:ok = WeaviateEx.cancel_backup(client, "daily-backup", :filesystem)
```
```

#### 7.2 Update CHANGELOG.md

```markdown
## [0.x.0] - 2025-12-28

### Added
- **Backup Module**: Complete backup and restore functionality
  - Create backups (`Backup.create/4`)
  - Restore backups (`Backup.restore/4`)
  - Status polling (`Backup.get_create_status/3`, `Backup.get_restore_status/3`)
  - List backups (`Backup.list/2`)
  - Cancel backups (`Backup.cancel/3`)
  - Wait for completion with configurable timeout
  - 4 storage backends: filesystem, S3, GCS, Azure
  - Backup configuration: CPU percentage, compression level
  - Storage location configuration with credentials support

- **Backup Types**
  - `WeaviateEx.Backup.Storage` - Storage backend enum
  - `WeaviateEx.Backup.Location` - Location configuration structs
  - `WeaviateEx.Backup.Config` - Create/restore configuration
  - `WeaviateEx.Backup.Status` - Status types and response structs
  - `WeaviateEx.Backup.Compression` - Compression level options

### Changed
- Extended `WeaviateEx.Error` with backup-specific error types

### Documentation
- Added backup & restore guide with all storage backends
- Updated README with backup examples
```

### Phase 8: Version Bump

#### 8.1 Update mix.exs

```elixir
def project do
  [
    app: :weaviate_ex,
    version: "0.x.0",  # Increment minor version
    # ...
  ]
end
```

---

## Quality Gates

### All Must Pass Before Completion

```bash
# 1. All tests pass
mix test

# 2. No compiler warnings
mix compile --warnings-as-errors

# 3. Dialyzer passes
mix dialyzer

# 4. Credo passes (strict mode)
mix credo --strict

# 5. Documentation generates without warnings
mix docs

# 6. Formatter check
mix format --check-formatted
```

### Test Coverage Requirements

- All 6 backup operations have tests
- All 4 storage backends tested
- All status transitions tested
- Wait/polling logic tested
- Error paths tested
- Integration tests with real Weaviate (filesystem backend minimum)

---

## Files to Create

```
lib/weaviate_ex/backup/
├── storage.ex               # Storage backend enum
├── compression.ex           # Compression level enum
├── status.ex                # Status types and response structs
├── config.ex                # Create/Restore configuration
└── location.ex              # Location structs (Filesystem, S3, GCS, Azure)

lib/weaviate_ex/api/
└── backup.ex                # Main backup operations API

test/weaviate_ex/backup/
├── storage_test.exs
├── compression_test.exs
├── status_test.exs
├── config_test.exs
└── location_test.exs

test/weaviate_ex/api/
└── backup_test.exs
```

## Files to Modify

```
lib/weaviate_ex.ex           # Add convenience delegations
lib/weaviate_ex/error.ex     # Add backup error types
mix.exs                      # Version bump
README.md                    # Add backup documentation
CHANGELOG.md                 # Document new features
```

---

## Success Criteria

1. `mix test` - All tests pass (0 failures)
2. `mix compile --warnings-as-errors` - No warnings
3. `mix dialyzer` - No errors
4. `mix credo --strict` - No issues
5. `mix docs` - Generates without warnings
6. All 6 backup operations implemented and tested
7. All 4 storage backends supported
8. Status polling with timeout works correctly
9. README documents backup usage with examples
10. CHANGELOG documents all new features
11. Version incremented in mix.exs

---

## Integration Test Requirements

Backup tests require Weaviate with backup modules enabled:

```yaml
# docker-compose.yml for testing
services:
  weaviate:
    image: semitechnologies/weaviate:latest
    environment:
      BACKUP_FILESYSTEM_PATH: /var/lib/weaviate/backups
    volumes:
      - weaviate_backups:/var/lib/weaviate/backups

volumes:
  weaviate_backups:
```

For S3/GCS/Azure testing, configure appropriate environment variables.

---

## Estimated Scope

| Component | Files | Estimated Effort |
|-----------|-------|------------------|
| Enums (Storage, Compression) | 2 | 2-3 hours |
| Status types | 1 | 3-4 hours |
| Config structs | 1 | 2-3 hours |
| Location structs (4 backends) | 1 | 4-6 hours |
| Backup API module | 1 | 8-12 hours |
| Error handling | 1 | 2-3 hours |
| Tests (unit + integration) | 6 | 12-16 hours |
| Documentation | 2 | 3-4 hours |
| **Total** | ~15 files | ~36-51 hours |

---

*This prompt provides complete instructions for implementing Backup operations in WeaviateEx with all storage backends, full test coverage, and documentation.*
