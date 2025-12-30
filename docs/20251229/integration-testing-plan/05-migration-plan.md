# Migration Plan: Mocks to Live Integration Tests

## Overview

This document outlines the step-by-step migration from the current mock-based test suite to comprehensive live integration tests against a running Weaviate instance.

---

## Current State

### Test Distribution
- **124 total test files**
- **119 unit tests** (mocked with Mox)
- **5 integration tests** (live, excluded by default)

### Mocking Strategy
- Protocol layer mocked via `WeaviateEx.Protocol.Mock`
- HTTP responses simulated
- No actual Weaviate communication in default test runs

### Limitations
- Cannot catch real API behavior changes
- Cannot test actual network/gRPC behavior
- Cannot verify against actual Weaviate responses
- Cannot test version compatibility

---

## Migration Phases

### Phase 1: Infrastructure Setup (Days 1-2)

#### 1.1 Create Docker Infrastructure

```bash
# Directory structure
mkdir -p ci/docker

# Copy/create docker-compose files
# (See 01-docker-stack-management.md for details)
```

**Files to create:**
- `ci/docker/docker-compose.yml` - Base config
- `ci/docker/docker-compose-cluster.yml` - 3-node cluster
- `ci/docker/docker-compose-async.yml` - Async indexing
- `ci/docker/docker-compose-rbac.yml` - RBAC/Auth
- `ci/docker/docker-compose-backup.yml` - Backup testing

#### 1.2 Create Management Scripts

```bash
# Shell scripts
ci/compose.sh        # Helper functions
ci/start_weaviate.sh # Start containers
ci/stop_weaviate.sh  # Stop containers
```

#### 1.3 Create Mix Tasks (Optional)

```elixir
# lib/mix/tasks/weaviate.ex
# mix weaviate.start
# mix weaviate.stop
# mix weaviate.status
```

#### 1.4 Verify Infrastructure

```bash
# Test the setup
./ci/start_weaviate.sh 1.28.14
curl http://localhost:8080/v1/.well-known/ready
./ci/stop_weaviate.sh
```

---

### Phase 2: Test Support Enhancement (Days 2-3)

#### 2.1 Create Integration Helper Module

**File**: `test/support/integration_helper.ex`

```elixir
defmodule WeaviateEx.Test.IntegrationHelper do
  @moduledoc """
  Helper functions for integration tests.
  """

  @doc "Start a client for integration testing"
  def start_client(opts \\ []) do
    port = Keyword.get(opts, :port, 8080)
    grpc_port = Keyword.get(opts, :grpc_port, 50051)

    WeaviateEx.Client.start_link(
      url: "http://localhost:#{port}",
      grpc_host: "localhost",
      grpc_port: grpc_port,
      headers: Keyword.get(opts, :headers, %{})
    )
  end

  @doc "Wait for Weaviate to be ready"
  def wait_for_ready(port \\ 8080, timeout \\ 30_000) do
    deadline = System.monotonic_time(:millisecond) + timeout
    do_wait_for_ready(port, deadline)
  end

  defp do_wait_for_ready(port, deadline) do
    url = "http://localhost:#{port}/v1/.well-known/ready"

    case :httpc.request(:get, {String.to_charlist(url), []}, [], []) do
      {:ok, {{_, 200, _}, _, _}} ->
        :ok

      _ ->
        if System.monotonic_time(:millisecond) < deadline do
          Process.sleep(500)
          do_wait_for_ready(port, deadline)
        else
          {:error, :timeout}
        end
    end
  end

  @doc "Generate unique collection name for test isolation"
  def unique_collection_name(prefix \\ "Test") do
    timestamp = System.os_time(:millisecond)
    random = :rand.uniform(999_999)
    "#{prefix}#{timestamp}#{random}"
  end
end
```

#### 2.2 Create Collection Factory

**File**: `test/support/collection_factory.ex`

```elixir
defmodule WeaviateEx.Test.CollectionFactory do
  @moduledoc """
  Factory for creating test collections with automatic cleanup.
  """

  alias WeaviateEx.Test.IntegrationHelper

  @doc """
  Creates a test collection and tracks it for cleanup.
  Returns {collection_name, collection_config}.
  """
  def create(client, opts \\ []) do
    name = Keyword.get_lazy(opts, :name, fn ->
      IntegrationHelper.unique_collection_name()
    end)

    # Delete if exists
    WeaviateEx.Collections.delete(client, name)

    # Build collection config
    properties = Keyword.get(opts, :properties, default_properties())
    vectorizer = Keyword.get(opts, :vectorizer, nil)

    config = %{
      class: name,
      properties: properties
    }

    config = if vectorizer do
      Map.put(config, :vectorizer, vectorizer)
    else
      config
    end

    # Create collection
    {:ok, _} = WeaviateEx.Collections.create(client, name, config)

    # Track for cleanup
    track_collection(name)

    {name, config}
  end

  @doc "Delete all tracked collections"
  def cleanup(client) do
    collections = Process.get(:test_collections, [])

    for name <- collections do
      WeaviateEx.Collections.delete(client, name)
    end

    Process.put(:test_collections, [])
  end

  defp track_collection(name) do
    collections = Process.get(:test_collections, [])
    Process.put(:test_collections, [name | collections])
  end

  defp default_properties do
    [
      %{name: "name", dataType: ["text"]},
      %{name: "description", dataType: ["text"]},
      %{name: "count", dataType: ["int"]}
    ]
  end
end
```

#### 2.3 Update test_helper.exs

```elixir
# test/test_helper.exs

ExUnit.start()

# Configure test exclusions
ExUnit.configure(
  exclude: [
    :integration,   # Requires live Weaviate
    :rbac,         # Requires RBAC instance
    :cluster,      # Requires cluster
    :performance,  # Slow tests
    :grpc          # gRPC-specific
  ],
  timeout: 60_000
)

# Define mocks
Mox.defmock(WeaviateEx.Protocol.Mock, for: WeaviateEx.Protocol)

# Default to mock protocol
Application.put_env(:weaviate_ex, :protocol_impl, WeaviateEx.Protocol.Mock)

# Helper for integration mode
defmodule WeaviateEx.TestConfig do
  def integration_mode? do
    System.get_env("WEAVIATE_INTEGRATION") == "true"
  end

  def setup_for_integration do
    Application.put_env(:weaviate_ex, :protocol_impl, WeaviateEx.Protocol.HTTP.Client)
  end

  def setup_for_mocks do
    Application.put_env(:weaviate_ex, :protocol_impl, WeaviateEx.Protocol.Mock)
  end
end
```

---

### Phase 3: Expand Existing Integration Tests (Days 3-5)

#### 3.1 Enhance Collections Integration Test

**File**: `test/integration/collections_integration_test.exs`

```elixir
defmodule WeaviateEx.Integration.CollectionsTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias WeaviateEx.Test.IntegrationHelper
  alias WeaviateEx.Test.CollectionFactory

  setup_all do
    # Ensure we're in integration mode
    WeaviateEx.TestConfig.setup_for_integration()

    # Wait for Weaviate
    :ok = IntegrationHelper.wait_for_ready()

    # Start client
    {:ok, client} = IntegrationHelper.start_client()

    on_exit(fn ->
      WeaviateEx.Client.stop(client)
    end)

    {:ok, client: client}
  end

  setup %{client: client} do
    on_exit(fn ->
      CollectionFactory.cleanup(client)
    end)
    :ok
  end

  describe "collection lifecycle" do
    test "creates and deletes collection", %{client: client} do
      {name, _} = CollectionFactory.create(client)

      # Verify exists
      {:ok, true} = WeaviateEx.Collections.exists?(client, name)

      # Delete
      {:ok, _} = WeaviateEx.Collections.delete(client, name)

      # Verify gone
      {:ok, false} = WeaviateEx.Collections.exists?(client, name)
    end

    test "gets collection schema", %{client: client} do
      {name, _} = CollectionFactory.create(client,
        properties: [
          %{name: "title", dataType: ["text"]},
          %{name: "count", dataType: ["int"]}
        ]
      )

      {:ok, schema} = WeaviateEx.Collections.get(client, name)

      assert schema["class"] == name
      assert length(schema["properties"]) == 2
    end

    test "lists all collections", %{client: client} do
      {name1, _} = CollectionFactory.create(client)
      {name2, _} = CollectionFactory.create(client)

      {:ok, list} = WeaviateEx.Collections.list(client)

      names = Enum.map(list["classes"], & &1["class"])
      assert name1 in names
      assert name2 in names
    end

    test "updates collection description", %{client: client} do
      {name, _} = CollectionFactory.create(client)

      {:ok, _} = WeaviateEx.Collections.update(client, name,
        description: "Updated description"
      )

      {:ok, schema} = WeaviateEx.Collections.get(client, name)
      assert schema["description"] == "Updated description"
    end
  end

  describe "collection properties" do
    test "adds property to collection", %{client: client} do
      {name, _} = CollectionFactory.create(client,
        properties: [%{name: "title", dataType: ["text"]}]
      )

      {:ok, _} = WeaviateEx.Collections.add_property(client, name,
        %{name: "new_prop", dataType: ["int"]}
      )

      {:ok, schema} = WeaviateEx.Collections.get(client, name)
      prop_names = Enum.map(schema["properties"], & &1["name"])
      assert "new_prop" in prop_names
    end
  end
end
```

#### 3.2 Enhance Objects Integration Test

**File**: `test/integration/objects_integration_test.exs`

```elixir
defmodule WeaviateEx.Integration.ObjectsTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias WeaviateEx.Test.IntegrationHelper
  alias WeaviateEx.Test.CollectionFactory

  setup_all do
    WeaviateEx.TestConfig.setup_for_integration()
    :ok = IntegrationHelper.wait_for_ready()
    {:ok, client} = IntegrationHelper.start_client()

    on_exit(fn -> WeaviateEx.Client.stop(client) end)
    {:ok, client: client}
  end

  setup %{client: client} do
    on_exit(fn -> CollectionFactory.cleanup(client) end)
    :ok
  end

  describe "object CRUD" do
    test "creates and retrieves object", %{client: client} do
      {name, _} = CollectionFactory.create(client,
        properties: [%{name: "title", dataType: ["text"]}]
      )

      {:ok, created} = WeaviateEx.Objects.create(client, name,
        properties: %{"title" => "Test Object"}
      )

      assert created["id"] != nil

      {:ok, retrieved} = WeaviateEx.Objects.get(client, name, created["id"])
      assert retrieved["properties"]["title"] == "Test Object"
    end

    test "updates object properties", %{client: client} do
      {name, _} = CollectionFactory.create(client,
        properties: [%{name: "title", dataType: ["text"]}]
      )

      {:ok, obj} = WeaviateEx.Objects.create(client, name,
        properties: %{"title" => "Original"}
      )

      {:ok, _} = WeaviateEx.Objects.update(client, name, obj["id"],
        properties: %{"title" => "Updated"}
      )

      {:ok, updated} = WeaviateEx.Objects.get(client, name, obj["id"])
      assert updated["properties"]["title"] == "Updated"
    end

    test "deletes object", %{client: client} do
      {name, _} = CollectionFactory.create(client,
        properties: [%{name: "title", dataType: ["text"]}]
      )

      {:ok, obj} = WeaviateEx.Objects.create(client, name,
        properties: %{"title" => "To Delete"}
      )

      {:ok, _} = WeaviateEx.Objects.delete(client, name, obj["id"])

      {:error, %{status: 404}} = WeaviateEx.Objects.get(client, name, obj["id"])
    end
  end

  describe "object with vectors" do
    test "creates object with custom vector", %{client: client} do
      {name, _} = CollectionFactory.create(client,
        properties: [%{name: "title", dataType: ["text"]}]
      )

      vector = for _ <- 1..128, do: :rand.uniform()

      {:ok, obj} = WeaviateEx.Objects.create(client, name,
        properties: %{"title" => "Vectorized"},
        vector: vector
      )

      {:ok, retrieved} = WeaviateEx.Objects.get(client, name, obj["id"],
        include_vector: true
      )

      assert length(retrieved["vector"]) == 128
    end
  end
end
```

#### 3.3 Enhance Batch Integration Test

**File**: `test/integration/batch_integration_test.exs`

```elixir
defmodule WeaviateEx.Integration.BatchTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias WeaviateEx.Test.IntegrationHelper
  alias WeaviateEx.Test.CollectionFactory

  setup_all do
    WeaviateEx.TestConfig.setup_for_integration()
    :ok = IntegrationHelper.wait_for_ready()
    {:ok, client} = IntegrationHelper.start_client()

    on_exit(fn -> WeaviateEx.Client.stop(client) end)
    {:ok, client: client}
  end

  setup %{client: client} do
    on_exit(fn -> CollectionFactory.cleanup(client) end)
    :ok
  end

  describe "batch insert" do
    test "inserts multiple objects", %{client: client} do
      {name, _} = CollectionFactory.create(client,
        properties: [%{name: "name", dataType: ["text"]}]
      )

      objects = for i <- 1..100 do
        %{properties: %{"name" => "Object #{i}"}}
      end

      {:ok, result} = WeaviateEx.Batch.insert_objects(client, name, objects)

      assert result.successful == 100
      assert result.failed == 0

      # Verify count
      {:ok, count} = WeaviateEx.Aggregate.count(client, name)
      assert count == 100
    end

    test "handles partial failures", %{client: client} do
      {name, _} = CollectionFactory.create(client,
        properties: [%{name: "count", dataType: ["int"]}]
      )

      objects = [
        %{properties: %{"count" => 1}},
        %{properties: %{"count" => "not_an_int"}},  # Invalid
        %{properties: %{"count" => 3}}
      ]

      {:ok, result} = WeaviateEx.Batch.insert_objects(client, name, objects)

      assert result.successful == 2
      assert result.failed == 1
    end

    test "batch delete by filter", %{client: client} do
      {name, _} = CollectionFactory.create(client,
        properties: [
          %{name: "name", dataType: ["text"]},
          %{name: "active", dataType: ["boolean"]}
        ]
      )

      objects = for i <- 1..10 do
        %{properties: %{"name" => "Object #{i}", "active" => rem(i, 2) == 0}}
      end
      {:ok, _} = WeaviateEx.Batch.insert_objects(client, name, objects)

      # Delete inactive objects
      {:ok, result} = WeaviateEx.Batch.delete(client, name,
        where: %{path: ["active"], operator: "Equal", valueBoolean: false}
      )

      assert result.deleted >= 5

      # Verify remaining
      {:ok, count} = WeaviateEx.Aggregate.count(client, name)
      assert count == 5
    end
  end
end
```

---

### Phase 4: Add New Integration Tests (Days 5-7)

#### 4.1 Query/Search Integration Test

**File**: `test/integration/search_integration_test.exs`

```elixir
defmodule WeaviateEx.Integration.SearchTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias WeaviateEx.Test.IntegrationHelper
  alias WeaviateEx.Test.CollectionFactory

  setup_all do
    WeaviateEx.TestConfig.setup_for_integration()
    :ok = IntegrationHelper.wait_for_ready()
    {:ok, client} = IntegrationHelper.start_client()

    # Create and populate test collection
    {name, _} = CollectionFactory.create(client,
      properties: [
        %{name: "title", dataType: ["text"]},
        %{name: "content", dataType: ["text"]},
        %{name: "category", dataType: ["text"]}
      ]
    )

    objects = [
      %{properties: %{"title" => "Apple iPhone", "content" => "A smartphone", "category" => "electronics"}},
      %{properties: %{"title" => "Samsung Galaxy", "content" => "Android phone", "category" => "electronics"}},
      %{properties: %{"title" => "Apple MacBook", "content" => "Laptop computer", "category" => "computers"}},
      %{properties: %{"title" => "Organic Apples", "content" => "Fresh fruit", "category" => "food"}},
    ]
    {:ok, _} = WeaviateEx.Batch.insert_objects(client, name, objects)

    # Wait for indexing
    Process.sleep(1000)

    on_exit(fn ->
      CollectionFactory.cleanup(client)
      WeaviateEx.Client.stop(client)
    end)

    {:ok, client: client, collection: name}
  end

  describe "BM25 search" do
    test "finds matching documents", %{client: client, collection: name} do
      {:ok, result} = WeaviateEx.Query.bm25(client, name,
        query: "Apple",
        limit: 10
      )

      assert length(result["objects"]) >= 2
      titles = Enum.map(result["objects"], & &1["properties"]["title"])
      assert "Apple iPhone" in titles or "Apple MacBook" in titles
    end

    test "searches specific properties", %{client: client, collection: name} do
      {:ok, result} = WeaviateEx.Query.bm25(client, name,
        query: "phone",
        properties: ["content"],
        limit: 10
      )

      assert length(result["objects"]) >= 1
    end
  end

  describe "filtering" do
    test "filters by text property", %{client: client, collection: name} do
      {:ok, result} = WeaviateEx.Query.get(client, name,
        where: %{path: ["category"], operator: "Equal", valueText: "electronics"},
        limit: 10
      )

      assert length(result["objects"]) == 2
      categories = Enum.map(result["objects"], & &1["properties"]["category"])
      assert Enum.all?(categories, & &1 == "electronics")
    end
  end
end
```

#### 4.2 Aggregate Integration Test

**File**: `test/integration/aggregate_integration_test.exs`

```elixir
defmodule WeaviateEx.Integration.AggregateTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  # ... setup similar to above ...

  describe "count aggregation" do
    test "counts all objects", %{client: client, collection: name} do
      {:ok, count} = WeaviateEx.Aggregate.count(client, name)
      assert count > 0
    end

    test "counts with filter", %{client: client, collection: name} do
      {:ok, count} = WeaviateEx.Aggregate.count(client, name,
        where: %{path: ["category"], operator: "Equal", valueText: "electronics"}
      )
      assert count == 2
    end
  end

  describe "property aggregation" do
    test "aggregates text property", %{client: client, collection: name} do
      {:ok, result} = WeaviateEx.Aggregate.over(client, name,
        properties: [%{name: "category", aggregations: ["count", "topOccurrences"]}]
      )

      assert result["category"]["count"] > 0
    end
  end
end
```

---

### Phase 5: CI/CD Integration (Days 7-8)

#### 5.1 Update GitHub Actions

See `04-cicd-integration.md` for full workflow.

#### 5.2 Add Mix Aliases

```elixir
# mix.exs
defp aliases do
  [
    "test.unit": ["test --exclude integration"],
    "test.integration": [
      "cmd ./ci/start_weaviate.sh",
      fn _ ->
        System.put_env("WEAVIATE_INTEGRATION", "true")
        Mix.Task.run("test", ["--include", "integration"])
      end,
      "cmd ./ci/stop_weaviate.sh"
    ],
    "test.all": [
      "cmd ./ci/start_weaviate.sh",
      fn _ ->
        System.put_env("WEAVIATE_INTEGRATION", "true")
        Mix.Task.run("test", ["--include", "integration", "--include", "rbac"])
      end,
      "cmd ./ci/stop_weaviate.sh"
    ]
  ]
end
```

---

## Migration Checklist

### Infrastructure
- [ ] Create `ci/docker/` directory
- [ ] Create all docker-compose files
- [ ] Create shell scripts (compose.sh, start_weaviate.sh, stop_weaviate.sh)
- [ ] Test Docker setup locally
- [ ] Create Mix tasks (optional)

### Test Support
- [ ] Create `test/support/integration_helper.ex`
- [ ] Create `test/support/collection_factory.ex`
- [ ] Create `test/support/generators.ex`
- [ ] Update `test/test_helper.exs`
- [ ] Verify test exclusion tags work

### Integration Tests
- [ ] Expand `collections_integration_test.exs`
- [ ] Expand `objects_integration_test.exs`
- [ ] Expand `batch_integration_test.exs`
- [ ] Expand `query_integration_test.exs`
- [ ] Add `search_integration_test.exs`
- [ ] Add `aggregate_integration_test.exs`
- [ ] Add `filter_integration_test.exs`
- [ ] Run all integration tests locally

### CI/CD
- [ ] Update `.github/workflows/ci.yml`
- [ ] Add Weaviate service to workflow
- [ ] Add integration test job
- [ ] Add version matrix testing
- [ ] Verify CI passes

### Documentation
- [ ] Update README with test instructions
- [ ] Document environment variables
- [ ] Document running integration tests locally

---

## Timeline Summary

| Phase | Duration | Deliverables |
|-------|----------|--------------|
| Phase 1: Infrastructure | 2 days | Docker configs, scripts |
| Phase 2: Test Support | 1 day | Helper modules, factories |
| Phase 3: Expand Existing | 2 days | Enhanced integration tests |
| Phase 4: New Tests | 2 days | Search, aggregate, filter tests |
| Phase 5: CI/CD | 1 day | GitHub Actions workflow |
| **Total** | **8 days** | Full integration test suite |
