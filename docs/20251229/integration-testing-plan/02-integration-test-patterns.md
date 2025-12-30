# Integration Test Patterns from Python Client

## Python Client Test Architecture

The Python client uses a sophisticated test architecture with multiple test types. This document analyzes their patterns for adaptation to Elixir.

---

## Test Directory Structure

```
weaviate-python-client/
├── test/                    # Unit tests (25 files)
├── mock_tests/              # Mock-based integration (7 files)
├── integration/             # Live integration tests (35 files)
├── journey_tests/           # End-to-end workflows (6 files)
├── profiling/               # Performance tests (4 files)
└── integration_embedded/    # Embedded Weaviate (1 file)
```

---

## Key Pytest Fixtures (conftest.py)

### 1. Client Factory Pattern

The Python client uses a factory pattern to create test clients with automatic cleanup:

```python
# integration/conftest.py (simplified)

@pytest.fixture
def client_factory(request: SubRequest) -> Generator[ClientFactory, None, None]:
    """Factory that creates WeaviateClient instances with cleanup."""
    client_fixture: Optional[WeaviateClient] = None

    def _factory(
        headers: Optional[Dict[str, str]] = None,
        ports: Tuple[int, int] = (8080, 50051),
        auth_credentials: Optional[weaviate.auth.AuthCredentials] = None,
    ) -> WeaviateClient:
        nonlocal client_fixture
        if client_fixture is not None:
            return client_fixture

        client_fixture = weaviate.connect_to_local(
            headers=headers,
            grpc_port=ports[1],
            port=ports[0],
            additional_config=AdditionalConfig(timeout=(60, 120)),
            auth_credentials=auth_credentials,
        )
        return client_fixture

    try:
        yield _factory
    finally:
        if client_fixture is not None:
            client_fixture.close()
```

**Elixir Equivalent:**
```elixir
defmodule WeaviateEx.Test.ClientFactory do
  def create(opts \\ []) do
    port = Keyword.get(opts, :port, 8080)
    grpc_port = Keyword.get(opts, :grpc_port, 50051)
    headers = Keyword.get(opts, :headers, %{})
    auth = Keyword.get(opts, :auth, nil)

    {:ok, client} = WeaviateEx.Client.start_link(
      url: "http://localhost:#{port}",
      grpc_host: "localhost",
      grpc_port: grpc_port,
      headers: headers,
      auth: auth
    )
    client
  end

  def stop(client) do
    WeaviateEx.Client.stop(client)
  end
end

# In test setup:
setup do
  client = WeaviateEx.Test.ClientFactory.create()
  on_exit(fn -> WeaviateEx.Test.ClientFactory.stop(client) end)
  {:ok, client: client}
end
```

### 2. Collection Factory Pattern

Creates test collections with automatic cleanup and unique naming:

```python
@pytest.fixture
def collection_factory(
    request: SubRequest,
    client_factory: ClientFactory
) -> Generator[CollectionFactory, None, None]:
    """Creates collections with auto-cleanup."""
    name_fixtures: List[str] = []
    call_counter = 0
    client_fixture: Optional[WeaviateClient] = None

    def _factory(
        properties: Optional[List[Property]] = None,
        vectorizer_config: Optional[_VectorizerConfigCreate] = None,
        # ... many more options
    ) -> Collection[Any, Any]:
        nonlocal call_counter, client_fixture
        call_counter += 1

        # Generate unique name from test file + function + counter
        name_fixture = _sanitize_collection_name(
            f"{request.node.fspath.basename}_{request.node.name}_{call_counter}"
        )
        name_fixtures.append(name_fixture)

        client_fixture = client_factory()

        # Delete if exists (idempotent)
        client_fixture.collections.delete(name_fixture)

        # Create with config
        collection = client_fixture.collections.create(
            name=name_fixture,
            properties=properties,
            vectorizer_config=vectorizer_config or Configure.Vectorizer.none(),
            # ...
        )
        return collection

    try:
        yield _factory
    finally:
        # Cleanup: delete all created collections
        if client_fixture is not None:
            for name_fixture in name_fixtures:
                client_fixture.collections.delete(name_fixture)
```

**Elixir Equivalent:**
```elixir
defmodule WeaviateEx.Test.CollectionFactory do
  @doc """
  Creates test collections with unique names and automatic cleanup.
  """
  def create(client, test_context, opts \\ []) do
    # Generate unique name from test module and test name
    base_name = sanitize_name("#{test_context.module}_#{test_context.test}")
    counter = Process.get(:collection_counter, 0) + 1
    Process.put(:collection_counter, counter)

    name = "#{base_name}_#{counter}"

    # Track for cleanup
    collections = Process.get(:test_collections, [])
    Process.put(:test_collections, [name | collections])

    # Delete if exists
    WeaviateEx.Collections.delete(client, name)

    # Create with config
    properties = Keyword.get(opts, :properties, [])
    vectorizer = Keyword.get(opts, :vectorizer, nil)

    {:ok, collection} = WeaviateEx.Collections.create(client, name,
      properties: properties,
      vectorizer_config: vectorizer
    )

    {name, collection}
  end

  def cleanup(client) do
    collections = Process.get(:test_collections, [])
    for name <- collections do
      WeaviateEx.Collections.delete(client, name)
    end
    Process.put(:test_collections, [])
    Process.put(:collection_counter, 0)
  end

  defp sanitize_name(name) do
    name
    |> String.replace(~r/[^a-zA-Z0-9]/, "")
    |> String.slice(0, 50)
    |> String.capitalize()
  end
end

# Usage in tests:
setup %{client: client} = context do
  on_exit(fn -> WeaviateEx.Test.CollectionFactory.cleanup(client) end)
  {:ok, context}
end

test "creates objects", %{client: client} = context do
  {name, _collection} = WeaviateEx.Test.CollectionFactory.create(client, context,
    properties: [
      %{name: "title", data_type: [:text]},
      %{name: "count", data_type: [:int]}
    ]
  )

  # Test with collection...
end
```

### 3. Retry Helper

Handles transient HTTP errors with exponential backoff:

```python
def retry_on_http_error(
    func: Callable[[], T],
    error_codes: Tuple[int, ...] = (404,),
    retries: int = 3,
    delay: float = 0.5,
) -> T:
    """Retry a function on specific HTTP errors."""
    for attempt in range(retries):
        try:
            return func()
        except UnexpectedStatusCodeError as e:
            if e.status_code not in error_codes or attempt == retries - 1:
                raise
            time.sleep(delay * (2 ** attempt))  # Exponential backoff
    raise RuntimeError("Retry limit exceeded")
```

**Elixir Equivalent:**
```elixir
defmodule WeaviateEx.Test.Retry do
  def with_retry(func, opts \\ []) do
    error_codes = Keyword.get(opts, :error_codes, [404])
    max_retries = Keyword.get(opts, :retries, 3)
    initial_delay = Keyword.get(opts, :delay, 500)

    do_retry(func, error_codes, max_retries, initial_delay, 0)
  end

  defp do_retry(func, error_codes, max_retries, delay, attempt) do
    case func.() do
      {:ok, result} ->
        {:ok, result}

      {:error, %WeaviateEx.Error{status: status}} = error
          when status in error_codes and attempt < max_retries ->
        Process.sleep(delay * :math.pow(2, attempt) |> trunc())
        do_retry(func, error_codes, max_retries, delay, attempt + 1)

      {:error, _} = error ->
        error
    end
  end
end
```

---

## Test Categories and Patterns

### 1. Collection CRUD Tests

**Python Pattern:**
```python
def test_collection_lifecycle(collection_factory: CollectionFactory):
    """Test full collection lifecycle."""
    # Create
    collection = collection_factory(
        properties=[Property(name="Name", data_type=DataType.TEXT)]
    )

    # Read
    config = collection.config.get()
    assert config.name is not None

    # Update
    collection.config.update(description="Updated description")

    # Properties exist
    assert "Name" in [p.name for p in config.properties]
```

**Elixir Pattern:**
```elixir
@tag :integration
test "collection lifecycle", %{client: client} = context do
  {name, _} = CollectionFactory.create(client, context,
    properties: [%{name: "Name", data_type: [:text]}]
  )

  # Read
  {:ok, config} = WeaviateEx.Collections.get(client, name)
  assert config["class"] == name

  # Update
  {:ok, _} = WeaviateEx.Collections.update(client, name,
    description: "Updated description"
  )

  # Verify
  {:ok, updated} = WeaviateEx.Collections.get(client, name)
  assert updated["description"] == "Updated description"
end
```

### 2. Batch Operations Tests

**Python Pattern:**
```python
def test_batch_insert(collection_factory: CollectionFactory):
    collection = collection_factory(
        properties=[Property(name="name", data_type=DataType.TEXT)]
    )

    # Batch insert
    with collection.batch.dynamic() as batch:
        for i in range(100):
            batch.add_object(properties={"name": f"Object {i}"})

    # Verify
    result = collection.query.fetch_objects(limit=200)
    assert len(result.objects) == 100


def test_batch_rate_limited(collection_factory: CollectionFactory):
    collection = collection_factory(...)

    with collection.batch.rate_limit(requests_per_minute=60) as batch:
        for i in range(10):
            batch.add_object(properties={"name": f"Object {i}"})

    assert collection.aggregate.over_all(total_count=True).total_count == 10
```

**Elixir Pattern:**
```elixir
@tag :integration
test "batch insert with dynamic batching", %{client: client} = context do
  {name, _} = CollectionFactory.create(client, context,
    properties: [%{name: "name", data_type: [:text]}]
  )

  # Batch insert
  objects = for i <- 1..100 do
    %{properties: %{"name" => "Object #{i}"}}
  end

  {:ok, result} = WeaviateEx.Batch.insert_objects(client, name, objects,
    strategy: :dynamic
  )

  assert result.successful == 100
  assert result.failed == 0

  # Verify
  {:ok, query_result} = WeaviateEx.Query.get(client, name, limit: 200)
  assert length(query_result["objects"]) == 100
end

@tag :integration
test "batch insert with rate limiting", %{client: client} = context do
  {name, _} = CollectionFactory.create(client, context,
    properties: [%{name: "name", data_type: [:text]}]
  )

  objects = for i <- 1..10 do
    %{properties: %{"name" => "Object #{i}"}}
  end

  {:ok, _} = WeaviateEx.Batch.insert_objects(client, name, objects,
    strategy: :rate_limited,
    rate_limit: 60
  )

  {:ok, count} = WeaviateEx.Aggregate.count(client, name)
  assert count == 10
end
```

### 3. Query/Search Tests

**Python Pattern:**
```python
def test_hybrid_search(collection_factory: CollectionFactory):
    collection = collection_factory(
        properties=[Property(name="text", data_type=DataType.TEXT)],
        vectorizer_config=Configure.Vectorizer.text2vec_contextionary(),
    )

    # Insert data
    collection.data.insert_many([
        {"text": "The quick brown fox"},
        {"text": "A lazy dog sleeps"},
    ])

    # Hybrid search
    result = collection.query.hybrid(
        query="fox",
        alpha=0.5,
        limit=10,
    )

    assert len(result.objects) > 0
    assert "fox" in result.objects[0].properties["text"].lower()
```

**Elixir Pattern:**
```elixir
@tag :integration
test "hybrid search", %{client: client} = context do
  {name, _} = CollectionFactory.create(client, context,
    properties: [%{name: "text", data_type: [:text]}],
    vectorizer_config: %{text2vec_contextionary: %{}}
  )

  # Insert data
  objects = [
    %{properties: %{"text" => "The quick brown fox"}},
    %{properties: %{"text" => "A lazy dog sleeps"}}
  ]
  {:ok, _} = WeaviateEx.Batch.insert_objects(client, name, objects)

  # Wait for indexing
  Process.sleep(1000)

  # Hybrid search
  {:ok, result} = WeaviateEx.Query.hybrid(client, name,
    query: "fox",
    alpha: 0.5,
    limit: 10
  )

  assert length(result["objects"]) > 0
  assert String.contains?(
    String.downcase(result["objects"] |> hd() |> get_in(["properties", "text"])),
    "fox"
  )
end
```

### 4. Authentication Tests

**Python Pattern:**
```python
def test_api_key_auth():
    client = weaviate.connect_to_local(
        port=8092,
        auth_credentials=weaviate.auth.AuthApiKey("admin-key"),
    )

    try:
        # Should succeed with valid key
        collections = client.collections.list_all()
        assert collections is not None
    finally:
        client.close()


def test_rbac_permissions():
    admin_client = weaviate.connect_to_local(
        port=8092,
        auth_credentials=weaviate.auth.AuthApiKey("admin-key"),
    )

    # Create role
    admin_client.roles.create("reader-role", permissions=[
        weaviate.rbac.permissions.Collections.read(),
    ])

    # Assign to user
    admin_client.users.assign_role("readonly-user", "reader-role")

    # Test with limited user
    limited_client = weaviate.connect_to_local(
        port=8092,
        auth_credentials=weaviate.auth.AuthApiKey("readonly-key"),
    )

    # Should be able to read
    collections = limited_client.collections.list_all()

    # Should fail to create
    with pytest.raises(AuthorizationError):
        limited_client.collections.create("Forbidden")
```

**Elixir Pattern:**
```elixir
@tag :integration
@tag :rbac
test "API key authentication" do
  {:ok, client} = WeaviateEx.Client.start_link(
    url: "http://localhost:8092",
    auth: {:api_key, "admin-key"}
  )

  {:ok, collections} = WeaviateEx.Collections.list(client)
  assert is_list(collections)

  WeaviateEx.Client.stop(client)
end

@tag :integration
@tag :rbac
test "RBAC permissions enforcement" do
  # Admin client
  {:ok, admin} = WeaviateEx.Client.start_link(
    url: "http://localhost:8092",
    auth: {:api_key, "admin-key"}
  )

  # Create role
  {:ok, _} = WeaviateEx.RBAC.create_role(admin, "reader-role",
    permissions: [%{action: "read", collection: "*"}]
  )

  # Assign role
  {:ok, _} = WeaviateEx.Users.assign_role(admin, "readonly-user", "reader-role")

  # Limited client
  {:ok, limited} = WeaviateEx.Client.start_link(
    url: "http://localhost:8092",
    auth: {:api_key, "readonly-key"}
  )

  # Should read
  {:ok, _} = WeaviateEx.Collections.list(limited)

  # Should fail to create
  {:error, %{status: 403}} = WeaviateEx.Collections.create(limited, "Forbidden",
    properties: []
  )

  WeaviateEx.Client.stop(admin)
  WeaviateEx.Client.stop(limited)
end
```

### 5. Async Tests (Python's pytest-asyncio)

**Python Pattern:**
```python
@pytest.mark.asyncio
async def test_async_batch(async_collection_factory):
    collection = await async_collection_factory(
        properties=[Property(name="name", data_type=DataType.TEXT)]
    )

    # Async batch insert
    async with collection.batch.dynamic() as batch:
        for i in range(100):
            batch.add_object(properties={"name": f"Object {i}"})

    # Async query
    result = await collection.query.fetch_objects(limit=200)
    assert len(result.objects) == 100
```

**Elixir Pattern:**
```elixir
# Elixir doesn't need special async test markers -
# use Task for concurrent operations

@tag :integration
test "concurrent batch operations", %{client: client} = context do
  {name, _} = CollectionFactory.create(client, context,
    properties: [%{name: "name", data_type: [:text]}]
  )

  # Concurrent batch inserts
  tasks = for batch_num <- 1..5 do
    Task.async(fn ->
      objects = for i <- 1..20 do
        %{properties: %{"name" => "Batch#{batch_num}_Object#{i}"}}
      end
      WeaviateEx.Batch.insert_objects(client, name, objects)
    end)
  end

  results = Task.await_many(tasks, 30_000)
  assert Enum.all?(results, &match?({:ok, _}, &1))

  # Verify total count
  {:ok, count} = WeaviateEx.Aggregate.count(client, name)
  assert count == 100
end
```

---

## Journey Tests Pattern

Journey tests verify complete workflows with web framework integration:

**Python Pattern (FastAPI):**
```python
# journey_tests/test_fastapi.py

@asynccontextmanager
async def lifespan(app: FastAPI):
    journeys["async"] = await AsyncJourneys.use()
    journeys["sync"] = SyncJourneys.use()
    yield
    await journeys["async"].close()
    journeys["sync"].close()

app = FastAPI(lifespan=lifespan)

@app.get("/sync")
def sync_endpoint():
    return journeys["sync"].simple()

@app.get("/async")
async def async_endpoint():
    return await journeys["async"].simple()

def test_fastapi_sync():
    client = TestClient(app)
    response = client.get("/sync")
    assert response.status_code == 200
```

**Elixir Pattern (Phoenix/Plug):**
```elixir
# test/integration/journey/phoenix_test.exs

defmodule WeaviateEx.Journey.PhoenixTest do
  use ExUnit.Case, async: false
  use Plug.Test

  @moduletag :integration
  @moduletag :journey

  defmodule TestRouter do
    use Plug.Router

    plug :match
    plug :dispatch

    get "/sync" do
      client = conn.private[:weaviate_client]
      {:ok, result} = WeaviateEx.Journey.simple(client)
      send_resp(conn, 200, Jason.encode!(result))
    end
  end

  setup_all do
    {:ok, client} = WeaviateEx.Client.start_link(url: "http://localhost:8090")
    {:ok, client: client}
  end

  test "sync endpoint journey", %{client: client} do
    conn = conn(:get, "/sync")
           |> put_private(:weaviate_client, client)
           |> TestRouter.call([])

    assert conn.status == 200
    assert {:ok, result} = Jason.decode(conn.resp_body)
    assert is_list(result)
  end
end

defmodule WeaviateEx.Journey do
  @doc "Complete journey test workflow"
  def simple(client) do
    name = "JourneyTest#{:rand.uniform(999_999)}"

    # Create collection
    {:ok, _} = WeaviateEx.Collections.create(client, name,
      properties: [
        %{name: "name", data_type: [:text]},
        %{name: "age", data_type: [:int]}
      ]
    )

    # Batch insert
    objects = for i <- 1..100 do
      %{properties: %{"name" => "Person #{i}", "age" => i}}
    end
    {:ok, _} = WeaviateEx.Batch.insert_objects(client, name, objects)

    # Query
    {:ok, result} = WeaviateEx.Query.get(client, name, limit: 100)

    # Cleanup
    WeaviateEx.Collections.delete(client, name)

    {:ok, result["objects"]}
  end
end
```

---

## Test Markers and Grouping

### Python pytest markers:
```python
@pytest.mark.xdist_group(name="backup")  # Run sequentially
@pytest.mark.parametrize("version", ["1.27", "1.28"])
@pytest.mark.skip(reason="Feature not available")
@pytest.mark.asyncio  # Async test
```

### Elixir tags:
```elixir
@moduletag :integration    # Exclude from default run
@moduletag :rbac          # RBAC-specific tests
@moduletag :grpc          # gRPC-specific tests
@tag :slow                # Slow tests
@tag :skip                # Skip test

# Parametrized equivalent using for comprehension:
for version <- ["1.27", "1.28"] do
  @tag {:weaviate_version, version}
  test "works with version #{version}" do
    # ...
  end
end
```

---

## Environment Variable Patterns

### Python:
```python
api_key = os.environ.get("OPENAI_APIKEY")
if api_key is None:
    pytest.skip("No OpenAI API key found.")
```

### Elixir:
```elixir
setup do
  case System.get_env("OPENAI_APIKEY") do
    nil ->
      {:skip, "No OpenAI API key found"}
    api_key ->
      {:ok, api_key: api_key}
  end
end
```
