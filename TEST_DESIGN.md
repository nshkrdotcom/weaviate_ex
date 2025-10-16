# WeaviateEx Test Design

> Comprehensive testing strategy with Mox mocks and TDD approach

---

## Table of Contents

1. [Testing Philosophy](#testing-philosophy)
2. [Test Structure](#test-structure)
3. [Mocking Strategy](#mocking-strategy)
4. [Test Categories](#test-categories)
5. [Stub Implementation Strategy](#stub-implementation-strategy)
6. [Test Fixtures and Factories](#test-fixtures-and-factories)
7. [Test Execution](#test-execution)

---

## Testing Philosophy

### Test-Driven Development (TDD)

1. **Write comprehensive tests first** - Define expected behavior
2. **Stub implementations that FAIL** - Start with NotImplementedError
3. **Implement one feature at a time** - Watch tests turn green
4. **Refactor with confidence** - Tests ensure correctness

### Testing Principles

- **Fast feedback** - Unit tests run in <1 second
- **Isolation** - No external dependencies in unit tests
- **Comprehensive** - Test happy paths and edge cases
- **Maintainable** - Clear, documented test code
- **Realistic** - Integration tests with real Weaviate

---

## Test Structure

### Test Organization

```
test/
├── test_helper.exs                 # Mox setup, shared config
│
├── support/                        # Test utilities
│   ├── mocks.ex                    # Mock definitions
│   ├── factory.ex                  # Test data factory
│   ├── fixtures.ex                 # Static test data
│   ├── assertions.ex               # Custom assertions
│   └── bypass_helpers.ex           # HTTP mock helpers
│
├── weaviate_ex/                    # Unit tests (mocked)
│   ├── client/
│   ├── auth/
│   ├── protocol/
│   ├── api/
│   ├── query/
│   ├── filter/
│   ├── batch/
│   ├── config/
│   └── types/
│
├── integration/                    # Integration tests (live)
│   ├── *_integration_test.exs
│   └── support/
│       └── integration_case.ex     # Integration test helpers
│
├── property/                       # Property-based tests
│   └── *_property_test.exs
│
└── performance/                    # Performance benchmarks
    └── *_bench.exs
```

---

## Mocking Strategy

### Mox Configuration

```elixir
# test/support/mocks.ex
defmodule WeaviateEx.Test.Mocks do
  @moduledoc """
  Mock definitions for testing.
  """

  # Protocol mock
  Mox.defmock(WeaviateEx.Protocol.Mock, for: WeaviateEx.Protocol)

  # HTTP client mock
  Mox.defmock(WeaviateEx.Protocol.HTTP.ClientMock, for: WeaviateEx.Protocol.HTTP.ClientBehaviour)

  # gRPC client mock
  Mox.defmock(WeaviateEx.Protocol.GRPC.ClientMock, for: WeaviateEx.Protocol.GRPC.ClientBehaviour)

  # Auth provider mock
  Mox.defmock(WeaviateEx.Auth.ProviderMock, for: WeaviateEx.Auth.Provider)

  @doc """
  Setup default mock configuration for test client.
  """
  def setup_test_client(_context) do
    client = %WeaviateEx.Client{
      config: %WeaviateEx.Client.Config{
        base_url: "http://localhost:8080",
        grpc_host: "localhost",
        grpc_port: 50051
      },
      connection: %WeaviateEx.Client.Connection{
        base_url: "http://localhost:8080"
      },
      protocol: :http,
      protocol_impl: WeaviateEx.Protocol.Mock
    }

    {:ok, client: client}
  end

  @doc """
  Expect successful HTTP response.
  """
  def expect_http_success(mock, method, path, response_body) do
    Mox.expect(mock, :request, fn _client, ^method, ^path, _body, _opts ->
      {:ok, response_body}
    end)
  end

  @doc """
  Expect HTTP error response.
  """
  def expect_http_error(mock, method, path, error_type, message \\ nil) do
    Mox.expect(mock, :request, fn _client, ^method, ^path, _body, _opts ->
      {:error, %WeaviateEx.Error{
        type: error_type,
        message: message || "Error occurred"
      }}
    end)
  end

  @doc """
  Stub any request to return success.
  """
  def stub_success(mock) do
    Mox.stub(mock, :request, fn _client, _method, _path, _body, _opts ->
      {:ok, %{}}
    end)
  end
end
```

### Test Helper Setup

```elixir
# test/test_helper.exs
ExUnit.start()

# Import mocks
Code.require_file("support/mocks.ex", __DIR__)

# Configure application for testing
Application.put_env(:weaviate_ex, :protocol_impl, WeaviateEx.Protocol.Mock)
Application.put_env(:weaviate_ex, :http_client, WeaviateEx.Protocol.HTTP.ClientMock)
Application.put_env(:weaviate_ex, :grpc_client, WeaviateEx.Protocol.GRPC.ClientMock)

# Exclude integration tests by default
ExUnit.configure(exclude: [:integration, :property, :performance])
```

---

## Test Categories

### 1. Unit Tests (Default, Fast)

**Purpose**: Test individual functions with mocked dependencies

**Location**: `test/weaviate_ex/`

**Example**: Collections API Unit Test

```elixir
# test/weaviate_ex/api/collections_test.exs
defmodule WeaviateEx.API.CollectionsTest do
  use ExUnit.Case, async: true
  import Mox
  import WeaviateEx.Test.Mocks

  alias WeaviateEx.API.Collections
  alias WeaviateEx.Protocol.Mock

  setup :verify_on_exit!
  setup :setup_test_client

  describe "list/1" do
    test "returns list of collection names", %{client: client} do
      # Arrange
      expect_http_success(Mock, :get, "/v1/schema", %{
        "classes" => [
          %{"class" => "Article", "vectorizer" => "text2vec-openai"},
          %{"class" => "Author", "vectorizer" => "none"}
        ]
      })

      # Act
      assert {:ok, collections} = Collections.list(client)

      # Assert
      assert length(collections) == 2
      assert "Article" in collections
      assert "Author" in collections
    end

    test "handles empty schema", %{client: client} do
      expect_http_success(Mock, :get, "/v1/schema", %{"classes" => []})

      assert {:ok, []} = Collections.list(client)
    end

    test "handles connection error", %{client: client} do
      expect_http_error(Mock, :get, "/v1/schema", :connection_error, "Connection refused")

      assert {:error, %WeaviateEx.Error{type: :connection_error}} =
        Collections.list(client)
    end

    test "handles authentication error", %{client: client} do
      expect_http_error(Mock, :get, "/v1/schema", :authentication_failed)

      assert {:error, %WeaviateEx.Error{type: :authentication_failed}} =
        Collections.list(client)
    end
  end

  describe "get/2" do
    test "returns collection config", %{client: client} do
      expect_http_success(Mock, :get, "/v1/schema/Article", %{
        "class" => "Article",
        "vectorizer" => "text2vec-openai",
        "properties" => [
          %{"name" => "title", "dataType" => ["text"]},
          %{"name" => "content", "dataType" => ["text"]}
        ]
      })

      assert {:ok, config} = Collections.get(client, "Article")
      assert config["class"] == "Article"
      assert length(config["properties"]) == 2
    end

    test "handles not found error", %{client: client} do
      expect_http_error(Mock, :get, "/v1/schema/NonExistent", :not_found)

      assert {:error, %WeaviateEx.Error{type: :not_found}} =
        Collections.get(client, "NonExistent")
    end
  end

  describe "create/2" do
    test "creates collection with minimal config", %{client: client} do
      config = %{"class" => "NewCollection"}

      Mock
      |> expect(:request, fn _client, :post, "/v1/schema", body, _opts ->
        assert body["class"] == "NewCollection"
        {:ok, body}
      end)

      assert {:ok, result} = Collections.create(client, config)
      assert result["class"] == "NewCollection"
    end

    test "creates collection with full config", %{client: client} do
      config = %{
        "class" => "Article",
        "vectorizer" => "text2vec-openai",
        "properties" => [
          %{"name" => "title", "dataType" => ["text"]},
          %{"name" => "content", "dataType" => ["text"]}
        ],
        "vectorIndexConfig" => %{
          "distance" => "cosine",
          "ef" => 100
        }
      }

      Mock
      |> expect(:request, fn _client, :post, "/v1/schema", body, _opts ->
        assert body["class"] == "Article"
        assert body["vectorizer"] == "text2vec-openai"
        assert length(body["properties"]) == 2
        {:ok, body}
      end)

      assert {:ok, _result} = Collections.create(client, config)
    end

    test "handles validation error", %{client: client} do
      config = %{"class" => "Invalid Name"}  # Invalid: contains space

      expect_http_error(Mock, :post, "/v1/schema", :validation_error,
        "Class name cannot contain spaces")

      assert {:error, %WeaviateEx.Error{type: :validation_error}} =
        Collections.create(client, config)
    end

    test "handles conflict error for duplicate collection", %{client: client} do
      config = %{"class" => "ExistingCollection"}

      expect_http_error(Mock, :post, "/v1/schema", :conflict,
        "Collection already exists")

      assert {:error, %WeaviateEx.Error{type: :conflict}} =
        Collections.create(client, config)
    end
  end

  describe "delete/2" do
    test "deletes existing collection", %{client: client} do
      expect_http_success(Mock, :delete, "/v1/schema/Article", %{})

      assert {:ok, _} = Collections.delete(client, "Article")
    end

    test "handles not found error", %{client: client} do
      expect_http_error(Mock, :delete, "/v1/schema/NonExistent", :not_found)

      assert {:error, %WeaviateEx.Error{type: :not_found}} =
        Collections.delete(client, "NonExistent")
    end
  end

  describe "update/3" do
    test "updates collection config", %{client: client} do
      updates = %{
        "vectorIndexConfig" => %{"ef" => 200}
      }

      Mock
      |> expect(:request, fn _client, :put, "/v1/schema/Article", body, _opts ->
        assert body["vectorIndexConfig"]["ef"] == 200
        {:ok, body}
      end)

      assert {:ok, _result} = Collections.update(client, "Article", updates)
    end

    test "handles immutable field error", %{client: client} do
      updates = %{"vectorizer" => "text2vec-cohere"}  # Cannot change vectorizer

      expect_http_error(Mock, :put, "/v1/schema/Article", :validation_error,
        "Vectorizer cannot be changed after creation")

      assert {:error, %WeaviateEx.Error{type: :validation_error}} =
        Collections.update(client, "Article", updates)
    end
  end

  describe "add_property/3" do
    test "adds new property", %{client: client} do
      property = %{
        "name" => "publishedAt",
        "dataType" => ["date"]
      }

      Mock
      |> expect(:request, fn _client, :post, "/v1/schema/Article/properties", body, _opts ->
        assert body["name"] == "publishedAt"
        assert body["dataType"] == ["date"]
        {:ok, body}
      end)

      assert {:ok, _result} = Collections.add_property(client, "Article", property)
    end

    test "handles duplicate property error", %{client: client} do
      property = %{"name" => "title", "dataType" => ["text"]}

      expect_http_error(Mock, :post, "/v1/schema/Article/properties", :conflict,
        "Property 'title' already exists")

      assert {:error, %WeaviateEx.Error{type: :conflict}} =
        Collections.add_property(client, "Article", property)
    end
  end

  describe "exists?/2" do
    test "returns true for existing collection", %{client: client} do
      expect_http_success(Mock, :head, "/v1/schema/Article", %{})

      assert {:ok, true} = Collections.exists?(client, "Article")
    end

    test "returns false for non-existent collection", %{client: client} do
      expect_http_error(Mock, :head, "/v1/schema/NonExistent", :not_found)

      assert {:ok, false} = Collections.exists?(client, "NonExistent")
    end
  end
end
```

### 2. Query Builder Tests

```elixir
# test/weaviate_ex/query/builder_test.exs
defmodule WeaviateEx.Query.BuilderTest do
  use ExUnit.Case, async: true
  import Mox
  import WeaviateEx.Test.Mocks

  alias WeaviateEx.Query.Builder
  alias WeaviateEx.Filter
  alias WeaviateEx.Protocol.Mock

  setup :verify_on_exit!
  setup :setup_test_client

  describe "near_text/3" do
    test "builds basic near_text query", %{client: client} do
      collection = %WeaviateEx.Collection{client: client, name: "Article"}

      query = Builder.new(collection)
      |> Builder.near_text("machine learning")

      assert query.query_type == {:near_text, %{concepts: ["machine learning"]}}
    end

    test "builds near_text with certainty", %{client: client} do
      collection = %WeaviateEx.Collection{client: client, name: "Article"}

      query = Builder.new(collection)
      |> Builder.near_text("AI", certainty: 0.7)

      assert query.query_type == {:near_text, %{
        concepts: ["AI"],
        certainty: 0.7
      }}
    end

    test "builds near_text with move parameters", %{client: client} do
      collection = %WeaviateEx.Collection{client: client, name: "Article"}

      query = Builder.new(collection)
      |> Builder.near_text("technology",
        move_to: %{concepts: ["programming"], force: 0.5},
        move_away: %{concepts: ["hardware"], force: 0.3}
      )

      assert query.query_type == {:near_text, %{
        concepts: ["technology"],
        move_to: %{concepts: ["programming"], force: 0.5},
        move_away: %{concepts: ["hardware"], force: 0.3}
      }}
    end
  end

  describe "where/2" do
    test "adds filter to query", %{client: client} do
      collection = %WeaviateEx.Collection{client: client, name: "Article"}

      filter = Filter.by_property("category")
      |> Filter.equal("technology")

      query = Builder.new(collection)
      |> Builder.where(filter)

      assert query.filters == filter
    end

    test "replaces existing filter", %{client: client} do
      collection = %WeaviateEx.Collection{client: client, name: "Article"}

      filter1 = Filter.by_property("category") |> Filter.equal("tech")
      filter2 = Filter.by_property("status") |> Filter.equal("published")

      query = Builder.new(collection)
      |> Builder.where(filter1)
      |> Builder.where(filter2)

      assert query.filters == filter2
    end
  end

  describe "execute/1" do
    test "executes simple fetch query", %{client: client} do
      collection = %WeaviateEx.Collection{client: client, name: "Article"}

      expected_graphql = """
      {
        Get {
          Article {
            title
            content
          }
        }
      }
      """

      Mock
      |> expect(:request, fn _client, :post, "/v1/graphql", body, _opts ->
        # Verify GraphQL query structure
        assert body["query"] =~ "Get"
        assert body["query"] =~ "Article"

        {:ok, %{
          "data" => %{
            "Get" => %{
              "Article" => [
                %{"title" => "Test", "content" => "Content"}
              ]
            }
          }
        }}
      end)

      query = Builder.new(collection)
      |> Builder.fields(["title", "content"])

      assert {:ok, results} = Builder.execute(query)
      assert length(results) == 1
      assert hd(results)["title"] == "Test"
    end

    test "executes near_text query with filters", %{client: client} do
      collection = %WeaviateEx.Collection{client: client, name: "Article"}

      filter = Filter.by_property("category") |> Filter.equal("technology")

      Mock
      |> expect(:request, fn _client, :post, "/v1/graphql", body, _opts ->
        graphql = body["query"]

        # Verify nearText is present
        assert graphql =~ "nearText"
        assert graphql =~ "machine learning"

        # Verify filter is present
        assert graphql =~ "where"
        assert graphql =~ "category"
        assert graphql =~ "technology"

        {:ok, %{
          "data" => %{
            "Get" => %{
              "Article" => [
                %{
                  "title" => "ML Article",
                  "_additional" => %{"certainty" => 0.95}
                }
              ]
            }
          }
        }}
      end)

      query = Builder.new(collection)
      |> Builder.near_text("machine learning")
      |> Builder.where(filter)
      |> Builder.fields(["title"])
      |> Builder.with_additional([:certainty])
      |> Builder.limit(10)

      assert {:ok, results} = Builder.execute(query)
      assert length(results) == 1
      assert hd(results)["_additional"]["certainty"] == 0.95
    end
  end
end
```

### 3. Filter Builder Tests

```elixir
# test/weaviate_ex/filter/filter_test.exs
defmodule WeaviateEx.Filter.FilterTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Filter

  describe "by_property/1" do
    test "creates property filter" do
      filter = Filter.by_property("title")

      assert filter.path == ["title"]
      assert filter.operator == nil
      assert filter.value == nil
    end

    test "creates nested property filter" do
      filter = Filter.by_property("author.name")

      assert filter.path == ["author", "name"]
    end
  end

  describe "equal/2" do
    test "adds equal operator to filter" do
      filter = Filter.by_property("category")
      |> Filter.equal("technology")

      assert filter.operator == :equal
      assert filter.value == "technology"
      assert filter.value_type == :text
    end

    test "infers value type for numbers" do
      filter = Filter.by_property("price")
      |> Filter.equal(99.99)

      assert filter.value_type == :number
      assert filter.value == 99.99
    end

    test "infers value type for integers" do
      filter = Filter.by_property("count")
      |> Filter.equal(42)

      assert filter.value_type == :int
    end

    test "infers value type for booleans" do
      filter = Filter.by_property("published")
      |> Filter.equal(true)

      assert filter.value_type == :boolean
    end
  end

  describe "comparison operators" do
    test "greater_than/2" do
      filter = Filter.by_property("price") |> Filter.greater_than(100)

      assert filter.operator == :greater_than
      assert filter.value == 100
    end

    test "less_than/2" do
      filter = Filter.by_property("price") |> Filter.less_than(100)

      assert filter.operator == :less_than
    end

    test "greater_or_equal/2" do
      filter = Filter.by_property("rating") |> Filter.greater_or_equal(4.0)

      assert filter.operator == :greater_or_equal
    end

    test "less_or_equal/2" do
      filter = Filter.by_property("rating") |> Filter.less_or_equal(3.0)

      assert filter.operator == :less_or_equal
    end
  end

  describe "like/2" do
    test "creates like filter with wildcard" do
      filter = Filter.by_property("title") |> Filter.like("machine*")

      assert filter.operator == :like
      assert filter.value == "machine*"
    end
  end

  describe "within_geo_range/3" do
    test "creates geospatial filter" do
      coordinate = %{latitude: 52.5, longitude: 13.4}

      filter = Filter.by_property("location")
      |> Filter.within_geo_range(coordinate, 10_000)  # 10km

      assert filter.operator == :within_geo_range
      assert filter.value == %{
        latitude: 52.5,
        longitude: 13.4,
        distance: 10_000
      }
    end
  end

  describe "array operators" do
    test "contains_any/2" do
      filter = Filter.by_property("tags")
      |> Filter.contains_any(["elixir", "phoenix"])

      assert filter.operator == :contains_any
      assert filter.value == ["elixir", "phoenix"]
    end

    test "contains_all/2" do
      filter = Filter.by_property("tags")
      |> Filter.contains_all(["elixir", "functional"])

      assert filter.operator == :contains_all
    end

    test "contains_none/2" do
      filter = Filter.by_property("tags")
      |> Filter.contains_none(["deprecated", "legacy"])

      assert filter.operator == :contains_none
    end
  end

  describe "is_none/1" do
    test "creates null check filter" do
      filter = Filter.by_property("deletedAt") |> Filter.is_none()

      assert filter.operator == :is_none
      assert filter.value == true
    end
  end

  describe "combinators" do
    test "all_of/1 combines filters with AND" do
      filter1 = Filter.by_property("category") |> Filter.equal("tech")
      filter2 = Filter.by_property("published") |> Filter.equal(true)

      combined = Filter.all_of([filter1, filter2])

      assert combined.operator == :all_of
      assert length(combined.operands) == 2
    end

    test "any_of/1 combines filters with OR" do
      filter1 = Filter.by_property("status") |> Filter.equal("published")
      filter2 = Filter.by_property("status") |> Filter.equal("featured")

      combined = Filter.any_of([filter1, filter2])

      assert combined.operator == :any_of
      assert length(combined.operands) == 2
    end

    test "not_/1 negates filter" do
      filter = Filter.by_property("deleted") |> Filter.equal(true)

      negated = Filter.not_(filter)

      assert negated.operator == :not
      assert length(negated.operands) == 1
    end

    test "complex nested combination" do
      # (category = "tech" AND published = true) OR (featured = true)

      tech_and_published = Filter.all_of([
        Filter.by_property("category") |> Filter.equal("tech"),
        Filter.by_property("published") |> Filter.equal(true)
      ])

      featured = Filter.by_property("featured") |> Filter.equal(true)

      combined = Filter.any_of([tech_and_published, featured])

      assert combined.operator == :any_of
      assert length(combined.operands) == 2
      assert hd(combined.operands).operator == :all_of
    end
  end

  describe "to_graphql/1" do
    test "converts simple equal filter to GraphQL" do
      filter = Filter.by_property("category") |> Filter.equal("technology")

      graphql = Filter.to_graphql(filter)

      assert graphql =~ "path: [\"category\"]"
      assert graphql =~ "operator: Equal"
      assert graphql =~ "valueText: \"technology\""
    end

    test "converts comparison filter to GraphQL" do
      filter = Filter.by_property("price") |> Filter.greater_than(100)

      graphql = Filter.to_graphql(filter)

      assert graphql =~ "operator: GreaterThan"
      assert graphql =~ "valueInt: 100" # or valueNumber depending on implementation
    end

    test "converts complex AND filter to GraphQL" do
      filter = Filter.all_of([
        Filter.by_property("category") |> Filter.equal("tech"),
        Filter.by_property("price") |> Filter.less_than(50)
      ])

      graphql = Filter.to_graphql(filter)

      assert graphql =~ "operator: And"
      assert graphql =~ "category"
      assert graphql =~ "price"
    end
  end
end
```

### 4. Batch Operation Tests

```elixir
# test/weaviate_ex/batch/batch_test.exs
defmodule WeaviateEx.Batch.BatchTest do
  use ExUnit.Case, async: true
  import Mox
  import WeaviateEx.Test.Mocks

  alias WeaviateEx.Batch
  alias WeaviateEx.Protocol.Mock

  setup :verify_on_exit!
  setup :setup_test_client

  describe "create_objects/2" do
    test "creates multiple objects successfully", %{client: client} do
      objects = [
        %{class: "Article", properties: %{title: "Article 1"}},
        %{class: "Article", properties: %{title: "Article 2"}},
        %{class: "Article", properties: %{title: "Article 3"}}
      ]

      Mock
      |> expect(:batch_request, fn _client, ops, _opts ->
        assert length(ops) == 3

        {:ok, %{
          "results" => [
            %{"status" => "SUCCESS", "id" => "uuid-1"},
            %{"status" => "SUCCESS", "id" => "uuid-2"},
            %{"status" => "SUCCESS", "id" => "uuid-3"}
          ]
        }}
      end)

      assert {:ok, result} = Batch.create_objects(client, objects)
      assert result.success_count == 3
      assert result.error_count == 0
      assert length(result.uuids) == 3
    end

    test "handles partial failures", %{client: client} do
      objects = [
        %{class: "Article", properties: %{title: "Valid"}},
        %{class: "Article", properties: %{invalid: "field"}},  # Will fail validation
        %{class: "Article", properties: %{title: "Also Valid"}}
      ]

      Mock
      |> expect(:batch_request, fn _client, _ops, _opts ->
        {:ok, %{
          "results" => [
            %{"status" => "SUCCESS", "id" => "uuid-1"},
            %{
              "status" => "FAILED",
              "errors" => [%{"message" => "Invalid property 'invalid'"}]
            },
            %{"status" => "SUCCESS", "id" => "uuid-3"}
          ]
        }}
      end)

      assert {:ok, result} = Batch.create_objects(client, objects)
      assert result.success_count == 2
      assert result.error_count == 1
      assert length(result.errors) == 1
    end

    test "handles complete failure", %{client: client} do
      objects = [%{class: "Article", properties: %{title: "Test"}}]

      expect_http_error(Mock, :post, "/v1/batch/objects", :connection_error)

      # When using batch_request
      Mock
      |> expect(:batch_request, fn _client, _ops, _opts ->
        {:error, %WeaviateEx.Error{type: :connection_error}}
      end)

      assert {:error, %WeaviateEx.Error{type: :connection_error}} =
        Batch.create_objects(client, objects)
    end

    test "includes vectors in batch", %{client: client} do
      objects = [
        %{
          class: "Article",
          properties: %{title: "With Vector"},
          vector: [0.1, 0.2, 0.3, 0.4]
        }
      ]

      Mock
      |> expect(:batch_request, fn _client, ops, _opts ->
        assert hd(ops)["vector"] == [0.1, 0.2, 0.3, 0.4]

        {:ok, %{
          "results" => [
            %{"status" => "SUCCESS", "id" => "uuid-1"}
          ]
        }}
      end)

      assert {:ok, _result} = Batch.create_objects(client, objects)
    end

    test "respects batch size configuration", %{client: client} do
      # Create 250 objects
      objects = Enum.map(1..250, fn i ->
        %{class: "Article", properties: %{title: "Article #{i}"}}
      end)

      # Expect 3 batch calls (100 + 100 + 50 with batch_size: 100)
      Mock
      |> expect(:batch_request, 3, fn _client, ops, _opts ->
        # First two batches: 100 objects
        # Last batch: 50 objects
        assert length(ops) in [50, 100]

        results = Enum.map(ops, fn _op ->
          %{"status" => "SUCCESS", "id" => UUID.uuid4()}
        end)

        {:ok, %{"results" => results}}
      end)

      assert {:ok, result} = Batch.create_objects(client, objects, batch_size: 100)
      assert result.success_count == 250
    end
  end

  describe "delete_objects/2" do
    test "deletes objects matching filter", %{client: client} do
      filter = %{
        "path" => ["category"],
        "operator" => "Equal",
        "valueText" => "deprecated"
      }

      Mock
      |> expect(:request, fn _client, :delete, "/v1/batch/objects", body, _opts ->
        assert body["match"]["class"] == "Article"
        assert body["match"]["where"] == filter

        {:ok, %{
          "results" => %{
            "matches" => 15,
            "successful" => 15,
            "failed" => 0
          }
        }}
      end)

      assert {:ok, result} = Batch.delete_objects(client, class: "Article", where: filter)
      assert result.successful == 15
      assert result.failed == 0
    end

    test "handles deletion errors", %{client: client} do
      filter = %{
        "path" => ["status"],
        "operator" => "Equal",
        "valueText" => "archived"
      }

      Mock
      |> expect(:request, fn _client, :delete, "/v1/batch/objects", _body, _opts ->
        {:ok, %{
          "results" => %{
            "matches" => 10,
            "successful" => 8,
            "failed" => 2
          }
        }}
      end)

      assert {:ok, result} = Batch.delete_objects(client, class: "Article", where: filter)
      assert result.successful == 8
      assert result.failed == 2
    end
  end

  describe "add_references/2" do
    test "adds references in batch", %{client: client} do
      references = [
        %{
          from_class: "Article",
          from_id: "article-uuid-1",
          from_property: "author",
          to_id: "author-uuid-1"
        },
        %{
          from_class: "Article",
          from_id: "article-uuid-2",
          from_property: "author",
          to_id: "author-uuid-2"
        }
      ]

      Mock
      |> expect(:batch_request, fn _client, ops, _opts ->
        assert length(ops) == 2

        {:ok, %{
          "results" => [
            %{"status" => "SUCCESS"},
            %{"status" => "SUCCESS"}
          ]
        }}
      end)

      assert {:ok, result} = Batch.add_references(client, references)
      assert result.success_count == 2
    end
  end
end
```

---

## Stub Implementation Strategy

### Phase 1: Create Module Structure with NotImplementedError

All modules should be created with proper structure but raise `NotImplementedError` on function calls.

```elixir
# lib/weaviate_ex/api/collections.ex
defmodule WeaviateEx.API.Collections do
  @moduledoc """
  Collection (schema) management API.

  Provides operations for creating, reading, updating, and deleting collections.
  """

  alias WeaviateEx.Client
  alias WeaviateEx.Error

  @doc """
  List all collections in the Weaviate instance.

  ## Examples

      {:ok, collections} = WeaviateEx.Collections.list(client)
      ["Article", "Author", "Category"]

  ## Returns

    * `{:ok, [String.t()]}` - List of collection names
    * `{:error, Error.t()}` - Error if request fails
  """
  @spec list(Client.t()) :: {:ok, [String.t()]} | {:error, Error.t()}
  def list(_client) do
    raise """
    NOT IMPLEMENTED: WeaviateEx.API.Collections.list/1

    This function needs to:
    1. Make GET request to /v1/schema
    2. Parse response and extract collection names
    3. Handle errors appropriately

    See test: test/weaviate_ex/api/collections_test.exs
    """
  end

  @doc """
  Get a specific collection configuration.

  ## Examples

      {:ok, config} = WeaviateEx.Collections.get(client, "Article")

  ## Returns

    * `{:ok, map()}` - Collection configuration
    * `{:error, Error.t()}` - Error if collection not found or request fails
  """
  @spec get(Client.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def get(_client, _collection_name) do
    raise """
    NOT IMPLEMENTED: WeaviateEx.API.Collections.get/2

    This function needs to:
    1. Make GET request to /v1/schema/:collection_name
    2. Parse and return collection configuration
    3. Handle not_found error if collection doesn't exist

    See test: test/weaviate_ex/api/collections_test.exs
    """
  end

  @doc """
  Create a new collection.

  ## Examples

      config = %{
        "class" => "Article",
        "vectorizer" => "text2vec-openai",
        "properties" => [
          %{"name" => "title", "dataType" => ["text"]}
        ]
      }

      {:ok, created} = WeaviateEx.Collections.create(client, config)

  ## Returns

    * `{:ok, map()}` - Created collection configuration
    * `{:error, Error.t()}` - Error if validation fails or collection exists
  """
  @spec create(Client.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def create(_client, _config) do
    raise """
    NOT IMPLEMENTED: WeaviateEx.API.Collections.create/2

    This function needs to:
    1. Validate collection configuration
    2. Make POST request to /v1/schema
    3. Return created collection config
    4. Handle validation and conflict errors

    See test: test/weaviate_ex/api/collections_test.exs
    """
  end

  @doc """
  Delete a collection.

  ## Examples

      {:ok, _} = WeaviateEx.Collections.delete(client, "Article")

  ## Returns

    * `{:ok, map()}` - Deletion confirmation
    * `{:error, Error.t()}` - Error if collection not found
  """
  @spec delete(Client.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def delete(_client, _collection_name) do
    raise """
    NOT IMPLEMENTED: WeaviateEx.API.Collections.delete/2

    This function needs to:
    1. Make DELETE request to /v1/schema/:collection_name
    2. Return success confirmation
    3. Handle not_found error

    See test: test/weaviate_ex/api/collections_test.exs
    """
  end

  # ... more stubbed functions
end
```

### Phase 2: Comprehensive Test Coverage

Every stubbed function must have corresponding tests that currently FAIL with NotImplementedError.

```elixir
# test/weaviate_ex/api/collections_test.exs
defmodule WeaviateEx.API.CollectionsTest do
  use ExUnit.Case, async: true
  import Mox
  import WeaviateEx.Test.Mocks

  alias WeaviateEx.API.Collections
  alias WeaviateEx.Protocol.Mock

  setup :verify_on_exit!
  setup :setup_test_client

  # This test will FAIL initially because list/1 raises NotImplementedError
  @tag :skip  # Remove this tag when implementing
  test "list/1 returns all collections", %{client: client} do
    expect_http_success(Mock, :get, "/v1/schema", %{
      "classes" => [
        %{"class" => "Article"},
        %{"class" => "Author"}
      ]
    })

    assert {:ok, collections} = Collections.list(client)
    assert length(collections) == 2
    assert "Article" in collections
  end

  # ... more tests
end
```

### Phase 3: Implementation Checklist

For each module, follow this process:

1. ✅ Create module with stubs (raises NotImplementedError)
2. ✅ Write comprehensive tests (initially skipped with `@tag :skip`)
3. ✅ Verify tests fail with NotImplementedError
4. ❌ Remove `@tag :skip` from one test
5. ❌ Implement minimal code to make that test pass
6. ❌ Refactor if needed
7. ❌ Repeat steps 4-6 for each test
8. ❌ All tests passing? Move to next module

---

## Test Fixtures and Factories

### Fixture Module

```elixir
# test/support/fixtures.ex
defmodule WeaviateEx.Test.Fixtures do
  @moduledoc """
  Static test data and fixtures.
  """

  def article_collection do
    %{
      "class" => "Article",
      "vectorizer" => "text2vec-openai",
      "properties" => [
        %{
          "name" => "title",
          "dataType" => ["text"],
          "tokenization" => "word"
        },
        %{
          "name" => "content",
          "dataType" => ["text"],
          "tokenization" => "word"
        },
        %{
          "name" => "publishedAt",
          "dataType" => ["date"]
        },
        %{
          "name" => "author",
          "dataType" => ["Author"]
        }
      ],
      "vectorIndexConfig" => %{
        "distance" => "cosine",
        "ef" => 100,
        "efConstruction" => 128,
        "maxConnections" => 64
      }
    }
  end

  def author_collection do
    %{
      "class" => "Author",
      "vectorizer" => "text2vec-openai",
      "properties" => [
        %{"name" => "name", "dataType" => ["text"]},
        %{"name" => "email", "dataType" => ["text"]}
      ]
    }
  end

  def article_object(attrs \\ %{}) do
    Map.merge(
      %{
        "title" => "Sample Article",
        "content" => "This is sample content for testing.",
        "publishedAt" => "2025-01-15T10:00:00Z"
      },
      attrs
    )
  end

  def article_with_vector(attrs \\ %{}) do
    object = article_object(attrs)
    vector = Enum.map(1..1536, fn _ -> :rand.uniform() end)

    Map.put(object, "vector", vector)
  end

  def graphql_response(class_name, objects) do
    %{
      "data" => %{
        "Get" => %{
          class_name => objects
        }
      }
    }
  end

  def graphql_error(message) do
    %{
      "errors" => [
        %{"message" => message}
      ]
    }
  end
end
```

### Factory Module

```elixir
# test/support/factory.ex
defmodule WeaviateEx.Test.Factory do
  @moduledoc """
  Factory for generating test data dynamically.
  """

  def build(:collection, attrs \\ []) do
    %{
      "class" => Keyword.get(attrs, :name, "TestCollection_#{unique_id()}"),
      "vectorizer" => Keyword.get(attrs, :vectorizer, "text2vec-openai"),
      "properties" => Keyword.get(attrs, :properties, [
        build(:property, name: "title")
      ])
    }
  end

  def build(:property, attrs \\ []) do
    %{
      "name" => Keyword.get(attrs, :name, "field_#{unique_id()}"),
      "dataType" => Keyword.get(attrs, :data_type, ["text"]),
      "tokenization" => Keyword.get(attrs, :tokenization, "word")
    }
  end

  def build(:object, attrs \\ []) do
    %{
      "class" => Keyword.get(attrs, :class, "TestCollection"),
      "properties" => Keyword.get(attrs, :properties, %{
        "title" => "Generated Title",
        "content" => "Generated content for testing purposes."
      }),
      "id" => Keyword.get(attrs, :id, UUID.uuid4())
    }
  end

  def build(:vector, attrs \\ []) do
    dimensions = Keyword.get(attrs, :dimensions, 1536)
    Enum.map(1..dimensions, fn _ -> :rand.uniform() end)
  end

  def build_list(type, count, attrs \\ []) do
    Enum.map(1..count, fn _ -> build(type, attrs) end)
  end

  defp unique_id do
    :crypto.strong_rand_bytes(4)
    |> Base.encode16(case: :lower)
  end
end
```

---

## Test Execution

### Running Tests

```bash
# Run all unit tests (default, fast)
mix test

# Run specific test file
mix test test/weaviate_ex/api/collections_test.exs

# Run specific test
mix test test/weaviate_ex/api/collections_test.exs:42

# Run with coverage
mix test --cover

# Run integration tests (requires live Weaviate)
mix test --include integration

# Run property-based tests
mix test --include property

# Run performance benchmarks
mix test --include performance

# Run all tests
mix test --include integration --include property --include performance

# Watch mode (requires mix_test_watch)
mix test.watch

# Verbose output
mix test --trace
```

### CI Configuration

```yaml
# .github/workflows/test.yml
name: Test

on: [push, pull_request]

jobs:
  unit_tests:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        elixir: ['1.18']
        otp: ['27']

    steps:
      - uses: actions/checkout@v2
      - uses: erlef/setup-beam@v1
        with:
          elixir-version: ${{ matrix.elixir }}
          otp-version: ${{ matrix.otp }}

      - name: Install dependencies
        run: mix deps.get

      - name: Run unit tests
        run: mix test --cover

      - name: Upload coverage
        uses: codecov/codecov-action@v2

  integration_tests:
    runs-on: ubuntu-latest

    services:
      weaviate:
        image: semitechnologies/weaviate:1.28.1
        ports:
          - 8080:8080
          - 50051:50051
        env:
          AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED: 'true'
          PERSISTENCE_DATA_PATH: '/var/lib/weaviate'

    steps:
      - uses: actions/checkout@v2
      - uses: erlef/setup-beam@v1

      - name: Install dependencies
        run: mix deps.get

      - name: Run integration tests
        run: mix test --include integration
        env:
          WEAVIATE_URL: http://localhost:8080
```

---

## Summary

This test design ensures:

1. **100% test coverage** - Every function has corresponding tests
2. **TDD approach** - Tests written before implementation
3. **Failing stubs** - All stubs raise NotImplementedError initially
4. **Isolated testing** - Mox mocks prevent external dependencies
5. **Comprehensive scenarios** - Happy paths, edge cases, and errors
6. **Maintainable** - Clear structure, factories, and helpers
7. **Fast feedback** - Unit tests run in <1 second
8. **Integration validation** - Separate suite for real Weaviate testing

Next step: Begin implementing the stubbed modules following the test suite!
