# Elixir Test Suite Expansion Plan

## Current State Analysis

### Existing Test Statistics
- **Total Test Files**: 124
- **Unit Tests (mocked)**: 119 files
- **Integration Tests (live)**: 5 files
- **Mocking Library**: Mox
- **Test Framework**: ExUnit

### Current Integration Tests

Located in `test/integration/`:

| File | Purpose | Coverage |
|------|---------|----------|
| `health_integration_test.exs` | Health check endpoint | Basic |
| `collections_integration_test.exs` | Collection CRUD | Basic |
| `objects_integration_test.exs` | Object CRUD | Basic |
| `batch_integration_test.exs` | Batch operations | Basic |
| `query_integration_test.exs` | Query operations | Basic |

### Gaps Compared to Python Client

The Python client has 35 integration test files covering:
- Advanced filtering and aggregation
- Hybrid search scenarios
- Multi-tenancy operations
- RBAC and authentication
- Backup and restore
- Cluster operations
- gRPC-specific tests
- Async operations
- Reference handling
- Vector operations
- Generative search

---

## Test Expansion Roadmap

### Phase 1: Core API Coverage (Week 1-2)

#### 1.1 Collection Tests Expansion

**File**: `test/integration/collections_integration_test.exs`

Add tests for:
```elixir
describe "collection configuration" do
  test "creates collection with vector config"
  test "creates collection with inverted index config"
  test "creates collection with replication config"
  test "updates collection description"
  test "updates collection vector index config"
  test "lists all collections"
  test "gets collection schema"
end

describe "collection properties" do
  test "adds property to existing collection"
  test "creates collection with nested properties"
  test "creates collection with array properties"
  test "creates collection with all data types"
end

describe "collection references" do
  test "creates collection with single reference"
  test "creates collection with multi-target reference"
  test "creates cross-references between collections"
end
```

#### 1.2 Object Tests Expansion

**File**: `test/integration/objects_integration_test.exs`

Add tests for:
```elixir
describe "object CRUD" do
  test "creates object with UUID"
  test "creates object without UUID (auto-generate)"
  test "updates object properties"
  test "patches object properties"
  test "deletes object by UUID"
  test "validates object against schema"
end

describe "object references" do
  test "adds reference to object"
  test "removes reference from object"
  test "replaces all references"
  test "handles cross-collection references"
end

describe "object vectors" do
  test "creates object with custom vector"
  test "creates object with named vectors"
  test "updates object vector"
end
```

#### 1.3 Batch Tests Expansion

**File**: `test/integration/batch_integration_test.exs`

Add tests for:
```elixir
describe "batch insert" do
  test "inserts multiple objects successfully"
  test "handles partial failures gracefully"
  test "respects rate limiting"
  test "uses dynamic batch sizing"
  test "inserts with custom vectors"
end

describe "batch delete" do
  test "deletes objects by filter"
  test "deletes by UUID list"
  test "dry run mode"
end

describe "batch references" do
  test "adds references in batch"
  test "removes references in batch"
end
```

### Phase 2: Search and Query (Week 2-3)

#### 2.1 Query Tests Expansion

**File**: `test/integration/query_integration_test.exs`

Add tests for:
```elixir
describe "basic queries" do
  test "fetches objects with limit"
  test "fetches objects with offset"
  test "fetches objects with after cursor"
  test "returns metadata (creation time, update time)"
  test "returns vector in response"
end

describe "BM25 search" do
  test "searches by single property"
  test "searches by multiple properties"
  test "uses custom boost weights"
end

describe "vector search" do
  test "near_vector search"
  test "near_object search"
  test "with certainty threshold"
  test "with distance threshold"
end

describe "hybrid search" do
  test "combines BM25 and vector"
  test "adjusts alpha parameter"
  test "uses fusion algorithms"
end
```

#### 2.2 Filter Tests

**New File**: `test/integration/filter_integration_test.exs`

```elixir
defmodule WeaviateEx.Integration.FilterTest do
  use ExUnit.Case, async: false
  @moduletag :integration

  describe "property filters" do
    test "filters by text equal"
    test "filters by text like (wildcard)"
    test "filters by int greater than"
    test "filters by int range"
    test "filters by boolean"
    test "filters by date range"
    test "filters by geo distance"
    test "filters by null/not null"
    test "filters by array contains"
  end

  describe "logical operators" do
    test "AND filter"
    test "OR filter"
    test "NOT filter"
    test "nested AND/OR combinations"
  end

  describe "reference filters" do
    test "filters by reference property"
    test "filters by nested reference"
    test "multi-hop reference filter"
  end
end
```

#### 2.3 Aggregate Tests

**New File**: `test/integration/aggregate_integration_test.exs`

```elixir
defmodule WeaviateEx.Integration.AggregateTest do
  use ExUnit.Case, async: false
  @moduletag :integration

  describe "count aggregations" do
    test "counts all objects"
    test "counts with filter"
    test "counts with group by"
  end

  describe "property aggregations" do
    test "aggregates numeric properties (min, max, mean, sum)"
    test "aggregates text properties (count, top occurrences)"
    test "aggregates boolean properties"
    test "aggregates date properties"
  end

  describe "group by" do
    test "groups by text property"
    test "groups by reference"
    test "limits groups"
  end
end
```

### Phase 3: Advanced Features (Week 3-4)

#### 3.1 Multi-Tenancy Tests

**New File**: `test/integration/tenants_integration_test.exs`

```elixir
defmodule WeaviateEx.Integration.TenantsTest do
  use ExUnit.Case, async: false
  @moduletag :integration

  describe "tenant management" do
    test "creates collection with multi-tenancy enabled"
    test "adds tenant to collection"
    test "lists tenants"
    test "gets tenant status"
    test "activates/deactivates tenant"
    test "deletes tenant"
  end

  describe "tenant data isolation" do
    test "inserts data for specific tenant"
    test "queries data for specific tenant"
    test "tenant data is isolated"
  end

  describe "tenant states" do
    test "creates hot tenant"
    test "freezes tenant to cold"
    test "unfreezes cold tenant"
  end
end
```

#### 3.2 Backup Tests

**New File**: `test/integration/backup_integration_test.exs`

```elixir
defmodule WeaviateEx.Integration.BackupTest do
  use ExUnit.Case, async: false
  @moduletag :integration
  # Use backup-specific Weaviate instance (port 8093)

  describe "backup operations" do
    test "creates backup"
    test "checks backup status"
    test "restores from backup"
    test "lists available backups"
  end

  describe "backup configuration" do
    test "backs up specific collections"
    test "excludes collections from backup"
    test "uses compression"
  end
end
```

#### 3.3 RBAC/Auth Tests

**New File**: `test/integration/auth_integration_test.exs`

```elixir
defmodule WeaviateEx.Integration.AuthTest do
  use ExUnit.Case, async: false
  @moduletag :integration
  @moduletag :rbac
  # Use RBAC-specific Weaviate instance (port 8092)

  describe "API key authentication" do
    test "authenticates with valid API key"
    test "rejects invalid API key"
    test "admin key has full access"
  end

  describe "RBAC roles" do
    test "creates role with permissions"
    test "assigns role to user"
    test "role permissions are enforced"
    test "deletes role"
  end

  describe "user management" do
    test "creates DB user"
    test "lists users"
    test "gets user info"
    test "deletes user"
  end
end
```

#### 3.4 Cluster Tests

**New File**: `test/integration/cluster_integration_test.exs`

```elixir
defmodule WeaviateEx.Integration.ClusterTest do
  use ExUnit.Case, async: false
  @moduletag :integration
  @moduletag :cluster
  # Use cluster Weaviate instances (ports 8087-8089)

  describe "cluster status" do
    test "gets cluster nodes"
    test "all nodes are healthy"
    test "gets node statistics"
  end

  describe "replication" do
    test "creates collection with replication factor"
    test "data is replicated across nodes"
  end
end
```

### Phase 4: gRPC and Performance (Week 4-5)

#### 4.1 gRPC Integration Tests

**New File**: `test/integration/grpc_integration_test.exs`

```elixir
defmodule WeaviateEx.Integration.GRPCTest do
  use ExUnit.Case, async: false
  @moduletag :integration
  @moduletag :grpc

  describe "gRPC batch operations" do
    test "batch insert via gRPC"
    test "batch delete via gRPC"
    test "handles large batches"
  end

  describe "gRPC search" do
    test "vector search via gRPC"
    test "hybrid search via gRPC"
    test "returns proper metadata"
  end

  describe "gRPC streaming" do
    test "streams batch results"
    test "handles connection interrupts"
  end
end
```

#### 4.2 Performance/Load Tests

**New File**: `test/integration/performance_test.exs`

```elixir
defmodule WeaviateEx.Integration.PerformanceTest do
  use ExUnit.Case, async: false
  @moduletag :integration
  @moduletag :performance
  @moduletag :slow

  describe "batch throughput" do
    test "inserts 10,000 objects" do
      # Measure time, should complete in reasonable time
    end

    test "concurrent batch inserts" do
      # Multiple parallel batch operations
    end
  end

  describe "query performance" do
    test "queries large dataset"
    test "concurrent query load"
  end
end
```

---

## Test Support Infrastructure

### 1. Enhanced Test Helper

**File**: `test/support/integration_helper.ex`

```elixir
defmodule WeaviateEx.Test.IntegrationHelper do
  @moduledoc """
  Helper functions for integration tests.
  """

  @default_ports %{
    base: {8080, 50051},
    cluster: [{8087, 50058}, {8088, 50059}, {8089, 50060}],
    async: {8090, 50061},
    rbac: {8092, 50063},
    backup: {8093, 50065}
  }

  def start_client(type \\ :base, opts \\ []) do
    {http_port, grpc_port} = get_ports(type)

    WeaviateEx.Client.start_link(
      Keyword.merge([
        url: "http://localhost:#{http_port}",
        grpc_host: "localhost",
        grpc_port: grpc_port
      ], opts)
    )
  end

  def get_ports(type) when is_atom(type) do
    case Map.get(@default_ports, type) do
      ports when is_tuple(ports) -> ports
      [first | _] -> first
      nil -> @default_ports.base
    end
  end

  def wait_for_indexing(client, collection, expected_count, timeout \\ 5000) do
    deadline = System.monotonic_time(:millisecond) + timeout

    Stream.repeatedly(fn ->
      case WeaviateEx.Aggregate.count(client, collection) do
        {:ok, ^expected_count} -> :done
        {:ok, _} -> :retry
        {:error, _} -> :retry
      end
    end)
    |> Stream.take_while(fn
      :done -> false
      :retry ->
        if System.monotonic_time(:millisecond) < deadline do
          Process.sleep(100)
          true
        else
          false
        end
    end)
    |> Enum.to_list()
  end

  def with_collection(client, context, opts \\ [], fun) do
    {name, _} = WeaviateEx.Test.CollectionFactory.create(client, context, opts)

    try do
      fun.(name)
    after
      WeaviateEx.Collections.delete(client, name)
    end
  end
end
```

### 2. Test Data Generators

**File**: `test/support/generators.ex`

```elixir
defmodule WeaviateEx.Test.Generators do
  @moduledoc """
  Generate test data for integration tests.
  """

  def random_string(length \\ 10) do
    :crypto.strong_rand_bytes(length)
    |> Base.encode64()
    |> binary_part(0, length)
  end

  def random_vector(dimensions \\ 128) do
    for _ <- 1..dimensions, do: :rand.uniform()
  end

  def sample_objects(count, opts \\ []) do
    properties_fn = Keyword.get(opts, :properties_fn, &default_properties/1)
    vector_fn = Keyword.get(opts, :vector_fn, nil)

    for i <- 1..count do
      obj = %{properties: properties_fn.(i)}

      if vector_fn do
        Map.put(obj, :vector, vector_fn.(i))
      else
        obj
      end
    end
  end

  defp default_properties(index) do
    %{
      "name" => "Object #{index}",
      "description" => random_string(50),
      "count" => index,
      "active" => rem(index, 2) == 0
    }
  end

  def sample_collection_config(opts \\ []) do
    name = Keyword.get(opts, :name, "TestCollection#{:rand.uniform(999_999)}")

    %{
      class: name,
      properties: Keyword.get(opts, :properties, default_properties_schema()),
      vectorizer: Keyword.get(opts, :vectorizer, "none")
    }
  end

  defp default_properties_schema do
    [
      %{name: "name", dataType: ["text"]},
      %{name: "description", dataType: ["text"]},
      %{name: "count", dataType: ["int"]},
      %{name: "active", dataType: ["boolean"]}
    ]
  end
end
```

### 3. Assertion Helpers

**File**: `test/support/assertions.ex`

```elixir
defmodule WeaviateEx.Test.Assertions do
  @moduledoc """
  Custom assertions for Weaviate tests.
  """

  import ExUnit.Assertions

  def assert_collection_exists(client, name) do
    case WeaviateEx.Collections.exists?(client, name) do
      {:ok, true} -> :ok
      {:ok, false} -> flunk("Collection #{name} does not exist")
      {:error, error} -> flunk("Failed to check collection: #{inspect(error)}")
    end
  end

  def assert_object_count(client, collection, expected) do
    case WeaviateEx.Aggregate.count(client, collection) do
      {:ok, ^expected} -> :ok
      {:ok, actual} -> flunk("Expected #{expected} objects, got #{actual}")
      {:error, error} -> flunk("Failed to count objects: #{inspect(error)}")
    end
  end

  def assert_search_returns(client, collection, query, expected_ids) do
    case WeaviateEx.Query.bm25(client, collection, query: query, limit: 100) do
      {:ok, result} ->
        returned_ids = Enum.map(result["objects"], & &1["id"])
        assert MapSet.new(returned_ids) == MapSet.new(expected_ids)

      {:error, error} ->
        flunk("Search failed: #{inspect(error)}")
    end
  end
end
```

---

## Test Configuration

### 1. Update test_helper.exs

```elixir
# test/test_helper.exs

ExUnit.start()

# Configure exclusions
ExUnit.configure(
  exclude: [
    :integration,    # Exclude by default, enable with --include integration
    :performance,    # Exclude slow tests
    :rbac,          # Requires RBAC container
    :cluster,       # Requires cluster containers
    :grpc,          # gRPC-specific tests
    :journey        # End-to-end journey tests
  ],
  timeout: 60_000   # 60 second timeout for integration tests
)

# Define Mox mocks
Mox.defmock(WeaviateEx.Protocol.Mock, for: WeaviateEx.Protocol)

# Set default protocol for tests
Application.put_env(:weaviate_ex, :protocol_impl, WeaviateEx.Protocol.Mock)

# Integration mode detection
defmodule WeaviateEx.TestConfig do
  def integration_mode? do
    System.get_env("WEAVIATE_INTEGRATION") == "true"
  end

  def setup_protocol(_context) do
    if integration_mode?() do
      Application.put_env(:weaviate_ex, :protocol_impl, WeaviateEx.Protocol.HTTP.Client)
    else
      Application.put_env(:weaviate_ex, :protocol_impl, WeaviateEx.Protocol.Mock)
    end
  end
end
```

### 2. Mix.exs Test Aliases

```elixir
# In mix.exs

defp aliases do
  [
    # ... existing aliases ...
    "test.integration": [
      "cmd ./ci/start_weaviate.sh",
      "test --include integration",
      "cmd ./ci/stop_weaviate.sh"
    ],
    "test.all": [
      "cmd ./ci/start_weaviate.sh",
      "test --include integration --include rbac --include cluster",
      "cmd ./ci/stop_weaviate.sh"
    ],
    "test.quick": "test --exclude slow"
  ]
end
```

---

## Recommended Test File Structure

```
test/
├── integration/
│   ├── collections_integration_test.exs   # Expanded
│   ├── objects_integration_test.exs       # Expanded
│   ├── batch_integration_test.exs         # Expanded
│   ├── query_integration_test.exs         # Expanded
│   ├── health_integration_test.exs        # Existing
│   ├── filter_integration_test.exs        # New
│   ├── aggregate_integration_test.exs     # New
│   ├── tenants_integration_test.exs       # New
│   ├── backup_integration_test.exs        # New
│   ├── auth_integration_test.exs          # New
│   ├── cluster_integration_test.exs       # New
│   ├── grpc_integration_test.exs          # New
│   ├── performance_test.exs               # New
│   └── journey/
│       ├── phoenix_test.exs               # New
│       └── workflow_test.exs              # New
├── support/
│   ├── factory.ex                         # Existing
│   ├── fixtures.ex                        # Existing
│   ├── mocks.ex                           # Existing
│   ├── integration_helper.ex              # New
│   ├── generators.ex                      # New
│   └── assertions.ex                      # New
├── weaviate_ex/
│   └── ... (existing unit tests)
└── test_helper.exs                        # Updated
```

---

## Test Coverage Targets

| Category | Current | Target | Priority |
|----------|---------|--------|----------|
| Collections CRUD | Basic | Comprehensive | High |
| Objects CRUD | Basic | Comprehensive | High |
| Batch Operations | Basic | Comprehensive | High |
| Query/Search | Basic | Comprehensive | High |
| Filtering | None | Comprehensive | High |
| Aggregation | None | Comprehensive | Medium |
| Multi-Tenancy | None | Comprehensive | Medium |
| RBAC/Auth | None | Comprehensive | Medium |
| Backup/Restore | None | Comprehensive | Medium |
| Cluster | None | Basic | Low |
| gRPC | None | Basic | Low |
| Performance | None | Basic | Low |
