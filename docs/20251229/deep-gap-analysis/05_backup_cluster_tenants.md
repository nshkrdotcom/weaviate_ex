# Deep Gap Analysis: Backup, Cluster, and Tenants

## Overview

This document provides a comprehensive comparison between the canonical Python Weaviate client and the Elixir port (WeaviateEx) for backup, cluster, and tenant management features.

**Analysis Date**: 2025-12-29
**Python Client Version**: Latest (from repository)
**Elixir Port Version**: v0.7.0

---

## 1. BACKUP FEATURES

### 1.1 Feature Inventory

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| **Storage Backends** |
| Filesystem | `BackupStorage.FILESYSTEM` | `:filesystem` | Implemented |
| S3 | `BackupStorage.S3` | `:s3` | Implemented |
| GCS | `BackupStorage.GCS` | `:gcs` | Implemented |
| Azure | `BackupStorage.AZURE` | `:azure` | Implemented |
| **Backup Operations** |
| Create backup | `backup.create()` | `Backup.create/4` | Implemented |
| Restore backup | `backup.restore()` | `Backup.restore/4` | Implemented |
| Get create status | `backup.get_create_status()` | `Backup.get_create_status/3` | Implemented |
| Get restore status | `backup.get_restore_status()` | `Backup.get_restore_status/3` | Implemented |
| List backups | `backup.list_backups()` | `Backup.list/2` | Implemented |
| Cancel backup | `backup.cancel()` | `Backup.cancel/3` | Implemented |
| Wait for completion | Built-in polling | `Backup.wait_for_completion/5` | Implemented |
| **Compression Options** |
| DefaultCompression | `BackupCompressionLevel.DEFAULT` | `:default` | Implemented |
| BestSpeed | `BackupCompressionLevel.BEST_SPEED` | `:best_speed` | Implemented |
| BestCompression | `BackupCompressionLevel.BEST_COMPRESSION` | `:best_compression` | Implemented |
| ZstdBestSpeed | `BackupCompressionLevel.ZSTD_BEST_SPEED` | `:zstd_best_speed` | Implemented |
| ZstdDefaultCompression | `BackupCompressionLevel.ZSTD_DEFAULT` | `:zstd_default` | Implemented |
| ZstdBestCompression | `BackupCompressionLevel.ZSTD_BEST_COMPRESSION` | `:zstd_best_compression` | Implemented |
| NoCompression | `BackupCompressionLevel.NO_COMPRESSION` | `:no_compression` | Implemented |
| **Configuration** |
| CPU percentage | `cpu_percentage` | `:cpu_percentage` | Implemented |
| Chunk size | `chunk_size` (deprecated) | `:chunk_size` | Implemented |
| **Collection Filtering** |
| Include collections | `include_collections` | `:include_collections` | Implemented |
| Exclude collections | `exclude_collections` | `:exclude_collections` | Implemented |
| **Dynamic Locations** |
| Filesystem location | `BackupLocation.FileSystem` | `Location.Filesystem` | Implemented |
| S3 location | `BackupLocation.S3` | `Location.S3` | Implemented |
| GCS location | `BackupLocation.GCP` | `Location.GCS` | Implemented |
| Azure location | `BackupLocation.Azure` | `Location.Azure` | Implemented |
| **Status Values** |
| STARTED | `BackupStatus.STARTED` | `:started` | Implemented |
| TRANSFERRING | `BackupStatus.TRANSFERRING` | `:transferring` | Implemented |
| TRANSFERRED | `BackupStatus.TRANSFERRED` | `:transferred` | Implemented |
| SUCCESS | `BackupStatus.SUCCESS` | `:success` | Implemented |
| FAILED | `BackupStatus.FAILED` | `:failed` | Implemented |
| CANCELED | `BackupStatus.CANCELED` | `:canceled` | Implemented |
| **RBAC Restore Options** |
| Roles restore | `roles_restore` | `:roles_restore` | Implemented |
| Users restore | `users_restore` | `:users_restore` | Implemented |
| Overwrite alias | `overwrite_alias` | `:overwrite_alias` | Implemented |
| **Return Types** |
| BackupReturn | `BackupReturn` | `Status.CreateResponse` | Implemented |
| BackupStatusReturn | `BackupStatusReturn` | `Status.CreateResponse` | Implemented |
| BackupListReturn | `BackupListReturn` | `Status.BackupInfo` | Partial |

### 1.2 Detailed Comparison

#### 1.2.1 Backup Creation

**Python:**
```python
from weaviate.backup import BackupStorage, BackupCompressionLevel
from weaviate.backup.backup import BackupConfigCreate

config = BackupConfigCreate(
    cpu_percentage=50,
    compression_level=BackupCompressionLevel.BEST_COMPRESSION
)

result = client.backup.create(
    backup_id="my-backup",
    backend=BackupStorage.S3,
    include_collections=["Article", "Author"],
    exclude_collections=None,
    wait_for_completion=True,
    config=config
)
```

**Elixir:**
```elixir
alias WeaviateEx.Backup.{Config, Location}

config = Config.create(
  cpu_percentage: 50,
  compression: :best_compression
)

{:ok, result} = WeaviateEx.API.Backup.create(client, "my-backup", :s3,
  include_collections: ["Article", "Author"],
  wait_for_completion: true,
  config: config
)
```

#### 1.2.2 Dynamic Location Configuration

**Python:**
```python
from weaviate.backup.backup_location import BackupLocation

location = BackupLocation.S3(path="/backups", bucket="my-bucket")

result = client.backup.create(
    backup_id="my-backup",
    backend=BackupStorage.S3,
    backup_location=location
)
```

**Elixir:**
```elixir
alias WeaviateEx.Backup.Location

location = Location.s3("my-bucket", "/backups",
  region: "us-west-2",
  access_key_id: "...",
  secret_access_key: "..."
)

{:ok, result} = WeaviateEx.API.Backup.create(client, "my-backup", location)
```

#### 1.2.3 Backup Restoration with RBAC Options

**Python:**
```python
result = client.backup.restore(
    backup_id="my-backup",
    backend=BackupStorage.FILESYSTEM,
    roles_restore="all",
    users_restore="noRestore",
    overwrite_alias=True
)
```

**Elixir:**
```elixir
{:ok, result} = WeaviateEx.API.Backup.restore(client, "my-backup", :filesystem,
  roles_restore: :all,
  users_restore: :none,
  overwrite_alias: true
)
```

### 1.3 Backup Gaps Summary

| Gap | Priority | Description |
|-----|----------|-------------|
| BackupListReturn timestamps | Low | Python includes `started_at`, `completed_at`, `size` in list response |
| Version check for dynamic locations | Medium | Python validates Weaviate >= 1.27.2 for dynamic locations |
| Async client wrapper | Low | Python has separate `_BackupAsync` class |

---

## 2. CLUSTER FEATURES

### 2.1 Feature Inventory

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| **Node Operations** |
| Get nodes | `cluster.nodes()` | `Cluster.nodes/2` | Implemented |
| Minimal output | `output="minimal"` | `output: :minimal` | Implemented |
| Verbose output | `output="verbose"` | `output: :verbose` | Implemented |
| Filter by collection | `collection="..."` | `collection: "..."` | Implemented |
| Filter by shard | `shard="..."` | N/A | Missing |
| **Replication Operations** |
| Initiate replication | `cluster.replicate()` | `Cluster.replicate/4` | Implemented |
| Get replication status | `replications.get()` | `Cluster.get_replication/3` | Implemented |
| List replications | `replications.list_all()` | `Cluster.list_replications/2` | Implemented |
| Query replications | `replications.query()` | `Cluster.list_replications/2` | Implemented |
| Cancel replication | `replications.cancel()` | `Cluster.cancel_replication/2` | Implemented |
| Delete replication | `replications.delete()` | `Cluster.delete_replication/2` | Implemented |
| Delete all replications | `replications.delete_all()` | N/A | Missing |
| Include history | `include_history=True` | `include_history: true` | Implemented |
| **Sharding State** |
| Query sharding state | `cluster.query_sharding_state()` | N/A | Missing |
| **Replication Types** |
| COPY | `ReplicationType.COPY` | `:copy` | Implemented |
| MOVE | `ReplicationType.MOVE` | `:move` | Implemented |
| **Replication States** |
| REGISTERED | `ReplicateOperationState.REGISTERED` | N/A | Missing |
| HYDRATING | `ReplicateOperationState.HYDRATING` | N/A | Missing |
| FINALIZING | `ReplicateOperationState.FINALIZING` | N/A | Missing |
| DEHYDRATING | `ReplicateOperationState.DEHYDRATING` | N/A | Missing |
| READY | `ReplicateOperationState.READY` | `:completed` | Partial |
| CANCELLED | `ReplicateOperationState.CANCELLED` | `:cancelled` | Implemented |
| **Node Status** |
| Status parsing | `NodeMinimal`/`NodeVerbose` | `Node.t()` | Implemented |
| Git hash | `git_hash` | `git_hash` | Implemented |
| Version | `version` | `version` | Implemented |
| Stats | `stats: Stats` | `stats: map()` | Implemented |
| Shards | `shards: List[Shard]` | `shards: [Shard.t()]` | Implemented |
| **Shard Status** |
| READONLY | yes | `:readonly` | Implemented |
| INDEXING | yes | `:indexing` | Implemented |
| READY | yes | `:ready` | Implemented |
| LAZY_LOADING | yes | N/A | Missing |
| Vector queue length | yes | `vector_queue_size` | Implemented |
| Compressed | yes | `compressed` | Implemented |
| Loaded | yes | N/A | Missing |
| **Additional Features** |
| Batch stats | N/A | `Cluster.batch_stats/1` | Elixir Extra |
| Wait for replications | N/A | `Cluster.wait_for_replications/2` | Elixir Extra |
| Get shards | N/A | `Cluster.shards/2` | Elixir Extra |
| Cluster statistics | N/A | `Cluster.statistics/1` | Elixir Extra |

### 2.2 Detailed Comparison

#### 2.2.1 Node Information

**Python:**
```python
from weaviate.cluster.types import Verbosity

# Minimal output
nodes = client.cluster.nodes(output="minimal")

# Verbose with collection filter
nodes = client.cluster.nodes(
    collection="Article",
    output="verbose"
)

for node in nodes:
    print(f"{node.name}: {node.status}")
    if node.shards:
        for shard in node.shards:
            print(f"  Shard: {shard.name}, Objects: {shard.object_count}")
```

**Elixir:**
```elixir
# Minimal output
{:ok, nodes} = WeaviateEx.API.Cluster.nodes(client)

# Verbose with collection filter
{:ok, nodes} = WeaviateEx.API.Cluster.nodes(client,
  collection: "Article",
  output: :verbose
)

Enum.each(nodes, fn node ->
  IO.puts("#{node.name}: #{node.status}")
  if node.shards do
    Enum.each(node.shards, fn shard ->
      IO.puts("  Shard: #{shard.name}, Objects: #{shard.object_count}")
    end)
  end
end)
```

#### 2.2.2 Replication Operations

**Python:**
```python
import uuid

# Start replication
op_id = client.cluster.replicate(
    collection="Article",
    shard="shard-0",
    source_node="node-1",
    target_node="node-2",
    replication_type=ReplicationType.COPY
)

# Get status with history
status = client.cluster.replications.get(
    uuid=op_id,
    include_history=True
)

# Query by collection
ops = client.cluster.replications.query(
    collection="Article",
    include_history=False
)

# Cancel
client.cluster.replications.cancel(uuid=op_id)
```

**Elixir:**
```elixir
# Start replication
{:ok, op} = WeaviateEx.API.Cluster.replicate(client, "Article", "shard-0",
  source: "node-1",
  target: "node-2",
  type: :copy
)

# Get status with history
{:ok, status} = WeaviateEx.API.Cluster.get_replication(client, op.id,
  include_history: true
)

# Query by collection
{:ok, ops} = WeaviateEx.API.Cluster.list_replications(client,
  collection: "Article"
)

# Cancel
:ok = WeaviateEx.API.Cluster.cancel_replication(client, op.id)
```

### 2.3 Cluster Gaps Summary

| Gap | Priority | Description |
|-----|----------|-------------|
| `query_sharding_state` | High | Missing endpoint to query shard distribution |
| Shard filter in nodes | Low | Python allows filtering nodes by shard name |
| `delete_all` replications | Low | Batch delete of all replication operations |
| Detailed replication states | Medium | Missing REGISTERED, HYDRATING, FINALIZING, DEHYDRATING states |
| Shard LAZY_LOADING status | Low | Missing status for lazy-loading shards |
| Shard `loaded` field | Low | Missing boolean for shard load state |

---

## 3. TENANTS FEATURES

### 3.1 Feature Inventory

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| **CRUD Operations** |
| Create tenant | `tenants.create()` | `Tenants.create/4` | Implemented |
| Get all tenants | `tenants.get()` | `Tenants.list/2` | Implemented |
| Get by name | `tenants.get_by_name()` | `Tenants.get/3` | Implemented |
| Get by names | `tenants.get_by_names()` | N/A | Missing |
| Remove tenants | `tenants.remove()` | `Tenants.delete/3` | Implemented |
| Update tenants | `tenants.update()` | `Tenants.update/4` | Implemented |
| Check exists | `tenants.exists()` | `Tenants.exists?/3` | Implemented |
| **Activity Status Operations** |
| Activate | `tenants.activate()` | `Tenants.activate/3` | Implemented |
| Deactivate | `tenants.deactivate()` | `Tenants.deactivate/3` | Implemented |
| Offload | `tenants.offload()` | `Tenants.offload/3` | Implemented |
| Freeze | N/A | `Tenants.freeze/3` | Elixir Extra |
| **Activity Status Values** |
| ACTIVE/HOT | `TenantActivityStatus.ACTIVE` | `:hot` | Implemented |
| INACTIVE/COLD | `TenantActivityStatus.INACTIVE` | `:cold` | Implemented |
| OFFLOADED/FROZEN | `TenantActivityStatus.OFFLOADED` | `:frozen`/`:offloaded` | Implemented |
| OFFLOADING | `TenantActivityStatus.OFFLOADING` | `:offloading` | Implemented |
| ONLOADING | `TenantActivityStatus.ONLOADING` | `:onloading` | Implemented |
| WARM | N/A | `:warm` | Elixir Extra |
| UNFREEZING | N/A | `:unfreezing` | Elixir Extra |
| FREEZING | N/A | `:freezing` | Elixir Extra |
| **gRPC Support** |
| gRPC list | Yes (auto-detected) | Yes (auto-detected) | Implemented |
| gRPC get by names | Yes | Yes | Implemented |
| **Batch Operations** |
| Batch create | Yes (list input) | Yes (list input) | Implemented |
| Batch update | Yes (with batching) | Yes | Partial |
| Batch delete | Yes (list input) | Yes (list input) | Implemented |
| **Return Types** |
| Tenant dict | `Dict[str, Tenant]` | `[map()]` | Different |
| TenantOutput | `TenantOutput` | map() | Different |
| **Validation** |
| Activity status validation | Yes (on create/update) | Partial | Partial |
| Update batch size limit | 100 per request | No limit | Different |
| **Additional Features** |
| Count tenants | N/A | `Tenants.count/2` | Elixir Extra |
| List active | N/A | `Tenants.list_active/2` | Elixir Extra |
| List inactive | N/A | `Tenants.list_inactive/2` | Elixir Extra |

### 3.2 Detailed Comparison

#### 3.2.1 Creating Tenants

**Python:**
```python
from weaviate.collections.classes.tenants import Tenant, TenantCreate

# Simple creation
collection.tenants.create("tenant1")

# With activity status
collection.tenants.create(
    TenantCreate(name="tenant1", activity_status="INACTIVE")
)

# Batch creation
collection.tenants.create([
    TenantCreate(name="tenant1"),
    TenantCreate(name="tenant2", activity_status="INACTIVE"),
    "tenant3"  # strings also allowed
])
```

**Elixir:**
```elixir
# Simple creation
{:ok, _} = WeaviateEx.API.Tenants.create(client, "Article", "tenant1")

# With activity status
{:ok, _} = WeaviateEx.API.Tenants.create(client, "Article", "tenant1",
  activity_status: :cold
)

# Batch creation
{:ok, _} = WeaviateEx.API.Tenants.create(client, "Article",
  ["tenant1", "tenant2", "tenant3"],
  activity_status: :hot
)
```

#### 3.2.2 Updating Activity Status

**Python:**
```python
from weaviate.collections.classes.tenants import Tenant, TenantUpdate

# Activate
collection.tenants.activate("tenant1")
collection.tenants.activate(["tenant1", "tenant2"])

# Deactivate
collection.tenants.deactivate("tenant1")

# Offload
collection.tenants.offload("tenant1")

# Generic update
collection.tenants.update(
    TenantUpdate(name="tenant1", activity_status="INACTIVE")
)
```

**Elixir:**
```elixir
# Activate
{:ok, _} = WeaviateEx.API.Tenants.activate(client, "Article", "tenant1")
{:ok, _} = WeaviateEx.API.Tenants.activate(client, "Article", ["tenant1", "tenant2"])

# Deactivate
{:ok, _} = WeaviateEx.API.Tenants.deactivate(client, "Article", "tenant1")

# Offload
{:ok, _} = WeaviateEx.API.Tenants.offload(client, "Article", "tenant1")

# Freeze (Elixir extra)
{:ok, _} = WeaviateEx.API.Tenants.freeze(client, "Article", "tenant1")

# Generic update
{:ok, _} = WeaviateEx.API.Tenants.update(client, "Article", "tenant1",
  activity_status: :cold
)
```

#### 3.2.3 Retrieving Tenants

**Python:**
```python
# Get all (returns Dict[str, Tenant])
tenants = collection.tenants.get()
for name, tenant in tenants.items():
    print(f"{name}: {tenant.activity_status}")

# Get by name (returns Optional[Tenant])
tenant = collection.tenants.get_by_name("tenant1")
if tenant:
    print(tenant.activity_status)

# Get by names (returns Dict[str, Tenant])
tenants = collection.tenants.get_by_names(["tenant1", "tenant2"])

# Check exists
exists = collection.tenants.exists("tenant1")
```

**Elixir:**
```elixir
# Get all (returns list of maps)
{:ok, tenants} = WeaviateEx.API.Tenants.list(client, "Article")
Enum.each(tenants, fn t ->
  IO.puts("#{t["name"]}: #{t["activityStatus"]}")
end)

# Get by name (returns map or error)
{:ok, tenant} = WeaviateEx.API.Tenants.get(client, "Article", "tenant1")

# Check exists
{:ok, true} = WeaviateEx.API.Tenants.exists?(client, "Article", "tenant1")

# Count (Elixir extra)
{:ok, 5} = WeaviateEx.API.Tenants.count(client, "Article")

# List active only (Elixir extra)
{:ok, active} = WeaviateEx.API.Tenants.list_active(client, "Article")
```

### 3.3 Activity Status Mapping

| Canonical Status | Python Value | Elixir Value | Notes |
|-----------------|--------------|--------------|-------|
| Active | `ACTIVE` | `:hot` | Elixir uses legacy names |
| Inactive | `INACTIVE` | `:cold` | Elixir uses legacy names |
| Offloaded | `OFFLOADED` | `:frozen`/`:offloaded` | Both supported |
| Offloading | `OFFLOADING` | `:offloading` | Transition state |
| Onloading | `ONLOADING` | `:onloading` | Transition state |

**Note:** Python deprecated `HOT`, `COLD`, `FROZEN` in favor of `ACTIVE`, `INACTIVE`, `OFFLOADED`. Elixir still uses the legacy naming convention in some places.

### 3.4 Tenants Gaps Summary

| Gap | Priority | Description |
|-----|----------|-------------|
| `get_by_names` | Medium | Batch get specific tenants by name list |
| Return type as Dict | Low | Python returns `Dict[str, Tenant]`, Elixir returns `[map()]` |
| Tenant struct | Medium | Elixir returns plain maps, not typed structs |
| Batch update size limiting | Low | Python limits updates to 100 per request |
| Activity status validation | Medium | Python validates status is writable on create/update |
| Status naming convention | Low | Consider updating to ACTIVE/INACTIVE/OFFLOADED |

---

## 4. REPLICATION CONFIGURATION

### 4.1 Feature Inventory

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Replication factor | Collection config | Collection config | Implemented |
| Async replication | Yes | Yes | Implemented |
| Shard replication (copy) | `ReplicationType.COPY` | `:copy` | Implemented |
| Shard replication (move) | `ReplicationType.MOVE` | `:move` | Implemented |

### 4.2 Replication Status States

**Python States (detailed):**
- `REGISTERED` - Operation registered
- `HYDRATING` - Copying data to target
- `FINALIZING` - Completing replication
- `DEHYDRATING` - Removing from source (for MOVE)
- `READY` - Operation complete
- `CANCELLED` - Operation cancelled

**Elixir States (simplified):**
- `:pending` - Operation waiting
- `:running` - Operation in progress
- `:completed` - Operation complete
- `:failed` - Operation failed
- `:cancelled` - Operation cancelled

### 4.3 Replication Gaps

| Gap | Priority | Description |
|-----|----------|-------------|
| Granular replication states | Medium | Elixir uses simplified states vs Python's detailed states |
| Status history parsing | Low | Python returns `List[ReplicateOperationStatus]` for history |

---

## 5. PRIORITY RECOMMENDATIONS

### 5.1 High Priority

1. **Add `query_sharding_state`** - Essential for monitoring shard distribution in clusters
2. **Add `get_by_names` for tenants** - Efficient batch tenant lookup

### 5.2 Medium Priority

1. **Tenant struct types** - Replace raw maps with proper Elixir structs
2. **Granular replication states** - Add REGISTERED, HYDRATING, FINALIZING, DEHYDRATING
3. **Activity status validation** - Validate status values on create/update
4. **BackupListReturn timestamps** - Add `started_at`, `completed_at`, `size` fields

### 5.3 Low Priority

1. **Update activity status naming** - Consider ACTIVE/INACTIVE/OFFLOADED
2. **Shard filter in nodes** - Add shard name filter to nodes endpoint
3. **Delete all replications** - Batch delete operation
4. **Batch update size limiting** - Match Python's 100-per-request limit
5. **Shard LAZY_LOADING status** - Add new shard status
6. **Shard `loaded` field** - Boolean for shard load state

---

## 6. IMPLEMENTATION NOTES

### 6.1 File Locations

**Python:**
- `/weaviate-python-client/weaviate/backup/backup.py` - Backup types and models
- `/weaviate-python-client/weaviate/backup/executor.py` - Backup operations
- `/weaviate-python-client/weaviate/backup/backup_location.py` - Location configs
- `/weaviate-python-client/weaviate/cluster/base.py` - Cluster executor
- `/weaviate-python-client/weaviate/cluster/models.py` - Replication models
- `/weaviate-python-client/weaviate/cluster/replicate/executor.py` - Replicate operations
- `/weaviate-python-client/weaviate/collections/tenants/executor.py` - Tenant operations
- `/weaviate-python-client/weaviate/collections/classes/tenants.py` - Tenant types

**Elixir:**
- `/lib/weaviate_ex/api/backup.ex` - Main backup API
- `/lib/weaviate_ex/backup/storage.ex` - Storage backends
- `/lib/weaviate_ex/backup/status.ex` - Status types
- `/lib/weaviate_ex/backup/location.ex` - Location configs
- `/lib/weaviate_ex/backup/compression.ex` - Compression options
- `/lib/weaviate_ex/backup/config.ex` - Backup configuration
- `/lib/weaviate_ex/api/cluster.ex` - Cluster API
- `/lib/weaviate_ex/cluster/node.ex` - Node types
- `/lib/weaviate_ex/cluster/shard.ex` - Shard types
- `/lib/weaviate_ex/cluster/replication.ex` - Replication types
- `/lib/weaviate_ex/api/tenants.ex` - Tenants API

### 6.2 Elixir Extras (Features beyond Python)

1. **Cluster:**
   - `Cluster.batch_stats/1` - Aggregated batch queue statistics
   - `Cluster.wait_for_replications/2` - Wait for all replications to complete
   - `Cluster.shards/2` - Direct shard access for a collection
   - `Cluster.statistics/1` - Cluster-wide statistics

2. **Tenants:**
   - `Tenants.count/2` - Count total tenants
   - `Tenants.list_active/2` - Filter to active tenants only
   - `Tenants.list_inactive/2` - Filter to inactive tenants only
   - `Tenants.freeze/3` - Explicit freeze operation

3. **Backup:**
   - Extended S3 location config (endpoint, region, credentials)
   - Helper functions for status checks (completed?, success?, in_progress?)

---

## 7. SUMMARY

### Overall Implementation Status

| Category | Features Implemented | Features Missing | Coverage |
|----------|---------------------|------------------|----------|
| Backup | 35 | 3 | ~92% |
| Cluster | 22 | 6 | ~79% |
| Tenants | 18 | 4 | ~82% |
| **Total** | **75** | **13** | **~85%** |

The Elixir port provides comprehensive coverage of the Python client's backup, cluster, and tenant features. Key areas for improvement are:

1. Adding `query_sharding_state` for cluster topology visibility
2. Implementing `get_by_names` for efficient tenant lookups
3. Enhancing tenant types with proper Elixir structs
4. Adding granular replication state tracking

The Elixir port also provides several features beyond the Python client, particularly around batch statistics, convenient filtering helpers, and extended location configuration options.
