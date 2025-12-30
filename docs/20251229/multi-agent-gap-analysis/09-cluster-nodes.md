# Deep Gap Analysis: Cluster and Node Management

## Overview

This document provides a comprehensive comparison of cluster and node management capabilities between the Python Weaviate client and the Elixir WeaviateEx port.

### Files Analyzed

**Python Client:**
- `weaviate-python-client/weaviate/cluster/__init__.py`
- `weaviate-python-client/weaviate/cluster/base.py`
- `weaviate-python-client/weaviate/cluster/models.py`
- `weaviate-python-client/weaviate/cluster/types.py`
- `weaviate-python-client/weaviate/cluster/sync.py`
- `weaviate-python-client/weaviate/cluster/async_.py`
- `weaviate-python-client/weaviate/cluster/replicate/executor.py`
- `weaviate-python-client/weaviate/collections/classes/cluster.py`

**Elixir Port:**
- `lib/weaviate_ex/api/cluster.ex`
- `lib/weaviate_ex/cluster/node.ex`
- `lib/weaviate_ex/cluster/shard.ex`
- `lib/weaviate_ex/cluster/replication.ex`

---

## 1. Node Listing and Status

### Python Implementation

```python
# Nodes endpoint with flexible verbosity
def nodes(
    self,
    collection: Optional[str] = None,
    shard: Optional[str] = None,
    *,
    output: Optional[Verbosity] = None,
) -> Union[List[NodeMinimal], List[NodeVerbose]]:
    """Get the status of all nodes in the cluster."""
    path = "/nodes"
    params = {}
    if collection is not None:
        path += "/" + _capitalize_first_letter(collection)
    if shard is not None:
        params["shardName"] = shard
    if output is not None:
        params["output"] = output
    # ...
```

**Python Node Types:**
```python
@dataclass
class Node(Generic[Sh, St]):
    git_hash: str
    name: str
    shards: Sh        # List[Shard] or None
    stats: St         # Stats or None
    status: str
    version: str

NodeVerbose = Node[Shards, Stats]
NodeMinimal = Node[None, None]
```

**Python Shard Model:**
```python
@dataclass
class Shard:
    collection: str
    name: str
    node: str
    object_count: int
    vector_indexing_status: Literal["READONLY", "INDEXING", "READY", "LAZY_LOADING"]
    vector_queue_length: int
    compressed: bool
    loaded: Optional[bool]  # not present in <1.24.x
```

### Elixir Implementation

```elixir
@spec nodes(Client.t(), opts()) :: {:ok, [Node.t()]} | {:error, Error.t()}
def nodes(client, opts \\ []) do
  collection = Keyword.get(opts, :collection)
  output = Keyword.get(opts, :output, :minimal)
  path = build_nodes_path(collection, output)
  # ...
end
```

**Elixir Node Type:**
```elixir
@type t :: %__MODULE__{
  name: String.t(),
  status: status(),           # :healthy | :unhealthy | :unavailable
  version: String.t() | nil,
  git_hash: String.t() | nil,
  stats: map() | nil,
  shards: [Shard.t()] | nil
}
```

**Elixir Shard Type:**
```elixir
@type t :: %__MODULE__{
  name: String.t(),
  collection: String.t() | nil,
  status: status(),                      # :ready | :readonly | :indexing | :loading
  object_count: non_neg_integer(),
  vector_queue_size: non_neg_integer(),
  vector_indexing_status: String.t() | nil,
  compressed: boolean()
}
```

### Comparison Table

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| List all nodes | `client.cluster.nodes()` | `Cluster.nodes(client)` | Implemented |
| Minimal output | `output=None` or `"minimal"` | `output: :minimal` | Implemented |
| Verbose output | `output="verbose"` | `output: :verbose` | Implemented |
| Filter by collection | `collection="Article"` | `collection: "Article"` | Implemented |
| Filter by shard | `shard="shard-0"` | N/A | **Missing** |
| Type overloading | `Union[NodeMinimal, NodeVerbose]` | Single `Node.t()` type | Different approach |
| Shard `node` field | Present | N/A | **Missing** |
| Shard `loaded` field | `Optional[bool]` | N/A | **Missing** |
| `LAZY_LOADING` status | Supported | N/A | **Missing** |

### Critical Gaps

1. **Shard Name Filtering**: Python supports filtering nodes by specific shard name via the `shard` parameter. Elixir lacks this capability.

2. **Shard `loaded` Field**: Python tracks whether a shard is loaded into memory (`loaded: Optional[bool]`), important for lazy loading scenarios. Elixir is missing this field.

3. **`LAZY_LOADING` Vector Status**: Python supports the `LAZY_LOADING` vector indexing status. Elixir only handles `READY`, `READONLY`, `INDEXING`, `LOADING`.

### Minor Gaps

1. **Shard `node` Field**: Python's Shard model includes the `node` field indicating which node hosts the shard. Elixir omits this.

2. **Type Generics**: Python uses generic types to distinguish `NodeMinimal` from `NodeVerbose`. Elixir uses a single type with optional fields.

---

## 2. Shard Information

### Python Implementation

```python
# Shards accessed via collection
def shards(self) -> List[Shard]:
    """Get the statuses of all shards of this collection."""
    return [
        shard
        for node in self.__cluster.nodes(self.name, output="verbose")
        for shard in node.shards
    ]
```

### Elixir Implementation

```elixir
@spec shards(Client.t(), String.t()) :: {:ok, [Shard.t()]} | {:error, Error.t()}
def shards(client, collection) do
  case Client.request(client, :get, "/v1/schema/#{collection}/shards", nil, []) do
    {:ok, shards_data} when is_list(shards_data) ->
      shards = shards_data
        |> Enum.map(&Shard.from_api/1)
        |> Enum.map(fn shard -> %{shard | collection: collection} end)
      {:ok, shards}
    # ...
  end
end
```

### Comparison Table

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Get shards for collection | Via `collection.shards()` | `Cluster.shards(client, collection)` | Implemented |
| API endpoint | Uses `/nodes` with verbose | Uses `/schema/{collection}/shards` | Different approach |
| Shard name | `shard.name` | `shard.name` | Implemented |
| Object count | `shard.object_count` | `shard.object_count` | Implemented |
| Vector queue | `shard.vector_queue_length` | `shard.vector_queue_size` | Different naming |
| Compressed flag | `shard.compressed` | `shard.compressed` | Implemented |
| Loaded flag | `shard.loaded` | N/A | **Missing** |
| Helper: `ready?/1` | N/A | `Shard.ready?/1` | Elixir extra |
| Helper: `vectors_indexed?/1` | N/A | `Shard.vectors_indexed?/1` | Elixir extra |

### Critical Gaps

1. **Shard `loaded` Field**: Missing from Elixir implementation.

### API Differences

- **Field Naming**: Python uses `vector_queue_length`, Elixir uses `vector_queue_size`.
- **API Approach**: Python derives shards from nodes endpoint; Elixir uses dedicated schema endpoint.

### Elixir Enhancements

Elixir provides helper functions not present in Python:
- `Shard.ready?/1` - Check if shard is ready for queries
- `Shard.vectors_indexed?/1` - Check if all vectors are indexed

---

## 3. Cluster Health

### Python Implementation

Python doesn't have a dedicated cluster health endpoint. Health is inferred from node status.

```python
# Health checking via node status
nodes = client.cluster.nodes()
all_healthy = all(node.status == "HEALTHY" for node in nodes)
```

### Elixir Implementation

```elixir
@spec statistics(Client.t()) :: {:ok, map()} | {:error, Error.t()}
def statistics(client) do
  Client.request(client, :get, "/v1/cluster/statistics", nil, [])
end
```

And node health helpers:
```elixir
@spec healthy?(t()) :: boolean()
def healthy?(%__MODULE__{status: :healthy}), do: true
def healthy?(_), do: false
```

### Comparison Table

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Cluster statistics | N/A | `Cluster.statistics/1` | Elixir extra |
| Node health check | Via node.status | `Node.healthy?/1` | Implemented |
| Total object count | N/A | `Node.total_object_count/1` | Elixir extra |
| Shards for collection | N/A | `Node.shards_for_collection/2` | Elixir extra |

### Elixir Enhancements

Elixir provides additional cluster analysis functions:
1. `Cluster.statistics/1` - Retrieve cluster-wide statistics
2. `Node.healthy?/1` - Boolean health check
3. `Node.total_object_count/1` - Sum objects across all node shards
4. `Node.shards_for_collection/2` - Filter shards by collection

---

## 4. Statistics Retrieval

### Python Implementation

Python provides batch statistics through the nodes endpoint:

```python
class BatchStats(TypedDict):
    queueLength: int
    ratePerSecond: int

class Node(TypedDict):
    batchStats: BatchStats
    # ...
```

### Elixir Implementation

```elixir
@type batch_stats :: %{
  queue_length: non_neg_integer(),
  rate_per_second: float(),
  failed_count: non_neg_integer()
}

@spec batch_stats(Client.t()) :: {:ok, batch_stats()} | {:error, Error.t()}
def batch_stats(client) do
  case nodes(client, output: :verbose) do
    {:ok, nodes_list} ->
      stats = aggregate_batch_stats(nodes_list)
      {:ok, stats}
    {:error, _} = error -> error
  end
end
```

### Comparison Table

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Batch queue length | `batchStats.queueLength` | `batch_stats.queue_length` | Implemented |
| Batch rate per second | `batchStats.ratePerSecond` | `batch_stats.rate_per_second` | Implemented |
| Failed count | N/A | `batch_stats.failed_count` | Elixir extra |
| Aggregated stats | N/A | `Cluster.batch_stats/1` | Elixir extra |
| Cluster statistics endpoint | N/A | `Cluster.statistics/1` | Elixir extra |

### Elixir Enhancements

- `batch_stats/1` aggregates batch statistics across all nodes
- Includes `failed_count` tracking not present in Python

---

## 5. Replication Status

### Python Implementation

Python provides a comprehensive replication management system:

```python
# Main cluster operations
def replicate(
    self,
    *,
    collection: str,
    shard: str,
    source_node: str,
    target_node: str,
    replication_type: ReplicationType = ReplicationType.COPY,
) -> uuid.UUID:
    """Replicate a shard from one node to another."""

def query_sharding_state(
    self,
    *,
    collection: str,
    shard: Optional[str] = None,
) -> Optional[ShardingState]:
    """Query the sharding state of a collection or shard."""
```

**Python Replications Sub-namespace:**
```python
class _ReplicateExecutor:
    def get(self, *, uuid: UUID, include_history: bool = False) -> Optional[ReplicateOperation]: ...
    def list_all(self) -> list[ReplicateOperationWithHistory]: ...
    def query(
        self, *,
        collection: Optional[str] = None,
        shard: Optional[str] = None,
        target_node: Optional[str] = None,
        include_history: bool = False,
    ) -> ReplicateOperations: ...
    def cancel(self, *, uuid: UUID) -> None: ...
    def delete(self, *, uuid: UUID) -> None: ...
    def delete_all(self) -> None: ...
```

**Python Replication Models:**
```python
class ReplicationType(str, Enum):
    COPY = "COPY"
    MOVE = "MOVE"

class ReplicateOperationState(str, Enum):
    REGISTERED = "REGISTERED"
    HYDRATING = "HYDRATING"
    FINALIZING = "FINALIZING"
    DEHYDRATING = "DEHYDRATING"
    READY = "READY"
    CANCELLED = "CANCELLED"

@dataclass
class ReplicateOperationStatus:
    state: ReplicateOperationState
    errors: List[str]

@dataclass
class _ReplicateOperation(Generic[H]):
    collection: str
    shard: str
    source_node: str
    status: ReplicateOperationStatus
    status_history: H  # None or List[ReplicateOperationStatus]
    target_node: str
    transfer_type: ReplicationType
    uuid: uuid.UUID

@dataclass
class ShardReplicas:
    name: str
    replicas: List[str]

@dataclass
class ShardingState:
    collection: str
    shards: List[ShardReplicas]
```

### Elixir Implementation

```elixir
# Initiate replication
@spec replicate(Client.t(), String.t(), String.t(), opts()) ::
        {:ok, Replication.Operation.t()} | {:error, Error.t()}
def replicate(client, collection, shard, opts) do
  source = Keyword.fetch!(opts, :source)
  target = Keyword.fetch!(opts, :target)
  type = Keyword.get(opts, :type, :copy)
  # ...
end

# List replications with filtering
@spec list_replications(Client.t(), opts()) ::
        {:ok, [Replication.Operation.t()]} | {:error, Error.t()}
def list_replications(client, opts \\ [])

# Get specific replication
@spec get_replication(Client.t(), String.t(), opts()) ::
        {:ok, Replication.Operation.t()} | {:error, Error.t()}
def get_replication(client, operation_id, opts \\ [])

# Cancel/Delete operations
@spec cancel_replication(Client.t(), String.t()) :: :ok | {:error, Error.t()}
@spec delete_replication(Client.t(), String.t()) :: :ok | {:error, Error.t()}

# Wait for completion
@spec wait_for_replications(Client.t(), opts()) ::
        :ok | {:error, :timeout | {:failed, [Replication.Operation.t()]}}
def wait_for_replications(client, opts \\ [])
```

**Elixir Replication Types:**
```elixir
@type operation_type :: :copy | :move
@type status :: :pending | :running | :completed | :failed | :cancelled

@type t :: %Operation{
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
```

### Comparison Table

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Initiate replication | `cluster.replicate()` | `Cluster.replicate/4` | Implemented |
| Get operation by ID | `replications.get(uuid)` | `Cluster.get_replication/3` | Implemented |
| List all operations | `replications.list_all()` | `Cluster.list_replications/2` | Different behavior |
| Query operations | `replications.query()` | `Cluster.list_replications/2` | Implemented |
| Cancel operation | `replications.cancel(uuid)` | `Cluster.cancel_replication/2` | Implemented |
| Delete operation | `replications.delete(uuid)` | `Cluster.delete_replication/2` | Implemented |
| Delete all operations | `replications.delete_all()` | N/A | **Missing** |
| Query sharding state | `cluster.query_sharding_state()` | N/A | **Missing** |
| Include history | `include_history=True` | `include_history: true` | Implemented |
| Wait for completion | N/A | `Cluster.wait_for_replications/2` | Elixir extra |
| COPY type | `ReplicationType.COPY` | `:copy` | Implemented |
| MOVE type | `ReplicationType.MOVE` | `:move` | Implemented |

### Replication State Comparison

| State | Python | Elixir | Status |
|-------|--------|--------|--------|
| PENDING | N/A | `:pending` | Elixir only |
| REGISTERED | `REGISTERED` | N/A | **Missing** |
| HYDRATING | `HYDRATING` | N/A | **Missing** |
| RUNNING | N/A | `:running` | Elixir only |
| FINALIZING | `FINALIZING` | N/A | **Missing** |
| DEHYDRATING | `DEHYDRATING` | N/A | **Missing** |
| READY | `READY` | `:completed` | Mapped differently |
| CANCELLED | `CANCELLED` | `:cancelled` | Implemented |
| FAILED | N/A | `:failed` | Elixir only |

### Critical Gaps

1. **`delete_all` for Replications**: Python provides `replications.delete_all()` to batch delete all replication records. Elixir is missing this.

2. **`query_sharding_state`**: Python provides a dedicated method to query the sharding state of a collection, returning which shards exist and their replica nodes. Elixir is completely missing this endpoint.

3. **Detailed Replication States**: Python has granular operation states:
   - `REGISTERED` - Operation registered
   - `HYDRATING` - Copying data to target
   - `FINALIZING` - Completing the copy
   - `DEHYDRATING` - Removing from source (MOVE only)
   - `READY` - Operation complete

   Elixir simplifies to `:pending`, `:running`, `:completed`, `:failed`, `:cancelled`.

4. **Status History with Errors**: Python's `ReplicateOperationStatus` includes an `errors: List[str]` field. Elixir only has a single `error: String.t()` field.

5. **Replications Sub-namespace**: Python organizes replication operations under `client.cluster.replications.*`. Elixir flattens everything into the Cluster module.

### Minor Gaps

1. **`list_all` vs `list_replications`**: Python's `list_all()` always includes history. Elixir's `list_replications/2` doesn't by default.

2. **ShardReplicas Type**: Python has a `ShardReplicas` dataclass showing which nodes host replicas. Elixir lacks this.

### Elixir Enhancements

1. **`wait_for_replications/2`**: Elixir provides a polling-based wait function with timeout and failure detection. Python lacks this convenience.

2. **Progress Tracking**: Elixir includes `progress: float()` field on operations.

3. **Timestamps**: Elixir includes `created_at` and `completed_at` DateTime fields.

---

## Summary of All Gaps

### Critical Gaps (Must Fix)

| Gap | Description | Priority |
|-----|-------------|----------|
| Shard name filtering in nodes | Add `shard` parameter to `nodes/2` | High |
| Shard `loaded` field | Add to Shard struct | High |
| `LAZY_LOADING` status | Add to vector indexing status enum | High |
| `delete_all_replications/1` | Add batch delete for replication records | High |
| `query_sharding_state/3` | Add sharding state query endpoint | High |
| Detailed replication states | Add REGISTERED, HYDRATING, FINALIZING, DEHYDRATING | Medium |
| Status errors list | Change from single error to list | Medium |

### Minor Gaps (Nice to Have)

| Gap | Description | Priority |
|-----|-------------|----------|
| Shard `node` field | Track which node hosts shard | Low |
| ShardReplicas type | Add type for replica tracking | Low |
| Replications sub-namespace | Organize like Python | Low |

### API Differences (Documentation Only)

| Difference | Python | Elixir |
|------------|--------|--------|
| Verbosity parameter | `output="verbose"` | `output: :verbose` |
| Vector queue field | `vector_queue_length` | `vector_queue_size` |
| Replication states | Granular (6 states) | Simplified (5 states) |
| Shard API | Via nodes endpoint | Via schema endpoint |
| Operation ID type | `uuid.UUID` | `String.t()` |

---

## Recommended Implementation Order

### Phase 1: Core Missing Features
1. Add `shard` parameter to `Cluster.nodes/2`
2. Add `loaded` field to `Shard` struct
3. Add `LAZY_LOADING` to vector indexing status
4. Implement `Cluster.delete_all_replications/1`
5. Implement `Cluster.query_sharding_state/3`

### Phase 2: Replication Enhancements
1. Add detailed replication states (REGISTERED, HYDRATING, etc.)
2. Change error field to errors list on operations
3. Add `ShardReplicas` type for sharding state

### Phase 3: Organization
1. Consider replications sub-namespace for consistency
2. Add `node` field to Shard struct
3. Document all API differences

---

## Code Examples for Missing Features

### Add Shard Filtering to Nodes

```elixir
# In WeaviateEx.API.Cluster

defp build_nodes_path(nil, nil, :minimal), do: "/v1/nodes"
defp build_nodes_path(nil, nil, :verbose), do: "/v1/nodes?output=verbose"
defp build_nodes_path(collection, nil, :minimal), do: "/v1/nodes/#{collection}"
defp build_nodes_path(collection, nil, :verbose), do: "/v1/nodes/#{collection}?output=verbose"
defp build_nodes_path(collection, shard, output) do
  base = build_nodes_path(collection, nil, output)
  "#{base}#{if String.contains?(base, "?"), do: "&", else: "?"}shardName=#{shard}"
end
```

### Add Loaded Field to Shard

```elixir
# In WeaviateEx.Cluster.Shard

@type t :: %__MODULE__{
  name: String.t(),
  collection: String.t() | nil,
  status: status(),
  object_count: non_neg_integer(),
  vector_queue_size: non_neg_integer(),
  vector_indexing_status: String.t() | nil,
  compressed: boolean(),
  loaded: boolean() | nil  # Add this
}

defstruct [
  :name,
  :collection,
  :status,
  :vector_indexing_status,
  :loaded,  # Add this
  object_count: 0,
  vector_queue_size: 0,
  compressed: false
]

def from_api(map) when is_map(map) do
  %__MODULE__{
    # ... existing fields ...
    loaded: Map.get(map, "loaded")  # Add this
  }
end
```

### Implement Query Sharding State

```elixir
# In WeaviateEx.API.Cluster

@doc """
Query the sharding state of a collection.

Returns which shards exist and their replica nodes.

## Examples

    {:ok, state} = Cluster.query_sharding_state(client, "Article")
    {:ok, state} = Cluster.query_sharding_state(client, "Article", shard: "shard-0")

## Returns

- `{:ok, ShardingState.t()}` - Sharding state
- `{:ok, nil}` - Collection or shard not found
- `{:error, Error.t()}` - Error
"""
@spec query_sharding_state(Client.t(), String.t(), opts()) ::
        {:ok, ShardingState.t() | nil} | {:error, Error.t()}
def query_sharding_state(client, collection, opts \\ []) do
  shard = Keyword.get(opts, :shard)

  params = [collection: collection]
  params = if shard, do: [{:shard, shard} | params], else: params
  query = URI.encode_query(params)

  case Client.request(client, :get, "/v1/replication/sharding-state?#{query}", nil, []) do
    {:ok, nil} -> {:ok, nil}
    {:ok, data} -> {:ok, ShardingState.from_api(data)}
    {:error, %Error{status: 404}} -> {:ok, nil}
    {:error, _} = error -> error
  end
end

# New module: WeaviateEx.Cluster.ShardingState
defmodule WeaviateEx.Cluster.ShardingState do
  defmodule ShardReplicas do
    @type t :: %__MODULE__{
      name: String.t(),
      replicas: [String.t()]
    }
    defstruct [:name, :replicas]

    def from_api(%{"shard" => name, "replicas" => replicas}) do
      %__MODULE__{name: name, replicas: replicas}
    end
  end

  @type t :: %__MODULE__{
    collection: String.t(),
    shards: [ShardReplicas.t()]
  }
  defstruct [:collection, :shards]

  def from_api(%{"shardingState" => %{"collection" => collection, "shards" => shards}}) do
    %__MODULE__{
      collection: collection,
      shards: Enum.map(shards, &ShardReplicas.from_api/1)
    }
  end
end
```

### Implement Delete All Replications

```elixir
# In WeaviateEx.API.Cluster

@doc """
Delete all replication operation records.

Removes all completed, failed, and cancelled replication records.

## Examples

    :ok = Cluster.delete_all_replications(client)

## Returns

- `:ok` - All records deleted
- `{:error, Error.t()}` - Error if deletion fails
"""
@spec delete_all_replications(Client.t()) :: :ok | {:error, Error.t()}
def delete_all_replications(client) do
  case Client.request(client, :delete, "/v1/replication/replicate", nil, []) do
    {:ok, _} -> :ok
    {:error, _} = error -> error
  end
end
```
