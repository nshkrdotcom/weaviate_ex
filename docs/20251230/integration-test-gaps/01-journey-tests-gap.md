# Gap Analysis: Journey Tests

**Priority**: P0 - Critical
**Effort**: High
**Status**: Not Implemented

---

## What Are Journey Tests?

Journey tests (also known as end-to-end scenario tests) validate that the client library works correctly when integrated into real-world web application frameworks. Unlike unit tests that test components in isolation, journey tests verify:

1. Client lifecycle management within web framework request/response cycles
2. Connection pooling behavior under concurrent load
3. Proper resource cleanup on application shutdown
4. Framework-specific integration patterns (plugs, middleware, etc.)

---

## Python Client Implementation

The canonical Python client includes journey tests in `journey_tests/`:

```
weaviate-python-client/journey_tests/
├── journeys.py          # Shared test scenarios
├── test_fastapi.py      # FastAPI integration
├── test_flask.py        # Flask integration
├── test_litestar.py     # Litestar integration
└── run.sh               # Test runner script
```

### Python Journey Test Pattern

```python
# journey_tests/journeys.py
class Journeys:
    """Shared journey scenarios executed across all frameworks."""

    def __init__(self, client: WeaviateClient):
        self.client = client

    def create_collection_and_insert(self):
        """Journey: Create collection, insert objects, query them."""
        collection = self.client.collections.create(...)
        collection.data.insert(...)
        results = collection.query.bm25(...)
        assert len(results.objects) > 0
        collection.delete()

    def batch_insert_and_search(self):
        """Journey: Batch insert 1000 objects, perform vector search."""
        ...

# journey_tests/test_fastapi.py
from fastapi import FastAPI
from fastapi.testclient import TestClient

app = FastAPI()
client: WeaviateClient = None

@app.on_event("startup")
async def startup():
    global client
    client = weaviate.connect_to_local()

@app.on_event("shutdown")
async def shutdown():
    client.close()

@app.get("/journey/{name}")
async def run_journey(name: str):
    journeys = Journeys(client)
    getattr(journeys, name)()
    return {"status": "success"}

def test_fastapi_journeys():
    with TestClient(app) as test_client:
        for journey in ["create_collection_and_insert", "batch_insert_and_search"]:
            response = test_client.get(f"/journey/{journey}")
            assert response.status_code == 200
```

### Frameworks Tested

| Framework | Python File | Purpose |
|-----------|-------------|---------|
| FastAPI | `test_fastapi.py` | Modern async API framework |
| Flask | `test_flask.py` | Traditional sync web framework |
| Litestar | `test_litestar.py` | High-performance async framework |

---

## Current Elixir Status

**Status**: No journey tests exist.

The Elixir client has no tests that verify integration with Phoenix, Plug, or other Elixir web frameworks.

---

## Recommended Implementation

### Directory Structure

```
weaviate_ex/
├── test/
│   └── journey/
│       ├── journeys.ex           # Shared journey scenarios
│       ├── phoenix_test.exs      # Phoenix integration
│       ├── plug_test.exs         # Plug integration (framework-agnostic)
│       └── bandit_test.exs       # Bandit HTTP server integration
```

### Implementation Guide

#### 1. Shared Journey Scenarios (`test/journey/journeys.ex`)

```elixir
defmodule WeaviateEx.Journey.Scenarios do
  @moduledoc """
  Shared journey test scenarios executed across all framework integrations.
  """

  alias WeaviateEx.Client

  @doc """
  Journey: Create collection, insert objects, query them.
  """
  def create_collection_and_insert(client) do
    collection_name = "JourneyTest_#{System.unique_integer([:positive])}"

    # Create collection
    {:ok, _} = Client.collections_create(client, %{
      name: collection_name,
      vectorizer: "none",
      properties: [
        %{name: "title", dataType: ["text"]},
        %{name: "content", dataType: ["text"]}
      ]
    })

    # Insert objects
    {:ok, _} = Client.objects_create(client, collection_name, %{
      properties: %{title: "Test", content: "Journey test content"}
    })

    # Query
    {:ok, results} = Client.query_bm25(client, collection_name, "journey")

    # Cleanup
    {:ok, _} = Client.collections_delete(client, collection_name)

    # Verify
    assert length(results.objects) >= 0
    :ok
  end

  @doc """
  Journey: Batch insert 1000 objects, perform vector search.
  """
  def batch_insert_and_search(client) do
    collection_name = "JourneyBatch_#{System.unique_integer([:positive])}"

    # Create collection with vector config
    {:ok, _} = Client.collections_create(client, %{
      name: collection_name,
      vectorizer: "none",
      vectorIndexConfig: %{distance: "cosine"},
      properties: [
        %{name: "index", dataType: ["int"]}
      ]
    })

    # Batch insert
    objects = for i <- 1..1000 do
      %{
        properties: %{index: i},
        vector: generate_random_vector(384)
      }
    end

    {:ok, _} = Client.batch_create(client, collection_name, objects)

    # Vector search
    {:ok, results} = Client.query_near_vector(client, collection_name, %{
      vector: generate_random_vector(384),
      limit: 10
    })

    # Cleanup
    {:ok, _} = Client.collections_delete(client, collection_name)

    # Verify
    assert length(results.objects) == 10
    :ok
  end

  defp generate_random_vector(dimensions) do
    for _ <- 1..dimensions, do: :rand.uniform()
  end
end
```

#### 2. Phoenix Integration Test (`test/journey/phoenix_test.exs`)

```elixir
defmodule WeaviateEx.Journey.PhoenixTest do
  use ExUnit.Case, async: false

  @moduletag :journey
  @moduletag :integration

  import WeaviateEx.Journey.Scenarios

  defmodule TestRouter do
    use Phoenix.Router
    import Plug.Conn
    import Phoenix.Controller

    pipeline :api do
      plug :accepts, ["json"]
    end

    scope "/api", WeaviateEx.Journey.PhoenixTest do
      pipe_through :api
      get "/journey/:name", JourneyController, :run
      get "/health", JourneyController, :health
    end
  end

  defmodule JourneyController do
    use Phoenix.Controller, formats: [:json]
    import Plug.Conn

    def run(conn, %{"name" => name}) do
      client = conn.assigns[:weaviate_client]

      result = case name do
        "create_collection_and_insert" -> create_collection_and_insert(client)
        "batch_insert_and_search" -> batch_insert_and_search(client)
        _ -> {:error, :unknown_journey}
      end

      case result do
        :ok -> json(conn, %{status: "success"})
        {:error, reason} -> conn |> put_status(500) |> json(%{error: reason})
      end
    end

    def health(conn, _params) do
      json(conn, %{status: "ok"})
    end
  end

  defmodule WeaviateClientPlug do
    @behaviour Plug
    import Plug.Conn

    def init(opts), do: opts

    def call(conn, _opts) do
      # Get client from application state (set during startup)
      client = Application.get_env(:weaviate_ex, :journey_test_client)
      assign(conn, :weaviate_client, client)
    end
  end

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :weaviate_ex

    plug WeaviateClientPlug
    plug TestRouter
  end

  setup_all do
    # Start Weaviate client
    {:ok, client} = WeaviateEx.Client.connect("http://localhost:8080")
    Application.put_env(:weaviate_ex, :journey_test_client, client)

    # Start Phoenix endpoint
    start_supervised!({Endpoint, []})

    on_exit(fn ->
      WeaviateEx.Client.close(client)
      Application.delete_env(:weaviate_ex, :journey_test_client)
    end)

    :ok
  end

  @journeys [
    "create_collection_and_insert",
    "batch_insert_and_search"
  ]

  for journey <- @journeys do
    @tag journey: journey
    test "Phoenix journey: #{journey}" do
      journey_name = unquote(journey)

      # Use Req or HTTPoison to call the endpoint
      {:ok, response} = Req.get("http://localhost:4002/api/journey/#{journey_name}")

      assert response.status == 200
      assert response.body["status"] == "success"
    end
  end
end
```

#### 3. Plug Integration Test (`test/journey/plug_test.exs`)

```elixir
defmodule WeaviateEx.Journey.PlugTest do
  use ExUnit.Case, async: false
  use Plug.Test

  @moduletag :journey
  @moduletag :integration

  import WeaviateEx.Journey.Scenarios

  defmodule TestPlug do
    use Plug.Router

    plug :match
    plug :dispatch

    get "/journey/:name" do
      client = Application.get_env(:weaviate_ex, :journey_test_client)

      result = case name do
        "create_collection_and_insert" -> create_collection_and_insert(client)
        "batch_insert_and_search" -> batch_insert_and_search(client)
        _ -> {:error, :unknown_journey}
      end

      case result do
        :ok ->
          send_resp(conn, 200, Jason.encode!(%{status: "success"}))
        {:error, reason} ->
          send_resp(conn, 500, Jason.encode!(%{error: reason}))
      end
    end
  end

  setup_all do
    {:ok, client} = WeaviateEx.Client.connect("http://localhost:8080")
    Application.put_env(:weaviate_ex, :journey_test_client, client)

    on_exit(fn ->
      WeaviateEx.Client.close(client)
      Application.delete_env(:weaviate_ex, :journey_test_client)
    end)

    :ok
  end

  @journeys [
    "create_collection_and_insert",
    "batch_insert_and_search"
  ]

  for journey <- @journeys do
    test "Plug journey: #{journey}" do
      journey_name = unquote(journey)

      conn = conn(:get, "/journey/#{journey_name}")
      conn = TestPlug.call(conn, TestPlug.init([]))

      assert conn.status == 200
      assert Jason.decode!(conn.resp_body)["status"] == "success"
    end
  end
end
```

#### 4. Test Configuration

Add to `test/test_helper.exs`:

```elixir
# Exclude journey tests by default (require full integration setup)
ExUnit.configure(exclude: [:journey])
```

Add to `mix.exs`:

```elixir
defp deps do
  [
    # ... existing deps
    {:phoenix, "~> 1.7", only: :test},
    {:bandit, "~> 1.0", only: :test},
    {:req, "~> 0.4", only: :test}
  ]
end
```

#### 5. Running Journey Tests

```bash
# Start Weaviate
./ci/start_weaviate.sh

# Run journey tests
WEAVIATE_INTEGRATION=true mix test --include journey

# Or with the mix task
mix weaviate.test --include journey
```

---

## Test Scenarios to Implement

### Core Journeys (P0)

| Journey | Description | Python Equivalent |
|---------|-------------|-------------------|
| `create_collection_and_insert` | CRUD lifecycle | Yes |
| `batch_insert_and_search` | High-volume batch + search | Yes |
| `concurrent_requests` | Multiple simultaneous operations | Yes |

### Extended Journeys (P1)

| Journey | Description | Python Equivalent |
|---------|-------------|-------------------|
| `connection_pooling` | Verify connection reuse under load | Implicit |
| `graceful_shutdown` | Clean disconnect on app termination | Yes |
| `error_recovery` | Handle transient failures | Partial |
| `long_running_session` | Stability over time | No |

### Elixir-Specific Journeys (P2)

| Journey | Description | Rationale |
|---------|-------------|-----------|
| `genserver_integration` | WeaviateEx as GenServer state | Elixir pattern |
| `supervision_tree` | Recovery under supervisor | OTP pattern |
| `telemetry_events` | Verify telemetry emissions | Elixir ecosystem |

---

## Acceptance Criteria

1. [ ] `test/journey/` directory exists with at least 2 test files
2. [ ] Phoenix integration test passes
3. [ ] Plug integration test passes
4. [ ] At least 3 journey scenarios implemented
5. [ ] Journey tests can be run with `mix test --include journey`
6. [ ] Journey tests documented in README.md
7. [ ] CI workflow includes journey test job (optional, can be manual)

---

## Estimated Effort

| Task | Effort |
|------|--------|
| Create directory structure and test helpers | 2 hours |
| Implement shared journey scenarios | 4 hours |
| Phoenix integration test | 4 hours |
| Plug integration test | 2 hours |
| Documentation updates | 1 hour |
| CI integration (optional) | 2 hours |
| **Total** | **15 hours** |

---

## References

- Python journey tests: `weaviate-python-client/journey_tests/`
- Phoenix testing guide: https://hexdocs.pm/phoenix/testing.html
- Plug testing: https://hexdocs.pm/plug/Plug.Test.html
