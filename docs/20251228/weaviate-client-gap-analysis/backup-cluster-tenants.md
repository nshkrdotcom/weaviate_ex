# Backup, Cluster & Tenants Gap Analysis

## Overview
Comprehensive comparison of Weaviate Python vs Elixir client Backup, Cluster, and Tenant operations.

**Analysis Date:** 2025-12-28
**Python Files Analyzed:** `weaviate/backup/`, `weaviate/cluster/`, `weaviate/collections/tenants/`
**Elixir Files Analyzed:** `lib/weaviate_ex/api/tenants.ex`

---

## Executive Summary

- **Tenants**: ~90% feature parity with some Elixir-only convenience functions
- **Backup**: ❌ Entirely missing in Elixir
- **Cluster**: ❌ Entirely missing in Elixir

---

## Backup Operations (ENTIRELY MISSING)

### Python Backup Features (`weaviate/backup/`)

| Operation | Python Method | Elixir Status |
|-----------|---------------|---------------|
| Create backup | `backup.create(backup_id, backend, ...)` | ❌ Missing |
| Get create status | `backup.get_create_status(backup_id, backend)` | ❌ Missing |
| Restore backup | `backup.restore(backup_id, backend, ...)` | ❌ Missing |
| Get restore status | `backup.get_restore_status(backup_id, backend)` | ❌ Missing |
| List backups | `backup.list_backups(backend, ...)` | ❌ Missing |
| Cancel backup | `backup.cancel(backup_id, backend)` | ❌ Missing |

### Backup Configuration Options
```python
backup.create(
    backup_id=backup_id,
    backend=BackupStorage.FILESYSTEM,  # S3, GCS, AZURE
    include_collections=["Article"],
    exclude_collections=["Temp"],
    wait_for_completion=True,
    config=BackupConfigCreate(
        cpu_percentage=50,
        compression_level=BackupCompressionLevel.BEST_COMPRESSION
    )
)
```

### Backup Storage Backends
- `BackupStorage.FILESYSTEM`
- `BackupStorage.S3`
- `BackupStorage.GCS`
- `BackupStorage.AZURE`

### Backup Location Classes
```python
BackupLocation.FileSystem(path="/backups")
BackupLocation.S3(bucket="my-bucket", path="/backups")
BackupLocation.GCP(bucket="my-bucket", path="/backups")
BackupLocation.Azure(bucket="container-name", path="/backups")
```

**Elixir Status**: ❌ All backup functionality missing

---

## Cluster Operations (ENTIRELY MISSING)

### Python Cluster Features (`weaviate/cluster/`)

| Operation | Python Method | Elixir Status |
|-----------|---------------|---------------|
| Get nodes | `cluster.nodes(collection, shard, output)` | ❌ Missing |
| Query sharding state | `cluster.query_sharding_state(collection, shard)` | ❌ Missing |
| Replicate shard | `cluster.replicate(collection, shard, source, target, type)` | ❌ Missing |

### Replication Operations (`weaviate/cluster/replicate/`)

| Operation | Python Method | Elixir Status |
|-----------|---------------|---------------|
| Get operation | `cluster.replications.get(uuid, include_history)` | ❌ Missing |
| List all operations | `cluster.replications.list_all()` | ❌ Missing |
| Query operations | `cluster.replications.query(collection, shard, target_node)` | ❌ Missing |
| Cancel operation | `cluster.replications.cancel(uuid)` | ❌ Missing |
| Delete operation | `cluster.replications.delete(uuid)` | ❌ Missing |
| Delete all operations | `cluster.replications.delete_all()` | ❌ Missing |

### Replication Types
```python
ReplicationType.COPY  # Copy shard to another node
ReplicationType.MOVE  # Move shard to another node
```

**Elixir Status**: ❌ All cluster functionality missing

---

## Tenant Operations

### Tenant CRUD

| Operation | Python | Elixir | Status |
|-----------|--------|--------|--------|
| Create tenant(s) | `tenants.create([Tenant(...)])` | `Tenants.create/3` | ✅ Full |
| Delete tenant(s) | `tenants.remove(["t1", "t2"])` | `Tenants.delete/3` | ✅ Full |
| Get tenant by name | `tenants.get_by_name("t1")` | `Tenants.get/3` | ✅ Full |
| Get tenants by names | `tenants.get_by_names(["t1", "t2"])` | ❌ Not implemented | Gap |
| List all tenants | `tenants.get()` | `Tenants.list/2` | ✅ Full |
| Check exists | `tenants.exists("t1")` | `Tenants.exists?/3` | ✅ Full |

### Activity Status Operations

| Operation | Python | Elixir | Status |
|-----------|--------|--------|--------|
| Update status | `tenants.update([Tenant(..., status)])` | `Tenants.update/4` | ✅ Full |
| Activate | `tenants.activate(["t1"])` | `Tenants.activate/3` | ✅ Full |
| Deactivate | `tenants.deactivate(["t1"])` | `Tenants.deactivate/3` | ✅ Full |
| Offload | `tenants.offload(["t1"])` | `Tenants.offload/3` | ✅ Full |

### Activity Status Types

| Status | Python | Elixir | Description |
|--------|--------|--------|-------------|
| ACTIVE | ✅ `TenantActivityStatus.ACTIVE` | ✅ `:hot` | Loaded in memory |
| INACTIVE | ✅ `TenantActivityStatus.INACTIVE` | ✅ `:cold` | Files stored locally |
| OFFLOADED | ✅ `TenantActivityStatus.OFFLOADED` | ✅ `:frozen` | Files in cloud storage |
| ONLOADING | ✅ Read-only transition | ✅ Read-only | Transition state |
| OFFLOADING | ✅ Read-only transition | ✅ Read-only | Transition state |

### Elixir-Only Features (ADVANTAGE)

| Feature | Elixir Method | Notes |
|---------|---------------|-------|
| List active tenants | `Tenants.list_active/2` | Filter by ACTIVE status |
| List inactive tenants | `Tenants.list_inactive/2` | Filter by INACTIVE status |
| Count tenants | `Tenants.count/2` | Get tenant count |

**Python Equivalent**: Requires client-side filtering

---

## Python File References

### Backup
- Executor: `weaviate/backup/executor.py`
- Locations: `weaviate/backup/backup_location.py`
- Sync/Async: `weaviate/backup/sync.py`, `weaviate/backup/async_.py`

### Cluster
- Base: `weaviate/cluster/base.py`
- Models: `weaviate/cluster/models.py`
- Replicate: `weaviate/cluster/replicate/executor.py`

### Tenants
- Executor: `weaviate/collections/tenants/executor.py`
- Types: `weaviate/collections/tenants/types.py`
- Classes: `weaviate/collections/classes/tenants.py`

---

## Elixir File References

### Tenants
- API: `lib/weaviate_ex/api/tenants.ex`

### Missing Modules to Create
```
lib/weaviate_ex/
├── api/
│   ├── backup.ex         # All backup operations
│   └── cluster.ex        # All cluster operations
├── backup/
│   ├── config.ex         # BackupConfig, compression levels
│   └── location.ex       # BackupLocation variants
└── cluster/
    ├── replicate.ex      # Replication operations
    └── models.ex         # Node, ShardingState models
```

---

## Summary Table

| Category | Python Features | Elixir Features | Gap |
|----------|-----------------|-----------------|-----|
| **Backup** | | | |
| Create/Restore | ✅ | ❌ | Missing |
| Status polling | ✅ | ❌ | Missing |
| List/Cancel | ✅ | ❌ | Missing |
| 4 Storage backends | ✅ | ❌ | Missing |
| Compression config | ✅ | ❌ | Missing |
| **Cluster** | | | |
| Get nodes | ✅ | ❌ | Missing |
| Sharding state | ✅ | ❌ | Missing |
| Shard replication | ✅ | ❌ | Missing |
| Replication management | ✅ | ❌ | Missing |
| **Tenants** | | | |
| Create | ✅ | ✅ | Full |
| Delete | ✅ | ✅ | Full |
| Get by name | ✅ | ✅ | Full |
| Get by names (batch) | ✅ | ❌ | Missing |
| List all | ✅ | ✅ | Full |
| Exists check | ✅ | ✅ | Full |
| Activity status update | ✅ | ✅ | Full |
| Convenience methods | ✅ | ✅ | Full |
| Filter by status | ❌ | ✅ | Elixir+ |
| Count | ❌ | ✅ | Elixir+ |

---

## Recommendations

### High Priority
1. **Implement Backup Module** - Complete backup/restore functionality
2. **Implement Cluster Module** - Node and sharding state queries
3. **Add `get_by_names/3`** - Batch tenant retrieval

### Medium Priority
4. **Shard Replication** - COPY/MOVE operations
5. **Replication Management** - Operation tracking and cancellation
6. **Backup Storage Backends** - S3, GCS, Azure location support

### Low Priority
7. **Compression Configuration** - Backup compression levels
8. **CPU Percentage Config** - Resource management for backups
