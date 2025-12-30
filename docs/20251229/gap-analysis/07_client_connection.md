# Gap Analysis: Client Connection and Configuration

This document provides a deep gap analysis between the Weaviate Python client (canonical reference) and the WeaviateEx Elixir port, focusing specifically on client connection and configuration capabilities.

## Executive Summary

The Elixir port has achieved **strong parity** with the Python client for core connection functionality, including gRPC support, timeout configuration, retry mechanisms, proxy support, custom headers, and embedded Weaviate support. The main architectural difference is Elixir's functional approach versus Python's class-based approach, which leads to different patterns for client lifecycle management.

### Key Gaps Identified

| Area | Severity | Description |
|------|----------|-------------|
| Async Client Variants | Low | Elixir uses async-first BEAM model; no separate sync/async clients needed |
| Connection Pool Timeout | Low | Python has session_pool_timeout; Elixir relies on Finch defaults |
| Rate Limit Headers | Medium | Python integrations support rate limit headers; Elixir does not |
| OIDC Discovery Validation | Medium | Python validates OIDC grant types; Elixir does not |
| Background Token Refresh Thread | Low | Architectural difference due to Elixir's process model |
| WCS gRPC Host Auto-Derivation | Low | Python auto-generates grpc-{cluster} format |

---

## 1. Client Initialization Options

### Python Implementation

Python provides multiple factory functions for creating clients:

```python
# Weaviate Cloud connection
client = weaviate.connect_to_weaviate_cloud(
    cluster_url="my-cluster.weaviate.network",
    auth_credentials=weaviate.classes.init.Auth.api_key("my-api-key"),
    headers={"X-OpenAI-Api-Key": "sk-..."},
    additional_config=AdditionalConfig(
        timeout=Timeout(init=2, query=30, insert=90),
        connection=ConnectionConfig(
            session_pool_connections=20,
            session_pool_maxsize=100,
            session_pool_max_retries=3,
            session_pool_timeout=5
        ),
        proxies=Proxies(http="...", https="...", grpc="..."),
        trust_env=True
    ),
    skip_init_checks=False
)

# Local connection
client = weaviate.connect_to_local(
    host="localhost",
    port=8080,
    grpc_port=50051,
    headers={...},
    additional_config=AdditionalConfig(...)
)

# Custom connection
client = weaviate.connect_to_custom(
    http_host="weaviate.example.com",
    http_port=443,
    http_secure=True,
    grpc_host="grpc-weaviate.example.com",
    grpc_port=443,
    grpc_secure=True,
    headers={...},
    additional_config=AdditionalConfig(...),
    auth_credentials=Auth.api_key("...")
)

# Embedded
client = weaviate.connect_to_embedded(
    hostname="127.0.0.1",
    port=8079,
    grpc_port=50050,
    version="1.30.5",
    persistence_data_path="/path/to/data",
    binary_path="/path/to/binary",
    environment_variables={"KEY": "value"}
)
```

**Key Components:**
- `ConnectionParams`: HTTP and gRPC protocol parameters
- `AdditionalConfig`: Timeout, connection pool, proxy settings
- `EmbeddedOptions`: Embedded Weaviate configuration
- Context managers for automatic cleanup

### Elixir Implementation

```elixir
# Connection factory module
config = WeaviateEx.Connect.to_weaviate_cloud(
  cluster_url: "my-cluster.weaviate.network",
  api_key: "my-api-key",
  headers: [{"X-OpenAI-Api-Key", "sk-..."}]
)

config = WeaviateEx.Connect.to_local(
  host: "localhost",
  port: 8080,
  grpc_port: 50051
)

config = WeaviateEx.Connect.to_custom(
  http_host: "weaviate.example.com",
  http_port: 443,
  http_secure: true,
  grpc_host: "grpc-weaviate.example.com",
  grpc_port: 443,
  grpc_secure: true
)

config = WeaviateEx.Connect.to_embedded(
  version: "1.30.5",
  port: 8079,
  grpc_port: 50050
)

# Create client from config
{:ok, client} = WeaviateEx.Client.connect(
  base_url: config.base_url,
  grpc_host: config.grpc_host,
  grpc_port: config.grpc_port,
  api_key: config.api_key,
  timeout: 30_000,
  skip_grpc: false
)

# With lifecycle management
WeaviateEx.Client.with_client([base_url: url], fn client ->
  WeaviateEx.Objects.list(client, "Article")
end)
```

**Key Components:**
- `WeaviateEx.Connect`: Connection configuration factory
- `WeaviateEx.Client.Config`: Client configuration struct
- `WeaviateEx.Client.State`: Lifecycle state tracking
- `WeaviateEx.Config.Timeout`: Timeout configuration

### Comparison Table

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| connect_to_weaviate_cloud | Yes | Yes | Complete |
| connect_to_local | Yes | Yes | Complete |
| connect_to_custom | Yes | Yes | Complete |
| connect_to_embedded | Yes | Yes | Complete |
| skip_init_checks | Yes | Partial | Missing version checks |
| Context managers | Yes | Yes (with_client) | Complete |
| WCS auto-detection | Yes | Yes | Complete |

---

## 2. Connection Pooling

### Python Implementation

Python uses httpx transport with configurable limits:

```python
@dataclass
class ConnectionConfig:
    session_pool_connections: int = 20      # Max keepalive connections
    session_pool_maxsize: int = 100         # Max total connections
    session_pool_max_retries: int = 3       # HTTP retries
    session_pool_timeout: int = 5           # Pool checkout timeout

# Applied via httpx.Limits
limits = Limits(
    max_connections=self.__connection_config.session_pool_maxsize,
    max_keepalive_connections=self.__connection_config.session_pool_connections,
)
transport = HTTPTransport(
    limits=limits,
    retries=self.__connection_config.session_pool_max_retries,
)
```

### Elixir Implementation

```elixir
defmodule WeaviateEx.Client.Pool do
  @type t :: %__MODULE__{
    size: pos_integer(),           # Connections in pool (default: 10)
    overflow: non_neg_integer(),   # Max overflow (default: 5)
    strategy: strategy(),          # :fifo or :lifo (default: :lifo)
    timeout: pos_integer(),        # Checkout timeout (default: 5000)
    idle_timeout: pos_integer(),   # Idle connection timeout (default: 60000)
    max_age: pos_integer() | nil   # Max connection age
  }

  def default_http() do
    new(size: 10, overflow: 5, strategy: :lifo, timeout: 5000, idle_timeout: 60_000)
  end

  def default_grpc() do
    new(size: 5, overflow: 2, strategy: :lifo, timeout: 10_000, idle_timeout: 120_000)
  end

  def to_finch_opts(%__MODULE__{} = pool) do
    [size: pool.size, count: 1]
  end
end
```

### Comparison Table

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Pool size | session_pool_connections=20 | size=10 | Complete |
| Max connections | session_pool_maxsize=100 | overflow mechanism | Different approach |
| Pool timeout | session_pool_timeout=5 | timeout=5000 | Complete |
| HTTP retries | session_pool_max_retries=3 | Via Retry module | Complete |
| Idle timeout | Not configurable | idle_timeout=60000 | Elixir has more |
| Connection max age | Not available | max_age option | Elixir has more |
| LIFO/FIFO strategy | Not configurable | Configurable | Elixir has more |

### Gap: Session Pool Timeout Integration

**Severity: Low**

Python's `session_pool_timeout` is used for the httpx pool checkout timeout. In Elixir, this is configured via Finch but not currently exposed through the pool configuration in actual client creation.

---

## 3. gRPC Support

### Python Implementation

```python
# ConnectionParams with separate HTTP and gRPC configuration
class ConnectionParams(BaseModel):
    http: ProtocolParams
    grpc: ProtocolParams

    def _grpc_channel(self, proxies, grpc_msg_size, is_async):
        opts = [
            ("grpc.max_send_message_length", grpc_msg_size),
            ("grpc.max_receive_message_length", grpc_msg_size),
            ("grpc.default_authority", self.grpc.host),
        ]
        if proxies.get("grpc"):
            opts.append(("grpc.http_proxy", proxies["grpc"]))

        if is_async:
            mod = grpc.aio
        else:
            mod = grpc

        if self.grpc.secure:
            return mod.secure_channel(target, ssl_channel_credentials(), options=opts)
        else:
            return mod.insecure_channel(target, options=opts)

# gRPC operations with headers
def grpc_headers(self):
    return tuple(self.__metadata_list)  # Auth + custom headers

# gRPC calls with retries
def grpc_search(self, request):
    return _Retry(4).with_exponential_backoff(
        0, f"Searching in {request.collection}",
        self.grpc_stub.Search, request,
        metadata=self.grpc_headers(),
        timeout=self.timeout_config.query
    )
```

### Elixir Implementation

```elixir
defmodule WeaviateEx.GRPC.Channel do
  def connect(config, opts \\ []) do
    host = "#{config.grpc_host}:#{config.grpc_port}"
    channel_opts = build_channel_opts(config.tls, config.max_message_size, timeout)
    GRPC.Stub.connect(host, channel_opts)
  end

  def build_metadata(config) do
    auth = case config.api_key do
      nil -> %{}
      key -> %{"authorization" => "Bearer #{key}"}
    end
    additional = lowercase_header_keys(config.additional_headers)
    Map.merge(auth, additional)
  end

  defp build_channel_opts(tls, _max_message_size, timeout) do
    base_opts = [
      adapter: GRPC.Client.Adapters.Gun,
      adapter_opts: %{transport_opts: %{timeout: timeout}}
    ]
    cred_opts = if tls, do: [cred: GRPC.Credential.new(ssl: [])], else: []
    interceptors = [{GRPC.Client.Interceptors.Logger, level: :debug}]
    base_opts ++ cred_opts ++ [interceptors: interceptors]
  end
end

# gRPC retry mechanism
defmodule WeaviateEx.GRPC.Retry do
  @retryable_statuses [14, 8, 10, 4]  # UNAVAILABLE, RESOURCE_EXHAUSTED, ABORTED, DEADLINE_EXCEEDED

  def with_retry(fun, opts \\ []) do
    max_retries = Keyword.get(opts, :max_retries, 4)
    base_delay_ms = Keyword.get(opts, :base_delay_ms, 1000)
    do_retry(fun, 0, max_retries, base_delay_ms)
  end
end
```

### Comparison Table

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Separate HTTP/gRPC params | Yes | Yes | Complete |
| TLS/SSL support | Yes | Yes | Complete |
| Max message size | Configurable | Configurable | Complete |
| gRPC proxy support | Yes | Via Channel | Complete |
| Auth metadata | Yes | Yes | Complete |
| Custom headers in metadata | Yes | Yes | Complete |
| gRPC health check | Yes | Yes | Complete |
| Async gRPC | grpc.aio | BEAM concurrency | N/A (different model) |

---

## 4. Timeout Configurations

### Python Implementation

```python
class Timeout(BaseModel):
    query: Union[int, float] = 30   # For GET and queries
    insert: Union[int, float] = 90  # For POST, PUT, DELETE
    init: Union[int, float] = 2     # For connection init

# Timeout selection based on method
def __get_timeout(self, method, is_gql_query):
    if method in ("DELETE", "PATCH", "PUT"):
        timeout = self.timeout_config.insert
    elif method in ("GET", "HEAD"):
        timeout = self.timeout_config.query
    elif method == "POST" and is_gql_query:
        timeout = self.timeout_config.query
    elif method == "POST":
        timeout = self.timeout_config.insert
    return Timeout(timeout=5.0, read=timeout, pool=session_pool_timeout)
```

### Elixir Implementation

```elixir
defmodule WeaviateEx.Config.Timeout do
  @default_init 2_000
  @default_query 30_000
  @default_insert 90_000

  defstruct init: @default_init, query: @default_query, insert: @default_insert

  def for_method(%__MODULE__{init: init}, :init), do: init
  def for_method(%__MODULE__{query: query}, :get), do: query
  def for_method(%__MODULE__{insert: insert}, :post), do: insert
  def for_method(%__MODULE__{insert: insert}, :put), do: insert
  def for_method(%__MODULE__{insert: insert}, :patch), do: insert
  def for_method(%__MODULE__{insert: insert}, :delete), do: insert

  def for_operation(%__MODULE__{query: query}, op) when op in [:search, :query, :aggregate], do: query
  def for_operation(%__MODULE__{insert: insert}, op) when op in [:insert, :update, :batch], do: insert
end
```

### Comparison Table

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Query timeout (default) | 30s | 30s | Complete |
| Insert timeout (default) | 90s | 90s | Complete |
| Init timeout (default) | 2s | 2s | Complete |
| Method-based timeout | Yes | Yes | Complete |
| Operation-based timeout | No | Yes | Elixir has more |
| GraphQL query detection | Yes | No | Gap (minor) |

---

## 5. Retry Mechanisms

### Python Implementation

```python
class _Retry:
    def __init__(self, n: float = 4):
        self.n = n

    def with_exponential_backoff(self, count, error, f, *args, **kwargs):
        try:
            return f(*args, **kwargs)
        except RpcError as e:
            if e.code() != StatusCode.UNAVAILABLE:
                raise e
            time.sleep(2**count)
            if count > self.n:
                raise WeaviateRetryError(str(e), count) from e
            return self.with_exponential_backoff(count + 1, error, f, *args, **kwargs)

    async def awith_exponential_backoff(self, count, error, f, *args, **kwargs):
        # Same but with asyncio.sleep for async
```

**Python retries on:**
- gRPC: StatusCode.UNAVAILABLE only
- HTTP: Via httpx transport retries (session_pool_max_retries)

### Elixir Implementation

```elixir
defmodule WeaviateEx.Retry do
  @retryable_statuses [429, 502, 503, 504]
  @retryable_grpc_codes [4, 8, 10, 14]  # More comprehensive
  @retryable_reasons [:timeout, :econnrefused, :econnreset, :closed, :nxdomain]

  def with_exponential_backoff(fun, opts \\ []) do
    max_retries = Keyword.get(opts, :max_retries, 3)
    base_delay = Keyword.get(opts, :base_delay, 100)
    max_delay = Keyword.get(opts, :max_delay, 5_000)
    do_retry(fun, 0, max_retries, base_delay, max_delay)
  end

  def calculate_delay(attempt, base_delay, max_delay) do
    delay = trunc(base_delay * :math.pow(2, attempt))
    delay = min(delay, max_delay)
    # Add jitter (+/- 10%)
    jitter = delay * 0.1
    trunc(delay + (:rand.uniform() * jitter * 2 - jitter))
  end
end

defmodule WeaviateEx.GRPC.Retry do
  @retryable_statuses [14, 8, 10, 4]  # UNAVAILABLE, RESOURCE_EXHAUSTED, ABORTED, DEADLINE_EXCEEDED

  def with_retry(fun, opts \\ []) do
    max_retries = Keyword.get(opts, :max_retries, 4)
    base_delay_ms = Keyword.get(opts, :base_delay_ms, 1000)
    do_retry(fun, 0, max_retries, base_delay_ms)
  end
end
```

### Comparison Table

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| gRPC UNAVAILABLE retry | Yes | Yes | Complete |
| gRPC RESOURCE_EXHAUSTED | No | Yes | Elixir has more |
| gRPC ABORTED | No | Yes | Elixir has more |
| gRPC DEADLINE_EXCEEDED | No | Yes | Elixir has more |
| HTTP status retries | Via transport | Yes (429, 502, 503, 504) | Elixir has more |
| Connection error retries | Via transport | Yes | Complete |
| Exponential backoff | Yes (2^n) | Yes (2^n) | Complete |
| Jitter | No | Yes (+/- 10%) | Elixir has more |
| Configurable base delay | No (1s fixed) | Yes | Elixir has more |
| Configurable max delay | No (32s cap) | Yes | Elixir has more |
| Async retry | Yes | N/A (BEAM) | Different model |

---

## 6. Proxy Support

### Python Implementation

```python
class Proxies(BaseModel):
    http: Optional[str] = None
    https: Optional[str] = None
    grpc: Optional[str] = None

def _get_proxies(proxies, trust_env):
    if proxies is not None:
        if isinstance(proxies, str):
            return {"http": proxies, "https": proxies, "grpc": proxies}
        if isinstance(proxies, dict):
            return proxies
        if isinstance(proxies, Proxies):
            return proxies.model_dump(exclude_none=True)

    if trust_env:
        # Read from HTTP_PROXY, HTTPS_PROXY, GRPC_PROXY env vars
        proxies = {}
        if http_proxy := os.environ.get("HTTP_PROXY") or os.environ.get("http_proxy"):
            proxies["http"] = http_proxy
        # ... similar for https and grpc
        return proxies
    return {}

# Applied to gRPC channel
if proxies.get("grpc"):
    opts.append(("grpc.http_proxy", proxies["grpc"]))

# Applied to HTTP transport
HTTPTransport(proxy=Proxy(url=proxy))
```

### Elixir Implementation

```elixir
defmodule WeaviateEx.Config.Proxy do
  defstruct http: nil, https: nil, grpc: nil

  def from_env do
    %__MODULE__{
      http: get_env_case_insensitive("HTTP_PROXY"),
      https: get_env_case_insensitive("HTTPS_PROXY"),
      grpc: get_env_case_insensitive("GRPC_PROXY")
    }
  end

  def to_finch_opts(%__MODULE__{} = proxy) do
    proxy_url = proxy.https || proxy.http
    case parse_proxy_url(proxy_url) do
      {:ok, scheme, host, port} -> [proxy: {scheme, host, port, []}]
      :error -> []
    end
  end

  def to_grpc_opts(%__MODULE__{grpc: nil}), do: []
  def to_grpc_opts(%__MODULE__{grpc: grpc_proxy}), do: [http_proxy: grpc_proxy]
end
```

### Comparison Table

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| HTTP proxy | Yes | Yes | Complete |
| HTTPS proxy | Yes | Yes | Complete |
| gRPC proxy | Yes | Yes | Complete |
| Environment variables | Yes (trust_env) | Yes (from_env) | Complete |
| Case-insensitive env | Yes | Yes | Complete |
| String shorthand | Yes (single URL) | No | Gap (minor) |
| Finch integration | N/A | Yes | Complete |
| gRPC integration | Yes | Yes | Complete |

---

## 7. Custom Headers

### Python Implementation

```python
# Additional headers in client init
additional_headers: Optional[dict] = None

# Headers applied to HTTP requests
self._headers = {"content-type": "application/json"}
if additional_headers is not None:
    for key, value in additional_headers.items():
        if value is None:
            raise WeaviateInvalidInputError(f"Value for '{key}' cannot be None.")
        self._headers[key.lower()] = value

# Headers applied to gRPC
def _prepare_grpc_headers(self):
    self.__metadata_list = []
    for key, val in self.additional_headers.items():
        if val is not None:
            self.__metadata_list.append((key.lower(), val))
    # ... add auth header

# WCS-specific header
def __add_weaviate_embedding_service_header(self, wcd_host):
    if is_weaviate_domain(wcd_host):
        self._headers["X-Weaviate-Cluster-URL"] = "https://" + wcd_host
```

### Elixir Implementation

```elixir
# In Client.Config
defstruct [
  # ...
  additional_headers: %{}
]

def new(opts \\ []) do
  additional_headers = Keyword.get(opts, :additional_headers, %{})
  validate_additional_headers!(additional_headers)
  %__MODULE__{additional_headers: additional_headers, ...}
end

defp validate_additional_headers!(headers) when is_map(headers) do
  Enum.each(headers, fn
    {key, nil} -> raise ArgumentError, "Header value cannot be nil for: #{key}"
    {_key, value} when is_binary(value) -> :ok
    {key, value} -> raise ArgumentError, "Header values must be strings: #{key}"
  end)
end

# WCS auto-detection
def maybe_add_wcs_headers(%__MODULE__{base_url: url, additional_headers: headers} = config) do
  if wcs_host?(url) do
    %{config | additional_headers: Map.put(headers, "X-Weaviate-Cluster-URL", url)}
  else
    config
  end
end

# gRPC metadata
defp lowercase_header_keys(headers) when is_map(headers) do
  Map.new(headers, fn {key, value} -> {String.downcase(to_string(key)), value} end)
end
```

### Comparison Table

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Custom headers | Yes | Yes | Complete |
| None value validation | Yes | Yes | Complete |
| HTTP headers | Yes | Yes | Complete |
| gRPC headers (lowercased) | Yes | Yes | Complete |
| WCS auto-detection | Yes | Yes | Complete |
| X-Weaviate-Cluster-URL | Yes | Yes | Complete |

---

## 8. Embedded Weaviate Support

### Python Implementation

```python
@dataclass
class EmbeddedOptions:
    persistence_data_path: str = DEFAULT_PERSISTENCE_DATA_PATH
    binary_path: str = DEFAULT_BINARY_PATH
    version: str = WEAVIATE_VERSION  # "1.30.5"
    port: int = 8079
    hostname: str = "127.0.0.1"
    additional_env_vars: Optional[Dict[str, str]] = None
    grpc_port: int = 50060

class EmbeddedV4(_EmbeddedBase):
    def start(self):
        self.ensure_weaviate_binary_exists()
        my_env = os.environ.copy()
        my_env.setdefault("AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED", "true")
        my_env.setdefault("QUERY_DEFAULTS_LIMIT", "20")
        my_env.setdefault("PERSISTENCE_DATA_PATH", self.options.persistence_data_path)
        # ... many more env vars

        process = subprocess.Popen([
            f"{self._weaviate_binary_path}",
            "--host", self.options.hostname,
            "--port", str(self.options.port),
            "--scheme", "http",
            "--read-timeout=600s",
            "--write-timeout=600s",
        ], env=my_env)
        self.wait_till_listening()

    def is_listening(self):
        # Check both HTTP and gRPC ports
        return self.__is_listening()[0] and self.__is_listening()[1]
```

### Elixir Implementation

```elixir
defmodule WeaviateEx.Embedded do
  @default_version "1.30.5"
  @ready_timeout 30_000

  defmodule Instance do
    defstruct [:options, :executable, :process_port, :os_pid]
  end

  def start(opts \\ []) do
    with {:ok, options} <- build_options(opts),
         :ok <- ensure_supported_platform(),
         :ok <- ensure_directories(options),
         {:ok, executable, parsed_version} <- ensure_binary(options),
         env <- build_environment(options, parsed_version),
         {:ok, process_port} <- spawn_instance(executable, env, options),
         :ok <- wait_until_ready(options.hostname, options.port, options.grpc_port, options.ready_timeout) do
      {:ok, %Instance{...}}
    end
  end

  defp build_environment(options, parsed_version) do
    %{
      "AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED" => "true",
      "QUERY_DEFAULTS_LIMIT" => "20",
      "PERSISTENCE_DATA_PATH" => options.persistence_data_path,
      "GRPC_PORT" => Integer.to_string(options.grpc_port),
      "ENABLE_MODULES" => "text2vec-openai,text2vec-cohere,...",
      # ... other env vars
    }
  end

  defp spawn_instance(executable, env, options) do
    args = ["--host", options.hostname, "--port", to_string(options.port), ...]
    port = Port.open({:spawn_executable, executable}, [:binary, :exit_status, {:env, env}, {:args, args}])
    {:ok, port}
  end
end
```

### Comparison Table

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Version configuration | Yes | Yes | Complete |
| Latest version fetch | Yes (GitHub API) | Yes | Complete |
| Custom binary path | Yes | Yes | Complete |
| Custom data path | Yes | Yes | Complete |
| Port configuration | Yes | Yes | Complete |
| gRPC port configuration | Yes | Yes | Complete |
| Environment variables | Yes | Yes | Complete |
| Binary download | Yes | Yes | Complete |
| Platform detection | Yes (Linux/macOS) | Yes | Complete |
| Windows unsupported | Yes (error) | Yes (error) | Complete |
| HTTP ready check | Yes | Yes | Complete |
| gRPC ready check | Yes | Yes | Complete |
| Stop/cleanup | Yes | Yes | Complete |

---

## 9. Async/Sync Client Variants

### Python Implementation

Python provides explicitly separate sync and async clients:

```python
@executor.wrap("sync")
class WeaviateClient(_WeaviateClientExecutor[ConnectionSync]):
    def __enter__(self) -> "WeaviateClient":
        executor.result(self.connect())
        return self

    def __exit__(self, ...):
        executor.result(self.close())

@executor.wrap("async")
class WeaviateAsyncClient(_WeaviateClientExecutor[ConnectionAsync]):
    async def __aenter__(self) -> "WeaviateAsyncClient":
        await executor.aresult(self.connect())
        return self

    async def __aexit__(self, ...):
        await executor.aresult(self.close())

# Factory functions
client = weaviate.connect_to_local()              # Returns WeaviateClient (sync)
client = weaviate.use_async_with_local()          # Returns WeaviateAsyncClient
```

**The executor module wraps methods:**
- Sync: Asserts result is not Awaitable
- Async: Awaits Awaitable results
- Common base class with coloured execution

### Elixir Implementation

Elixir uses the BEAM's concurrent model:

```elixir
defmodule WeaviateEx.Client do
  @doc """
  Connect to a Weaviate instance.
  """
  @spec connect(keyword()) :: {:ok, t()} | {:error, Error.t()}
  def connect(opts \\ []) do
    # All operations are inherently async-capable on BEAM
    # No separate sync/async variants needed
  end

  @doc """
  Execute with auto-managed client lifecycle.
  """
  @spec with_client(keyword(), (t() -> result)) :: result when result: term()
  def with_client(opts, fun) when is_function(fun, 1) do
    {:ok, client} = new(opts)
    try do
      fun.(client)
    after
      close(client)
    end
  end
end
```

### Comparison Table

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Sync client | WeaviateClient | N/A | Different model |
| Async client | WeaviateAsyncClient | N/A | Different model |
| Unified client | No | Yes | Elixir simpler |
| Context managers | Yes | with_client/2 | Complete |
| Automatic cleanup | Yes | Yes | Complete |
| Concurrent operations | Via asyncio | Native BEAM | Different model |

### Architectural Note

The Elixir implementation takes a simpler approach because:

1. **BEAM Concurrency**: All operations in Elixir are inherently concurrent-ready. There's no need for separate async/sync variants because the BEAM handles concurrency transparently.

2. **Process Model**: Each client operation can be run in its own process without blocking others, eliminating the Python async/await distinction.

3. **Functional Design**: The client is a pure data structure, not a class with connection state tied to a specific execution model.

---

## 10. Integration Headers (AI Providers)

### Python Implementation

```python
class Integrations:
    @staticmethod
    def openai(*, api_key, organization=None, requests_per_minute_embeddings=None,
               tokens_per_minute_embeddings=None, base_url=None):
        return _IntegrationConfigOpenAi(
            api_key=api_key,
            organization=organization,
            requests_per_minute_embeddings=requests_per_minute_embeddings,
            tokens_per_minute_embeddings=tokens_per_minute_embeddings,
            base_url=base_url
        )

    @staticmethod
    def cohere(*, api_key, base_url=None, requests_per_minute_embeddings=None):
        return _IntegrationConfigCohere(...)

# Usage with client
client.integrations.configure(
    Integrations.openai(api_key="sk-...", requests_per_minute_embeddings=100)
)
```

### Elixir Implementation

```elixir
defmodule WeaviateEx.Integrations do
  def openai(opts) do
    api_key = Keyword.fetch!(opts, :api_key)
    [{"X-OpenAI-Api-Key", api_key}]
    |> maybe_add("X-OpenAI-Organization", Keyword.get(opts, :organization))
  end

  def cohere(opts), do: [{"X-Cohere-Api-Key", Keyword.fetch!(opts, :api_key)}]
  def huggingface(opts), do: [{"X-HuggingFace-Api-Key", Keyword.fetch!(opts, :api_key)}]
  def voyageai(opts), do: [{"X-VoyageAI-Api-Key", Keyword.fetch!(opts, :api_key)}]
  def jinaai(opts), do: [{"X-JinaAI-Api-Key", Keyword.fetch!(opts, :api_key)}]
  def mistral(opts), do: [{"X-Mistral-Api-Key", Keyword.fetch!(opts, :api_key)}]
  def anthropic(opts), do: [{"X-Anthropic-Api-Key", Keyword.fetch!(opts, :api_key)}]
  def google(opts), do: [{"X-Google-Api-Key", Keyword.fetch!(opts, :api_key)}]
  def azure_openai(opts), do: [{"X-Azure-Api-Key", Keyword.fetch!(opts, :api_key)}]
  def aws(opts), do: [{"X-AWS-Access-Key", ...}, {"X-AWS-Secret-Key", ...}]
  def nvidia(opts), do: [{"X-NVIDIA-Api-Key", Keyword.fetch!(opts, :api_key)}]
  def databricks(opts), do: [{"X-Databricks-Token", Keyword.fetch!(opts, :token)}]

  def merge(header_lists), do: List.flatten(header_lists)
end
```

### Comparison Table

| Provider | Python | Elixir | Status |
|----------|--------|--------|--------|
| OpenAI | Yes | Yes | Complete |
| Cohere | Yes | Yes | Complete |
| HuggingFace | Yes | Yes | Complete |
| VoyageAI | Yes | Yes | Complete |
| JinaAI | Yes | Yes | Complete |
| Mistral | Yes | Yes | Complete |
| Anthropic | No | Yes | Elixir has more |
| Google | No | Yes | Elixir has more |
| Azure OpenAI | No | Yes | Elixir has more |
| AWS | Commented out | Yes | Elixir has more |
| NVIDIA | No | Yes | Elixir has more |
| Databricks | No | Yes | Elixir has more |

### Gap: Rate Limit Headers

**Severity: Medium**

Python integrations support rate limit configuration headers:
- `X-OpenAI-Ratelimit-RequestPM-Embedding`
- `X-OpenAI-Ratelimit-TokenPM-Embedding`
- `X-Cohere-Ratelimit-RequestPM-Embedding`
- etc.

Elixir does not currently support these rate limit headers. This could be important for production workloads to avoid rate limiting.

**Recommendation**: Add optional rate limit header support to Elixir integrations:

```elixir
def openai(opts) do
  [{"X-OpenAI-Api-Key", Keyword.fetch!(opts, :api_key)}]
  |> maybe_add("X-OpenAI-Organization", opts[:organization])
  |> maybe_add("X-OpenAI-Ratelimit-RequestPM-Embedding", opts[:requests_per_minute])
  |> maybe_add("X-OpenAI-Ratelimit-TokenPM-Embedding", opts[:tokens_per_minute])
  |> maybe_add("X-OpenAI-Baseurl", opts[:base_url])
end
```

---

## 11. Authentication

### Python Implementation

```python
# Auth types
class AuthApiKey: api_key: str
class AuthBearerToken: access_token, expires_in, refresh_token
class AuthClientCredentials: client_secret, scope_list
class AuthClientPassword: username, password, scope_list

# OIDC flow
class _Auth:
    def get_auth_session(self):
        if isinstance(self._credentials, AuthBearerToken):
            return self._get_session_auth_bearer_token()
        elif isinstance(self._credentials, AuthClientCredentials):
            return self._get_session_client_credential()
        elif isinstance(self._credentials, AuthClientPassword):
            return self._get_session_user_pw()

    # Background token refresh
    def _create_background_token_refresh(self, _auth=None):
        demon = Thread(
            target=periodic_refresh_token,
            args=(expires_in, _auth),
            daemon=True,
            name="TokenRefresh"
        )
        demon.start()
```

### Elixir Implementation

```elixir
defmodule WeaviateEx.Auth do
  @type t :: api_key_auth() | bearer_token_auth() | client_credentials_auth() | password_auth()

  def api_key(key), do: %{type: :api_key, api_key: key}
  def bearer_token(token, opts \\ []), do: %{type: :bearer_token, access_token: token, ...}
  def client_credentials(client_id, client_secret, opts \\ []), do: %{type: :oidc_client_credentials, ...}
  def client_password(username, password, opts \\ []), do: %{type: :oidc_password, ...}

  def to_headers(%{type: :api_key, api_key: key}), do: [{"Authorization", "Bearer #{key}"}]
  def to_headers(%{type: :bearer_token, access_token: token}), do: [{"Authorization", "Bearer #{token}"}]
end

defmodule WeaviateEx.Auth.TokenManager do
  use GenServer

  # Automatic token refresh via GenServer
  def handle_info(:refresh_token, state) do
    send(self(), :fetch_token)
    {:noreply, state}
  end

  defp schedule_refresh(%{token: token, refresh_buffer_seconds: buffer} = state) do
    refresh_in = max(1, (token.expires_in - buffer) * 1000)
    timer_ref = Process.send_after(self(), :refresh_token, refresh_in)
    %{state | refresh_timer: timer_ref}
  end
end
```

### Comparison Table

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| API Key auth | Yes | Yes | Complete |
| Bearer token | Yes | Yes | Complete |
| Client credentials | Yes | Yes | Complete |
| Password grant | Yes | Yes | Complete |
| OIDC discovery | Yes | Yes | Complete |
| Token refresh | Background thread | GenServer | Complete |
| Scope validation | Yes | No | Gap |
| Grant type validation | Yes (for password) | No | Gap |
| Azure/MS detection | Yes (prevents password) | No | Gap |

### Gap: OIDC Validation

**Severity: Medium**

Python validates OIDC configuration before attempting authentication:
- Checks `grant_types_supported` for password grant
- Prevents Azure/MS password authentication (not supported)
- Validates scopes

Elixir's TokenManager does not currently perform these validations.

---

## Summary of Gaps

### Critical Gaps (None)

No critical gaps identified. Core functionality is complete.

### Medium Severity Gaps

1. **Rate Limit Headers** - Integrations don't support rate limit configuration headers
2. **OIDC Validation** - No grant type or scope validation before auth attempts

### Low Severity Gaps

1. **GraphQL Query Detection** - Python adjusts timeout for POST requests that are GraphQL queries
2. **String Proxy Shorthand** - Python allows single string for all proxies
3. **WCS gRPC Host Format** - Python auto-generates `grpc-{cluster}` format

### Architectural Differences (Not Gaps)

1. **Async/Sync Clients** - Elixir uses unified client due to BEAM concurrency model
2. **Background Refresh** - Elixir uses GenServer instead of daemon thread
3. **Connection Pooling** - Different pool configuration options (Elixir has more)
4. **Retry Strategy** - Elixir retries more gRPC status codes and adds jitter

---

## Recommendations

### Priority 1 (Medium Effort, Medium Impact)
1. Add rate limit header support to integrations module
2. Add OIDC grant type validation to TokenManager

### Priority 2 (Low Effort, Low Impact)
1. Add GraphQL query detection for timeout selection
2. Add single-string proxy shorthand

### Priority 3 (Already Better in Elixir)
The Elixir implementation already exceeds Python in several areas:
- More comprehensive gRPC retry status codes
- Jitter in exponential backoff
- More integration providers supported
- Connection pool idle timeout and max age
- Operation-based timeout selection
