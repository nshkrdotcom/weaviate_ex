# Deep Gap Analysis: Backup and Restore Functionality

## Executive Summary

This document provides a comprehensive comparison of backup and restore functionality between the canonical Python client (`weaviate-python-client/weaviate/backup/`) and the Elixir port (`lib/weaviate_ex/api/backup.ex`, `lib/weaviate_ex/backup/`). The analysis covers all aspects of backup operations including creation, restoration, status monitoring, storage backends, compression, async patterns, cancellation, and error handling.

**Overall Assessment**: The Elixir implementation provides **excellent parity** with the Python client for core backup functionality. All four storage backends are supported, dynamic backup locations are fully implemented with even richer configuration options than Python, and all compression levels are available. The identified gaps are primarily in advanced features and developer experience enhancements.

### Summary Matrix

| Category | Python Client | Elixir Port | Gap Level |
|----------|--------------|-------------|-----------|
| Backup Creation (Full) | Complete | Complete | **None** |
| Backup Creation (Partial/Collection) | Collection-level API | Global API only | Minor |
| Backup Restore | Complete | Complete | **None** |
| Status Monitoring | Full support | Full support with extras | **None** |
| Storage Backends (4 types) | Complete | Complete | **None** |
| Compression Options (7 levels) | Complete | Complete | **None** |
| Wait/Async Patterns | Native async/await | Sync with polling | Medium |
| Backup Cancellation | Full support | Full support | **None** |
| Error Handling | Specific exceptions | Generic error struct | Minor |
| Dynamic Locations | Basic fields | Extended fields | **Elixir Better** |
| List with Sorting | Supported | Supported | **None** |
| List Metadata | Full metadata | Full metadata | **None** |
| Version Checking | Automatic | Not implemented | Medium |

---

## 1. Backup Creation

### 1.1 Full Backup (All Collections)

#### Python Implementation
**File**: `weaviate-python-client/weaviate/backup/executor.py`

```python
def create(
    self,
    backup_id: str,
    backend: BackupStorage,
    include_collections: Union[List[str], str, None] = None,
    exclude_collections: Union[List[str], str, None] = None,
    wait_for_completion: bool = False,
    config: Optional[BackupConfigCreate] = None,
    backup_location: Optional[BackupLocationType] = None,
) -> executor.Result[BackupReturn]:
```

**Key Features**:
- Storage backends: filesystem, s3, gcs, azure
- Dynamic backup location configuration
- Include/exclude collections filtering
- Wait for completion with internal polling loop
- Configuration options: CPU percentage, compression level
- Automatic version checking for dynamic locations (requires Weaviate 1.27.2+)

#### Elixir Implementation
**File**: `lib/weaviate_ex/api/backup.ex`

```elixir
@spec create(Client.t(), String.t(), Storage.t() | Location.t(), keyword()) ::
        {:ok, Status.CreateResponse.t()} | {:error, Error.t()}
def create(client, backup_id, backend, opts \\ [])

# Options:
# - :include_collections - List of collections to include
# - :exclude_collections - List of collections to exclude
# - :wait_for_completion - Wait for backup to complete (default: false)
# - :config - Backup configuration (Config.Create struct)
# - :poll_interval - Status poll interval in ms (default: 1000)
# - :timeout - Maximum wait time in ms (default: 300000)
```

**Supported Pattern Matching**:
```elixir
def create(client, backup_id, %Location.Filesystem{} = location, opts)
def create(client, backup_id, %Location.S3{} = location, opts)
def create(client, backup_id, %Location.GCS{} = location, opts)
def create(client, backup_id, %Location.Azure{} = location, opts)
def create(client, backup_id, backend, opts) when is_atom(backend)
```

#### Gap Analysis

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Basic backup creation | Yes | Yes | **Parity** |
| Filesystem backend | Yes | Yes | **Parity** |
| S3 backend | Yes | Yes | **Parity** |
| GCS backend | Yes | Yes | **Parity** |
| Azure backend | Yes | Yes | **Parity** |
| Include collections | Yes | Yes | **Parity** |
| Exclude collections | Yes | Yes | **Parity** |
| Include as string or list | Yes | List only | Minor Gap |
| Wait for completion | Yes | Yes | **Parity** |
| Poll interval configuration | No | Yes | **Elixir Better** |
| Timeout configuration | No | Yes | **Elixir Better** |
| Dynamic location | Yes | Yes | **Parity** |
| Version check for dynamic location | Yes | No | **Gap** |

### 1.2 Partial/Collection Backup

#### Python Implementation
**File**: `weaviate-python-client/weaviate/collections/backups/executor.py`

```python
class _CollectionBackupExecutor(Generic[ConnectionType]):
    def __init__(self, connection: ConnectionType, name: str) -> None:
        self._executor = _BackupExecutor(connection)
        self._name = name

    def create(
        self,
        backup_id: str,
        backend: BackupStorage,
        wait_for_completion: bool = False,
        config: Optional[BackupConfigCreate] = None,
        backup_location: Optional[BackupLocationType] = None,
    ) -> executor.Result[BackupStatusReturn]:
        # Automatically includes only this collection
        return executor.execute(
            method=self._executor.create,
            include_collections=[self._name],
            ...
        )
```

**Usage**:
```python
article = client.collections.use("Article")
article.backup.create(backup_id="article-backup", backend=BackupStorage.FILESYSTEM)
```

#### Elixir Implementation

**Not implemented as collection-level API**. Users must use the global backup API:

```elixir
# Equivalent in Elixir
Backup.create(client, "article-backup", :filesystem, include_collections: ["Article"])
```

#### Gap Analysis

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Collection-level create API | Yes | No | **Gap** |
| Single collection backup via include | Yes | Yes | **Parity** |
| Multi-collection partial backup | Yes | Yes | **Parity** |
| Exclude collections filtering | Yes | Yes | **Parity** |

**Impact**: Minor - functionality is available, just with different ergonomics.

---

## 2. Backup Restore Operations

### Python Implementation
**File**: `weaviate-python-client/weaviate/backup/executor.py`

```python
def restore(
    self,
    backup_id: str,
    backend: BackupStorage,
    include_collections: Union[List[str], str, None] = None,
    exclude_collections: Union[List[str], str, None] = None,
    roles_restore: Optional[Literal["noRestore", "all"]] = None,
    users_restore: Optional[Literal["noRestore", "all"]] = None,
    wait_for_completion: bool = False,
    config: Optional[BackupConfigRestore] = None,
    backup_location: Optional[BackupLocationType] = None,
    overwrite_alias: bool = False,
) -> executor.Result[BackupReturn]:
```

### Elixir Implementation
**File**: `lib/weaviate_ex/api/backup.ex`

```elixir
@spec restore(Client.t(), String.t(), Storage.t() | Location.t(), keyword()) ::
        {:ok, Status.RestoreResponse.t()} | {:error, Error.t()}
def restore(client, backup_id, backend, opts \\ [])

# Options:
# - :include_collections - List of collections to restore
# - :exclude_collections - List of collections to exclude
# - :wait_for_completion - Wait for restore to complete (default: false)
# - :config - Restore configuration (Config.Restore struct)
# - :poll_interval - Status poll interval in ms (default: 1000)
# - :timeout - Maximum wait time in ms (default: 300000)
# - :roles_restore - RBAC roles restore: :all, :none, or list of role names
# - :users_restore - RBAC users restore: :all, :none, or list of user IDs
# - :overwrite_alias - Whether to overwrite existing aliases (default: false)
```

### Gap Analysis

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Basic restore | Yes | Yes | **Parity** |
| Include collections | Yes | Yes | **Parity** |
| Exclude collections | Yes | Yes | **Parity** |
| Wait for completion | Yes | Yes | **Parity** |
| CPU percentage config | Yes | Yes | **Parity** |
| roles_restore option | Yes ("noRestore", "all") | Yes (:all, :none, list) | **Elixir Better** |
| users_restore option | Yes ("noRestore", "all") | Yes (:all, :none, list) | **Elixir Better** |
| overwrite_alias option | Yes | Yes | **Parity** |
| Dynamic location | Yes | Yes | **Parity** |
| Collection-level restore | Yes | No | **Gap** |

**Note**: Elixir's RBAC options support lists of specific roles/users, which Python doesn't expose as easily.

---

## 3. Backup Status Monitoring

### Python Implementation
**File**: `weaviate-python-client/weaviate/backup/backup.py`

```python
class BackupStatus(str, Enum):
    STARTED = "STARTED"
    TRANSFERRING = "TRANSFERRING"
    TRANSFERRED = "TRANSFERRED"
    SUCCESS = "SUCCESS"
    FAILED = "FAILED"
    CANCELED = "CANCELED"

class BackupStatusReturn(BaseModel):
    error: Optional[str] = Field(default=None)
    status: BackupStatus
    path: str
    backup_id: str = Field(alias="id")

class BackupReturn(BackupStatusReturn):
    collections: List[str] = Field(default_factory=list, alias="classes")
```

### Elixir Implementation
**File**: `lib/weaviate_ex/backup/status.ex`

```elixir
@type status :: :started | :transferring | :transferred | :success | :failed | :canceled

defmodule CreateResponse do
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

# Helper functions
@spec completed?(status()) :: boolean()
@spec success?(status()) :: boolean()
@spec in_progress?(status()) :: boolean()
```

### Gap Analysis

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| STARTED status | Yes | Yes (:started) | **Parity** |
| TRANSFERRING status | Yes | Yes (:transferring) | **Parity** |
| TRANSFERRED status | Yes | Yes (:transferred) | **Parity** |
| SUCCESS status | Yes | Yes (:success) | **Parity** |
| FAILED status | Yes | Yes (:failed) | **Parity** |
| CANCELED status | Yes | Yes (:canceled) | **Parity** |
| Error message | Yes | Yes | **Parity** |
| Path field | Yes | Yes | **Parity** |
| Collections field | Yes | Yes | **Parity** |
| Backend field | No | Yes | **Elixir Better** |
| completed?() helper | No | Yes | **Elixir Better** |
| success?() helper | No | Yes | **Elixir Better** |
| in_progress?() helper | No | Yes | **Elixir Better** |

---

## 4. Backend Storage Types

### Python Implementation
**File**: `weaviate-python-client/weaviate/backup/backup.py`

```python
STORAGE_NAMES = {"filesystem", "s3", "gcs", "azure"}

class BackupStorage(str, Enum):
    FILESYSTEM = "filesystem"
    S3 = "s3"
    GCS = "gcs"
    AZURE = "azure"
```

### Elixir Implementation
**File**: `lib/weaviate_ex/backup/storage.ex`

```elixir
@type t :: :filesystem | :s3 | :gcs | :azure

@backends [:filesystem, :s3, :gcs, :azure]

@spec all() :: [t()]
@spec valid?(atom()) :: boolean()
@spec to_api_path(t()) :: String.t()
@spec from_api(String.t()) :: {:ok, t()} | {:error, :invalid_backend}
```

### Gap Analysis

| Backend | Python | Elixir | Status |
|---------|--------|--------|--------|
| Filesystem | Yes | Yes | **Parity** |
| S3 | Yes | Yes | **Parity** |
| GCS | Yes | Yes | **Parity** |
| Azure | Yes | Yes | **Parity** |
| Validation helper | No | Yes (valid?/1) | **Elixir Better** |
| List all backends | No | Yes (all/0) | **Elixir Better** |

---

## 5. Compression Options

### Python Implementation
**File**: `weaviate-python-client/weaviate/backup/backup.py`

```python
class BackupCompressionLevel(str, Enum):
    DEFAULT = "DefaultCompression"
    BEST_SPEED = "BestSpeed"
    BEST_COMPRESSION = "BestCompression"
    ZSTD_BEST_SPEED = "ZstdBestSpeed"
    ZSTD_DEFAULT = "ZstdDefaultCompression"
    ZSTD_BEST_COMPRESSION = "ZstdBestCompression"
    NO_COMPRESSION = "NoCompression"

class BackupConfigCreate(_BackupConfigBase):
    CPUPercentage: Optional[int] = Field(default=None, alias="cpu_percentage")
    ChunkSize: Optional[int] = Field(  # DEPRECATED
        default=None,
        alias="chunk_size",
        description="DEPRECATED: This parameter no longer has any effect.",
        exclude=True,
    )
    CompressionLevel: Optional[BackupCompressionLevel] = Field(
        default=None, alias="compression_level"
    )
```

### Elixir Implementation
**File**: `lib/weaviate_ex/backup/compression.ex`

```elixir
@type t ::
        :default
        | :best_speed
        | :best_compression
        | :zstd_default
        | :zstd_best_speed
        | :zstd_best_compression
        | :no_compression

@gzip_levels [:default, :best_speed, :best_compression]
@zstd_levels [:zstd_default, :zstd_best_speed, :zstd_best_compression]

@spec all() :: [t()]
@spec valid?(atom()) :: boolean()
@spec gzip?(atom()) :: boolean()
@spec zstd?(atom()) :: boolean()
@spec to_api(t()) :: String.t()
@spec from_api(String.t()) :: {:ok, t()} | {:error, :invalid_compression}
```

**File**: `lib/weaviate_ex/backup/config.ex`

```elixir
defmodule Create do
  @type t :: %__MODULE__{
          cpu_percentage: pos_integer() | nil,
          chunk_size: pos_integer() | nil,
          compression: Compression.t() | nil
        }
  defstruct [:cpu_percentage, :chunk_size, :compression]
end

defmodule Restore do
  @type t :: %__MODULE__{cpu_percentage: pos_integer() | nil}
  defstruct [:cpu_percentage]
end
```

### Gap Analysis

| Compression Level | Python | Elixir | Status |
|-------------------|--------|--------|--------|
| Default (GZIP) | Yes | Yes (:default) | **Parity** |
| Best Speed (GZIP) | Yes | Yes (:best_speed) | **Parity** |
| Best Compression (GZIP) | Yes | Yes (:best_compression) | **Parity** |
| ZSTD Default | Yes | Yes (:zstd_default) | **Parity** |
| ZSTD Best Speed | Yes | Yes (:zstd_best_speed) | **Parity** |
| ZSTD Best Compression | Yes | Yes (:zstd_best_compression) | **Parity** |
| No Compression | Yes | Yes (:no_compression) | **Parity** |
| gzip?() helper | No | Yes | **Elixir Better** |
| zstd?() helper | No | Yes | **Elixir Better** |
| valid?() helper | No | Yes | **Elixir Better** |

---

## 6. Wait/Async Patterns

### Python Implementation
**Files**: `weaviate-python-client/weaviate/backup/executor.py`, `async_.py`, `sync.py`

```python
# Sync version
@executor.wrap("sync")
class _Backup(_BackupExecutor[ConnectionSync]):
    pass

# Async version
@executor.wrap("async")
class _BackupAsync(_BackupExecutor[ConnectionAsync]):
    pass

# Async waiting pattern
async def _execute() -> BackupReturn:
    res = await executor.aresult(
        self._connection.post(path=path, weaviate_object=payload, ...)
    )
    create_status = _decode_json_response_dict(res, "Backup creation")
    if wait_for_completion:
        while True:
            status = await executor.aresult(
                self.get_create_status(backup_id=backup_id, backend=backend)
            )
            if status.status == BackupStatus.SUCCESS:
                break
            if status.status == BackupStatus.FAILED:
                raise BackupFailedException(...)
            if status.status == BackupStatus.CANCELED:
                raise BackupCanceledError(...)
            await asyncio.sleep(1)
    return BackupReturn(**create_status)
```

### Elixir Implementation
**File**: `lib/weaviate_ex/api/backup.ex`

```elixir
@default_poll_interval 1000
@default_timeout 300_000

@spec wait_for_completion(
        Client.t(),
        String.t(),
        Storage.t(),
        :create | :restore,
        keyword()
      ) :: {:ok, Status.CreateResponse.t() | Status.RestoreResponse.t()} | {:error, Error.t()}
def wait_for_completion(client, backup_id, backend, operation, opts \\ []) do
  poll_interval = Keyword.get(opts, :poll_interval, @default_poll_interval)
  timeout = Keyword.get(opts, :timeout, @default_timeout)
  deadline = System.monotonic_time(:millisecond) + timeout

  do_wait_for_completion(client, backup_id, backend, operation, poll_interval, deadline)
end

defp do_wait_for_completion(client, backup_id, backend, operation, poll_interval, deadline) do
  if System.monotonic_time(:millisecond) > deadline do
    {:error, Error.backup_timeout(backup_id, operation)}
  else
    check_and_wait(client, backup_id, backend, operation, poll_interval, deadline)
  end
end

defp handle_status_check(_client, _backup_id, _backend, _op, _interval, _deadline, status)
     when status.status in [:success, :failed, :canceled] do
  {:ok, status}
end

defp handle_status_check(client, backup_id, backend, operation, poll_interval, deadline, _status) do
  Process.sleep(poll_interval)
  do_wait_for_completion(client, backup_id, backend, operation, poll_interval, deadline)
end
```

### Gap Analysis

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Synchronous API | Yes | Yes | **Parity** |
| Native async/await | Yes | No | **Gap** |
| Wait for completion | Yes | Yes | **Parity** |
| Configurable poll interval | Fixed (1 second) | Yes | **Elixir Better** |
| Configurable timeout | No | Yes | **Elixir Better** |
| Timeout handling | No timeout | Yes (error returned) | **Elixir Better** |
| Task-based async | No | Possible via Task.async | Architectural Difference |
| GenServer-based streaming | No | Possible | Architectural Difference |

**Critical Gap**: Python provides native async/await support through the `_BackupAsync` class. Elixir uses synchronous operations with polling. However, Elixir's concurrency model through processes and Task makes this less impactful:

```elixir
# Elixir pattern for async backup
Task.async(fn -> Backup.create(client, "backup-id", :filesystem, wait_for_completion: true) end)
```

---

## 7. Backup Cancellation

### Python Implementation
**File**: `weaviate-python-client/weaviate/backup/executor.py`

```python
def cancel(
    self,
    backup_id: str,
    backend: BackupStorage,
    backup_location: Optional[BackupLocationType] = None,
) -> executor.Result[bool]:
    """Cancels a running backup.

    Returns:
        A bool indicating if the cancellation was successful.
    """
    path = f"/backups/{backend.value}/{backup_id}"
    params: Dict[str, str] = {}

    if backup_location is not None:
        if self._connection._weaviate_version.is_lower_than(1, 27, 2):
            raise WeaviateUnsupportedFeatureError(...)
        params.update(backup_location._to_dict())

    return executor.execute(
        response_callback=resp,
        method=self._connection.delete,
        path=path,
        params=params,
        status_codes=_ExpectedStatusCodes(ok_in=[204, 404], error="cancel backup"),
    )
```

### Elixir Implementation
**File**: `lib/weaviate_ex/api/backup.ex`

```elixir
@spec cancel(Client.t(), String.t(), Storage.t(), keyword()) ::
        :ok | {:error, Error.t()}
def cancel(client, backup_id, backend, opts \\ []) do
  path = "/v1/backups/#{Storage.to_api_path(backend)}/#{backup_id}"
  body = build_cancel_body(opts)

  case Client.request(client, :delete, path, body, []) do
    {:ok, _} -> :ok
    {:error, error} -> {:error, error}
  end
end

defp build_cancel_body(opts) do
  case Keyword.get(opts, :location) do
    nil -> nil
    %Location.Filesystem{} = loc -> %{"config" => Location.to_api(loc)}
    %Location.S3{} = loc -> %{"config" => Location.to_api(loc)}
    %Location.GCS{} = loc -> %{"config" => Location.to_api(loc)}
    %Location.Azure{} = loc -> %{"config" => Location.to_api(loc)}
  end
end
```

### Gap Analysis

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Basic cancel | Yes | Yes | **Parity** |
| Returns bool/ok | Yes (bool) | Yes (:ok) | **Parity** |
| Dynamic location support | Yes (params) | Yes (body) | **Parity** |
| Version check for location | Yes | No | **Gap** |
| 204/404 status handling | Yes | Yes | **Parity** |

---

## 8. Error Handling

### Python Implementation
**File**: `weaviate-python-client/weaviate/exceptions.py` (referenced in executor.py)

```python
from weaviate.exceptions import (
    BackupCanceledError,
    BackupFailedException,
    EmptyResponseException,
    WeaviateUnsupportedFeatureError,
)

# Specific exception raising
if status.status == BackupStatus.FAILED:
    raise BackupFailedException(
        f"Backup failed: {create_status} with error: {status.error}"
    )
if status.status == BackupStatus.CANCELED:
    raise BackupCanceledError(
        f"Backup was canceled: {create_status} with error: {status.error}"
    )

# Feature check
if backup_location is not None:
    if self._connection._weaviate_version.is_lower_than(1, 27, 2):
        raise WeaviateUnsupportedFeatureError(
            "BackupConfigCreate dynamic backup location",
            str(self._connection._weaviate_version),
            "1.27.2",
        )
```

### Elixir Implementation
**File**: `lib/weaviate_ex/api/backup.ex` (error handling pattern)

```elixir
# Generic error pattern
{:error, Error.invalid_backend(backend)}
{:error, Error.backup_timeout(backup_id, operation)}
{:error, error}

# Success/failure in status structs
defp handle_status_check(_client, _backup_id, _backend, _op, _interval, _deadline, status)
     when status.status in [:success, :failed, :canceled] do
  {:ok, status}  # Even failed/canceled returns {:ok, status}
end
```

### Gap Analysis

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| BackupFailedException | Yes | No (returns {:ok, status} with :failed) | Different Pattern |
| BackupCanceledError | Yes | No (returns {:ok, status} with :canceled) | Different Pattern |
| WeaviateUnsupportedFeatureError | Yes | No | **Gap** |
| EmptyResponseException | Yes | Generic error | Different Pattern |
| Error includes message | Yes | Yes | **Parity** |
| Error includes context | Yes | Yes (details map) | **Parity** |
| invalid_backend error | Via ValueError | Yes (Error.invalid_backend/1) | **Parity** |
| backup_timeout error | No (infinite wait) | Yes (Error.backup_timeout/2) | **Elixir Better** |

**Architectural Note**: Python raises exceptions on failure, while Elixir returns `{:ok, status}` even for failed/canceled backups, allowing the caller to check `status.status`. This is idiomatic for both languages.

---

## 9. Dynamic Backup Locations

### Python Implementation
**File**: `weaviate-python-client/weaviate/backup/backup_location.py`

```python
class _BackupLocationFilesystem(_BackupLocationConfig):
    path: str

class _BackupLocationS3(_BackupLocationConfig):
    path: str
    bucket: str

class _BackupLocationGCP(_BackupLocationConfig):
    path: str
    bucket: str

class _BackupLocationAzure(_BackupLocationConfig):
    path: str
    bucket: str

class BackupLocation:
    FileSystem = _BackupLocationFilesystem
    S3 = _BackupLocationS3
    GCP = _BackupLocationGCP
    Azure = _BackupLocationAzure
```

### Elixir Implementation
**File**: `lib/weaviate_ex/backup/location.ex`

```elixir
defmodule Filesystem do
  @type t :: %__MODULE__{path: String.t()}
  defstruct [:path]
end

defmodule S3 do
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
end

defmodule GCS do
  @type t :: %__MODULE__{
          bucket: String.t(),
          path: String.t(),
          project_id: String.t() | nil,
          credentials: map() | nil
        }
  defstruct [:bucket, :path, :project_id, :credentials]
end

defmodule Azure do
  @type t :: %__MODULE__{
          container: String.t(),
          path: String.t(),
          connection_string: String.t() | nil
        }
  defstruct [:container, :path, :connection_string]
end
```

### Gap Analysis

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Filesystem: path | Yes | Yes | **Parity** |
| S3: bucket | Yes | Yes | **Parity** |
| S3: path | Yes | Yes | **Parity** |
| S3: endpoint | No | Yes | **Elixir Better** |
| S3: region | No | Yes | **Elixir Better** |
| S3: access_key_id | No | Yes | **Elixir Better** |
| S3: secret_access_key | No | Yes | **Elixir Better** |
| S3: use_ssl | No | Yes | **Elixir Better** |
| GCS: bucket | Yes | Yes | **Parity** |
| GCS: path | Yes | Yes | **Parity** |
| GCS: project_id | No | Yes | **Elixir Better** |
| GCS: credentials | No | Yes | **Elixir Better** |
| Azure: bucket/container | Yes (bucket) | Yes (container) | **Parity** |
| Azure: path | Yes | Yes | **Parity** |
| Azure: connection_string | No | Yes | **Elixir Better** |
| Helper: backend/1 | No | Yes | **Elixir Better** |
| Helper: to_api/1 | Yes | Yes | **Parity** |

**Significant Advantage**: The Elixir implementation provides much richer dynamic location configuration, especially for cloud providers. This allows direct credential and connection configuration without relying solely on environment variables.

---

## 10. Backup Listing

### Python Implementation
**File**: `weaviate-python-client/weaviate/backup/executor.py`

```python
class BackupListReturn(BaseModel):
    collections: List[str] = Field(default_factory=list, alias="classes")
    status: BackupStatus
    backup_id: str = Field(alias="id")
    started_at: Optional[datetime] = Field(alias="startedAt", default=None)
    completed_at: Optional[datetime] = Field(alias="completedAt", default=None)
    size: float = Field(default=0)

def list_backups(
    self, backend: BackupStorage, sort_by_starting_time_asc: Optional[bool] = None
) -> executor.Result[List[BackupListReturn]]:
    path = f"/backups/{backend.value}"
    params = {}
    if sort_by_starting_time_asc:
        params["order"] = "asc"
    # ...
```

### Elixir Implementation
**File**: `lib/weaviate_ex/api/backup.ex`

```elixir
@spec list(Client.t(), Storage.t(), keyword()) ::
        {:ok, [Status.BackupInfo.t()]} | {:error, Error.t()}
def list(client, backend, opts \\ []) do
  sort_asc = Keyword.get(opts, :sort_by_starting_time_asc, false)
  query_string = if sort_asc, do: "?sortByStartingTimeAsc=true", else: ""
  path = "/v1/backups/#{Storage.to_api_path(backend)}#{query_string}"
  # ...
end
```

**File**: `lib/weaviate_ex/backup/status.ex`

```elixir
defmodule BackupInfo do
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
    :id, :backend, :status, :path, :started_at, :completed_at, :size_bytes, :error,
    collections: []
  ]
end
```

### Gap Analysis

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| List backups | Yes | Yes | **Parity** |
| sort_by_starting_time_asc | Yes | Yes | **Parity** |
| collections field | Yes | Yes | **Parity** |
| status field | Yes | Yes | **Parity** |
| backup_id field | Yes | Yes (id) | **Parity** |
| started_at field | Yes | Yes | **Parity** |
| completed_at field | Yes | Yes | **Parity** |
| size field | Yes (size: float) | Yes (size_bytes: integer) | **Parity** |
| backend field | No | Yes | **Elixir Better** |
| path field | No | Yes | **Elixir Better** |
| error field | No | Yes | **Elixir Better** |
| DateTime parsing | Pydantic auto | Manual ISO8601 parse | **Parity** |

---

## Critical Gaps Summary

### High Priority Gaps (Should Fix)

1. **Version Checking for Dynamic Locations**
   - **Python**: Automatically checks Weaviate version >= 1.27.2
   - **Elixir**: No version check
   - **Impact**: Users may get confusing errors on older Weaviate versions
   - **Recommendation**: Add version check in dynamic location code paths

2. **Native Async/Await Pattern**
   - **Python**: True async support with `_BackupAsync` class
   - **Elixir**: Synchronous with polling
   - **Impact**: Less flexible for concurrent operations in async contexts
   - **Recommendation**: Consider adding `create_async/4`, `restore_async/4` that return Tasks

### Medium Priority Gaps (Nice to Have)

3. **Collection-Level Backup API**
   - **Python**: `collection.backup.create()`, etc.
   - **Elixir**: Only global API with `include_collections`
   - **Impact**: Less ergonomic for single-collection backups
   - **Recommendation**: Add `WeaviateEx.Collection.Backup` module

4. **Include Collections as String**
   - **Python**: Accepts both `"Article"` and `["Article"]`
   - **Elixir**: Only accepts list
   - **Impact**: Minor convenience difference
   - **Recommendation**: Add clause to accept single string

### Low Priority Gaps (Minor)

5. **Specific Exception Types**
   - **Python**: `BackupFailedException`, `BackupCanceledError`
   - **Elixir**: Returns `{:ok, status}` with status containing failure info
   - **Impact**: Different error handling idiom (both valid)
   - **Recommendation**: Keep current pattern, optionally add specific error types

---

## Elixir Advantages

The Elixir implementation provides several advantages over Python:

1. **Richer Dynamic Location Configuration**
   - S3: endpoint, region, credentials, use_ssl
   - GCS: project_id, credentials
   - Azure: connection_string

2. **Better Timeout and Polling Control**
   - Configurable poll_interval (Python fixed at 1 second)
   - Configurable timeout with proper error handling
   - Python has no timeout (infinite wait possible)

3. **Helper Functions**
   - `Status.completed?/1`, `success?/1`, `in_progress?/1`
   - `Compression.gzip?/1`, `zstd?/1`, `valid?/1`
   - `Storage.valid?/1`, `all/0`

4. **Richer BackupInfo Struct**
   - Includes backend, path, error fields not present in Python
   - Uses DateTime vs datetime strings

5. **Pattern Matching for Locations**
   - Direct function clause matching on location type
   - More explicit and type-safe

---

## Test Coverage Comparison

### Python Integration Tests
**File**: `weaviate-python-client/integration/test_backup_v4.py`

- `test_create_and_restore_backup_with_waiting`
- `test_create_and_restore_backup_without_waiting`
- `test_create_and_restore_1_of_2_classes`
- `test_fail_on_non_existing_class`
- `test_fail_restoring_backup_for_existing_class`
- `test_fail_creating_existing_backup`
- `test_fail_restoring_non_existing_backup`
- `test_fail_checking_status_for_non_existing_restore`
- `test_fail_creating_backup_for_both_include_and_exclude_classes`
- `test_backup_and_restore_with_dynamic_location`
- `test_backup_and_restore_with_collection_and_config_1_24_x`
- `test_cancel_backup`
- `test_backup_and_restore_with_roles_and_users`
- `test_list_backup`
- `test_list_backup_ascending_order`
- `test_overwrite_alias_true`

### Elixir Integration Tests
**File**: `test/integration/backup_integration_test.exs`

- `Backup.create/3` - creates a backup to filesystem
- `Backup.create/3` - creates a backup with wait_for_completion
- `Backup.get_create_status/3` - gets backup status
- `Backup.list/2` - lists backups for filesystem backend
- Full backup and restore cycle - create, delete, restore, verify
- `Backup.restore/3` - restores a backup from filesystem
- `Backup.get_restore_status/3` - gets restore status after operation

**Missing Tests in Elixir**:
- Cancel backup test
- Dynamic location tests
- RBAC (roles/users) restore tests
- Compression configuration tests
- List with sorting test
- Error scenario tests (existing class, non-existing backup, etc.)
- Overwrite alias test

---

## Recommendations

### Priority 1: Version Checking

```elixir
# lib/weaviate_ex/backup/version_check.ex
defmodule WeaviateEx.Backup.VersionCheck do
  @min_dynamic_location_version "1.27.2"

  def check_dynamic_location_support!(client) do
    case WeaviateEx.Meta.get(client) do
      {:ok, meta} ->
        version = meta["version"]
        if Version.compare(version, @min_dynamic_location_version) == :lt do
          raise WeaviateEx.UnsupportedFeatureError,
            feature: "Dynamic backup location",
            current_version: version,
            required_version: @min_dynamic_location_version
        end
      {:error, _} ->
        :ok  # Skip check if version unavailable
    end
  end
end
```

### Priority 2: Async Support

```elixir
# Add to lib/weaviate_ex/api/backup.ex
@doc """
Create a backup asynchronously.

Returns immediately with a Task that can be awaited.
"""
@spec create_async(Client.t(), String.t(), Storage.t() | Location.t(), keyword()) :: Task.t()
def create_async(client, backup_id, backend, opts \\ []) do
  Task.async(fn ->
    create(client, backup_id, backend, Keyword.put(opts, :wait_for_completion, true))
  end)
end

@spec restore_async(Client.t(), String.t(), Storage.t() | Location.t(), keyword()) :: Task.t()
def restore_async(client, backup_id, backend, opts \\ []) do
  Task.async(fn ->
    restore(client, backup_id, backend, Keyword.put(opts, :wait_for_completion, true))
  end)
end
```

### Priority 3: Include as String or List

```elixir
# Add helper in build_create_body
defp normalize_collections(nil), do: nil
defp normalize_collections(collection) when is_binary(collection), do: [collection]
defp normalize_collections(collections) when is_list(collections), do: collections
```

---

## Conclusion

The Elixir backup implementation provides **excellent feature parity** with the Python client, with several notable improvements in configuration flexibility, timeout handling, and helper functions. The identified gaps are primarily:

1. Missing version checking (medium priority)
2. No native async API (medium priority - mitigated by Elixir's Task system)
3. No collection-level API (low priority - same functionality available)

The implementation is **production-ready** for most use cases. The dynamic location support actually exceeds Python's capabilities with additional configuration options for cloud providers.
