# Reference: Python Client Fixtures Analysis

This document provides a detailed reference of the Python client's test fixtures for use as a guide when implementing Elixir equivalents.

---

## Conftest File Locations

| File | Lines | Purpose |
|------|-------|---------|
| `integration/conftest.py` | 502 | Main integration test fixtures |
| `mock_tests/conftest.py` | 349 | Mock server fixtures |
| `profiling/conftest.py` | 86 | Performance test fixtures |
| `test/collection/conftest.py` | 20 | Unit test connection fixture |
| `weaviate/conftest.py` | 13 | pytest-xdist scheduler |

---

## Integration Test Fixtures

### client_factory

**Purpose**: Create and manage WeaviateClient instances

**Source**: `integration/conftest.py:88-112`

```python
@pytest.fixture
def client_factory(request: SubRequest) -> Generator[ClientFactory, None, None]:
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

**Key Features**:
- Lazy client creation (created on first call)
- Client reuse across test (singleton per test)
- Automatic cleanup in finally block
- Configurable headers, ports, auth

### collection_factory

**Purpose**: Create test collections with automatic cleanup

**Source**: `integration/conftest.py:115-192`

```python
@pytest.fixture
def collection_factory(
    request: SubRequest, client_factory: ClientFactory
) -> Generator[CollectionFactory, None, None]:
    name_fixtures: List[str] = []
    call_counter = 0
    client_fixture: Optional[WeaviateClient] = None

    def _factory(
        properties: Optional[List[Property]] = None,
        references: Optional[List[_ReferencePropertyBase]] = None,
        vectorizer_config: Optional[_VectorizerConfigCreate] = None,
        inverted_index_config: Optional[_InvertedIndexConfigCreate] = None,
        multi_tenancy_config: Optional[_MultiTenancyConfigCreate] = None,
        generative_config: Optional[_GenerativeConfigCreate] = None,
        replication_config: Optional[_ReplicationConfigCreate] = None,
        vector_index_config: Optional[_VectorIndexConfigCreate] = None,
        ports: Tuple[int, int] = (8080, 50051),
        headers: Optional[Dict[str, str]] = None,
        data_model_properties: Optional[Type[Properties]] = None,
        data_model_refs: Optional[Type[References]] = None,
        auth_credentials: Optional[weaviate.auth.AuthCredentials] = None,
        ttl_config: Optional[weaviate.classes.config.ObjectTTLConfig] = None,
    ) -> Collection[Any, Any]:
        nonlocal call_counter, client_fixture
        call_counter += 1

        # Generate unique name from test path
        name_fixture = _sanitize_collection_name(
            request.node.fspath.basename + "_" + request.node.name + "_" + str(call_counter)
        )
        name_fixtures.append(name_fixture)

        client_fixture = client_factory(
            headers=headers, ports=ports, auth_credentials=auth_credentials
        )

        # Delete if exists
        client_fixture.collections.delete(name_fixture)

        # Create with config
        collection = client_fixture.collections.create(
            name=name_fixture,
            properties=properties,
            references=references,
            vectorizer_config=vectorizer_config or Configure.Vectorizer.none(),
            inverted_index_config=inverted_index_config,
            multi_tenancy_config=multi_tenancy_config,
            generative_config=generative_config,
            replication_config=replication_config,
            vector_index_config=vector_index_config,
            data_model_properties=data_model_properties,
            data_model_refs=data_model_refs,
            ttl_config=ttl_config,
        )
        return collection

    try:
        yield _factory
    finally:
        if client_fixture is not None and name_fixtures is not None:
            for name_fixture in name_fixtures:
                client_fixture.collections.delete(name_fixture)
```

**Key Features**:
- Unique collection names per test
- Call counter for multiple collections per test
- Comprehensive configuration options
- Auto-delete existing collection before create
- Cleanup of all created collections

### async_client_factory

**Purpose**: Async version of client_factory

**Source**: `integration/conftest.py:234-257`

```python
@pytest_asyncio.fixture
async def async_client_factory(
    request: SubRequest,
) -> AsyncGenerator[AsyncClientFactory, None]:
    client_fixture: Optional[weaviate.WeaviateAsyncClient] = None

    async def _factory(
        headers: Optional[Dict[str, str]] = None,
        ports: Tuple[int, int] = (8080, 50051),
        auth_credentials: Optional[weaviate.auth.AuthCredentials] = None,
    ) -> weaviate.WeaviateAsyncClient:
        nonlocal client_fixture
        if client_fixture is not None:
            return client_fixture

        client_fixture = weaviate.use_async_with_local(
            port=ports[0],
            grpc_port=ports[1],
            headers=headers,
            additional_config=AdditionalConfig(timeout=(60, 120)),
            auth_credentials=auth_credentials,
        )
        await client_fixture.connect()
        return client_fixture

    try:
        yield _factory
    finally:
        if client_fixture is not None:
            await client_fixture.close()
```

### openai_collection

**Purpose**: Collection with OpenAI integration

**Source**: `integration/conftest.py:342-375`

```python
@pytest.fixture
def openai_collection(
    request: SubRequest,
) -> Generator[Collection[Any, Any], None, None]:
    api_key = os.environ.get("OPENAI_APIKEY")
    if api_key is None:
        pytest.skip("No OpenAI API key found in environment variables. Skipping test.")

    client = weaviate.connect_to_local(
        port=8086,  # OpenAI module instance
        grpc_port=50057,
        headers={"X-OpenAI-Api-Key": api_key},
        additional_config=AdditionalConfig(timeout=(60, 120)),
    )

    name = _sanitize_collection_name(
        request.node.fspath.basename + "_" + request.node.name
    )

    client.collections.delete(name)
    collection = client.collections.create(
        name=name,
        properties=[
            Property(name="text", data_type=DataType.TEXT),
        ],
        generative_config=Configure.Generative.openai(),
        vectorizer_config=Configure.Vectorizer.self_provided(),
    )

    try:
        yield collection
    finally:
        client.collections.delete(name)
        client.close()
```

**Key Features**:
- Skips test if API key not found
- Uses dedicated OpenAI instance (port 8086)
- Passes API key via headers
- Pre-configured for generative search

### retry_on_http_error

**Purpose**: Retry function for transient errors

**Source**: `integration/conftest.py:474-502`

```python
def retry_on_http_error(
    func: Callable[[], T],
    error_codes: Tuple[int, ...] = (404,),
    retries: int = 3,
    delay: float = 0.5,
) -> T:
    for attempt in range(retries):
        try:
            return func()
        except UnexpectedStatusCodeError as e:
            if e.status_code not in error_codes:
                raise
            if attempt == retries - 1:
                raise
            time.sleep(delay * (2 ** attempt))

    raise RuntimeError("Retry limit exceeded")
```

**Key Features**:
- Configurable error codes to retry
- Exponential backoff
- Configurable retry count
- Raises original error after exhaustion

---

## Mock Test Fixtures

### HTTP Server Mocks

**Source**: `mock_tests/conftest.py:50-105`

```python
@pytest.fixture
def ready_mock(httpserver: HTTPServer) -> HTTPServer:
    httpserver.expect_request("/v1/.well-known/ready").respond_with_json({})
    return httpserver


@pytest.fixture
def weaviate_mock(ready_mock: HTTPServer) -> HTTPServer:
    ready_mock.expect_request("/v1/meta").respond_with_json({"version": "1.34"})
    ready_mock.expect_request("/v1/nodes").respond_with_json(
        {"nodes": [{"gitHash": "ABC"}]}
    )
    return ready_mock


@pytest.fixture
def weaviate_no_auth_mock(weaviate_mock: HTTPServer) -> HTTPServer:
    weaviate_mock.expect_request(
        "/v1/.well-known/openid-configuration"
    ).respond_with_json({}, status=404)
    return weaviate_mock


@pytest.fixture
def weaviate_auth_mock(weaviate_mock: HTTPServer) -> HTTPServer:
    weaviate_mock.expect_request(
        "/v1/.well-known/openid-configuration"
    ).respond_with_json({
        "href": "http://127.0.0.1:23536/auth",
        "clientId": "DoesNotMatter",
    })
    weaviate_mock.expect_request("/auth").respond_with_json({
        "token_endpoint": "http://127.0.0.1:23536/token",
    })
    return weaviate_mock


@pytest.fixture
def weaviate_timeouts_mock(weaviate_no_auth_mock: HTTPServer) -> HTTPServer:
    weaviate_no_auth_mock.expect_request(
        re.compile(r"/v1/schema/.*")
    ).respond_with_handler(lambda req: Response(json.dumps({}), delay=1))

    weaviate_no_auth_mock.expect_request(
        re.compile(r"/v1/objects.*"), method="POST"
    ).respond_with_handler(lambda req: Response(json.dumps({}), delay=2))

    return weaviate_no_auth_mock
```

### gRPC Server Mock

**Source**: `mock_tests/conftest.py:108-130`

```python
@pytest.fixture
def start_grpc_server() -> Generator[grpc.Server, None, None]:
    server = grpc.server(ThreadPoolExecutor(max_workers=10))
    health = HealthServicer()
    health_pb2_grpc.add_HealthServicer_to_server(health, server)
    health.set("", health_pb2.HealthCheckResponse.SERVING)
    health.set("weaviate.v1.Weaviate", health_pb2.HealthCheckResponse.SERVING)

    server.add_insecure_port("127.0.0.1:23537")
    server.start()

    try:
        yield server
    finally:
        server.stop(0)
```

### Collection Mocks with Custom Services

**Source**: `mock_tests/conftest.py:158-250`

```python
@pytest.fixture
def tenants_collection(
    weaviate_no_auth_mock: HTTPServer, start_grpc_server: grpc.Server
) -> Generator[Collection[Any, Any], None, None]:
    # Add custom gRPC servicer
    class MockWeaviateService(weaviate_pb2_grpc.WeaviateServicer):
        def TenantsGet(self, request, context):
            return tenants_pb2.TenantsGetReply(
                took=10.0,
                tenants=[
                    tenants_pb2.Tenant(name=f"tenant{i}", activity_status=status)
                    for i, status in enumerate([
                        tenants_pb2.TENANT_ACTIVITY_STATUS_HOT,
                        tenants_pb2.TENANT_ACTIVITY_STATUS_COLD,
                        # ... more statuses
                    ])
                ],
            )

    weaviate_pb2_grpc.add_WeaviateServicer_to_server(
        MockWeaviateService(), start_grpc_server
    )

    # Setup mock schema response
    weaviate_no_auth_mock.expect_request(
        "/v1/schema/Test"
    ).respond_with_json(mock_class)

    client = weaviate.connect_to_local(port=23536, grpc_port=23537)
    try:
        yield client.collections.get("Test")
    finally:
        client.close()


@pytest.fixture
def retries(
    weaviate_no_auth_mock: HTTPServer, start_grpc_server: grpc.Server
) -> Generator[Tuple[Collection[Any, Any], MockRetriesWeaviateService], None, None]:
    service = MockRetriesWeaviateService()
    weaviate_pb2_grpc.add_WeaviateServicer_to_server(service, start_grpc_server)

    weaviate_no_auth_mock.expect_request("/v1/schema/Test").respond_with_json(mock_class)

    client = weaviate.connect_to_local(port=23536, grpc_port=23537)
    try:
        yield client.collections.get("Test"), service
    finally:
        client.close()


class MockRetriesWeaviateService(weaviate_pb2_grpc.WeaviateServicer):
    def __init__(self):
        self.call_count = 0

    def Search(self, request, context):
        self.call_count += 1
        if self.call_count == 1:
            context.abort(grpc.StatusCode.INTERNAL, "Internal error")
        elif self.call_count == 2:
            context.abort(grpc.StatusCode.UNAVAILABLE, "Unavailable")
        else:
            return search_get_pb2.SearchReply(
                took=0.1,
                results=[search_get_pb2.SearchResult(...)],
            )
```

---

## Helper Functions

### Collection Name Sanitization

**Source**: `integration/conftest.py:466-468`

```python
def _sanitize_collection_name(name: str) -> str:
    name = name.replace("[", "").replace("]", "").replace("-", "").replace(" ", "").replace(".", "")
    return name[0].upper() + name[1:]
```

**Elixir Equivalent**:
```elixir
def sanitize_collection_name(name) do
  name
  |> String.replace(~r/[\[\]\-\s\.]/, "")
  |> String.capitalize()
end
```

---

## Test Markers and Grouping

### xdist Grouping

**Source**: `integration/test_backup_v4.py`

```python
@pytest.mark.xdist_group(name="backup")
class TestBackup:
    # Tests run sequentially in same worker
```

**Elixir Equivalent**:
```elixir
# Use async: false for sequential tests
defmodule BackupTest do
  use ExUnit.Case, async: false
  @moduletag :backup
end
```

### Version Skipping

**Source**: Various integration tests

```python
@pytest.mark.skipif(
    weaviate_version < "1.28.0",
    reason="Feature requires Weaviate 1.28+"
)
def test_new_feature():
    pass
```

**Elixir Equivalent**:
```elixir
setup do
  {:ok, version} = WeaviateEx.Health.get_version(client)
  if Version.compare(version, "1.28.0") == :lt do
    {:skip, "Requires Weaviate 1.28+"}
  else
    :ok
  end
end
```

---

## Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `OPENAI_APIKEY` | OpenAI API key for generative tests | Skip test |
| `COHERE_APIKEY` | Cohere API key for reranking | Skip test |
| `OKTA_CLIENT_SECRET` | Okta OAuth testing | Skip test |
| `WCS_DUMMY_CI_PW` | WCS integration testing | Skip test |
| `WEAVIATE_VERSION` | Docker image version | `latest` |

---

## Port Assignments

| Instance | HTTP Port | gRPC Port | Purpose |
|----------|-----------|-----------|---------|
| Base | 8080 | 50051 | General testing |
| Okta CC | 8082 | - | Client credentials auth |
| Okta Users | 8083 | - | User auth |
| Backup | 8093 | 50065 | Backup testing |
| WCS | 8085 | 50056 | Cloud testing |
| Modules | 8086 | 50057 | OpenAI/Cohere |
| Cluster 1 | 8087 | 50058 | Cluster node 1 |
| Cluster 2 | 8088 | 50059 | Cluster node 2 |
| Cluster 3 | 8089 | 50060 | Cluster node 3 |
| Async | 8090 | 50061 | Async indexing |
| RBAC | 8092 | 50063 | RBAC testing |
| Mock HTTP | 23536 | - | Mock tests |
| Mock gRPC | - | 23537 | Mock tests |

---

## pytest.ini Configuration

```ini
[pytest]
addopts = -m 'not profiling' --benchmark-skip -l
markers =
    profiling: marks tests that can be profiled
asyncio_default_fixture_loop_scope = function
```

**Key Settings**:
- Excludes profiling tests by default
- Skips benchmarks
- Shows local variables on failure (`-l`)
- Function-scoped async event loops

---

## Type Definitions

### Factory Types

```python
ClientFactory = Callable[
    [
        Optional[Dict[str, str]],  # headers
        Tuple[int, int],           # ports (http, grpc)
        Optional[AuthCredentials], # auth
    ],
    WeaviateClient
]

CollectionFactory = Callable[
    [...],  # Many configuration options
    Collection[Any, Any]
]

AsyncClientFactory = Callable[
    [...],
    WeaviateAsyncClient
]
```

### Elixir Typespecs

```elixir
@type client_factory :: (keyword() -> {:ok, pid()} | {:error, term()})

@type collection_factory :: (
  client :: pid(),
  opts :: keyword()
) -> {String.t(), map()}
```
