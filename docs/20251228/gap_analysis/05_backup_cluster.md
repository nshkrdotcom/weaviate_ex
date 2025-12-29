# Gap Analysis: Backup and Cluster Management

## Executive Summary

The Elixir WeaviateEx client has **ZERO** implementation of Backup and Cluster management features. The Python client provides comprehensive support for:

- **Backup Operations**: Create, restore, cancel, list backups with support for multiple storage backends (filesystem, S3, GCS, Azure)
- **Cluster Operations**: Node status, shard information, replication management

This represents a **Critical** gap for production-ready deployments where data backup and cluster management are essential.

### Gap Score: 0% (No implementation exists)

| Feature Area | Python Client | Elixir Client | Gap |
|--------------|---------------|---------------|-----|
| Backup Create | Full | None | Critical |
| Backup Restore | Full | None | Critical |
| Backup Status | Full | None | High |
| Backup Cancel | Full | None | High |
| Backup List | Full | None | High |
| Cluster Nodes | Full | None | High |
| Replication Management | Full | None | Medium |
| Sharding State | Full | None | Medium |

---

## Detailed Feature Comparison

### 1. Backup Operations

#### 1.1 Backup Storage Backends

| Backend | Python | Elixir | Priority |
|---------|--------|--------|----------|
| Filesystem | Yes | No | Critical |
| S3 | Yes | No | Critical |
| GCS (Google Cloud Storage) | Yes | No | High |
| Azure Blob Storage | Yes | No | High |

**Python Implementation:**

```python
from weaviate.backup import BackupStorage

# Filesystem backup
client.backup.create(
    backup_id="my-backup",
    backend=BackupStorage.FILESYSTEM,
    include_collections=["Article"],
    wait_for_completion=True
)

# S3 backup
client.backup.create(
    backup_id="my-backup",
    backend=BackupStorage.S3,
    include_collections=["Article"]
)

# GCS backup
client.backup.create(
    backup_id="my-backup",
    backend=BackupStorage.GCS,
    include_collections=["Article"]
)

# Azure backup
client.backup.create(
    backup_id="my-backup",
    backend=BackupStorage.AZURE,
    include_collections=["Article"]
)
```

**Proposed Elixir Implementation:**

```elixir
defmodule WeaviateEx.Backup do
  @moduledoc """
  Backup and restore operations for Weaviate.

  Supports multiple storage backends:
  - `:filesystem` - Local filesystem
  - `:s3` - Amazon S3
  - `:gcs` - Google Cloud Storage
  - `:azure` - Azure Blob Storage
  """

  @type backend :: :filesystem | :s3 | :gcs | :azure
  @type backup_id :: String.t()
  @type compression_level ::
    :default | :best_speed | :best_compression |
    :zstd_best_speed | :zstd_default | :zstd_best_compression |
    :no_compression
  @type backup_status :: :started | :transferring | :transferred | :success | :failed | :canceled

  @doc """
  Creates a backup of collections.

  ## Options
    - `:include_collections` - List of collections to include (optional)
    - `:exclude_collections` - List of collections to exclude (optional)
    - `:wait_for_completion` - Wait until backup completes (default: false)
    - `:config` - Backup configuration options
      - `:cpu_percentage` - CPU usage limit
      - `:compression_level` - Compression level

  ## Examples

      # Basic filesystem backup
      {:ok, backup} = WeaviateEx.Backup.create("my-backup", :filesystem)

      # S3 backup with specific collections
      {:ok, backup} = WeaviateEx.Backup.create("my-backup", :s3,
        include_collections: ["Article", "Author"],
        wait_for_completion: true
      )

      # With compression settings
      {:ok, backup} = WeaviateEx.Backup.create("my-backup", :filesystem,
        config: [compression_level: :best_compression, cpu_percentage: 80]
      )
  """
  @spec create(backup_id(), backend(), Keyword.t()) :: {:ok, map()} | {:error, term()}
  def create(backup_id, backend, opts \\ []) do
    include = Keyword.get(opts, :include_collections, [])
    exclude = Keyword.get(opts, :exclude_collections, [])
    wait = Keyword.get(opts, :wait_for_completion, false)
    config = Keyword.get(opts, :config, [])

    payload = %{
      "id" => backup_id,
      "include" => normalize_collections(include),
      "exclude" => normalize_collections(exclude)
    }
    |> maybe_add_config(config)

    path = "/v1/backups/#{backend}"

    case WeaviateEx.request(:post, path, payload) do
      {:ok, response} when wait ->
        wait_for_backup_completion(backup_id, backend, response)
      result ->
        result
    end
  end

  defp normalize_collections(collections) when is_list(collections) do
    Enum.map(collections, &String.capitalize/1)
  end
  defp normalize_collections(collection) when is_binary(collection) do
    [String.capitalize(collection)]
  end

  defp maybe_add_config(payload, []), do: payload
  defp maybe_add_config(payload, config) do
    config_map = %{}
    |> maybe_put("CPUPercentage", Keyword.get(config, :cpu_percentage))
    |> maybe_put("CompressionLevel", format_compression_level(Keyword.get(config, :compression_level)))

    if config_map == %{} do
      payload
    else
      Map.put(payload, "config", config_map)
    end
  end

  defp format_compression_level(nil), do: nil
  defp format_compression_level(:default), do: "DefaultCompression"
  defp format_compression_level(:best_speed), do: "BestSpeed"
  defp format_compression_level(:best_compression), do: "BestCompression"
  defp format_compression_level(:zstd_best_speed), do: "ZstdBestSpeed"
  defp format_compression_level(:zstd_default), do: "ZstdDefaultCompression"
  defp format_compression_level(:zstd_best_compression), do: "ZstdBestCompression"
  defp format_compression_level(:no_compression), do: "NoCompression"
end
```

---

#### 1.2 Backup Restore

**Python Implementation:**

```python
# Basic restore
client.backup.restore(
    backup_id="my-backup",
    backend=BackupStorage.FILESYSTEM,
    wait_for_completion=True
)

# Restore with options
client.backup.restore(
    backup_id="my-backup",
    backend=BackupStorage.S3,
    include_collections=["Article"],
    exclude_collections=["TempData"],
    config=BackupConfigRestore(cpu_percentage=50),
    wait_for_completion=True
)

# Restore with roles and users (RBAC)
client.backup.restore(
    backup_id="my-backup",
    backend=BackupStorage.FILESYSTEM,
    roles_restore="all",      # or "noRestore"
    users_restore="all",      # or "noRestore"
    overwrite_alias=True
)
```

**Proposed Elixir Implementation:**

```elixir
@doc """
Restores a backup.

## Options
  - `:include_collections` - List of collections to restore
  - `:exclude_collections` - List of collections to exclude from restore
  - `:wait_for_completion` - Wait until restore completes (default: false)
  - `:roles_restore` - How to handle roles: :all or :no_restore
  - `:users_restore` - How to handle users: :all or :no_restore
  - `:overwrite_alias` - Overwrite collection aliases if conflict (default: false)
  - `:config` - Restore configuration
    - `:cpu_percentage` - CPU usage limit

## Examples

    # Basic restore
    {:ok, result} = WeaviateEx.Backup.restore("my-backup", :filesystem)

    # Restore with waiting
    {:ok, result} = WeaviateEx.Backup.restore("my-backup", :s3,
      wait_for_completion: true,
      include_collections: ["Article"]
    )

    # Restore with RBAC options
    {:ok, result} = WeaviateEx.Backup.restore("my-backup", :filesystem,
      roles_restore: :all,
      users_restore: :all,
      overwrite_alias: true
    )
"""
@spec restore(backup_id(), backend(), Keyword.t()) :: {:ok, map()} | {:error, term()}
def restore(backup_id, backend, opts \\ []) do
  include = Keyword.get(opts, :include_collections, [])
  exclude = Keyword.get(opts, :exclude_collections, [])
  wait = Keyword.get(opts, :wait_for_completion, false)
  roles = Keyword.get(opts, :roles_restore)
  users = Keyword.get(opts, :users_restore)
  overwrite = Keyword.get(opts, :overwrite_alias, false)
  config = Keyword.get(opts, :config, [])

  payload = %{
    "include" => normalize_collections(include),
    "exclude" => normalize_collections(exclude),
    "overwriteAlias" => overwrite
  }
  |> maybe_add_restore_config(config, roles, users)

  path = "/v1/backups/#{backend}/#{backup_id}/restore"

  case WeaviateEx.request(:post, path, payload) do
    {:ok, response} when wait ->
      wait_for_restore_completion(backup_id, backend, response)
    result ->
      result
  end
end
```

---

#### 1.3 Backup Status

**Python Implementation:**

```python
# Get create status
status = client.backup.get_create_status(
    backup_id="my-backup",
    backend=BackupStorage.FILESYSTEM
)
print(status.status)  # BackupStatus.SUCCESS
print(status.path)
print(status.error)   # None if no error

# Get restore status
status = client.backup.get_restore_status(
    backup_id="my-backup",
    backend=BackupStorage.FILESYSTEM
)
```

**Proposed Elixir Implementation:**

```elixir
@doc """
Gets the status of a backup creation.

## Examples

    {:ok, status} = WeaviateEx.Backup.get_create_status("my-backup", :filesystem)
    # => {:ok, %{status: :success, path: "/backups/my-backup", error: nil}}
"""
@spec get_create_status(backup_id(), backend()) :: {:ok, map()} | {:error, term()}
def get_create_status(backup_id, backend) do
  path = "/v1/backups/#{backend}/#{String.downcase(backup_id)}"

  case WeaviateEx.request(:get, path, nil) do
    {:ok, response} ->
      {:ok, %{
        status: parse_status(response["status"]),
        path: response["path"],
        backup_id: backup_id,
        error: response["error"]
      }}
    error ->
      error
  end
end

@doc """
Gets the status of a backup restoration.

## Examples

    {:ok, status} = WeaviateEx.Backup.get_restore_status("my-backup", :filesystem)
"""
@spec get_restore_status(backup_id(), backend()) :: {:ok, map()} | {:error, term()}
def get_restore_status(backup_id, backend) do
  path = "/v1/backups/#{backend}/#{String.downcase(backup_id)}/restore"

  case WeaviateEx.request(:get, path, nil) do
    {:ok, response} ->
      {:ok, %{
        status: parse_status(response["status"]),
        path: response["path"],
        backup_id: backup_id,
        error: response["error"]
      }}
    error ->
      error
  end
end

defp parse_status("STARTED"), do: :started
defp parse_status("TRANSFERRING"), do: :transferring
defp parse_status("TRANSFERRED"), do: :transferred
defp parse_status("SUCCESS"), do: :success
defp parse_status("FAILED"), do: :failed
defp parse_status("CANCELED"), do: :canceled
```

---

#### 1.4 Backup Cancel

**Python Implementation:**

```python
# Cancel a running backup
success = client.backup.cancel(
    backup_id="my-backup",
    backend=BackupStorage.FILESYSTEM
)
print(success)  # True if cancelled successfully
```

**Proposed Elixir Implementation:**

```elixir
@doc """
Cancels a running backup.

## Examples

    {:ok, true} = WeaviateEx.Backup.cancel("my-backup", :filesystem)
"""
@spec cancel(backup_id(), backend()) :: {:ok, boolean()} | {:error, term()}
def cancel(backup_id, backend) do
  path = "/v1/backups/#{backend}/#{String.downcase(backup_id)}"

  case WeaviateEx.request(:delete, path, nil) do
    {:ok, _} -> {:ok, true}
    {:error, %{status: 204}} -> {:ok, true}
    {:error, %{status: 404}} -> {:ok, false}
    error -> error
  end
end
```

---

#### 1.5 Backup List

**Python Implementation:**

```python
# List all backups
backups = client.backup.list_backups(backend=BackupStorage.FILESYSTEM)
for backup in backups:
    print(f"ID: {backup.backup_id}")
    print(f"Status: {backup.status}")
    print(f"Collections: {backup.collections}")
    print(f"Started: {backup.started_at}")
    print(f"Completed: {backup.completed_at}")
    print(f"Size: {backup.size}")

# List with sorting
backups = client.backup.list_backups(
    backend=BackupStorage.S3,
    sort_by_starting_time_asc=True
)
```

**Proposed Elixir Implementation:**

```elixir
@doc """
Lists all backups for a storage backend.

## Options
  - `:sort_by_start_time` - Sort by start time: :asc or :desc

## Examples

    {:ok, backups} = WeaviateEx.Backup.list(:filesystem)
    # => {:ok, [
    #   %{
    #     backup_id: "backup-1",
    #     status: :success,
    #     collections: ["Article", "Author"],
    #     started_at: ~U[2024-01-15 10:00:00Z],
    #     completed_at: ~U[2024-01-15 10:05:00Z],
    #     size: 1024000.0
    #   }
    # ]}

    # Sorted by start time
    {:ok, backups} = WeaviateEx.Backup.list(:s3, sort_by_start_time: :asc)
"""
@spec list(backend(), Keyword.t()) :: {:ok, list(map())} | {:error, term()}
def list(backend, opts \\ []) do
  params = case Keyword.get(opts, :sort_by_start_time) do
    :asc -> "?order=asc"
    _ -> ""
  end

  path = "/v1/backups/#{backend}#{params}"

  case WeaviateEx.request(:get, path, nil) do
    {:ok, backups} when is_list(backups) ->
      {:ok, Enum.map(backups, &parse_backup_list_item/1)}
    error ->
      error
  end
end

defp parse_backup_list_item(item) do
  %{
    backup_id: item["id"],
    status: parse_status(item["status"]),
    collections: item["classes"] || [],
    started_at: parse_datetime(item["startedAt"]),
    completed_at: parse_datetime(item["completedAt"]),
    size: item["size"] || 0.0
  }
end

defp parse_datetime(nil), do: nil
defp parse_datetime(datetime_string) do
  case DateTime.from_iso8601(datetime_string) do
    {:ok, dt, _} -> dt
    _ -> nil
  end
end
```

---

#### 1.6 Dynamic Backup Location (Weaviate 1.27.2+)

**Python Implementation:**

```python
from weaviate.backup import BackupLocation

# Create with dynamic location
client.backup.create(
    backup_id="my-backup",
    backend=BackupStorage.S3,
    backup_location=BackupLocation.S3(
        path="/custom/path",
        bucket="my-bucket"
    )
)

# Filesystem with custom path
client.backup.create(
    backup_id="my-backup",
    backend=BackupStorage.FILESYSTEM,
    backup_location=BackupLocation.FileSystem(path="/custom/backup/path")
)

# GCP with custom location
client.backup.create(
    backup_id="my-backup",
    backend=BackupStorage.GCS,
    backup_location=BackupLocation.GCP(
        path="/custom/path",
        bucket="my-gcs-bucket"
    )
)

# Azure with custom location
client.backup.create(
    backup_id="my-backup",
    backend=BackupStorage.AZURE,
    backup_location=BackupLocation.Azure(
        path="/custom/path",
        bucket="my-container"  # Azure calls it container but API uses bucket
    )
)
```

**Proposed Elixir Implementation:**

```elixir
defmodule WeaviateEx.Backup.Location do
  @moduledoc """
  Dynamic backup location configurations for different storage backends.
  """

  @doc "Creates a filesystem location configuration"
  def filesystem(path) when is_binary(path) do
    %{type: :filesystem, path: path}
  end

  @doc "Creates an S3 location configuration"
  def s3(path, bucket) when is_binary(path) and is_binary(bucket) do
    %{type: :s3, path: path, bucket: bucket}
  end

  @doc "Creates a GCS location configuration"
  def gcs(path, bucket) when is_binary(path) and is_binary(bucket) do
    %{type: :gcs, path: path, bucket: bucket}
  end

  @doc "Creates an Azure location configuration"
  def azure(path, container) when is_binary(path) and is_binary(container) do
    %{type: :azure, path: path, bucket: container}
  end
end

# Usage in create/restore:
@doc """
Creates a backup with dynamic location.

## Examples

    # S3 with custom location
    {:ok, backup} = WeaviateEx.Backup.create("my-backup", :s3,
      location: WeaviateEx.Backup.Location.s3("/backups", "my-bucket")
    )
"""
```

---

### 2. Cluster Operations

#### 2.1 Get Cluster Nodes

**Python Implementation:**

```python
# Get minimal node info
nodes = client.cluster.nodes()
for node in nodes:
    print(f"Name: {node.name}")
    print(f"Status: {node.status}")
    print(f"Version: {node.version}")
    print(f"Git Hash: {node.git_hash}")

# Get verbose node info (includes shards and stats)
nodes = client.cluster.nodes(output="verbose")
for node in nodes:
    print(f"Name: {node.name}")
    print(f"Status: {node.status}")
    print(f"Stats: objects={node.stats.object_count}, shards={node.stats.shard_count}")
    for shard in node.shards:
        print(f"  Shard: {shard.name}")
        print(f"    Collection: {shard.collection}")
        print(f"    Object Count: {shard.object_count}")
        print(f"    Vector Status: {shard.vector_indexing_status}")
        print(f"    Compressed: {shard.compressed}")
        print(f"    Loaded: {shard.loaded}")

# Filter by collection
nodes = client.cluster.nodes(
    collection="Article",
    output="verbose"
)

# Filter by shard
nodes = client.cluster.nodes(
    collection="Article",
    shard="shard-0",
    output="verbose"
)
```

**Proposed Elixir Implementation:**

```elixir
defmodule WeaviateEx.Cluster do
  @moduledoc """
  Cluster management operations for Weaviate.

  Provides functions to:
  - Get node status and information
  - Query sharding state
  - Manage replication operations
  """

  @type verbosity :: :minimal | :verbose
  @type node_status :: :healthy | :unhealthy | :unavailable

  @doc """
  Gets information about all nodes in the cluster.

  ## Options
    - `:output` - Verbosity level: :minimal (default) or :verbose
    - `:collection` - Filter by collection name
    - `:shard` - Filter by shard name (requires collection)

  ## Examples

      # Minimal info
      {:ok, nodes} = WeaviateEx.Cluster.nodes()
      # => {:ok, [
      #   %{name: "node1", status: "HEALTHY", version: "1.28.0", git_hash: "abc123"}
      # ]}

      # Verbose info with shards and stats
      {:ok, nodes} = WeaviateEx.Cluster.nodes(output: :verbose)
      # => {:ok, [
      #   %{
      #     name: "node1",
      #     status: "HEALTHY",
      #     version: "1.28.0",
      #     git_hash: "abc123",
      #     stats: %{object_count: 1000, shard_count: 2},
      #     shards: [
      #       %{
      #         name: "shard-0",
      #         collection: "Article",
      #         object_count: 500,
      #         vector_indexing_status: :ready,
      #         vector_queue_length: 0,
      #         compressed: false,
      #         loaded: true
      #       }
      #     ]
      #   }
      # ]}

      # Filter by collection
      {:ok, nodes} = WeaviateEx.Cluster.nodes(collection: "Article", output: :verbose)
  """
  @spec nodes(Keyword.t()) :: {:ok, list(map())} | {:error, term()}
  def nodes(opts \\ []) do
    collection = Keyword.get(opts, :collection)
    shard = Keyword.get(opts, :shard)
    output = Keyword.get(opts, :output, :minimal)

    path = build_nodes_path(collection)
    params = build_nodes_params(shard, output)
    full_path = if params == "", do: path, else: "#{path}?#{params}"

    case WeaviateEx.request(:get, full_path, nil) do
      {:ok, %{"nodes" => nodes}} when is_list(nodes) ->
        {:ok, parse_nodes(nodes, output)}
      {:ok, response} ->
        {:error, {:unexpected_response, response}}
      error ->
        error
    end
  end

  defp build_nodes_path(nil), do: "/v1/nodes"
  defp build_nodes_path(collection), do: "/v1/nodes/#{String.capitalize(collection)}"

  defp build_nodes_params(shard, output) do
    params = []
    params = if shard, do: [{"shardName", shard} | params], else: params
    params = if output == :verbose, do: [{"output", "verbose"} | params], else: params

    params
    |> Enum.map(fn {k, v} -> "#{k}=#{URI.encode_www_form(v)}" end)
    |> Enum.join("&")
  end

  defp parse_nodes(nodes, :minimal) do
    Enum.map(nodes, fn node ->
      %{
        name: node["name"],
        status: node["status"],
        version: node["version"] || "",
        git_hash: node["gitHash"] || ""
      }
    end)
  end

  defp parse_nodes(nodes, :verbose) do
    Enum.map(nodes, fn node ->
      %{
        name: node["name"],
        status: node["status"],
        version: node["version"] || "",
        git_hash: node["gitHash"] || "",
        stats: parse_stats(node["stats"]),
        shards: parse_shards(node["shards"], node["name"])
      }
    end)
  end

  defp parse_stats(nil), do: %{object_count: 0, shard_count: 0}
  defp parse_stats(stats) do
    %{
      object_count: stats["objectCount"] || 0,
      shard_count: stats["shardCount"] || 0
    }
  end

  defp parse_shards(nil, _node_name), do: []
  defp parse_shards(shards, node_name) when is_list(shards) do
    Enum.map(shards, fn shard ->
      %{
        name: shard["name"],
        collection: shard["class"],
        node: node_name,
        object_count: shard["objectCount"],
        vector_indexing_status: parse_vector_status(shard["vectorIndexingStatus"]),
        vector_queue_length: shard["vectorQueueLength"],
        compressed: shard["compressed"],
        loaded: shard["loaded"]
      }
    end)
  end

  defp parse_vector_status("READY"), do: :ready
  defp parse_vector_status("INDEXING"), do: :indexing
  defp parse_vector_status("READONLY"), do: :readonly
  defp parse_vector_status("LAZY_LOADING"), do: :lazy_loading
  defp parse_vector_status(status), do: status
end
```

---

#### 2.2 Shard Replication Management

**Python Implementation:**

```python
# Replicate a shard to another node
task_id = client.cluster.replicate(
    collection="Article",
    shard="shard-0",
    source_node="node1",
    target_node="node2",
    replication_type=ReplicationType.COPY  # or MOVE
)

# Get replication operation status
operation = client.cluster.replications.get(uuid=task_id)
print(f"State: {operation.status.state}")
print(f"Errors: {operation.status.errors}")

# Get with history
operation = client.cluster.replications.get(uuid=task_id, include_history=True)
for status in operation.status_history:
    print(f"  State: {status.state}, Errors: {status.errors}")

# List all replication operations
operations = client.cluster.replications.list_all()

# Query replication operations
operations = client.cluster.replications.query(
    collection="Article",
    shard="shard-0",
    target_node="node2"
)

# Cancel a replication
client.cluster.replications.cancel(uuid=task_id)

# Delete a replication operation
client.cluster.replications.delete(uuid=task_id)

# Delete all replication operations
client.cluster.replications.delete_all()
```

**Proposed Elixir Implementation:**

```elixir
defmodule WeaviateEx.Cluster.Replications do
  @moduledoc """
  Shard replication management for Weaviate clusters.
  """

  @type replication_type :: :copy | :move
  @type replication_state :: :registered | :hydrating | :finalizing | :dehydrating | :ready | :cancelled

  @doc """
  Initiates a shard replication operation.

  ## Options
    - `:replication_type` - :copy (default) or :move

  ## Examples

      {:ok, task_id} = WeaviateEx.Cluster.Replications.replicate(
        collection: "Article",
        shard: "shard-0",
        source_node: "node1",
        target_node: "node2",
        replication_type: :copy
      )
  """
  @spec replicate(Keyword.t()) :: {:ok, String.t()} | {:error, term()}
  def replicate(opts) do
    body = %{
      "collection" => Keyword.fetch!(opts, :collection),
      "shard" => Keyword.fetch!(opts, :shard),
      "sourceNode" => Keyword.fetch!(opts, :source_node),
      "targetNode" => Keyword.fetch!(opts, :target_node),
      "type" => format_replication_type(Keyword.get(opts, :replication_type, :copy))
    }

    case WeaviateEx.request(:post, "/v1/replication/replicate", body) do
      {:ok, %{"id" => id}} -> {:ok, id}
      error -> error
    end
  end

  @doc """
  Gets a replication operation by UUID.

  ## Options
    - `:include_history` - Include status history (default: false)

  ## Examples

      {:ok, operation} = WeaviateEx.Cluster.Replications.get(task_id)
      {:ok, operation} = WeaviateEx.Cluster.Replications.get(task_id, include_history: true)
  """
  @spec get(String.t(), Keyword.t()) :: {:ok, map()} | {:error, term()}
  def get(uuid, opts \\ []) do
    include_history = Keyword.get(opts, :include_history, false)
    params = if include_history, do: "?includeHistory=true", else: ""

    case WeaviateEx.request(:get, "/v1/replication/replicate/#{uuid}#{params}", nil) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, response} -> {:ok, parse_replication_operation(response, include_history)}
      error -> error
    end
  end

  @doc """
  Lists all replication operations.

  ## Examples

      {:ok, operations} = WeaviateEx.Cluster.Replications.list_all()
  """
  @spec list_all() :: {:ok, list(map())} | {:error, term()}
  def list_all do
    case WeaviateEx.request(:get, "/v1/replication/replicate/list?includeHistory=true", nil) do
      {:ok, operations} when is_list(operations) ->
        {:ok, Enum.map(operations, &parse_replication_operation(&1, true))}
      error ->
        error
    end
  end

  @doc """
  Queries replication operations with filters.

  ## Options
    - `:collection` - Filter by collection
    - `:shard` - Filter by shard
    - `:target_node` - Filter by target node
    - `:include_history` - Include status history

  ## Examples

      {:ok, operations} = WeaviateEx.Cluster.Replications.query(
        collection: "Article",
        target_node: "node2"
      )
  """
  @spec query(Keyword.t()) :: {:ok, list(map())} | {:error, term()}
  def query(opts \\ []) do
    params = opts
    |> Keyword.take([:collection, :shard, :target_node, :include_history])
    |> Enum.map(fn
      {:collection, v} -> {"collection", v}
      {:shard, v} -> {"shard", v}
      {:target_node, v} -> {"targetNode", v}
      {:include_history, v} -> {"includeHistory", to_string(v)}
    end)
    |> URI.encode_query()

    path = if params == "", do: "/v1/replication/replicate/list", else: "/v1/replication/replicate/list?#{params}"
    include_history = Keyword.get(opts, :include_history, false)

    case WeaviateEx.request(:get, path, nil) do
      {:ok, operations} when is_list(operations) ->
        {:ok, Enum.map(operations, &parse_replication_operation(&1, include_history))}
      error ->
        error
    end
  end

  @doc """
  Cancels a replication operation.

  ## Examples

      :ok = WeaviateEx.Cluster.Replications.cancel(task_id)
  """
  @spec cancel(String.t()) :: :ok | {:error, term()}
  def cancel(uuid) do
    case WeaviateEx.request(:post, "/v1/replication/replicate/#{uuid}/cancel", %{}) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Deletes a replication operation.

  ## Examples

      :ok = WeaviateEx.Cluster.Replications.delete(task_id)
  """
  @spec delete(String.t()) :: :ok | {:error, term()}
  def delete(uuid) do
    case WeaviateEx.request(:delete, "/v1/replication/replicate/#{uuid}", nil) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Deletes all replication operations.

  ## Examples

      :ok = WeaviateEx.Cluster.Replications.delete_all()
  """
  @spec delete_all() :: :ok | {:error, term()}
  def delete_all do
    case WeaviateEx.request(:delete, "/v1/replication/replicate", nil) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  defp format_replication_type(:copy), do: "COPY"
  defp format_replication_type(:move), do: "MOVE"

  defp parse_replication_operation(data, include_history) do
    base = %{
      uuid: data["id"],
      collection: data["collection"],
      shard: data["shard"],
      source_node: data["sourceNode"],
      target_node: data["targetNode"],
      transfer_type: parse_transfer_type(data["type"]),
      status: parse_status(data["status"])
    }

    if include_history && data["statusHistory"] do
      Map.put(base, :status_history, Enum.map(data["statusHistory"], &parse_status/1))
    else
      Map.put(base, :status_history, nil)
    end
  end

  defp parse_transfer_type("COPY"), do: :copy
  defp parse_transfer_type("MOVE"), do: :move

  defp parse_status(nil), do: nil
  defp parse_status(status) do
    %{
      state: parse_state(status["state"]),
      errors: status["errors"] || []
    }
  end

  defp parse_state("REGISTERED"), do: :registered
  defp parse_state("HYDRATING"), do: :hydrating
  defp parse_state("FINALIZING"), do: :finalizing
  defp parse_state("DEHYDRATING"), do: :dehydrating
  defp parse_state("READY"), do: :ready
  defp parse_state("CANCELLED"), do: :cancelled
end
```

---

#### 2.3 Query Sharding State

**Python Implementation:**

```python
# Get sharding state for a collection
state = client.cluster.query_sharding_state(collection="Article")
if state:
    print(f"Collection: {state.collection}")
    for shard in state.shards:
        print(f"  Shard: {shard.name}")
        print(f"  Replicas: {shard.replicas}")

# Get sharding state for specific shard
state = client.cluster.query_sharding_state(
    collection="Article",
    shard="shard-0"
)
```

**Proposed Elixir Implementation:**

```elixir
@doc """
Queries the sharding state of a collection.

## Options
  - `:shard` - Query specific shard (optional)

## Examples

    {:ok, state} = WeaviateEx.Cluster.sharding_state("Article")
    # => {:ok, %{
    #   collection: "Article",
    #   shards: [
    #     %{name: "shard-0", replicas: ["node1", "node2"]},
    #     %{name: "shard-1", replicas: ["node2", "node3"]}
    #   ]
    # }}

    {:ok, state} = WeaviateEx.Cluster.sharding_state("Article", shard: "shard-0")
"""
@spec sharding_state(String.t(), Keyword.t()) :: {:ok, map() | nil} | {:error, term()}
def sharding_state(collection, opts \\ []) do
  shard = Keyword.get(opts, :shard)

  params = [{"collection", collection}]
  params = if shard, do: [{"shard", shard} | params], else: params
  query = URI.encode_query(params)

  case WeaviateEx.request(:get, "/v1/replication/sharding-state?#{query}", nil) do
    {:ok, nil} -> {:ok, nil}
    {:ok, %{"shardingState" => ss}} ->
      {:ok, %{
        collection: ss["collection"],
        shards: Enum.map(ss["shards"] || [], fn shard ->
          %{
            name: shard["shard"],
            replicas: shard["replicas"] || []
          }
        end)
      }}
    error ->
      error
  end
end
```

---

## Complete Module Structure

### Proposed File Structure

```
lib/weaviate_ex/
  backup.ex                    # Main backup module
  backup/
    location.ex               # Dynamic backup locations
    config.ex                 # Backup configuration structs
  cluster.ex                   # Main cluster module
  cluster/
    replications.ex           # Replication management
    nodes.ex                  # Node status helpers
```

---

## Priority Recommendations

### Critical Priority (Must Have for Production)

| Feature | Effort | Business Value |
|---------|--------|----------------|
| `Backup.create/3` | Medium | Essential for data safety |
| `Backup.restore/3` | Medium | Essential for disaster recovery |
| `Backup.get_create_status/2` | Low | Required for async backup monitoring |
| `Backup.get_restore_status/2` | Low | Required for async restore monitoring |

### High Priority (Important for Operations)

| Feature | Effort | Business Value |
|---------|--------|----------------|
| `Backup.list/2` | Low | Backup inventory management |
| `Backup.cancel/2` | Low | Abort long-running backups |
| `Cluster.nodes/1` | Low | Cluster health monitoring |

### Medium Priority (Enhanced Functionality)

| Feature | Effort | Business Value |
|---------|--------|----------------|
| `Backup.Location` module | Low | Flexible storage configuration |
| `Cluster.Replications` module | Medium | Advanced cluster management |
| `Cluster.sharding_state/2` | Low | Debugging shard distribution |

### Low Priority (Nice to Have)

| Feature | Effort | Business Value |
|---------|--------|----------------|
| Compression level options | Low | Performance tuning |
| RBAC restore options | Low | Enterprise features |

---

## Implementation Roadmap

### Phase 1: Core Backup (Week 1)
1. Implement `WeaviateEx.Backup` module with create/restore
2. Add status checking functions
3. Basic error handling

### Phase 2: Backup Enhancements (Week 2)
1. Add cancel and list functions
2. Implement `WeaviateEx.Backup.Location` module
3. Add configuration options (compression, CPU)
4. Add wait_for_completion with polling

### Phase 3: Cluster Basics (Week 3)
1. Implement `WeaviateEx.Cluster.nodes/1`
2. Add verbose output parsing
3. Implement `sharding_state/2`

### Phase 4: Replication Management (Week 4)
1. Implement `WeaviateEx.Cluster.Replications` module
2. Add all CRUD operations for replication tasks
3. Add query filtering

---

## Testing Considerations

### Required Test Infrastructure

```elixir
# test/support/backup_test_helpers.ex
defmodule WeaviateEx.BackupTestHelpers do
  @backup_test_timeout 60_000  # Backups can take time

  def wait_for_backup(backup_id, backend, timeout \\ @backup_test_timeout) do
    start = System.monotonic_time(:millisecond)

    Stream.repeatedly(fn -> WeaviateEx.Backup.get_create_status(backup_id, backend) end)
    |> Stream.take_while(fn
      {:ok, %{status: :success}} -> false
      {:ok, %{status: :failed}} -> false
      {:ok, %{status: :canceled}} -> false
      _ -> (System.monotonic_time(:millisecond) - start) < timeout
    end)
    |> Enum.take(-1)
  end
end
```

### Docker Compose for Testing

Testing backup functionality requires specific Weaviate configuration:

```yaml
# ci/docker-compose-backup.yml
services:
  weaviate:
    image: semitechnologies/weaviate:latest
    environment:
      BACKUP_FILESYSTEM_PATH: "/tmp/backups"
      ENABLE_MODULES: "backup-filesystem"
    volumes:
      - ./backups:/tmp/backups
```

---

## Summary

The Elixir client completely lacks Backup and Cluster management features that are fully implemented in the Python client. This gap analysis identifies:

- **16 missing features** across Backup and Cluster modules
- **4 Critical** features for production deployments
- **3 High** priority features for operations
- **5 Medium** priority features for advanced use cases

Implementing these features should follow the phased approach outlined above, with Critical features in the first phase to enable production-ready deployments.
