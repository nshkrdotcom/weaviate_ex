# WeaviateEx: High Priority Features Implementation Prompt

**Date:** 2025-12-28
**Objective:** Implement four high-priority feature gaps in a single development cycle. Full TDD approach.
**Version Bump:** 0.x.0 → 0.(x+1).0

---

## Scope Overview

| Feature Area | Current State | Operations | Est. Effort |
|--------------|---------------|------------|-------------|
| Cluster Management | 0% | 8 operations | 2-3 weeks |
| Query Rerank/Group By | Not integrated | 4 integrations | 1-2 weeks |
| Batch Advanced Features | Partial | 4 features | 2-3 weeks |
| Rerankers | 1 of 6 | 5 new rerankers | 1-2 weeks |

**Total: ~21 new features/operations across 4 modules**

---

## Pre-Implementation Required Reading

### 1. Python Client Reference Files

```
# Cluster Management
weaviate-python-client/weaviate/cluster/
├── __init__.py              # Module exports
├── base.py                  # Base cluster operations
├── models.py                # Node, ShardingState models
├── sync.py                  # Sync operations
├── async_.py                # Async operations
└── replicate/
    ├── executor.py          # Replication operations
    └── models.py            # Replication models

# Query Rerank/Group By
weaviate-python-client/weaviate/collections/queries/
├── near_vector/query/executor.py   # rerank, group_by params
├── near_text/query/executor.py     # rerank, group_by params
├── bm25/query/executor.py          # rerank, group_by params
├── hybrid/query/executor.py        # rerank, group_by params
└── near_object/query/executor.py   # rerank, group_by params

weaviate-python-client/weaviate/collections/classes/
├── grpc.py                  # Rerank, GroupBy classes
└── aggregate.py             # GroupBy response types

# Batch Advanced Features
weaviate-python-client/weaviate/collections/batch/
├── batch_wrapper.py         # wait_for_vector_indexing (line 62-85)
├── base.py                  # Multi-target references, auto UUID
└── grpc_batch_objects.py    # gRPC batch implementation

# Rerankers
weaviate-python-client/weaviate/collections/classes/config.py
# Search for: Reranker, _RerankerConfigCreate
# Lines with: reranker-cohere, reranker-transformers, reranker-voyageai, etc.
```

### 2. Elixir Client Current State

```
# Cluster - MISSING (create new)
# (no existing files)

# Query - EXISTS (extend)
lib/weaviate_ex/query.ex                    # Main query module
lib/weaviate_ex/query/rerank.ex             # Rerank module (NOT INTEGRATED)
lib/weaviate_ex/query/group_by.ex           # GroupBy module (NOT INTEGRATED)
lib/weaviate_ex/api/query_advanced.ex       # Advanced query ops

# Batch - EXISTS (extend)
lib/weaviate_ex/batch.ex                    # Main batch module
lib/weaviate_ex/batch/fixed_size.ex         # Fixed size batcher
lib/weaviate_ex/batch/dynamic.ex            # Dynamic batcher
lib/weaviate_ex/api/batch.ex                # Batch API operations

# Rerankers - EXISTS (extend)
lib/weaviate_ex/api/vector_config.ex        # Has reranker_cohere only
```

### 3. Gap Analysis Documentation

```
docs/20251228/weaviate-client-gap-analysis/
├── backup-cluster-tenants.md    # Cluster gaps
├── query-api.md                 # Rerank/GroupBy gaps
├── batch-operations.md          # Batch advanced gaps
├── generative-integrations.md   # Reranker gaps
└── gap-analysis-summary.md      # Overall priorities
```

### 4. Weaviate REST API Endpoints

```
# Cluster Management
GET    /v1/nodes                              # Get all nodes
GET    /v1/nodes/{node_name}                  # Get specific node
GET    /v1/cluster/statistics                 # Cluster statistics
GET    /v1/schema/{collection}/shards         # Get shard status

# Replication Operations
POST   /v1/cluster/replications               # Create replication
GET    /v1/cluster/replications               # List replications
GET    /v1/cluster/replications/{uuid}        # Get replication status
DELETE /v1/cluster/replications/{uuid}        # Cancel/delete replication

# Query (GraphQL) - rerank and groupBy are GraphQL parameters
POST   /v1/graphql                            # All queries with rerank/groupBy

# Batch
GET    /v1/schema/{collection}/shards         # For wait_for_vector_indexing
POST   /v1/batch/objects                      # Batch insert (multi-target refs)
```

---

# PART 1: CLUSTER MANAGEMENT

## Context

Cluster management provides visibility into Weaviate cluster state, node health, and shard replication operations. Currently 0% implemented in Elixir.

### Module Structure

```
lib/weaviate_ex/
├── cluster/
│   ├── node.ex              # Node struct and types
│   ├── shard.ex             # Shard struct and types
│   └── replication.ex       # Replication operation types
└── api/
    └── cluster.ex           # Cluster operations API
```

## Phase 1.1: Node and Shard Types (TDD)

### Create Node Struct

Create `lib/weaviate_ex/cluster/node.ex`:

```elixir
defmodule WeaviateEx.Cluster.Node do
  @moduledoc """
  Represents a node in the Weaviate cluster.
  """

  @type status :: :healthy | :unhealthy | :unavailable

  @type t :: %__MODULE__{
    name: String.t(),
    status: status(),
    version: String.t(),
    git_hash: String.t() | nil,
    stats: map() | nil,
    shards: [Shard.t()] | nil
  }

  defstruct [:name, :status, :version, :git_hash, :stats, :shards]

  @doc "Parse node from API response"
  @spec from_api(map()) :: t()
  def from_api(map)

  @doc "Parse status string to atom"
  @spec parse_status(String.t()) :: status()
  def parse_status("HEALTHY"), do: :healthy
  def parse_status("UNHEALTHY"), do: :unhealthy
  def parse_status(_), do: :unavailable
end
```

### Create Shard Struct

Create `lib/weaviate_ex/cluster/shard.ex`:

```elixir
defmodule WeaviateEx.Cluster.Shard do
  @moduledoc """
  Represents a shard in a Weaviate collection.
  """

  @type status :: :ready | :readonly | :indexing | :loading

  @type t :: %__MODULE__{
    name: String.t(),
    collection: String.t(),
    status: status(),
    object_count: non_neg_integer(),
    vector_queue_size: non_neg_integer(),
    vector_indexing_status: String.t() | nil,
    compressed: boolean()
  }

  defstruct [
    :name,
    :collection,
    :status,
    :object_count,
    :vector_queue_size,
    :vector_indexing_status,
    compressed: false
  ]

  @doc "Parse shard from API response"
  @spec from_api(map()) :: t()
  def from_api(map)

  @doc "Check if shard is ready for queries"
  @spec ready?(t()) :: boolean()
  def ready?(%__MODULE__{status: :ready, vector_queue_size: 0}), do: true
  def ready?(_), do: false

  @doc "Check if vectors are fully indexed"
  @spec vectors_indexed?(t()) :: boolean()
  def vectors_indexed?(%__MODULE__{vector_queue_size: 0}), do: true
  def vectors_indexed?(_), do: false
end
```

### Create Replication Types

Create `lib/weaviate_ex/cluster/replication.ex`:

```elixir
defmodule WeaviateEx.Cluster.Replication do
  @moduledoc """
  Replication operation types and status.
  """

  @type operation_type :: :copy | :move

  @type status :: :pending | :running | :completed | :failed | :cancelled

  defmodule Operation do
    @moduledoc "A shard replication operation"
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
      :id, :collection, :shard, :source_node, :target_node,
      :type, :status, :progress, :error, :created_at, :completed_at
    ]

    def from_api(map)
  end

  @doc "Convert operation type to API string"
  @spec type_to_api(operation_type()) :: String.t()
  def type_to_api(:copy), do: "COPY"
  def type_to_api(:move), do: "MOVE"

  @doc "Parse operation type from API"
  @spec type_from_api(String.t()) :: operation_type()
  def type_from_api("COPY"), do: :copy
  def type_from_api("MOVE"), do: :move
end
```

**Tests first** in `test/weaviate_ex/cluster/`:
- `node_test.exs`: Parse node, status parsing, shard inclusion
- `shard_test.exs`: Parse shard, ready?/1, vectors_indexed?/1
- `replication_test.exs`: Operation parsing, type conversions

## Phase 1.2: Cluster API Module (TDD)

Create `lib/weaviate_ex/api/cluster.ex`:

```elixir
defmodule WeaviateEx.API.Cluster do
  @moduledoc """
  Cluster management operations.

  ## Examples

      # Get all nodes
      {:ok, nodes} = Cluster.nodes(client)

      # Get nodes with shard info for specific collection
      {:ok, nodes} = Cluster.nodes(client, collection: "Article", output: :verbose)

      # Get sharding state for collection
      {:ok, shards} = Cluster.shards(client, "Article")

      # Replicate a shard to another node
      {:ok, op} = Cluster.replicate(client, "Article", "shard-1",
        source: "node-1",
        target: "node-2",
        type: :copy
      )
  """

  alias WeaviateEx.Cluster.{Node, Shard, Replication}

  @type output_verbosity :: :minimal | :verbose

  @doc """
  Get cluster nodes.

  ## Options

  - `:collection` - Filter by collection (shows shards for that collection)
  - `:output` - Verbosity level (`:minimal` or `:verbose`)

  ## Examples

      {:ok, nodes} = Cluster.nodes(client)
      {:ok, nodes} = Cluster.nodes(client, collection: "Article", output: :verbose)
  """
  @spec nodes(client :: term(), keyword()) :: {:ok, [Node.t()]} | {:error, term()}
  def nodes(client, opts \\ [])

  @doc """
  Get shards for a collection.

  Returns shard status including vector queue depth for indexing monitoring.

  ## Examples

      {:ok, shards} = Cluster.shards(client, "Article")
      Enum.all?(shards, &Shard.ready?/1)
  """
  @spec shards(client :: term(), collection :: String.t()) ::
    {:ok, [Shard.t()]} | {:error, term()}
  def shards(client, collection)

  @doc """
  Get cluster statistics.

  ## Examples

      {:ok, stats} = Cluster.statistics(client)
  """
  @spec statistics(client :: term()) :: {:ok, map()} | {:error, term()}
  def statistics(client)

  @doc """
  Initiate shard replication.

  ## Options

  - `:source` - Source node name (required)
  - `:target` - Target node name (required)
  - `:type` - Replication type (`:copy` or `:move`, default: `:copy`)

  ## Examples

      {:ok, op} = Cluster.replicate(client, "Article", "shard-0",
        source: "node-1",
        target: "node-2",
        type: :copy
      )
  """
  @spec replicate(client :: term(), collection :: String.t(), shard :: String.t(), keyword()) ::
    {:ok, Replication.Operation.t()} | {:error, term()}
  def replicate(client, collection, shard, opts)

  @doc """
  List all replication operations.

  ## Options

  - `:collection` - Filter by collection
  - `:shard` - Filter by shard
  - `:target_node` - Filter by target node

  ## Examples

      {:ok, ops} = Cluster.list_replications(client)
      {:ok, ops} = Cluster.list_replications(client, collection: "Article")
  """
  @spec list_replications(client :: term(), keyword()) ::
    {:ok, [Replication.Operation.t()]} | {:error, term()}
  def list_replications(client, opts \\ [])

  @doc """
  Get a specific replication operation.

  ## Options

  - `:include_history` - Include operation history (default: false)

  ## Examples

      {:ok, op} = Cluster.get_replication(client, "uuid-123")
  """
  @spec get_replication(client :: term(), operation_id :: String.t(), keyword()) ::
    {:ok, Replication.Operation.t()} | {:error, term()}
  def get_replication(client, operation_id, opts \\ [])

  @doc """
  Cancel a replication operation.

  ## Examples

      :ok = Cluster.cancel_replication(client, "uuid-123")
  """
  @spec cancel_replication(client :: term(), operation_id :: String.t()) ::
    :ok | {:error, term()}
  def cancel_replication(client, operation_id)

  @doc """
  Delete a completed replication operation record.

  ## Examples

      :ok = Cluster.delete_replication(client, "uuid-123")
  """
  @spec delete_replication(client :: term(), operation_id :: String.t()) ::
    :ok | {:error, term()}
  def delete_replication(client, operation_id)
end
```

**Tests first** in `test/weaviate_ex/api/cluster_test.exs`:

```elixir
describe "nodes/2" do
  test "returns list of nodes with minimal output"
  test "returns nodes with shard info when collection specified"
  test "returns verbose output with stats"
end

describe "shards/2" do
  test "returns shards for collection"
  test "includes vector_queue_size for indexing status"
  test "returns error for non-existent collection"
end

describe "statistics/1" do
  test "returns cluster statistics map"
end

describe "replicate/4" do
  test "initiates COPY replication"
  test "initiates MOVE replication"
  test "returns error for non-existent shard"
  test "returns error for invalid target node"
end

describe "list_replications/2" do
  test "returns all replication operations"
  test "filters by collection"
  test "filters by target_node"
end

describe "get_replication/3" do
  test "returns operation details"
  test "includes history when requested"
  test "returns error for non-existent operation"
end

describe "cancel_replication/2" do
  test "cancels running operation"
  test "returns error for completed operation"
end

describe "delete_replication/2" do
  test "deletes completed operation"
  test "returns error for running operation"
end
```

---

# PART 2: QUERY RERANK & GROUP BY INTEGRATION

## Context

Rerank and GroupBy modules exist but are **not integrated** into the main Query module. All query types should support these features.

### Current State

```elixir
# EXISTS but NOT USED in Query module:
lib/weaviate_ex/query/rerank.ex      # Has to_graphql/1
lib/weaviate_ex/query/group_by.ex    # Has to_graphql/1
```

## Phase 2.1: Rerank Struct Enhancement (TDD)

Update `lib/weaviate_ex/query/rerank.ex`:

```elixir
defmodule WeaviateEx.Query.Rerank do
  @moduledoc """
  Reranking configuration for query results.

  Reranking re-orders search results using a reranker model configured
  on the collection. The reranker scores results based on relevance to
  the query and returns a `rerank_score` in metadata.

  ## Examples

      # Rerank using default property
      rerank = Rerank.new("What is machine learning?")

      # Rerank using specific property
      rerank = Rerank.new("What is machine learning?", property: "content")

      # Use in query
      Query.near_text(query, "search terms", rerank: rerank)
  """

  @type t :: %__MODULE__{
    query: String.t(),
    property: String.t() | nil
  }

  defstruct [:query, :property]

  @doc """
  Create a new rerank configuration.

  ## Options

  - `:property` - Property to use for reranking (default: collection's default)

  ## Examples

      Rerank.new("relevance query")
      Rerank.new("relevance query", property: "content")
  """
  @spec new(String.t(), keyword()) :: t()
  def new(query, opts \\ []) do
    %__MODULE__{
      query: query,
      property: Keyword.get(opts, :property)
    }
  end

  @doc "Convert to GraphQL arguments"
  @spec to_graphql(t()) :: map()
  def to_graphql(%__MODULE__{query: query, property: nil}) do
    %{query: query}
  end

  def to_graphql(%__MODULE__{query: query, property: property}) do
    %{query: query, property: property}
  end

  @doc "Validate rerank configuration"
  @spec valid?(t()) :: boolean()
  def valid?(%__MODULE__{query: query}) when is_binary(query) and query != "", do: true
  def valid?(_), do: false
end
```

## Phase 2.2: GroupBy Struct Enhancement (TDD)

Update `lib/weaviate_ex/query/group_by.ex`:

```elixir
defmodule WeaviateEx.Query.GroupBy do
  @moduledoc """
  Group search results by property values.

  GroupBy clusters results based on a property path, returning
  groups with their objects.

  ## Examples

      # Group by category, 3 objects per group, max 10 groups
      group_by = GroupBy.new("category",
        objects_per_group: 3,
        number_of_groups: 10
      )

      # Use in query
      Query.near_text(query, "search", group_by: group_by)
  """

  @type t :: %__MODULE__{
    path: String.t() | [String.t()],
    objects_per_group: pos_integer(),
    number_of_groups: pos_integer()
  }

  @default_objects_per_group 10
  @default_number_of_groups 10

  defstruct [:path, :objects_per_group, :number_of_groups]

  @doc """
  Create a new group by configuration.

  ## Options

  - `:objects_per_group` - Max objects per group (default: 10)
  - `:number_of_groups` - Max number of groups (default: 10)

  ## Examples

      GroupBy.new("category")
      GroupBy.new(["nested", "property"], objects_per_group: 5)
  """
  @spec new(String.t() | [String.t()], keyword()) :: t()
  def new(path, opts \\ []) do
    %__MODULE__{
      path: path,
      objects_per_group: Keyword.get(opts, :objects_per_group, @default_objects_per_group),
      number_of_groups: Keyword.get(opts, :number_of_groups, @default_number_of_groups)
    }
  end

  @doc "Convert to GraphQL arguments"
  @spec to_graphql(t()) :: map()
  def to_graphql(%__MODULE__{} = gb) do
    path = if is_list(gb.path), do: gb.path, else: [gb.path]

    %{
      path: path,
      groups: gb.number_of_groups,
      objectsPerGroup: gb.objects_per_group
    }
  end

  @doc "Validate group by configuration"
  @spec valid?(t()) :: boolean()
  def valid?(%__MODULE__{path: path, objects_per_group: opg, number_of_groups: nog})
      when is_binary(path) or is_list(path) and opg > 0 and nog > 0,
      do: true
  def valid?(_), do: false
end
```

## Phase 2.3: Integrate into Query Module (TDD)

Update `lib/weaviate_ex/query.ex` to accept rerank and group_by options:

```elixir
defmodule WeaviateEx.Query do
  # Add to existing module

  alias WeaviateEx.Query.{Rerank, GroupBy}

  @doc """
  Vector similarity search with optional reranking and grouping.

  ## Options

  - `:limit` - Maximum results (default: 10)
  - `:offset` - Skip first N results
  - `:certainty` - Minimum certainty threshold
  - `:distance` - Maximum distance threshold
  - `:where` - Filter conditions
  - `:rerank` - Rerank configuration (see `WeaviateEx.Query.Rerank`)
  - `:group_by` - Group by configuration (see `WeaviateEx.Query.GroupBy`)
  - `:auto_limit` - Automatic result cutoff
  - `:target_vector` - Target named vector for multi-vector collections
  - `:return_metadata` - Metadata fields to return
  - `:include_vector` - Include vector in response

  ## Examples

      # Basic near_vector
      Query.near_vector(query, vector)

      # With reranking
      rerank = Rerank.new("What is AI?")
      Query.near_vector(query, vector, rerank: rerank)

      # With grouping
      group_by = GroupBy.new("category", objects_per_group: 5)
      Query.near_vector(query, vector, group_by: group_by)

      # With both
      Query.near_vector(query, vector, rerank: rerank, group_by: group_by)
  """
  @spec near_vector(t(), vector :: [float()], keyword()) :: t()
  def near_vector(query, vector, opts \\ []) do
    # Existing implementation + add rerank/group_by to GraphQL
    query
    |> add_near_vector(vector, opts)
    |> maybe_add_rerank(Keyword.get(opts, :rerank))
    |> maybe_add_group_by(Keyword.get(opts, :group_by))
    |> maybe_add_auto_limit(Keyword.get(opts, :auto_limit))
    |> maybe_add_target_vector(Keyword.get(opts, :target_vector))
  end

  @doc """
  Semantic text search with optional reranking and grouping.

  Supports same options as `near_vector/3` plus text-specific options.
  """
  @spec near_text(t(), query :: String.t(), keyword()) :: t()
  def near_text(query, search_query, opts \\ []) do
    query
    |> add_near_text(search_query, opts)
    |> maybe_add_rerank(Keyword.get(opts, :rerank))
    |> maybe_add_group_by(Keyword.get(opts, :group_by))
    |> maybe_add_auto_limit(Keyword.get(opts, :auto_limit))
  end

  @doc """
  BM25 keyword search with optional reranking and grouping.

  ## Additional Options

  - `:properties` - Properties to search in
  - `:operator` - Boolean operator (`:and`, `:or`, default: `:or`)
  """
  @spec bm25(t(), query :: String.t(), keyword()) :: t()
  def bm25(query, search_query, opts \\ []) do
    query
    |> add_bm25(search_query, opts)
    |> maybe_add_rerank(Keyword.get(opts, :rerank))
    |> maybe_add_group_by(Keyword.get(opts, :group_by))
    |> maybe_add_bm25_operator(Keyword.get(opts, :operator))
  end

  @doc """
  Hybrid search combining vector and keyword search.

  ## Additional Options

  - `:alpha` - Balance between vector (1.0) and keyword (0.0), default: 0.5
  - `:vector` - Custom vector for hybrid search
  - `:fusion_type` - Fusion algorithm (`:ranked` or `:relative_score`)
  - `:bm25_operator` - Boolean operator for BM25 component
  """
  @spec hybrid(t(), query :: String.t(), keyword()) :: t()
  def hybrid(query, search_query, opts \\ []) do
    query
    |> add_hybrid(search_query, opts)
    |> maybe_add_rerank(Keyword.get(opts, :rerank))
    |> maybe_add_group_by(Keyword.get(opts, :group_by))
    |> maybe_add_hybrid_vector(Keyword.get(opts, :vector))
    |> maybe_add_bm25_operator(Keyword.get(opts, :bm25_operator))
  end

  @doc """
  Near object search with optional reranking and grouping.
  """
  @spec near_object(t(), object_id :: String.t(), keyword()) :: t()
  def near_object(query, object_id, opts \\ []) do
    query
    |> add_near_object(object_id, opts)
    |> maybe_add_rerank(Keyword.get(opts, :rerank))
    |> maybe_add_group_by(Keyword.get(opts, :group_by))
  end

  # Private helper functions
  defp maybe_add_rerank(query, nil), do: query
  defp maybe_add_rerank(query, %Rerank{} = rerank) do
    # Add rerank to GraphQL additional clause
    update_additional(query, :rerank, Rerank.to_graphql(rerank))
  end

  defp maybe_add_group_by(query, nil), do: query
  defp maybe_add_group_by(query, %GroupBy{} = group_by) do
    # Add groupBy to GraphQL query
    update_group_by(query, GroupBy.to_graphql(group_by))
  end

  defp maybe_add_auto_limit(query, nil), do: query
  defp maybe_add_auto_limit(query, limit) when is_integer(limit) do
    update_param(query, :autoLimit, limit)
  end

  defp maybe_add_target_vector(query, nil), do: query
  defp maybe_add_target_vector(query, target) when is_binary(target) do
    update_param(query, :targetVector, target)
  end

  defp maybe_add_bm25_operator(query, nil), do: query
  defp maybe_add_bm25_operator(query, :and), do: update_param(query, :operator, "And")
  defp maybe_add_bm25_operator(query, :or), do: update_param(query, :operator, "Or")

  defp maybe_add_hybrid_vector(query, nil), do: query
  defp maybe_add_hybrid_vector(query, vector) when is_list(vector) do
    update_param(query, :vector, vector)
  end
end
```

**Tests first** in `test/weaviate_ex/query_test.exs`:

```elixir
describe "near_vector with rerank" do
  test "adds rerank to GraphQL query"
  test "includes rerank_score in response metadata"
end

describe "near_vector with group_by" do
  test "adds groupBy to GraphQL query"
  test "returns grouped results"
end

describe "near_text with rerank and group_by" do
  test "supports both options together"
end

describe "bm25 with operator" do
  test "adds AND operator"
  test "adds OR operator"
  test "defaults to OR when not specified"
end

describe "hybrid with vector and bm25_operator" do
  test "adds custom vector to hybrid query"
  test "adds bm25_operator to hybrid query"
end

describe "query options" do
  test "auto_limit limits results automatically"
  test "target_vector targets named vector"
end
```

---

# PART 3: BATCH ADVANCED FEATURES

## Context

Batch module is solid but missing critical features: `wait_for_vector_indexing`, auto UUID, and multi-target references.

### Features to Implement

1. `wait_for_vector_indexing/3` - Poll shards until vectors indexed
2. Auto UUID generation in `add_object/4`
3. Multi-target references in `add_reference/5`
4. Typed `DeleteManyReturn` struct

## Phase 3.1: Wait for Vector Indexing (TDD)

Add to `lib/weaviate_ex/batch.ex`:

```elixir
defmodule WeaviateEx.Batch do
  # Add to existing module

  alias WeaviateEx.Cluster.Shard

  @default_poll_interval 1000
  @default_max_failures 5
  @default_timeout 300_000

  @doc """
  Wait for all vectors to be indexed after batch insertion.

  This function polls shard status until all vector queues are empty,
  indicating that async vectorization is complete.

  ## Options

  - `:poll_interval` - Milliseconds between status checks (default: 1000)
  - `:max_failures` - Max consecutive failures before error (default: 5)
  - `:timeout` - Maximum wait time in milliseconds (default: 300000)
  - `:shards` - Specific shards to monitor (default: all shards)

  ## Examples

      # Wait for all shards
      :ok = Batch.wait_for_vector_indexing(client, "Article")

      # Wait with custom timeout
      :ok = Batch.wait_for_vector_indexing(client, "Article", timeout: 60_000)

      # Wait for specific shards
      :ok = Batch.wait_for_vector_indexing(client, "Article", shards: ["shard-0"])

  ## Returns

  - `:ok` - All vectors indexed successfully
  - `{:error, :timeout}` - Timed out waiting for indexing
  - `{:error, {:max_failures, reason}}` - Too many consecutive failures
  """
  @spec wait_for_vector_indexing(client :: term(), collection :: String.t(), keyword()) ::
    :ok | {:error, term()}
  def wait_for_vector_indexing(client, collection, opts \\ []) do
    poll_interval = Keyword.get(opts, :poll_interval, @default_poll_interval)
    max_failures = Keyword.get(opts, :max_failures, @default_max_failures)
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    target_shards = Keyword.get(opts, :shards)

    deadline = System.monotonic_time(:millisecond) + timeout

    do_wait_for_indexing(client, collection, target_shards, poll_interval, max_failures, deadline, 0)
  end

  defp do_wait_for_indexing(client, collection, target_shards, interval, max_fails, deadline, fail_count) do
    now = System.monotonic_time(:millisecond)

    cond do
      now >= deadline ->
        {:error, :timeout}

      fail_count >= max_fails ->
        {:error, {:max_failures, "exceeded #{max_fails} consecutive failures"}}

      true ->
        case check_indexing_status(client, collection, target_shards) do
          {:ok, :complete} ->
            :ok

          {:ok, :in_progress} ->
            Process.sleep(interval)
            do_wait_for_indexing(client, collection, target_shards, interval, max_fails, deadline, 0)

          {:error, _reason} ->
            Process.sleep(interval)
            do_wait_for_indexing(client, collection, target_shards, interval, max_fails, deadline, fail_count + 1)
        end
    end
  end

  defp check_indexing_status(client, collection, target_shards) do
    case WeaviateEx.API.Cluster.shards(client, collection) do
      {:ok, shards} ->
        shards_to_check = filter_shards(shards, target_shards)

        if Enum.all?(shards_to_check, &Shard.vectors_indexed?/1) do
          {:ok, :complete}
        else
          {:ok, :in_progress}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp filter_shards(shards, nil), do: shards
  defp filter_shards(shards, target_names) do
    Enum.filter(shards, fn shard -> shard.name in target_names end)
  end
end
```

**Tests first** in `test/weaviate_ex/batch_test.exs`:

```elixir
describe "wait_for_vector_indexing/3" do
  test "returns :ok when vectors are already indexed"
  test "polls until vectors are indexed"
  test "respects poll_interval option"
  test "returns error on timeout"
  test "returns error after max_failures"
  test "filters to specific shards when provided"
end
```

## Phase 3.2: Auto UUID Generation (TDD)

Update `lib/weaviate_ex/batch/fixed_size.ex`:

```elixir
defmodule WeaviateEx.Batch.FixedSize do
  # Update add_object to support auto UUID

  @doc """
  Add an object to the batch.

  ## Options

  - `:uuid` - Explicit UUID (optional, auto-generated if not provided)
  - `:vector` - Vector embedding (optional)
  - `:tenant` - Tenant name for multi-tenant collections

  ## Examples

      # Auto-generate UUID
      batch = Batch.add_object(batch, "Article", %{title: "Hello"})

      # Explicit UUID
      batch = Batch.add_object(batch, "Article", %{title: "Hello"}, uuid: "custom-uuid")

      # Deterministic UUID from value
      uuid = WeaviateEx.UUID.from_string("Article", "unique-identifier")
      batch = Batch.add_object(batch, "Article", %{title: "Hello"}, uuid: uuid)
  """
  @spec add_object(t(), String.t(), map(), keyword()) :: t()
  def add_object(batch, collection, properties, opts \\ []) do
    uuid = Keyword.get_lazy(opts, :uuid, fn -> WeaviateEx.UUID.generate() end)

    object = %{
      class: collection,
      properties: properties,
      id: uuid
    }
    |> maybe_add_vector(Keyword.get(opts, :vector))
    |> maybe_add_tenant(Keyword.get(opts, :tenant))

    add_to_queue(batch, object)
  end
end
```

## Phase 3.3: Multi-Target References (TDD)

Update `lib/weaviate_ex/batch/fixed_size.ex`:

```elixir
defmodule WeaviateEx.Batch.FixedSize do
  # Add multi-target reference support

  @doc """
  Add a reference to the batch.

  ## Single Target

      Batch.add_reference(batch, "Article", article_uuid, "author", author_uuid)

  ## Multi-Target References

      Batch.add_reference(batch, "Article", article_uuid, "relatedTo", [
        %{collection: "Article", uuid: related_uuid1},
        %{collection: "Video", uuid: video_uuid}
      ])
  """
  @spec add_reference(t(), String.t(), String.t(), String.t(), String.t() | [map()], keyword()) :: t()
  def add_reference(batch, from_collection, from_uuid, property, to_target, opts \\ [])

  # Single target (existing behavior)
  def add_reference(batch, from_collection, from_uuid, property, to_uuid, opts)
      when is_binary(to_uuid) do
    reference = build_single_reference(from_collection, from_uuid, property, to_uuid, opts)
    add_reference_to_queue(batch, reference)
  end

  # Multi-target (new)
  def add_reference(batch, from_collection, from_uuid, property, targets, opts)
      when is_list(targets) do
    references = Enum.map(targets, fn target ->
      build_multi_target_reference(from_collection, from_uuid, property, target, opts)
    end)

    Enum.reduce(references, batch, &add_reference_to_queue(&2, &1))
  end

  defp build_multi_target_reference(from_collection, from_uuid, property, target, opts) do
    %{
      from: %{
        class: from_collection,
        id: from_uuid
      },
      to: %{
        class: target.collection,
        id: target.uuid
      },
      property: property
    }
    |> maybe_add_tenant(Keyword.get(opts, :tenant))
  end
end
```

## Phase 3.4: Typed Delete Response (TDD)

Create `lib/weaviate_ex/batch/delete_result.ex`:

```elixir
defmodule WeaviateEx.Batch.DeleteResult do
  @moduledoc """
  Typed result from batch delete operations.
  """

  @type t :: %__MODULE__{
    matches: non_neg_integer(),
    limit: non_neg_integer(),
    successful: non_neg_integer(),
    failed: non_neg_integer(),
    objects: [DeletedObject.t()] | nil,
    dry_run: boolean()
  }

  defstruct [:matches, :limit, :successful, :failed, :objects, dry_run: false]

  defmodule DeletedObject do
    @moduledoc "Individual deleted object info"
    @type t :: %__MODULE__{
      id: String.t(),
      status: :success | :failed,
      error: String.t() | nil
    }
    defstruct [:id, :status, :error]
  end

  @doc "Parse from API response"
  @spec from_api(map()) :: t()
  def from_api(response) do
    results = response["results"] || %{}

    %__MODULE__{
      matches: results["matches"] || 0,
      limit: results["limit"] || 0,
      successful: results["successful"] || 0,
      failed: results["failed"] || 0,
      objects: parse_objects(results["objects"]),
      dry_run: response["dryRun"] || false
    }
  end

  defp parse_objects(nil), do: nil
  defp parse_objects(objects) when is_list(objects) do
    Enum.map(objects, fn obj ->
      %DeletedObject{
        id: obj["id"],
        status: if(obj["status"] == "SUCCESS", do: :success, else: :failed),
        error: obj["error"]
      }
    end)
  end

  @doc "Check if delete was fully successful"
  @spec success?(t()) :: boolean()
  def success?(%__MODULE__{failed: 0}), do: true
  def success?(_), do: false
end
```

**Tests first**:
- `test "from_api/1 parses complete response"`
- `test "from_api/1 handles missing objects"`
- `test "success?/1 returns true when no failures"`

---

# PART 4: RERANKER IMPLEMENTATIONS

## Context

Only `reranker-cohere` is implemented. Need to add 5 more rerankers.

### Rerankers to Implement

| Reranker | Module Name | Key Options |
|----------|-------------|-------------|
| reranker-transformers | Transformers | model, base_url |
| reranker-voyageai | VoyageAI | model, base_url |
| reranker-jinaai | JinaAI | model, base_url |
| reranker-nvidia | NVIDIA | model, base_url |
| reranker-contextualai | ContextualAI | model, base_url, api_key |

## Phase 4.1: Create Reranker Module (TDD)

Create `lib/weaviate_ex/config/reranker.ex`:

```elixir
defmodule WeaviateEx.Config.Reranker do
  @moduledoc """
  Reranker configuration for Weaviate collections.

  Rerankers re-order search results based on relevance to a query.
  They are configured at the collection level and used at query time.

  ## Supported Rerankers

  - `:cohere` - Cohere Rerank API
  - `:transformers` - Local transformer models
  - `:voyageai` - Voyage AI Rerank API
  - `:jinaai` - Jina AI Rerank API
  - `:nvidia` - NVIDIA NeMo Rerank
  - `:contextualai` - Contextual AI Rerank

  ## Examples

      # Cohere reranker
      reranker = Reranker.cohere(model: "rerank-english-v3.0")

      # Transformers (local)
      reranker = Reranker.transformers(model: "cross-encoder/ms-marco-MiniLM-L-6-v2")

      # Use in collection config
      VectorConfig.with_reranker(config, reranker)
  """

  @type t :: cohere() | transformers() | voyageai() | jinaai() | nvidia() | contextualai()

  @type cohere :: %{
    type: :cohere,
    model: String.t() | nil
  }

  @type transformers :: %{
    type: :transformers,
    model: String.t() | nil,
    base_url: String.t() | nil
  }

  @type voyageai :: %{
    type: :voyageai,
    model: String.t() | nil,
    base_url: String.t() | nil
  }

  @type jinaai :: %{
    type: :jinaai,
    model: String.t() | nil,
    base_url: String.t() | nil
  }

  @type nvidia :: %{
    type: :nvidia,
    model: String.t() | nil,
    base_url: String.t() | nil
  }

  @type contextualai :: %{
    type: :contextualai,
    model: String.t() | nil,
    base_url: String.t() | nil,
    api_key: String.t() | nil
  }

  @doc """
  Cohere reranker configuration.

  ## Options

  - `:model` - Model name (e.g., "rerank-english-v3.0", "rerank-multilingual-v3.0")

  ## Examples

      Reranker.cohere()
      Reranker.cohere(model: "rerank-english-v3.0")
  """
  @spec cohere(keyword()) :: cohere()
  def cohere(opts \\ []) do
    %{
      type: :cohere,
      model: Keyword.get(opts, :model)
    }
  end

  @doc """
  Transformers reranker configuration (local models).

  ## Options

  - `:model` - Model name (e.g., "cross-encoder/ms-marco-MiniLM-L-6-v2")
  - `:base_url` - Custom inference endpoint URL

  ## Examples

      Reranker.transformers(model: "cross-encoder/ms-marco-MiniLM-L-6-v2")
  """
  @spec transformers(keyword()) :: transformers()
  def transformers(opts \\ []) do
    %{
      type: :transformers,
      model: Keyword.get(opts, :model),
      base_url: Keyword.get(opts, :base_url)
    }
  end

  @doc """
  Voyage AI reranker configuration.

  ## Options

  - `:model` - Model name (e.g., "rerank-1", "rerank-lite-1")
  - `:base_url` - Custom API endpoint URL

  ## Examples

      Reranker.voyageai(model: "rerank-1")
  """
  @spec voyageai(keyword()) :: voyageai()
  def voyageai(opts \\ []) do
    %{
      type: :voyageai,
      model: Keyword.get(opts, :model),
      base_url: Keyword.get(opts, :base_url)
    }
  end

  @doc """
  Jina AI reranker configuration.

  ## Options

  - `:model` - Model name (e.g., "jina-reranker-v2-base-multilingual")
  - `:base_url` - Custom API endpoint URL

  ## Examples

      Reranker.jinaai(model: "jina-reranker-v2-base-multilingual")
  """
  @spec jinaai(keyword()) :: jinaai()
  def jinaai(opts \\ []) do
    %{
      type: :jinaai,
      model: Keyword.get(opts, :model),
      base_url: Keyword.get(opts, :base_url)
    }
  end

  @doc """
  NVIDIA NeMo reranker configuration.

  ## Options

  - `:model` - Model name
  - `:base_url` - NVIDIA API endpoint URL

  ## Examples

      Reranker.nvidia(model: "nv-rerank-qa-mistral-4b:1")
  """
  @spec nvidia(keyword()) :: nvidia()
  def nvidia(opts \\ []) do
    %{
      type: :nvidia,
      model: Keyword.get(opts, :model),
      base_url: Keyword.get(opts, :base_url)
    }
  end

  @doc """
  Contextual AI reranker configuration.

  ## Options

  - `:model` - Model name
  - `:base_url` - Custom API endpoint URL
  - `:api_key` - API key (if not using header-based auth)

  ## Examples

      Reranker.contextualai(model: "ctxl-rerank-en-v1-instruct")
  """
  @spec contextualai(keyword()) :: contextualai()
  def contextualai(opts \\ []) do
    %{
      type: :contextualai,
      model: Keyword.get(opts, :model),
      base_url: Keyword.get(opts, :base_url),
      api_key: Keyword.get(opts, :api_key)
    }
  end

  @doc "Convert reranker config to API format"
  @spec to_api(t()) :: map()
  def to_api(%{type: :cohere} = r) do
    %{"reranker-cohere" => build_config(r, [:model])}
  end

  def to_api(%{type: :transformers} = r) do
    %{"reranker-transformers" => build_config(r, [:model, :base_url])}
  end

  def to_api(%{type: :voyageai} = r) do
    %{"reranker-voyageai" => build_config(r, [:model, :base_url])}
  end

  def to_api(%{type: :jinaai} = r) do
    %{"reranker-jinaai" => build_config(r, [:model, :base_url])}
  end

  def to_api(%{type: :nvidia} = r) do
    %{"reranker-nvidia" => build_config(r, [:model, :base_url])}
  end

  def to_api(%{type: :contextualai} = r) do
    %{"reranker-contextualai" => build_config(r, [:model, :base_url, :api_key])}
  end

  defp build_config(reranker, keys) do
    keys
    |> Enum.map(fn key -> {to_api_key(key), Map.get(reranker, key)} end)
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp to_api_key(:base_url), do: "baseURL"
  defp to_api_key(:api_key), do: "apiKey"
  defp to_api_key(key), do: Atom.to_string(key)
end
```

## Phase 4.2: Update VectorConfig (TDD)

Update `lib/weaviate_ex/api/vector_config.ex`:

```elixir
defmodule WeaviateEx.API.VectorConfig do
  # Add to existing module

  alias WeaviateEx.Config.Reranker

  @doc """
  Add reranker configuration to collection config.

  ## Examples

      config
      |> VectorConfig.with_reranker(Reranker.cohere(model: "rerank-english-v3.0"))

      config
      |> VectorConfig.with_reranker(Reranker.transformers(model: "cross-encoder/..."))
  """
  @spec with_reranker(map(), Reranker.t()) :: map()
  def with_reranker(config, reranker) do
    reranker_config = Reranker.to_api(reranker)

    Map.update(config, "moduleConfig", reranker_config, fn existing ->
      Map.merge(existing, reranker_config)
    end)
  end
end
```

**Tests first** in `test/weaviate_ex/config/reranker_test.exs`:

```elixir
describe "cohere/1" do
  test "creates cohere config with defaults"
  test "creates cohere config with model"
end

describe "transformers/1" do
  test "creates transformers config with model"
  test "creates transformers config with base_url"
end

describe "voyageai/1" do
  test "creates voyageai config with all options"
end

describe "jinaai/1" do
  test "creates jinaai config with all options"
end

describe "nvidia/1" do
  test "creates nvidia config with all options"
end

describe "contextualai/1" do
  test "creates contextualai config with all options"
  test "includes api_key when provided"
end

describe "to_api/1" do
  test "converts cohere to API format"
  test "converts transformers to API format"
  test "converts all rerankers to correct module names"
  test "excludes nil values"
end
```

---

# INTEGRATION & DOCUMENTATION

## Main Module Updates

Update `lib/weaviate_ex.ex`:

```elixir
defmodule WeaviateEx do
  # ... existing code ...

  # Cluster convenience functions
  defdelegate cluster_nodes(client, opts \\ []), to: WeaviateEx.API.Cluster, as: :nodes
  defdelegate cluster_shards(client, collection), to: WeaviateEx.API.Cluster, as: :shards
  defdelegate cluster_statistics(client), to: WeaviateEx.API.Cluster, as: :statistics

  # Batch convenience functions
  defdelegate wait_for_vector_indexing(client, collection, opts \\ []), to: WeaviateEx.Batch

  # Re-export reranker and groupby for convenience
  defdelegate rerank(query, opts \\ []), to: WeaviateEx.Query.Rerank, as: :new
  defdelegate group_by(path, opts \\ []), to: WeaviateEx.Query.GroupBy, as: :new
end
```

## Error Handling Updates

Update `lib/weaviate_ex/error.ex`:

```elixir
# Cluster errors
def node_not_found(node_name) do
  %__MODULE__{type: :not_found, message: "Node '#{node_name}' not found", details: %{category: :cluster}}
end

def shard_not_found(collection, shard) do
  %__MODULE__{type: :not_found, message: "Shard '#{shard}' not found in collection '#{collection}'", details: %{category: :cluster}}
end

def replication_failed(reason) do
  %__MODULE__{type: :replication_failed, message: "Replication failed: #{reason}", details: %{category: :cluster}}
end

# Batch errors
def indexing_timeout(collection) do
  %__MODULE__{type: :timeout_error, message: "Timed out waiting for vector indexing on '#{collection}'", details: %{category: :batch}}
end

# Query errors
def invalid_rerank_config(reason) do
  %__MODULE__{type: :bad_request, message: "Invalid rerank configuration: #{reason}", details: %{category: :query}}
end

def invalid_group_by_config(reason) do
  %__MODULE__{type: :bad_request, message: "Invalid group_by configuration: #{reason}", details: %{category: :query}}
end
```

## Update README.md

Add sections for all four feature areas:

```markdown
## Cluster Management

```elixir
# Get cluster nodes
{:ok, nodes} = WeaviateEx.cluster_nodes(client)

# Get shard status for collection
{:ok, shards} = WeaviateEx.cluster_shards(client, "Article")

# Replicate shard to another node
{:ok, op} = WeaviateEx.API.Cluster.replicate(client, "Article", "shard-0",
  source: "node-1",
  target: "node-2",
  type: :copy
)
```

## Query Reranking & Grouping

```elixir
alias WeaviateEx.Query.{Rerank, GroupBy}

# Rerank search results
rerank = Rerank.new("What is machine learning?")
{:ok, results} = client
  |> Query.collection("Article")
  |> Query.near_text("AI and ML", rerank: rerank)
  |> Query.execute()

# Group results by property
group_by = GroupBy.new("category", objects_per_group: 5)
{:ok, grouped} = client
  |> Query.collection("Article")
  |> Query.near_text("technology", group_by: group_by)
  |> Query.execute()

# Both together
{:ok, results} = client
  |> Query.collection("Article")
  |> Query.hybrid("search query", rerank: rerank, group_by: group_by)
  |> Query.execute()
```

## Batch Advanced Features

```elixir
# Wait for vector indexing after batch insert
{:ok, _} = Batch.with_batch(client, fn batch ->
  Enum.reduce(objects, batch, fn obj, b ->
    Batch.add_object(b, "Article", obj)  # Auto-generates UUID
  end)
end)

# Wait for async vectorization to complete
:ok = WeaviateEx.wait_for_vector_indexing(client, "Article", timeout: 60_000)

# Multi-target references
Batch.add_reference(batch, "Article", article_uuid, "relatedTo", [
  %{collection: "Article", uuid: related_article_uuid},
  %{collection: "Video", uuid: related_video_uuid}
])
```

## Reranker Configuration

```elixir
alias WeaviateEx.Config.Reranker

# Available rerankers
Reranker.cohere(model: "rerank-english-v3.0")
Reranker.transformers(model: "cross-encoder/ms-marco-MiniLM-L-6-v2")
Reranker.voyageai(model: "rerank-1")
Reranker.jinaai(model: "jina-reranker-v2-base-multilingual")
Reranker.nvidia(model: "nv-rerank-qa-mistral-4b:1")
Reranker.contextualai(model: "ctxl-rerank-en-v1-instruct")

# Add to collection config
config = VectorConfig.with_reranker(config, Reranker.voyageai(model: "rerank-1"))
```
```

## Update CHANGELOG.md

```markdown
## [0.x.0] - 2025-12-28

### Added

#### Cluster Management (NEW MODULE)
- `Cluster.nodes/2` - Get cluster nodes with optional verbosity
- `Cluster.shards/2` - Get shard status for collection
- `Cluster.statistics/1` - Get cluster statistics
- `Cluster.replicate/4` - Initiate shard replication (COPY/MOVE)
- `Cluster.list_replications/2` - List replication operations
- `Cluster.get_replication/3` - Get replication status
- `Cluster.cancel_replication/2` - Cancel running replication
- `Cluster.delete_replication/2` - Delete completed replication
- Cluster type structs: `Node`, `Shard`, `Replication.Operation`

#### Query Enhancements
- Integrated `rerank` option into all query types (near_vector, near_text, bm25, hybrid, near_object)
- Integrated `group_by` option into all query types
- Added `auto_limit` option for automatic result cutoff
- Added `target_vector` option for multi-vector collections
- Added `operator` option for BM25 queries (`:and`, `:or`)
- Added `vector` option for hybrid queries (custom vector)
- Added `bm25_operator` option for hybrid queries

#### Batch Advanced Features
- `Batch.wait_for_vector_indexing/3` - Poll until async vectorization completes
- Auto UUID generation in `Batch.add_object/4` (no longer requires explicit UUID)
- Multi-target reference support in `Batch.add_reference/5`
- Typed `Batch.DeleteResult` struct for batch delete responses

#### Reranker Implementations
- `Reranker.transformers/1` - Local transformer reranker
- `Reranker.voyageai/1` - Voyage AI reranker
- `Reranker.jinaai/1` - Jina AI reranker
- `Reranker.nvidia/1` - NVIDIA NeMo reranker
- `Reranker.contextualai/1` - Contextual AI reranker

### Changed
- Extended `WeaviateEx.Error` with cluster, batch, and query error types
- `Query.Rerank` and `Query.GroupBy` now integrated into main Query module
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

---

## Files to Create

```
lib/weaviate_ex/cluster/
├── node.ex                  # Node struct
├── shard.ex                 # Shard struct
└── replication.ex           # Replication types

lib/weaviate_ex/api/
└── cluster.ex               # Cluster operations

lib/weaviate_ex/batch/
└── delete_result.ex         # Typed delete response

lib/weaviate_ex/config/
└── reranker.ex              # All reranker types

test/weaviate_ex/cluster/
├── node_test.exs
├── shard_test.exs
└── replication_test.exs

test/weaviate_ex/api/
└── cluster_test.exs

test/weaviate_ex/batch/
└── delete_result_test.exs

test/weaviate_ex/config/
└── reranker_test.exs
```

## Files to Modify

```
lib/weaviate_ex.ex                    # Add convenience delegations
lib/weaviate_ex/query.ex              # Integrate rerank/group_by
lib/weaviate_ex/query/rerank.ex       # Enhance struct
lib/weaviate_ex/query/group_by.ex     # Enhance struct
lib/weaviate_ex/batch.ex              # Add wait_for_vector_indexing
lib/weaviate_ex/batch/fixed_size.ex   # Auto UUID, multi-target refs
lib/weaviate_ex/api/vector_config.ex  # with_reranker/2
lib/weaviate_ex/error.ex              # New error types
mix.exs                               # Version bump
README.md                             # Documentation
CHANGELOG.md                          # Document changes
test/weaviate_ex/query_test.exs       # Rerank/GroupBy integration tests
test/weaviate_ex/batch_test.exs       # wait_for_vector_indexing tests
```

---

## Success Criteria

1. `mix test` - All tests pass (0 failures)
2. `mix compile --warnings-as-errors` - No warnings
3. `mix dialyzer` - No errors
4. `mix credo --strict` - No issues
5. `mix docs` - Generates without warnings
6. **Cluster**: All 8 operations implemented and tested
7. **Query**: Rerank and GroupBy integrated into all 5 query types
8. **Batch**: wait_for_vector_indexing, auto UUID, multi-target refs working
9. **Rerankers**: All 6 rerankers implemented (1 existing + 5 new)
10. README documents all new features with examples
11. CHANGELOG documents all changes
12. Version incremented in mix.exs

---

## Estimated Scope

| Component | Files | Estimated Effort |
|-----------|-------|------------------|
| **Cluster Management** | | |
| Types (Node, Shard, Replication) | 3 | 6-8 hours |
| Cluster API | 1 | 8-12 hours |
| Tests | 4 | 8-12 hours |
| **Query Rerank/GroupBy** | | |
| Struct enhancements | 2 | 3-4 hours |
| Query integration | 1 | 8-12 hours |
| Tests | 1 | 6-8 hours |
| **Batch Advanced** | | |
| wait_for_vector_indexing | 1 | 6-8 hours |
| Auto UUID + Multi-target | 1 | 4-6 hours |
| DeleteResult | 1 | 2-3 hours |
| Tests | 2 | 6-8 hours |
| **Rerankers** | | |
| Reranker module (6 types) | 1 | 4-6 hours |
| VectorConfig integration | 1 | 2-3 hours |
| Tests | 1 | 4-6 hours |
| **Integration** | | |
| Main module + errors | 2 | 3-4 hours |
| Documentation | 2 | 4-6 hours |
| **Total** | ~24 files | ~75-106 hours |

---

*This prompt provides complete instructions for implementing Cluster Management, Query Rerank/GroupBy integration, Batch Advanced Features, and all 6 Rerankers in WeaviateEx with full test coverage and documentation.*
