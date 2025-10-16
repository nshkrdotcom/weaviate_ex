# WeaviateEx v2.0 - Implementation Prompt

> Complete instructions for implementing WeaviateEx v2.0 with TDD using Mox

---

## 🎯 Mission

Implement a production-ready Elixir client for Weaviate with **100% feature parity** with weaviate-python-client v4, using **Test-Driven Development (TDD)** with **Mox** for mocking.

---

## 📚 Required Reading (IN ORDER)

Before starting, read these documents to understand the complete vision:

1. **DESIGN_SUMMARY.md** (START HERE)
   - Executive overview and key decisions
   - Quick navigation guide
   - ~10 minutes

2. **FEATURE_PARITY_CHECKLIST.md**
   - All 500+ features we need to implement
   - Current status and priorities
   - Use as reference throughout implementation
   - ~20 minutes to skim, refer back often

3. **ARCHITECTURE.md**
   - Complete directory structure
   - Module organization with code examples
   - Protocol layer design
   - Error handling patterns
   - ~30 minutes

4. **TEST_DESIGN.md**
   - TDD approach and test structure
   - Mox mocking strategy
   - Complete test examples
   - Stub implementation patterns
   - ~25 minutes

5. **IMPLEMENTATION_ROADMAP.md**
   - 22-week phase-by-phase plan
   - Feature breakdown per phase
   - Success criteria
   - ~15 minutes

**Total Reading Time: ~90 minutes**

---

## 🏗️ Implementation Approach

### Core Principles

1. **TDD Always** - Write test first, stub implementation, then implement
2. **One Feature at a Time** - Small, focused commits
3. **Mox for Everything** - Mock all external dependencies
4. **Make Tests Fail First** - Verify tests catch the issue
5. **Watch Tests Turn Green** - Implement minimal code to pass
6. **Refactor Confidently** - Tests ensure correctness

### The TDD Cycle

```
┌─────────────────────────────────────────┐
│  1. Write Test (RED)                    │
│     - Test describes expected behavior  │
│     - Test will fail initially          │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  2. Stub Implementation (RED)           │
│     - Create function signature         │
│     - Raise NotImplementedError         │
│     - Verify test fails correctly       │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  3. Implement (GREEN)                   │
│     - Write minimal code to pass test   │
│     - Run test and watch it pass        │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  4. Refactor (GREEN)                    │
│     - Improve code quality              │
│     - Tests ensure correctness          │
└──────────────┬──────────────────────────┘
               │
               ▼
          Next Feature
```

---

## 📋 Phase-by-Phase Implementation

---

## 🔧 PHASE 0: Foundation (Weeks 1-2)

### Goal
Set up test infrastructure, core client structure, and basic HTTP protocol.

### Step 0.1: Setup Test Infrastructure

**Create test support files:**

```bash
# Create test support directory
mkdir -p test/support

# Files to create:
touch test/support/mocks.ex
touch test/support/factory.ex
touch test/support/fixtures.ex
touch test/support/assertions.ex
```

**test/support/mocks.ex:**
```elixir
defmodule WeaviateEx.Test.Mocks do
  @moduledoc """
  Mock definitions using Mox for testing.
  """

  # Define all mocks
  Mox.defmock(WeaviateEx.Protocol.Mock, for: WeaviateEx.Protocol)
  Mox.defmock(WeaviateEx.HTTPClient.Mock, for: WeaviateEx.HTTPClient)

  @doc "Setup test client with mocked protocol"
  def setup_test_client(_context) do
    client = %WeaviateEx.Client{
      config: %WeaviateEx.Client.Config{
        base_url: "http://localhost:8080",
        grpc_host: "localhost",
        grpc_port: 50051,
        api_key: nil
      },
      protocol_impl: WeaviateEx.Protocol.Mock
    }

    {:ok, client: client}
  end

  @doc "Expect successful HTTP response"
  def expect_http_success(mock, method, path, response_body) do
    Mox.expect(mock, :request, fn _client, ^method, ^path, _body, _opts ->
      {:ok, response_body}
    end)
  end

  @doc "Expect HTTP error"
  def expect_http_error(mock, method, path, error_type) do
    Mox.expect(mock, :request, fn _client, ^method, ^path, _body, _opts ->
      {:error, %WeaviateEx.Error{type: error_type, message: "Test error"}}
    end)
  end
end
```

**test/support/factory.ex:**
```elixir
defmodule WeaviateEx.Test.Factory do
  @moduledoc """
  Factory for generating test data.
  """

  def build(:collection, attrs \\ []) do
    %{
      "class" => Keyword.get(attrs, :name, "TestCollection_#{unique_id()}"),
      "vectorizer" => Keyword.get(attrs, :vectorizer, "text2vec-openai"),
      "properties" => Keyword.get(attrs, :properties, [
        build(:property, name: "title", data_type: ["text"])
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
      "class" => Keyword.get(attrs, :class, "TestClass"),
      "properties" => Keyword.get(attrs, :properties, %{
        "title" => "Test Title"
      }),
      "id" => Keyword.get(attrs, :id, UUID.uuid4())
    }
  end

  def build_list(type, count, attrs \\ []) do
    Enum.map(1..count, fn _ -> build(type, attrs) end)
  end

  defp unique_id do
    :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
  end
end
```

**test/support/fixtures.ex:**
```elixir
defmodule WeaviateEx.Test.Fixtures do
  @moduledoc """
  Static test fixtures.
  """

  def article_collection do
    %{
      "class" => "Article",
      "vectorizer" => "text2vec-openai",
      "properties" => [
        %{"name" => "title", "dataType" => ["text"]},
        %{"name" => "content", "dataType" => ["text"]},
        %{"name" => "publishedAt", "dataType" => ["date"]}
      ],
      "vectorIndexConfig" => %{
        "distance" => "cosine",
        "ef" => 100
      }
    }
  end

  def article_object(attrs \\ %{}) do
    Map.merge(%{
      "title" => "Test Article",
      "content" => "Test content",
      "publishedAt" => "2025-01-15T10:00:00Z"
    }, attrs)
  end
end
```

**Update test/test_helper.exs:**
```elixir
ExUnit.start()

# Load support files
Code.require_file("support/mocks.ex", __DIR__)
Code.require_file("support/factory.ex", __DIR__)
Code.require_file("support/fixtures.ex", __DIR__)

# Configure Mox
Mox.defmock(WeaviateEx.Protocol.Mock, for: WeaviateEx.Protocol)

# Set global mode for async tests
Application.put_env(:weaviate_ex, :protocol_impl, WeaviateEx.Protocol.Mock)

# Exclude integration tests by default
ExUnit.configure(exclude: [:integration, :property, :performance])
```

### Step 0.2: Create Core Client Structure

**Create directory structure:**
```bash
mkdir -p lib/weaviate_ex/client
mkdir -p lib/weaviate_ex/protocol/http
mkdir -p lib/weaviate_ex/error
mkdir -p lib/weaviate_ex/types
```

**1. Create Protocol Behavior (lib/weaviate_ex/protocol.ex):**
```elixir
defmodule WeaviateEx.Protocol do
  @moduledoc """
  Protocol behavior for HTTP and gRPC implementations.
  """

  @type method :: :get | :post | :put | :patch | :delete | :head
  @type path :: String.t()
  @type body :: map() | nil
  @type opts :: keyword()
  @type response :: {:ok, map()} | {:error, WeaviateEx.Error.t()}

  @callback request(client :: term(), method(), path(), body(), opts()) :: response()
end
```

**2. Create Error Module (lib/weaviate_ex/error.ex):**
```elixir
defmodule WeaviateEx.Error do
  @moduledoc """
  Error struct for WeaviateEx operations.
  """

  @type t :: %__MODULE__{
    type: atom(),
    message: String.t(),
    details: map(),
    status_code: integer() | nil
  }

  defexception [:type, :message, :details, :status_code]

  def exception(opts) do
    type = Keyword.get(opts, :type, :unknown_error)
    message = Keyword.get(opts, :message, "An error occurred")
    details = Keyword.get(opts, :details, %{})
    status_code = Keyword.get(opts, :status_code)

    %__MODULE__{
      type: type,
      message: message,
      details: details,
      status_code: status_code
    }
  end

  @doc "Create error from HTTP status code"
  def from_status_code(code, body) when is_integer(code) do
    type = status_to_type(code)
    message = extract_message(body)

    %__MODULE__{
      type: type,
      message: message,
      details: body,
      status_code: code
    }
  end

  defp status_to_type(code) do
    case code do
      400 -> :bad_request
      401 -> :authentication_failed
      403 -> :forbidden
      404 -> :not_found
      409 -> :conflict
      422 -> :validation_error
      500 -> :server_error
      503 -> :service_unavailable
      _ -> :unknown_error
    end
  end

  defp extract_message(body) when is_map(body) do
    body["message"] || body["error"] || "Request failed"
  end
  defp extract_message(_), do: "Request failed"
end
```

**3. Create Client Config (lib/weaviate_ex/client/config.ex):**
```elixir
defmodule WeaviateEx.Client.Config do
  @moduledoc """
  Client configuration.
  """

  @type t :: %__MODULE__{
    base_url: String.t(),
    grpc_host: String.t() | nil,
    grpc_port: integer() | nil,
    api_key: String.t() | nil,
    timeout: integer(),
    protocol: :http | :grpc | :auto
  }

  defstruct [
    :base_url,
    :grpc_host,
    :grpc_port,
    :api_key,
    timeout: 60_000,
    protocol: :http
  ]

  @doc "Create config from keyword list"
  def new(opts \\ []) do
    %__MODULE__{
      base_url: Keyword.get(opts, :base_url, "http://localhost:8080"),
      grpc_host: Keyword.get(opts, :grpc_host),
      grpc_port: Keyword.get(opts, :grpc_port),
      api_key: Keyword.get(opts, :api_key),
      timeout: Keyword.get(opts, :timeout, 60_000),
      protocol: Keyword.get(opts, :protocol, :http)
    }
  end
end
```

**4. Create Client Module (lib/weaviate_ex/client.ex):**
```elixir
defmodule WeaviateEx.Client do
  @moduledoc """
  WeaviateEx client.
  """

  alias WeaviateEx.Client.Config
  alias WeaviateEx.Protocol

  @type t :: %__MODULE__{
    config: Config.t(),
    protocol_impl: module()
  }

  defstruct [:config, :protocol_impl]

  @doc """
  Create a new client.

  ## Examples

      {:ok, client} = WeaviateEx.Client.new(
        base_url: "http://localhost:8080",
        api_key: "secret-key"
      )
  """
  @spec new(keyword()) :: {:ok, t()}
  def new(opts \\ []) do
    config = Config.new(opts)
    protocol_impl = Keyword.get(opts, :protocol_impl, WeaviateEx.Protocol.HTTP.Client)

    client = %__MODULE__{
      config: config,
      protocol_impl: protocol_impl
    }

    {:ok, client}
  end

  @doc "Make a request using the configured protocol"
  @spec request(t(), Protocol.method(), Protocol.path(), Protocol.body(), Protocol.opts()) ::
    Protocol.response()
  def request(%__MODULE__{protocol_impl: impl} = client, method, path, body, opts) do
    impl.request(client, method, path, body, opts)
  end
end
```

**5. Create HTTP Client Stub (lib/weaviate_ex/protocol/http/client.ex):**
```elixir
defmodule WeaviateEx.Protocol.HTTP.Client do
  @moduledoc """
  HTTP protocol implementation using Finch.
  """

  @behaviour WeaviateEx.Protocol

  alias WeaviateEx.Client
  alias WeaviateEx.Error

  @impl true
  def request(%Client{} = _client, _method, _path, _body, _opts) do
    raise """
    NOT IMPLEMENTED: WeaviateEx.Protocol.HTTP.Client.request/5

    This function needs to:
    1. Build HTTP request with Finch
    2. Add authentication headers
    3. Execute request
    4. Parse response
    5. Handle errors

    See test: test/weaviate_ex/protocol/http/client_test.exs
    """
  end
end
```

### Step 0.3: Write First Test (Collections.list/1)

**Create test file (test/weaviate_ex/api/collections_test.exs):**
```elixir
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
          %{"class" => "Article"},
          %{"class" => "Author"}
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
      expect_http_error(Mock, :get, "/v1/schema", :connection_error)

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
    test "returns collection configuration", %{client: client} do
      expect_http_success(Mock, :get, "/v1/schema/Article", %{
        "class" => "Article",
        "vectorizer" => "text2vec-openai",
        "properties" => [
          %{"name" => "title", "dataType" => ["text"]}
        ]
      })

      assert {:ok, config} = Collections.get(client, "Article")
      assert config["class"] == "Article"
      assert config["vectorizer"] == "text2vec-openai"
    end

    test "handles not found error", %{client: client} do
      expect_http_error(Mock, :get, "/v1/schema/NonExistent", :not_found)

      assert {:error, %WeaviateEx.Error{type: :not_found}} =
        Collections.get(client, "NonExistent")
    end
  end

  # Add more tests for create, update, delete, etc.
end
```

### Step 0.4: Create Stubbed Collections Module

**Create module (lib/weaviate_ex/api/collections.ex):**
```elixir
defmodule WeaviateEx.API.Collections do
  @moduledoc """
  Collection (schema) management API.
  """

  alias WeaviateEx.Client
  alias WeaviateEx.Error

  @doc """
  List all collections.

  ## Examples

      {:ok, collections} = WeaviateEx.API.Collections.list(client)
      ["Article", "Author"]

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
    2. Parse response and extract collection names from "classes" array
    3. Return {:ok, list_of_names} or {:error, error}

    See test: test/weaviate_ex/api/collections_test.exs

    Example implementation:
    ```
    case Client.request(client, :get, "/v1/schema", nil, []) do
      {:ok, %{"classes" => classes}} ->
        names = Enum.map(classes, & &1["class"])
        {:ok, names}

      {:error, error} ->
        {:error, error}
    end
    ```
    """
  end

  @doc """
  Get a specific collection configuration.

  ## Examples

      {:ok, config} = WeaviateEx.API.Collections.get(client, "Article")

  ## Returns

    * `{:ok, map()}` - Collection configuration
    * `{:error, Error.t()}` - Error if not found
  """
  @spec get(Client.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def get(_client, _collection_name) do
    raise """
    NOT IMPLEMENTED: WeaviateEx.API.Collections.get/2

    This function needs to:
    1. Make GET request to /v1/schema/:collection_name
    2. Return collection configuration
    3. Handle not_found error

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
      {:ok, created} = WeaviateEx.API.Collections.create(client, config)

  ## Returns

    * `{:ok, map()}` - Created collection config
    * `{:error, Error.t()}` - Error if validation fails or exists
  """
  @spec create(Client.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def create(_client, _config) do
    raise """
    NOT IMPLEMENTED: WeaviateEx.API.Collections.create/2

    See test: test/weaviate_ex/api/collections_test.exs
    """
  end

  @doc "Delete a collection"
  @spec delete(Client.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def delete(_client, _collection_name) do
    raise """
    NOT IMPLEMENTED: WeaviateEx.API.Collections.delete/2

    See test: test/weaviate_ex/api/collections_test.exs
    """
  end

  @doc "Update a collection"
  @spec update(Client.t(), String.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def update(_client, _collection_name, _updates) do
    raise """
    NOT IMPLEMENTED: WeaviateEx.API.Collections.update/3

    See test: test/weaviate_ex/api/collections_test.exs
    """
  end

  @doc "Add property to collection"
  @spec add_property(Client.t(), String.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def add_property(_client, _collection_name, _property) do
    raise """
    NOT IMPLEMENTED: WeaviateEx.API.Collections.add_property/3

    See test: test/weaviate_ex/api/collections_test.exs
    """
  end

  @doc "Check if collection exists"
  @spec exists?(Client.t(), String.t()) :: {:ok, boolean()} | {:error, Error.t()}
  def exists?(_client, _collection_name) do
    raise """
    NOT IMPLEMENTED: WeaviateEx.API.Collections.exists?/2

    See test: test/weaviate_ex/api/collections_test.exs
    """
  end
end
```

### Step 0.5: Run Tests and Verify They Fail

```bash
# Run the test
mix test test/weaviate_ex/api/collections_test.exs

# Expected output: All tests fail with NotImplementedError
# This proves our test infrastructure works!
```

### Step 0.6: Implement One Function (Collections.list/1)

**Update lib/weaviate_ex/api/collections.ex:**
```elixir
def list(client) do
  case Client.request(client, :get, "/v1/schema", nil, []) do
    {:ok, %{"classes" => classes}} when is_list(classes) ->
      names = Enum.map(classes, & &1["class"])
      {:ok, names}

    {:ok, %{"classes" => _}} ->
      {:ok, []}

    {:ok, _} ->
      {:ok, []}

    {:error, error} ->
      {:error, error}
  end
end
```

### Step 0.7: Run Tests Again

```bash
mix test test/weaviate_ex/api/collections_test.exs::describe_list/1

# Expected: Tests for list/1 now PASS!
# Other tests still fail with NotImplementedError
```

### Step 0.8: Repeat for Each Function

Continue this cycle for `get/2`, `create/2`, `delete/2`, etc.

---

## 📦 PHASE 1: Core Features (Weeks 3-6)

After Phase 0 is complete, continue with Phase 1 features:

### Implementation Order

1. **Collections API** (complete all functions)
2. **Data Operations** (CRUD for objects)
3. **Query Builder** (basic queries)
4. **Filter System** (complete DSL)
5. **Batch Operations** (bulk operations)
6. **Authentication** (all 4 methods)

### For Each Module

1. **Create test file** with comprehensive tests
2. **Create module** with stubbed functions (NotImplementedError)
3. **Run tests** - verify they fail correctly
4. **Implement one function at a time**
5. **Watch tests turn green**
6. **Refactor** when all tests pass
7. **Move to next function**

---

## 🔄 Daily Workflow

### Morning Checklist

```bash
# 1. Pull latest changes
git pull

# 2. Run all tests
mix test

# 3. Check Dialyzer
mix dialyzer

# 4. Check Credo
mix credo
```

### Development Cycle

```bash
# 1. Create feature branch
git checkout -b feature/collections-api

# 2. Write test for one function
# Edit: test/weaviate_ex/api/collections_test.exs

# 3. Run test (should fail)
mix test test/weaviate_ex/api/collections_test.exs:42

# 4. Create stub or implement function
# Edit: lib/weaviate_ex/api/collections.ex

# 5. Run test (should pass)
mix test test/weaviate_ex/api/collections_test.exs:42

# 6. Run all tests
mix test

# 7. Format code
mix format

# 8. Commit
git add .
git commit -m "Implement Collections.list/1 with tests"

# 9. Repeat for next function
```

### End of Day

```bash
# 1. Run full test suite
mix test

# 2. Check coverage
mix test --cover

# 3. Push changes
git push origin feature/collections-api

# 4. Update FEATURE_PARITY_CHECKLIST.md with progress
```

---

## 🧪 Testing Commands

```bash
# Run all unit tests (default, fast)
mix test

# Run specific test file
mix test test/weaviate_ex/api/collections_test.exs

# Run specific test
mix test test/weaviate_ex/api/collections_test.exs:42

# Run with coverage
mix test --cover

# Run and watch for changes
mix test.watch

# Run integration tests (requires Weaviate running)
mix test --include integration

# Run all tests
mix test --include integration --include property

# Verbose output
mix test --trace

# Run tests in random order (find test dependencies)
mix test --seed 0
```

---

## 📝 Commit Message Convention

```
<type>: <subject>

<body>

<footer>
```

**Types:**
- `feat:` New feature
- `fix:` Bug fix
- `test:` Adding tests
- `refactor:` Code refactoring
- `docs:` Documentation
- `style:` Formatting
- `chore:` Maintenance

**Examples:**
```
feat: Implement Collections.list/1 with Mox tests

- Add comprehensive unit tests for list/1
- Stub implementation initially
- Implement with proper error handling
- All tests passing

Closes #1
```

```
test: Add test suite for Filter DSL

- Test all filter operators
- Test filter combinators (AND, OR, NOT)
- Test GraphQL conversion
- All tests initially failing with NotImplementedError

Part of Phase 1 - Filter System
```

---

## 🎯 Success Criteria for Each Phase

### Phase 0 Complete When:
- [ ] All test infrastructure set up
- [ ] Mox mocks working correctly
- [ ] Core client structure created
- [ ] Collections.list/1 fully implemented and tested
- [ ] Can run `mix test` successfully

### Phase 1 Complete When:
- [ ] All Collections API functions implemented
- [ ] All Data CRUD operations implemented
- [ ] Basic query builder working
- [ ] Complete filter system implemented
- [ ] Batch operations working
- [ ] All 4 auth methods implemented
- [ ] ~150+ tests passing

### Ongoing Quality Checks:
- [ ] `mix test` - all tests passing
- [ ] `mix test --cover` - coverage increasing
- [ ] `mix dialyzer` - no errors
- [ ] `mix credo` - no warnings
- [ ] `mix format --check-formatted` - code formatted

---

## 🚨 Important Reminders

### Always:
1. **Write the test first** - No exceptions
2. **Make it fail** - Verify test catches the problem
3. **Make it pass** - Minimal implementation
4. **Make it right** - Refactor with confidence
5. **Commit often** - Small, focused commits

### Never:
1. **Skip tests** - Every function needs tests
2. **Implement without test** - No cowboy coding
3. **Push failing tests** - All tests must pass
4. **Ignore Dialyzer** - Fix type issues immediately
5. **Leave NotImplementedError** - Complete what you start

---

## 📖 Quick Reference

### Key Files
- `FEATURE_PARITY_CHECKLIST.md` - Feature tracking
- `ARCHITECTURE.md` - Code design
- `TEST_DESIGN.md` - Testing patterns
- `IMPLEMENTATION_ROADMAP.md` - Phase breakdown

### Key Commands
- `mix test` - Run tests
- `mix test --cover` - Coverage report
- `mix dialyzer` - Type checking
- `mix credo` - Code analysis
- `mix format` - Format code

### Key Patterns
- `{:ok, result} | {:error, Error.t()}` - Return pattern
- `raise "NOT IMPLEMENTED..."` - Stub pattern
- `Mox.expect(Mock, :request, fn ... -> ... end)` - Mock pattern

---

## 🎬 START HERE

Ready to begin? Follow these steps:

### Step 1: Read All Documents (~90 minutes)
Read the required documents in order (listed at top).

### Step 2: Set Up Environment
```bash
# Install dependencies
mix deps.get

# Compile
mix compile

# Run existing tests
mix test
```

### Step 3: Start Phase 0
Begin with **Step 0.1** above and work through each step sequentially.

### Step 4: Follow TDD Cycle
For every single function:
1. Write test (RED)
2. Stub implementation (RED)
3. Implement (GREEN)
4. Refactor (GREEN)

### Step 5: Track Progress
Update `FEATURE_PARITY_CHECKLIST.md` as you complete features.

---

## ✅ Current Task: Phase 0 - Setup Test Infrastructure

**Your first task is Step 0.1: Setup Test Infrastructure**

Create these files in order:
1. `test/support/mocks.ex`
2. `test/support/factory.ex`
3. `test/support/fixtures.ex`
4. Update `test/test_helper.exs`

Then proceed to Step 0.2, 0.3, etc.

---

## 🆘 Need Help?

If you get stuck:
1. Re-read TEST_DESIGN.md for testing patterns
2. Re-read ARCHITECTURE.md for design guidance
3. Look at existing tests for examples
4. Check FEATURE_PARITY_CHECKLIST.md for requirements
5. Refer to Python client source code
6. Ask for clarification

---

## 🎉 Let's Build This!

You now have everything you need:
- ✅ Complete feature list (500+ features)
- ✅ Clean architecture design
- ✅ Comprehensive test strategy
- ✅ Phase-by-phase roadmap
- ✅ Detailed implementation instructions
- ✅ TDD workflow and patterns

**Start with Phase 0, Step 0.1. Write tests first. Make them fail. Make them pass. Repeat.**

Good luck! 🚀
